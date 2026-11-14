// 할 일 블록 저장소(`plan_blocks` 표). docs/architecture.md '도메인 기본값과 배치 엔진' 5단계, docs/screens.md
// '제안과 확정'·'옮기기 시트'·'빈 시간에 놓기 시트'·'02 홈'(피드백 카드).
//
// 사용자의 블록 동작(확정·직접 놓기·옮기기·지우기·완료·피드백 답)과 01 아침 브리핑의 확정 교체를 한 트랜잭션에서
// 하고 되돌리기 기록을 남긴다. 상태를 고르는 조건은 읽은 값이 아니라 저장된 값으로 견준다(모르는 값은
// `dismissed`로 읽히므로, docs/architecture.md '폰 DB'의 '모르는 값'). 블록을 완료하면 그 길이를 할 일의
// 한 만큼(`spentMin`)에 더하고 완료를 끄면 뺀다. 제안 블록을 다시 만드는 재계산과 놓침 판정은 배치 엔진
// 쪽이 한다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart';

/// 할 일 블록 저장소.
class PlanBlockRepository {
  PlanBlockRepository(this._db);

  final AppDatabase _db;

  static const _table = 'plan_blocks';

  /// 제안 블록을 엔진 자리 그대로 확정한다(근거 유지. 근거 시트 [확정], 09 일간 '모두 확정', 02 홈 빈 시간
  /// 없음 카드). 제안이 아닌 블록은 건너뛰고, 하나라도 확정했으면 true다.
  Future<Result<bool>> confirm(List<int> ids, {required DateTime now}) =>
      guardStorage(
        'plan_blocks.confirm',
        () => _db.transaction(() async {
          final suggested =
              await (_db.select(_db.planBlocks)..where(
                    (b) =>
                        b.id.isIn(ids) &
                        b.status.equalsValue(PlanBlockStatus.suggested),
                  ))
                  .get();
          if (suggested.isEmpty) return false;
          final undo = UndoRecorder(_db);
          for (final block in suggested) {
            await undo.before(_table, block.id);
          }
          await (_db.update(_db.planBlocks)..where(
                (b) => b.id.isIn([for (final block in suggested) block.id]),
              ))
              .write(
                const PlanBlocksCompanion(
                  status: Value(PlanBlockStatus.confirmed),
                ),
              );
          await undo.write(table: _table, action: UndoAction.update, now: now);
          return true;
        }),
      );

