// 02 홈 피드백 카드가 보일 것. docs/screens.md '02 홈'의 피드백 카드 표.
//
// 오늘(논리적 하루) 확정했던 블록(완료·놓침이 된 것 포함)만 보고, 표의 위에서부터 처음 맞는 하나를 고른다.
// 1·2번은 방금 한 답([HomeAnswer])으로 정하고, 그 블록의 상태가 답과 맞지 않게 바뀌었으면(되돌림, 다른 곳에서
// 바꿈) 그 답은 보지 않는다. 할 일을 찾지 못한 블록(숨긴 LMS 할 일 등)은 보지 않는다. 문구는 화면이 만든다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/placement.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';

/// 02 홈 피드백 카드에서 방금 한 답.
final class HomeAnswer {
  const HomeAnswer({required this.blockId, required this.did, this.slot});

  /// 답한 블록(`plan_blocks.id`).
  final int blockId;

  /// '했어요'·'끝냈어요'면 true, '못 했어요'면 false다.
  final bool did;

  /// '못 했어요' 뒤 [다시 놓기]가 놓을 자리(`retrySlot`). 없으면 null이다.
  final TimeSpan? slot;
}

/// 피드백 카드가 보일 것(표의 한 줄).
sealed class HomeFeedback {
  const HomeFeedback();
}

/// 1. 방금 '했어요'·'끝냈어요'로 끝낸 블록. [left]는 오늘 남은 확정 블록(시작 순서)이다.
final class FeedbackRecorded extends HomeFeedback {
  const FeedbackRecorded(this.block, {required this.left});

  final BlockItem block;
  final List<BlockItem> left;
}

/// 2. 방금 '못 했어요'로 답한 블록과 다시 놓을 자리(없으면 null).
final class FeedbackRetry extends HomeFeedback {
  const FeedbackRetry(this.block, {required this.slot});

  final BlockItem block;
  final TimeSpan? slot;
}

/// 3. 끝났는데 답하지 않은 블록(놓침이 된 것 포함). 가장 늦게 끝난 것이다.
final class FeedbackAsk extends HomeFeedback {
  const FeedbackAsk(this.block);

  final BlockItem block;
}

/// 4. 지금 하는 확정 블록.
final class FeedbackLive extends HomeFeedback {
  const FeedbackLive(this.block);

  final BlockItem block;
}

/// 5. 다음 확정 블록. [left]는 오늘 남은 확정 블록 수(이 블록 포함)다.
final class FeedbackNext extends HomeFeedback {
  const FeedbackNext(this.block, {required this.left});

  final BlockItem block;
  final int left;
}

/// 6. 오늘 블록을 모두 끝냈거나 놓쳤다. [doneMin]은 끝낸 블록의 분 합이다.
final class FeedbackAllDone extends HomeFeedback {
  const FeedbackAllDone({
    required this.done,
    required this.missed,
    required this.doneMin,
  });

  final int done;
  final int missed;
  final int doneMin;
}

/// 7. 오늘 확정한 블록이 없다. [freeMin]은 지금 뒤 오늘 남은 빈 시간(최소 조각이 들어가는 빈 구간만)의 분
/// 합이고, [nearest]는 그 가운데 가장 가까운 빈 구간(시작은 5분 단위로 올림)이다. 없으면 null이다.
final class FeedbackNone extends HomeFeedback {
  const FeedbackNone({required this.freeMin, this.nearest});

  final int freeMin;
  final TimeSpan? nearest;
}

/// [now]에 보일 피드백 카드. [blocks]는 오늘 시간표의 블록(`dayItems`, 제안·지운 블록 제외)이고, [free]는
/// 오늘의 빈 구간(`DayAvailability.free`)이며, [answer]는 방금 한 답이다.
HomeFeedback homeFeedback({
  required DateTime now,
  required List<BlockItem> blocks,
  required List<TimeSpan> free,
  HomeAnswer? answer,
}) {
  // 제안 블록은 아래 상태 조건(확정·완료·놓침)에 들지 않으므로 따로 거르지 않는다.
  final today = [
    for (final item in blocks)
      if (item.entry != null) item,
  ];
  final confirmed = [
    for (final item in today)
      if (item.block.status == PlanBlockStatus.confirmed) item,
  ];
  final left = [
    for (final item in confirmed)
      if (item.block.endAt.isAfter(now)) item,
  ]..sort(_byStart);

  if (answer != null) {
    final answered = today
        .where((item) => item.block.id == answer.blockId)
        .firstOrNull;
    final status = answered?.block.status;
    if (answered != null && answer.did && status == PlanBlockStatus.done) {
      return FeedbackRecorded(answered, left: left);
    }
    if (answered != null && !answer.did && status == PlanBlockStatus.missed) {
      return FeedbackRetry(answered, slot: answer.slot);
    }
  }

  final asks = [
    for (final item in today)
      if ((item.block.status == PlanBlockStatus.confirmed ||
              item.block.status == PlanBlockStatus.missed) &&
          item.block.answeredAt == null &&
          !item.block.endAt.isAfter(now))
        item,
  ];
  if (asks.isNotEmpty) {
    asks.sort((a, b) {
      final byEnd = b.block.endAt.compareTo(a.block.endAt);
      return byEnd != 0 ? byEnd : b.block.id.compareTo(a.block.id);
    });
    return FeedbackAsk(asks.first);
  }

  final live = [
    for (final item in left)
      if (!item.block.startAt.isAfter(now)) item,
  ];
  if (live.isNotEmpty) return FeedbackLive(live.first);
  if (left.isNotEmpty) return FeedbackNext(left.first, left: left.length);

  final done = [
    for (final item in today)
      if (item.block.status == PlanBlockStatus.done) item,
  ];
  final missed = today
      .where((item) => item.block.status == PlanBlockStatus.missed)
      .length;
  if (done.isNotEmpty || missed > 0) {
    return FeedbackAllDone(
      done: done.length,
      missed: missed,
      doneMin: done.fold(0, (sum, item) => sum + item.block.minutes),
    );
  }

  final gaps = [
    for (final span in spansFrom(free, now))
      if (span.end.difference(roundUpToFive(span.start)).inMinutes >=
          Defaults.minChunkMin)
        span,
  ];
  final first = gaps.firstOrNull;
  return FeedbackNone(
    freeMin: gaps.fold(0, (sum, span) => sum + span.minutes),
    nearest: first == null
        ? null
        : TimeSpan(roundUpToFive(first.start), first.end),
  );
}

int _byStart(BlockItem a, BlockItem b) {
  final byStart = a.block.startAt.compareTo(b.block.startAt);
  return byStart != 0 ? byStart : a.block.id.compareTo(b.block.id);
}

extension on PlanBlock {
  int get minutes => endAt.difference(startAt).inMinutes;
}
