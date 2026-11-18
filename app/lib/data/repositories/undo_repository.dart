// 되돌리기 기록과 마지막 동작 되돌리기. docs/architecture.md '폰 DB'의 되돌리기.
//
// 동작마다 `undo_log` 한 행을 덮어쓴다. 다른 저장소는 동작의 트랜잭션 안에서 [UndoRecorder]로 바뀌는 행의
// 직전 값을 모으고, 같은 트랜잭션 끝에 [UndoRecorder.write]로 남긴다. [UndoRepository.undoLast]는 그
// 단계를 뒤에서부터 적용해 한 번에 되돌린다. 행 값은 폰 DB에 저장된 그대로(열 이름과 SQL 값) 담고
// 되살리므로 표마다 직렬화 코드를 두지 않는다. 되살리기는 `INSERT … ON CONFLICT ("id") DO UPDATE`라
// 행을 지웠다 다시 넣지 않는다(자식 행의 외래 키를 건드리지 않음).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart';

/// 되돌릴 수 있는 표. docs/architecture.md '폰 DB'의 되돌리기 대상과 같다. `courses`는 수업 시트의
/// [직접 입력]으로 수업과 함께 만든 과목을 그 동작과 함께 지울 때만 쓴다(`ClassSlotRepository`).
const Set<String> undoableTables = {
  'courses',
  'events',
  'tasks',
  'fixed_blocks',
  'plan_blocks',
  'class_slots',
  'class_exceptions',
  'rules',
};

/// 되돌리기 기록 하나를 가리킨다: 그 동작의 요약 표([table])와 그 동작에 넘긴 시각([at], 밀리초까지 견줌).
final class UndoMark {
  const UndoMark(this.table, this.at);

  final String table;
  final DateTime at;

  /// [entry]가 이 동작의 기록인지.
  bool matches(UndoLogEntry entry) =>
      entry.targetTable == table &&
      entry.createdAt.millisecondsSinceEpoch == at.millisecondsSinceEpoch;
}

/// 한 동작에서 바뀌는 행의 직전 값을 모은다.
///
/// 저장소는 트랜잭션 안에서 행을 고치거나 지우기 전에 [before]를, 새 행을 넣은 뒤 [inserted]를 부르고,
/// 같은 트랜잭션 끝에 [write]로 `undo_log`를 덮어쓴다. 한 행은 처음 담은 값만 남긴다.
class UndoRecorder {
  UndoRecorder(this._db);

  final AppDatabase _db;
  final List<UndoStep> _steps = [];
  final Set<(String, int)> _rows = {};

  /// [table]의 [id] 행을 고치거나 지우기 전에 부른다. 행이 없으면 담지 않는다.
  Future<void> before(String table, int id) async {
    _checkTable(table);
    if (!_rows.add((table, id))) return;
    final row = await _db
        .customSelect(
          'SELECT * FROM "$table" WHERE "id" = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      _rows.remove((table, id));
      return;
    }
    _steps.add(UndoRestore(table, row.data));
  }

  /// [table]의 [id] 행에서 [columns](SQL 열 이름)만 고치기 전에 부른다. 되돌리면 그 열만 직전 값으로
  /// 돌리고 나머지 열은 지금 값을 둔다. 동기화가 다른 열을 바꾸는 표(`tasks`)의 사용자 열에 쓴다.
  /// 행이 없으면 담지 않는다. [columns]가 비었거나 `id`를 담으면 [ArgumentError]다.
  Future<void> beforeColumns(String table, int id, Set<String> columns) async {
    _checkTable(table);
    if (columns.isEmpty || columns.contains('id')) {
      throw ArgumentError.value(columns, 'columns');
    }
    if (!_rows.add((table, id))) return;
    final names = columns.map((column) => '"$column"').join(', ');
    final row = await _db
        .customSelect(
          'SELECT $names FROM "$table" WHERE "id" = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      _rows.remove((table, id));
      return;
    }
    _steps.add(UndoPatch(table, id, Map.of(row.data)));
  }

  /// [table]에 새로 넣은 [id] 행을 담는다(되돌리면 지운다).
  void inserted(String table, int id) {
    _checkTable(table);
    if (_rows.add((table, id))) _steps.add(UndoDelete(table, id));
  }

  /// 모은 단계로 `undo_log`를 덮어쓴다. [table]·[action]은 그 동작의 요약이고, 바뀐 행이 하나면 그
  /// id를, 여럿이면 null을 `rowId`로 적는다. 담은 것이 없으면 이전 기록을 지운다(다음 동작이 오면
  /// 이전 동작은 되돌리지 않는다).
  Future<void> write({
    required String table,
    required UndoAction action,
    required DateTime now,
  }) async {
    if (_steps.isEmpty) {
      await _db.delete(_db.undoLog).go();
      return;
    }
    await _db
        .into(_db.undoLog)
        .insertOnConflictUpdate(
          UndoLogCompanion.insert(
            targetTable: table,
            action: action,
            rowId: Value(_rows.length == 1 ? _rows.single.$2 : null),
            beforeJson: Value(encodeUndoSteps(_steps)),
            createdAt: now,
          ),
        );
  }