  /// 할 일 [taskId]를 [start]–[end]에 직접 정한 확정 블록으로 놓고 id를 돌려준다(빈 시간에 놓기 시트,
  /// 02 홈 [다시 놓기]). 할 일이 없으면 null이다. [end]가 [start]보다 늦지 않으면 [ArgumentError]다.
  Future<Result<int?>> place({
    required int taskId,
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    _checkSpan(start, end);
    return guardStorage(
      'plan_blocks.place',
      () => _db.transaction(() async {
        if (!await _taskExists(taskId)) return null;
        final id = await _insert(
          BlockDraft(
            taskId: taskId,
            startAt: start,
            endAt: end,
            source: BlockSource.manual,
          ),
          status: PlanBlockStatus.confirmed,
        );
        final undo = UndoRecorder(_db)..inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 블록을 [start]–[end]로 옮겨 직접 정한 확정 블록으로 두고 그 id를 돌려준다(옮기기 시트, 02 홈 끌어
  /// 옮기기). 제안 블록이면 그 자리를 지운 자리로 남기고 새 확정 블록을 만들고, 확정 블록이면 그 블록의
  /// 시각을 바꾼다. 다른 상태이거나 블록이 없으면 null이다. [end]가 [start]보다 늦지 않으면
  /// [ArgumentError]다.
  Future<Result<int?>> move(
    int id, {
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) {
    _checkSpan(start, end);
    return guardStorage(
      'plan_blocks.move',
      () => _db.transaction(() async {
        final block = await _storedWithStatus(id, const {
          PlanBlockStatus.suggested,
          PlanBlockStatus.confirmed,
        });
        if (block == null) return null;
        final undo = UndoRecorder(_db);
        await undo.before(_table, id);
        final int movedId;
        if (block.status == PlanBlockStatus.suggested) {
          await _setStatus(id, PlanBlockStatus.dismissed);
          movedId = await _insert(
            BlockDraft(
              taskId: block.taskId,
              startAt: start,
              endAt: end,
              source: BlockSource.manual,
            ),
            status: PlanBlockStatus.confirmed,
          );
          undo.inserted(_table, movedId);
        } else {
          await (_db.update(
            _db.planBlocks,
          )..where((b) => b.id.equals(id))).write(
            PlanBlocksCompanion(
              startAt: Value(start),
              endAt: Value(end),
              source: const Value(BlockSource.manual),
              reason: const Value(null),
            ),
          );
          movedId = id;
        }
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return movedId;
      }),
    );
  }

  /// 블록을 지운다. 지운 자리는 그 논리적 하루에 그 할 일에 다시 제안하지 않는다. 제안·확정 블록만
  /// 지우고, 다른 상태이거나 없으면 false다.
  Future<Result<bool>> dismiss(int id, {required DateTime now}) => guardStorage(
    'plan_blocks.dismiss',
    () => _db.transaction(() async {
      final block = await _storedWithStatus(id, const {
        PlanBlockStatus.suggested,
        PlanBlockStatus.confirmed,
      });
      if (block == null) return false;
      final undo = UndoRecorder(_db);
      await undo.before(_table, id);
      await _setStatus(id, PlanBlockStatus.dismissed);
      await undo.write(table: _table, action: UndoAction.update, now: now);
      return true;
    }),
  );

  /// 블록을 완료로 바꾸고 그 길이를 할 일의 한 만큼에 더한다(블록 체크). 확정·놓침 블록만 완료하고,
  /// 다른 상태이거나 없으면 false다.
  Future<Result<bool>> complete(int id, {required DateTime now}) =>
      guardStorage(
        'plan_blocks.complete',
        () => _db.transaction(() async {
          final block = await _storedWithStatus(id, const {
            PlanBlockStatus.confirmed,
            PlanBlockStatus.missed,
          });
          if (block == null) return false;
          final undo = UndoRecorder(_db);
          await _markDone(block, undo);
          await undo.write(table: _table, action: UndoAction.update, now: now);
          return true;
        }),
      );

  /// 블록 완료를 끈다. 확정으로 돌리고 할 일의 한 만큼에서 그 길이를 뺀다(0 아래로 내리지 않음). 완료
  /// 블록만 되돌리고, 다른 상태이거나 없으면 false다.
  Future<Result<bool>> uncomplete(int id, {required DateTime now}) =>
      guardStorage(
        'plan_blocks.uncomplete',
        () => _db.transaction(() async {
          final block = await _storedWithStatus(id, const {
            PlanBlockStatus.done,
          });
          if (block == null) return false;
          final undo = UndoRecorder(_db);
          await undo.before(_table, id);
          await _setStatus(id, PlanBlockStatus.confirmed);
          await _addSpent(block.taskId, -_minutes(block), undo);
          await undo.write(table: _table, action: UndoAction.update, now: now);
          return true;
        }),
      );

  /// 02 홈 피드백 카드의 답. [did]면 완료로 바꾸고 한 만큼에 더하며(놓침이 된 블록도), 아니면 놓침으로
  /// 바꾼다. 어느 쪽이든 답한 시각을 [now]로 적는다. 확정·놓침 블록만 받고, 다른 상태이거나 없으면
  /// false다.
  Future<Result<bool>> answer(
    int id, {
    required bool did,
    required DateTime now,
  }) => guardStorage(
    'plan_blocks.answer',
    () => _db.transaction(() async {
      final block = await _storedWithStatus(id, const {
        PlanBlockStatus.confirmed,
        PlanBlockStatus.missed,
      });
      if (block == null) return false;
      final undo = UndoRecorder(_db);
      if (did) {
        await _markDone(block, undo);
      } else {
        await undo.before(_table, id);
        await _setStatus(id, PlanBlockStatus.missed);
      }
      await (_db.update(_db.planBlocks)..where((b) => b.id.equals(id))).write(
        PlanBlocksCompanion(answeredAt: Value(now)),
      );
      await undo.write(table: _table, action: UndoAction.update, now: now);
      return true;
    }),
  );

  /// 01 아침 브리핑의 'N개 확정하기'. [dayStart]–[dayEnd](그날 논리적 하루) 안에서 [now]보다 늦게 시작하는
  /// 확정 블록 가운데 엔진 자리 그대로 확정한 것(`source` `auto`)과 전에 브리핑에서 확정한 것을 지우고,
  /// [drafts]를 브리핑에서 확정한 블록으로 넣는다(한 번에 되돌림). 넣은 블록의 id를 돌려준다. 초안의 끝이
  /// 시작보다 늦지 않으면 [ArgumentError]다.
  Future<Result<List<int>>> confirmFromBriefing({
    required DateTime dayStart,
    required DateTime dayEnd,
    required List<BlockDraft> drafts,
    required DateTime now,
  }) {
    _checkSpan(dayStart, dayEnd);
    for (final draft in drafts) {
      _checkSpan(draft.startAt, draft.endAt);
    }
    return guardStorage(
      'plan_blocks.confirmFromBriefing',
      () => _db.transaction(() async {
        final from = kstToUtc(now.isAfter(dayStart) ? now : dayStart);
        final replaced =
            await (_db.select(_db.planBlocks)..where(
                  (b) =>
                      b.status.equalsValue(PlanBlockStatus.confirmed) &
                      (b.source.equalsValue(BlockSource.auto) |
                          b.fromBriefing.equals(true)) &
                      b.startAt.isBiggerThanValue(from) &
                      b.startAt.isSmallerThanValue(kstToUtc(dayEnd)),
                ))
                .get();
        final undo = UndoRecorder(_db);
        for (final block in replaced) {
          await undo.before(_table, block.id);
        }
        if (replaced.isNotEmpty) {
          await (_db.delete(_db.planBlocks)..where(
                (b) => b.id.isIn([for (final block in replaced) block.id]),
              ))
              .go();
        }
        final ids = <int>[];
        for (final draft in drafts) {
          final id = await _insert(
            draft,
            status: PlanBlockStatus.confirmed,
            fromBriefing: true,
          );
          undo.inserted(_table, id);
          ids.add(id);
        }
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return ids;
      }),
    );
  }

  /// 저장된 상태가 [statuses] 가운데 하나인 블록. 없거나 다른 상태면 null이다.
  Future<PlanBlock?> _storedWithStatus(int id, Set<PlanBlockStatus> statuses) =>
      (_db.select(_db.planBlocks)
            ..where((b) => b.id.equals(id) & b.status.isInValues(statuses)))
          .getSingleOrNull();

  Future<bool> _taskExists(int taskId) async =>
      await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(taskId))).getSingleOrNull() !=
      null;

  Future<int> _insert(
    BlockDraft draft, {
    required PlanBlockStatus status,
    bool fromBriefing = false,
  }) => _db
      .into(_db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: draft.taskId,
          startAt: draft.startAt,
          endAt: draft.endAt,
          status: status,
          source: draft.source,
          reason: Value(draft.reason),
          fromBriefing: Value(fromBriefing),
        ),
      );

  Future<void> _setStatus(int id, PlanBlockStatus status) =>
      (_db.update(_db.planBlocks)..where((b) => b.id.equals(id))).write(
        PlanBlocksCompanion(status: Value(status)),
      );

  Future<void> _markDone(PlanBlock block, UndoRecorder undo) async {
    await undo.before(_table, block.id);
    await _setStatus(block.id, PlanBlockStatus.done);
    await _addSpent(block.taskId, _minutes(block), undo);
  }

  /// 할 일 [taskId]의 한 만큼에 [minutes]를 더한다(빼면 0 아래로 내리지 않음).
  Future<void> _addSpent(int taskId, int minutes, UndoRecorder undo) async {
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return;
    await undo.beforeColumns('tasks', taskId, const {'spent_min'});
    final spent = (task.spentMin ?? 0) + minutes;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(spentMin: Value(spent < 0 ? 0 : spent)),
    );
  }

  static int _minutes(PlanBlock block) =>
      block.endAt.difference(block.startAt).inMinutes;

  static void _checkSpan(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }
}
