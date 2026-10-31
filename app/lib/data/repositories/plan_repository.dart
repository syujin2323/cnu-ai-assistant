import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

/// 일정 추가와 할 일 배치(확정 블록)를 쓰는 저장소. docs/architecture.md '폰 DB'의 되돌리기,
/// '도메인 기본값, 빈 시간과 여유도' 4·5단계.
///
/// 쓸 때마다 같은 트랜잭션에서 직전 상태를 `undo_log` 한 행으로 덮어쓰고(추가는 `insert`와 새 행
/// id, 상태 바꾸기는 `update`와 직전 `status`의 JSON), [undoLast]는 [undoWindow] 안의 마지막 동작 하나만 되살린다. 실패하면 예외 대신
/// [StorageError]를 담은 [Err]다.
class PlanRepository {
  PlanRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// 되돌리기를 받는 시간(스낵바가 떠 있는 시간).
  static const Duration undoWindow = Duration(seconds: 10);

  /// 일정을 더하고 새 행 id를 돌려준다.
  Future<Result<int>> addEvent({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required bool allDay,
    String? place,
    required EventSource source,
  }) => _insert(
    'events',
    'plan.addEvent',
    () => _db
        .into(_db.events)
        .insert(
          EventsCompanion.insert(
            title: title,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            place: Value(place),
            source: source,
          ),
        ),
  );

  /// 할 일 [taskId]에 시간을 정한다(바로 확정 블록).
  Future<Result<int>> placeTask({
    required int taskId,
    required DateTime startAt,
    required DateTime endAt,
    required BlockSource source,
  }) => _insert(
    'plan_blocks',
    'plan.placeTask',
    () => _db
        .into(_db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: startAt,
            endAt: endAt,
            status: PlanBlockStatus.confirmed,
            source: source,
          ),
        ),
  );

  /// 확정 블록 [blockId]를 완료(`done`)로, [done]이 false면 다시 `confirmed`로 둔다.
  /// 데일리 스케줄의 To-Do 체크에 쓴다.
  Future<Result<void>> setBlockDone(int blockId, {required bool done}) =>
      _setStatus(
        'plan_blocks',
        'plan.setBlockDone',
        blockId,
        snakeName(done ? PlanBlockStatus.done : PlanBlockStatus.confirmed),
      );

  /// 할 일 [taskId]를 완료(`done`)로, [done]이 false면 다시 `todo`로 둔다.
  /// 데일리 스케줄의 To-Do에서 그날 마감인 할 일을 체크할 때 쓴다.
  Future<Result<void>> setTaskDone(int taskId, {required bool done}) =>
      _setStatus(
        'tasks',
        'plan.setTaskDone',
        taskId,
        snakeName(done ? TaskStatus.done : TaskStatus.todo),
      );

  /// 마지막 동작을 되돌린다. 되돌렸으면 true, [undoWindow]가 지났거나 기록이 없으면 false다.
  Future<Result<bool>> undoLast() async {
    try {
      return Ok(
        await _db.transaction(() async {
          final entry = await _db.select(_db.undoLog).getSingleOrNull();
          if (entry == null) return false;
          await _db.delete(_db.undoLog).go();
          final age = _clock.now().difference(entry.createdAt);
          final rowId = entry.rowId;
          if (age > undoWindow || rowId == null) return false;
          final table = _table(entry.targetTable);
          if (table == null) return false;
          if (entry.action == UndoAction.update) {
            // 상태 바꾸기는 직전 status로 돌린다.
            final before = entry.beforeJson;
            final status = before == null
                ? null
                : (jsonDecode(before) as Map<String, Object?>)['status'];
            if (status is! String) return false;
            await _db.customUpdate(
              'UPDATE ${table.actualTableName} SET status = ? WHERE id = ?',
              variables: [Variable.withString(status), Variable.withInt(rowId)],
              updates: {table},
              updateKind: UpdateKind.update,
            );
            return true;
          }
          if (entry.action != UndoAction.insert) return false;
          await _db.customUpdate(
            'DELETE FROM ${table.actualTableName} WHERE id = ?',
            variables: [Variable.withInt(rowId)],
            updates: {table},
            updateKind: UpdateKind.delete,
          );
          return true;
        }),
      );
    } on Exception catch (error) {
      return Err(
        StorageError('plan.undoLast', causeType: error.runtimeType.toString()),
      );
    }
  }

  TableInfo<Table, Object?>? _table(String name) => switch (name) {
    'events' => _db.events,
    'plan_blocks' => _db.planBlocks,
    'tasks' => _db.tasks,
    _ => null,
  };

  /// [table]의 행 [id]의 status를 [status](DB 값)로 바꾸고, 직전 status를 되돌리기 기록에 둔다.
  Future<Result<void>> _setStatus(
    String table,
    String operation,
    int id,
    String status,
  ) async {
    try {
      await _db.transaction(() async {
        final info = _table(table)!;
        final rows = await _db
            .customSelect(
              'SELECT status FROM ${info.actualTableName} WHERE id = ?',
              variables: [Variable.withInt(id)],
              readsFrom: {info},
            )
            .get();
        if (rows.isEmpty) return;
        final before = rows.single.read<String>('status');
        await _db.customUpdate(
          'UPDATE ${info.actualTableName} SET status = ? WHERE id = ?',
          variables: [Variable.withString(status), Variable.withInt(id)],
          updates: {info},
          updateKind: UpdateKind.update,
        );
        await _db
            .into(_db.undoLog)
            .insertOnConflictUpdate(
              UndoLogCompanion.insert(
                id: const Value(1),
                targetTable: table,
                action: UndoAction.update,
                rowId: Value(id),
                beforeJson: Value(jsonEncode({'status': before})),
                createdAt: _clock.now(),
              ),
            );
      });
      return const Ok(null);
    } on Exception catch (error) {
      return Err(
        StorageError(operation, causeType: error.runtimeType.toString()),
      );
    }
  }

  Future<Result<int>> _insert(
    String table,
    String operation,
    Future<int> Function() insert,
  ) async {
    try {
      return Ok(
        await _db.transaction(() async {
          final id = await insert();
          await _db
              .into(_db.undoLog)
              .insertOnConflictUpdate(
                UndoLogCompanion.insert(
                  id: const Value(1),
                  targetTable: table,
                  action: UndoAction.insert,
                  rowId: Value(id),
                  createdAt: _clock.now(),
                ),
              );
          return id;
        }),
      );
    } on Exception catch (error) {
      return Err(
        StorageError(operation, causeType: error.runtimeType.toString()),
      );
    }
  }
}