  static void _checkTable(String table) {
    if (!undoableTables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'not undoable');
    }
  }
}

/// [mark]가 가리키는 동작이 아직 마지막 기록이면, 그 기록에 [table]의 [id] 행 [columns](SQL 열 이름)의 지금 값을
/// 더하고(되돌리면 그 열도 지금 값으로 돌아감) 기록 시각을 [now]로 옮긴 뒤 true다. 시트를 거쳐 끝나는 동작(03 할 일의
/// 끝내기 → '얼마나 걸렸어요?')의 뒤쪽 쓰기를 같은 되돌리기로 묶고, 토스트의 10초가 동작이 끝난 때부터 시작하게
/// 하려는 것이다. 그 행을 이미 통째로 되살리거나 지우는 기록이면 열을 더하지 않는다. 마지막 기록이 다른 동작이거나
/// 읽을 수 없거나 행이 없으면 아무것도 바꾸지 않고 false다. 같은 트랜잭션 안에서 그 열을 고치기 전에 부른다.
Future<bool> amendUndo(
  AppDatabase db,
  UndoMark mark, {
  required String table,
  required int id,
  Set<String> columns = const {},
  required DateTime now,
}) async {
  UndoRecorder._checkTable(table);
  if (columns.contains('id')) throw ArgumentError.value(columns, 'columns');
  final entry = await db.select(db.undoLog).getSingleOrNull();
  final json = entry?.beforeJson;
  if (entry == null || json == null || !mark.matches(entry)) return false;
  final List<UndoStep> steps;
  try {
    steps = [...decodeUndoSteps(json)];
  } on FormatException {
    return false;
  }
  if (columns.isNotEmpty) {
    final names = columns.map((column) => '"$column"').join(', ');
    final row = await db
        .customSelect(
          'SELECT $names FROM "$table" WHERE "id" = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    if (row == null) return false;
    final covered = steps.any(
      (step) => switch (step) {
        UndoRestore(:final row) => step.table == table && row['id'] == id,
        UndoDelete(id: final deleted) => step.table == table && deleted == id,
        UndoPatch() => false,
      },
    );
    final patch = steps.indexWhere(
      (step) => step is UndoPatch && step.table == table && step.id == id,
    );
    if (patch >= 0) {
      // 앞서 담은 값이 그 동작 전의 값이므로 겹치는 열은 그것을 둔다.
      steps[patch] = UndoPatch(table, id, {
        ...row.data,
        ...(steps[patch] as UndoPatch).values,
      });
    } else if (!covered) {
      steps.add(UndoPatch(table, id, Map.of(row.data)));
    }
  }
  await (db.update(db.undoLog)..where((log) => log.id.equals(entry.id))).write(
    UndoLogCompanion(
      beforeJson: Value(encodeUndoSteps(steps)),
      createdAt: Value(now),
    ),
  );
  return true;
}

/// 마지막 동작을 되돌리는 저장소. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.
class UndoRepository {
  UndoRepository(this._db);

  final AppDatabase _db;

  /// 마지막 동작을 되돌린다. 되돌렸으면 true다. 기록이 없거나, [Defaults.undoWindow]가 지났거나
  /// (기기 시각이 기록보다 이르면 지난 것으로 봄), 기록을 읽을 수 없으면 기록을 버리고 false다.
  ///
  /// [only]를 주면 마지막 기록이 그 동작일 때만 되돌리고 시간은 보지 않는다(02 홈 피드백 카드의 답은 화면을
  /// 떠날 때까지 카드 안 [되돌리기]로 돌린다, docs/screens.md '되돌리기'). 그 뒤에 다른 동작이 기록을
  /// 덮어썼으면 그 기록은 그대로 두고 false다.
  Future<Result<bool>> undoLast({required DateTime now, UndoMark? only}) async {
    final UndoLogEntry? entry;
    switch (await guardStorage(
      'undo.read',
      () => _db.select(_db.undoLog).getSingleOrNull(),
    )) {
      case Ok(:final value):
        entry = value;
      case Err(:final error):
        return Err(error);
    }
    if (entry == null) return const Ok(false);
    if (only != null && !only.matches(entry)) return const Ok(false);
    final steps = _stepsToApply(entry, now, timed: only == null);
    if (steps == null) {
      return switch (await discard()) {
        Ok() => const Ok(false),
        Err(:final error) => Err(error),
      };
    }
    return guardStorage(
      'undo.apply',
      () => _db.transaction(() async {
        for (final step in steps.reversed) {
          await _apply(step);
        }
        await _db.delete(_db.undoLog).go();
        return true;
      }),
    );
  }

  /// 기록을 버린다. 되돌리기를 받지 않게 된 때(화면을 떠남 등) 부른다. [only]를 주면 마지막 기록이 그
  /// 동작일 때만 버린다(그 뒤 다른 동작의 기록은 남김).
  Future<Result<void>> discard({UndoMark? only}) =>
      guardStorage('undo.discard', () async {
        if (only != null) {
          final entry = await _db.select(_db.undoLog).getSingleOrNull();
          if (entry == null || !only.matches(entry)) return;
        }
        await _db.delete(_db.undoLog).go();
      });

  /// [entry]에서 적용할 단계. [timed]면 시간이 지난 기록도 null이고, 읽을 수 없으면 null이다.
  List<UndoStep>? _stepsToApply(
    UndoLogEntry entry,
    DateTime now, {
    required bool timed,
  }) {
    final age = now.difference(entry.createdAt);
    if (timed && (age.isNegative || age > Defaults.undoWindow)) return null;
    final json = entry.beforeJson;
    if (json == null) return null;
    try {
      final steps = decodeUndoSteps(json);
      steps.forEach(_checkStep);
      return steps;
    } on FormatException {
      appLog('undo_log_unreadable', area: 'storage');
      return null;
    }
  }

  /// 표와 열이 이 DB에 있는지 본다. 아니면 [FormatException]이다.
  void _checkStep(UndoStep step) {
    if (!undoableTables.contains(step.table)) {
      throw const FormatException('undo step table');
    }
    final columns = _table(step.table).columnsByName.keys.toSet();
    final ok = switch (step) {
      UndoDelete() => true,
      UndoRestore(:final row) =>
        row.keys.toSet().containsAll(columns) &&
            columns.containsAll(row.keys) &&
            row['id'] is int,
      UndoPatch(:final values) =>
        !values.containsKey('id') && columns.containsAll(values.keys),
    };
    if (!ok) throw const FormatException('undo step columns');
  }

  Future<void> _apply(UndoStep step) async {
    final table = _table(step.table);
    final name = '"${step.table}"';
    switch (step) {
      case UndoDelete(:final id):
        if (step.table == 'tasks') await _deleteGeneratedBlocks(id);
        await _db.customUpdate(
          'DELETE FROM $name WHERE "id" = ?',
          variables: [Variable.withInt(id)],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
      case UndoRestore(:final row):
        final columns = row.keys.toList();
        final updates = [
          for (final column in columns)
            if (column != 'id') '"$column" = excluded."$column"',
        ];
        await _db.customUpdate(
          'INSERT INTO $name (${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')}) '
          'ON CONFLICT ("id") DO UPDATE SET ${updates.join(', ')}',
          variables: [for (final column in columns) Variable(row[column])],
          updates: {table},
          updateKind: UpdateKind.update,
        );
      case UndoPatch(:final id, :final values):
        final columns = values.keys.toList();
        await _db.customUpdate(
          'UPDATE $name SET ${columns.map((c) => '"$c" = ?').join(', ')} '
          'WHERE "id" = ?',
          variables: [
            for (final column in columns) Variable(values[column]),
            Variable.withInt(id),
          ],
          updates: {table},
          updateKind: UpdateKind.update,
        );
    }
  }

  /// 넣은 할 일 [taskId]를 되돌려 지우기 전에, 그사이 재계산이 만든 그 할 일의 제안·지운 블록을 지운다.
  ///
  /// 할 일을 넣으면 재계산(`app/plan_controller.dart`, 300ms 뒤)이 그 할 일의 제안 블록을 만드는데, 재계산은
  /// 되돌리기 기록을 남기지 않으므로 넣기의 기록이 그대로 마지막 동작이다. 블록의 외래 키는 기본 동작(NO
  /// ACTION)이라 남은 블록이 있으면 할 일을 지울 수 없어 되돌리기가 실패한다. 확정·완료·놓친 블록은 사용자의
  /// 동작이라 그 기록이 넣기의 기록을 덮어쓰므로 여기서는 지우지 않는다(남아 있으면 지우기가 실패한다).
  Future<void> _deleteGeneratedBlocks(int taskId) => _db.customUpdate(
    'DELETE FROM "plan_blocks" WHERE "task_id" = ? AND "status" IN (?, ?)',
    variables: [
      Variable.withInt(taskId),
      Variable.withString(PlanBlockStatus.suggested.name),
      Variable.withString(PlanBlockStatus.dismissed.name),
    ],
    updates: {_db.planBlocks},
    updateKind: UpdateKind.delete,
  );

  TableInfo<Table, Object?> _table(String name) =>
      _db.allTables.firstWhere((table) => table.actualTableName == name);
}
