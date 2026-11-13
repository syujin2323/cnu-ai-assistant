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
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart';

/// 되돌릴 수 있는 표. docs/architecture.md '폰 DB'의 되돌리기 대상과 같다.
const Set<String> undoableTables = {
  'events',
  'tasks',
  'fixed_blocks',
  'plan_blocks',
  'class_slots',
  'class_exceptions',
  'rules',
};

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

/// 마지막 동작을 되돌리는 저장소. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.
class UndoRepository {
  UndoRepository(this._db);

  final AppDatabase _db;

  /// 마지막 동작을 되돌린다. 되돌렸으면 true다. 기록이 없거나, [Defaults.undoWindow]가 지났거나
  /// (기기 시각이 기록보다 이르면 지난 것으로 봄), 기록을 읽을 수 없으면 기록을 버리고 false다.
  Future<Result<bool>> undoLast({required DateTime now}) async {
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
    final steps = _stepsToApply(entry, now);
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

  /// 기록을 버린다. 되돌리기를 받지 않게 된 때(화면을 떠남 등) 부른다.
  Future<Result<void>> discard() =>
      guardStorage('undo.discard', () => _db.delete(_db.undoLog).go());

  /// [entry]에서 적용할 단계. 시간이 지났거나 읽을 수 없으면 null이다.
  List<UndoStep>? _stepsToApply(UndoLogEntry entry, DateTime now) {
    final age = now.difference(entry.createdAt);
    if (age.isNegative || age > Defaults.undoWindow) return null;
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

  Future<void> _apply(UndoStep step) {
    final table = _table(step.table);
    final name = '"${step.table}"';
    switch (step) {
      case UndoDelete(:final id):
        return _db.customUpdate(
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
        return _db.customUpdate(
          'INSERT INTO $name (${columns.map((c) => '"$c"').join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')}) '
          'ON CONFLICT ("id") DO UPDATE SET ${updates.join(', ')}',
          variables: [for (final column in columns) Variable(row[column])],
          updates: {table},
          updateKind: UpdateKind.update,
        );
      case UndoPatch(:final id, :final values):
        final columns = values.keys.toList();
        return _db.customUpdate(
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

  TableInfo<Table, Object?> _table(String name) =>
      _db.allTables.firstWhere((table) => table.actualTableName == name);
}
