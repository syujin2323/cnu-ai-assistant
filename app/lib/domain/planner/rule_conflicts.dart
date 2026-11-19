// 규칙을 바꾸면 빈 시간에서 빠지는 확정 블록. docs/screens.md '06 AI 비서'의 카드 4(겹치는 확정 블록마다
// [옮기기]/[그대로 두기])·'12 내 규칙'(겹치는 블록 시트), docs/architecture.md '도메인 기본값과 배치 엔진'
// 5단계(새 규칙과 겹친 확정 블록은 사용자가 옮기기를 고를 때만 옮김).
//
// 아직 끝나지 않은 확정 블록마다 그 논리적 하루의 빈 시간을 바꾸기 전([before])과 뒤([after])의 배치 설정으로
// 계산하고(블록은 모두 빼고 계산), 전에는 빈 시간 하나 안에 들고 한 번에 할 최대 시간을 넘지 않았는데 뒤에는
// 그렇지 않은 블록을 고른다(최종 프로토타입). 원래 빈 시간 밖에 있던 블록은 새 규칙 때문이 아니므로 고르지 않는다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 규칙을 [before]에서 [after]로 바꾸면 빈 시간에서 빠지는 확정 블록(시작 순서). [schedule]은 그 블록들의
/// 논리적 하루를 덮는 일정이다. [now] 전에 끝난 블록은 보지 않는다.
List<PlanBlock> blocksBrokenBy(
  Schedule schedule, {
  required PlannerConfig before,
  required PlannerConfig after,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final open = Schedule(
    classSlots: schedule.classSlots,
    classExceptions: schedule.classExceptions,
    fixedBlocks: schedule.fixedBlocks,
    events: schedule.events,
    planBlocks: const [],
  );
  final free = <(bool, DateTime), List<TimeSpan>>{};
  bool fits(PlannerConfig config, PlanBlock block) {
    if (block.endAt.difference(block.startAt).inMinutes > config.maxBlockMin) {
      return false;
    }
    final day = logicalDate(block.startAt, dayBoundaryMin: dayBoundaryMin);
    final spans = free.putIfAbsent(
      (identical(config, after), day),
      () => dayAvailability(
        day,
        schedule: open,
        config: config,
        dayBoundaryMin: dayBoundaryMin,
      ).free,
    );
    return spans.any(
      (span) =>
          !span.start.isAfter(block.startAt) && !span.end.isBefore(block.endAt),
    );
  }

  return [
    for (final block in schedule.planBlocks)
      if (block.status == PlanBlockStatus.confirmed &&
          block.endAt.isAfter(now) &&
          fits(before, block) &&
          !fits(after, block))
        block,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
}
