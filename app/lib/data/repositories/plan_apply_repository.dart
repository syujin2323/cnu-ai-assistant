// 재계산 결과를 폰 DB에 쓰는 저장소(`plan_blocks` 표). docs/architecture.md '도메인 기본값과 배치 엔진' 4–5단계.
//
// 재계산 서비스(`data/plan_recalculator.dart`)가 배치 엔진의 제안을 넘기면 한 트랜잭션에서 세 가지를 한다.
// 1. 놓침 판정: 끝나고 [Defaults.missedAfterMin]분이 지나도 완료가 아닌 확정 블록을 놓침으로 바꾼다. 그 할 일이
//    이미 끝났으면(앱에서 끝냄, LMS 제출·출석 인정) 놓침으로 남기지 않고 지운다.
// 2. 지운 블록 정리: 그 논리적 하루가 끝난 지운 블록을 없앤다.
// 3. 제안 바꿔 끼우기: 새 제안과 같은 자리(할 일·시작·끝)의 제안은 두고 근거만 고치며, 나머지 제안은 지우고 새
//    제안을 넣는다. 블록 id가 이유 없이 바뀌지 않게 하려는 것이다.
// 사용자의 동작이 아니므로 되돌리기 기록을 남기지 않는다. 바꿀 것이 없으면 아무 문장도 실행하지 않아 표 바뀜
// 알림이 생기지 않는다(재계산이 자기 쓰기 때문에 다시 불리며 끝없이 돌지 않게). 상태를 고르는 조건은 저장된 값으로
// 견준다(docs/architecture.md '폰 DB'의 '모르는 값'). 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:drift/drift.dart';

/// 재계산 결과를 쓰는 저장소.
class PlanApplyRepository {
  PlanApplyRepository(this._db);

  final AppDatabase _db;

  /// [suggestions]로 제안을 바꿔 끼우고 놓침 판정·지운 블록 정리를 한다. [doneTaskIds]는 끝난 할 일이다(놓친 확정
  /// 블록을 지울지 가름). 무엇이든 바꿨으면 true다.
  Future<Result<bool>> apply({
    required List<BlockDraft> suggestions,
    required Set<int> doneTaskIds,
    required DateTime now,
    required int dayBoundaryMin,
  }) => guardStorage(
    'plan_blocks.apply',
    () => _db.transaction(() async {
      final blocks = _db.planBlocks;
      var changed = false;

      // 1. 놓침 판정.
      final cutoff = now.subtract(
        const Duration(minutes: Defaults.missedAfterMin),
      );
      final ended =
          await (_db.selectOnly(blocks)
                ..addColumns([blocks.id, blocks.taskId])
                ..where(
                  blocks.status.equalsValue(PlanBlockStatus.confirmed) &
                      blocks.endAt.isSmallerOrEqualValue(kstToUtc(cutoff)),
                ))
              .get();
      final gone = <int>[];
      final missed = <int>[];
      for (final row in ended) {
        final id = row.read(blocks.id)!;
        (doneTaskIds.contains(row.read(blocks.taskId)) ? gone : missed).add(id);
      }
      if (missed.isNotEmpty) {
        await (_db.update(blocks)..where((b) => b.id.isIn(missed))).write(
          const PlanBlocksCompanion(status: Value(PlanBlockStatus.missed)),
        );
        changed = true;
      }

      // 2. 지운 블록 정리.
      final dismissed =
          await (_db.selectOnly(blocks)
                ..addColumns([blocks.id, blocks.startAt])
                ..where(blocks.status.equalsValue(PlanBlockStatus.dismissed)))
              .get();
      for (final row in dismissed) {
        final day = logicalDate(
          row.readWithConverter<DateTime, DateTime>(blocks.startAt)!,
          dayBoundaryMin: dayBoundaryMin,
        );
        if (!logicalDayEnd(day, dayBoundaryMin: dayBoundaryMin).isAfter(now)) {
          gone.add(row.read(blocks.id)!);
        }
      }

      // 3. 제안 바꿔 끼우기.
      final existing =
          await (_db.selectOnly(blocks)
                ..addColumns([
                  blocks.id,
                  blocks.taskId,
                  blocks.startAt,
                  blocks.endAt,
                  blocks.reason,
                ])
                ..where(blocks.status.equalsValue(PlanBlockStatus.suggested)))
              .get();
      final kept = <(int, DateTime, DateTime), ({int id, String? reason})>{};
      for (final row in existing) {
        final key = (
          row.read(blocks.taskId)!,
          row.readWithConverter<DateTime, DateTime>(blocks.startAt)!,
          row.readWithConverter<DateTime, DateTime>(blocks.endAt)!,
        );
        final id = row.read(blocks.id)!;
        if (kept.containsKey(key)) {
          gone.add(id);
        } else {
          kept[key] = (id: id, reason: row.read(blocks.reason));
        }
      }
      final inserts = <BlockDraft>[];
      for (final draft in suggestions) {
        final match = kept.remove((draft.taskId, draft.startAt, draft.endAt));
        if (match == null) {
          inserts.add(draft);
          continue;
        }
        final reason = draft.reason == null
            ? null
            : jsonEncode(draft.reason!.toJson());
        if (match.reason != reason) {
          await (_db.update(blocks)..where((b) => b.id.equals(match.id))).write(
            PlanBlocksCompanion(reason: Value(draft.reason)),
          );
          changed = true;
        }
      }
      gone.addAll([for (final stale in kept.values) stale.id]);
      if (gone.isNotEmpty) {
        await (_db.delete(blocks)..where((b) => b.id.isIn(gone))).go();
        changed = true;
      }
      for (final draft in inserts) {
        await _db
            .into(blocks)
            .insert(
              PlanBlocksCompanion.insert(
                taskId: draft.taskId,
                startAt: draft.startAt,
                endAt: draft.endAt,
                status: PlanBlockStatus.suggested,
                source: draft.source,
                reason: Value(draft.reason),
              ),
            );
        changed = true;
      }
      return changed;
    }),
  );
}
