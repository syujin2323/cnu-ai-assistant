// 할 일의 남은 작업 시간과 여유도. docs/architecture.md '도메인 기본값과 배치 엔진' 2단계.
//
// - 남은 작업 시간: 영상은 사캠 진도(인정 시간 − 시청 시간)를 쓰고, 진도가 없거나 영상이 아니면
//   예상 시간(사용자 입력 → 영상 길이 → `estimate` 규칙 → 종류별 기본값)에서 한 만큼(`spentMin`)을 뺀다.
// - 배치할 시간: 남은 작업 시간에서 그 할 일의 아직 끝나지 않은 확정 블록 길이를 뺀다.
// - 여유도: 마감 전까지 남은 빈 시간의 합 − 배치할 시간.
// 진도는 인정 시간과 시청 시간이 모두 있을 때만 쓴다(빈 값을 0으로 보지 않는다). 한 만큼이 비어 있으면
// 아직 한 것이 없다고 본다.

import 'dart:math' show max;

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 남은 작업 시간을 어디서 얻었는지.
enum EstimateSource {
  /// 사캠 진도(인정 시간 − 시청 시간).
  lmsProgress,

  /// 사용자가 이 할 일에 답한 예상 시간(`tasks.estimateMin`).
  user,

  /// 영상 길이.
  videoLength,

  /// `estimate` 규칙.
  rule,

  /// 종류별 기본값([Defaults.taskEstimateMin]). 화면이 예상 시간을 한 번 묻는다.
  kindDefault,
}

/// 할 일 하나의 작업량(분).
final class Workload {
  const Workload({
    required this.remainingMin,
    required this.toPlaceMin,
    required this.source,
  });

  /// 남은 작업 시간.
  final int remainingMin;

  /// 배치할 시간. 0이면 제안 블록을 만들지 않는다.
  final int toPlaceMin;

  final EstimateSource source;
}

/// [task]의 작업량. [item]은 `lmsKey`로 이어진 사캠 항목(직접 만든 할 일은 null)이고,
/// [blocks]는 모든 할 일의 블록이어도 된다(이 할 일의 것만 본다).
Workload workloadOf(
  Task task, {
  LmsItem? item,
  required PlannerConfig config,
  required Iterable<PlanBlock> blocks,
  required DateTime now,
}) {
  final (remaining, source) = _remaining(task, item, config);
  final pending = blocks
      .where(
        (block) =>
            block.taskId == task.id &&
            block.status == PlanBlockStatus.confirmed &&
            block.endAt.isAfter(now),
      )
      .fold(Duration.zero, (sum, block) {
        final start = block.startAt.isAfter(now) ? block.startAt : now;
        return sum + block.endAt.difference(start);
      });
  return Workload(
    remainingMin: remaining,
    toPlaceMin: max(0, remaining - pending.inMinutes),
    source: source,
  );
}

/// 여유도(분). 지금(영상은 공개 시각이 더 늦으면 공개 시각)부터 마감 전까지 [free]의 합에서
/// 배치할 시간을 뺀다. 음수면 시간이 모자란다. 마감이 없으면 null이다.
///
/// [free]는 계산 기간의 빈 구간이다(하루마다 `freeSlots`를 이어 붙인 것).
int? slackMin(
  Task task, {
  LmsItem? item,
  required Workload workload,
  required List<TimeSpan> free,
  required DateTime now,
}) {
  final dueAt = task.dueAt;
  if (dueAt == null) return null;
  final openAt = item?.openAt;
  final from = openAt != null && openAt.isAfter(now) ? openAt : now;
  return freeMinutesBetween(free, from, dueAt) - workload.toPlaceMin;
}

/// [free]에서 [from]부터 [to] 전까지 겹치는 시간의 합(분).
int freeMinutesBetween(List<TimeSpan> free, DateTime from, DateTime to) {
  var total = Duration.zero;
  for (final span in free) {
    final start = span.start.isAfter(from) ? span.start : from;
    final end = span.end.isBefore(to) ? span.end : to;
    if (end.isAfter(start)) total += end.difference(start);
  }
  return total.inMinutes;
}

(int, EstimateSource) _remaining(
  Task task,
  LmsItem? item,
  PlannerConfig config,
) {
  final isVideo = task.kind == TaskKind.video;
  final requiredMin = item?.requiredMin;
  final watchedMin = item?.watchedMin;
  if (isVideo && requiredMin != null && watchedMin != null) {
    return (max(0, requiredMin - watchedMin), EstimateSource.lmsProgress);
  }

  final videoMin = isVideo ? item?.videoMin : null;
  final ruleMin = config.estimateMin(courseId: item?.courseId, kind: task.kind);
  final (estimate, source) = switch ((task.estimateMin, videoMin, ruleMin)) {
    (final user?, _, _) => (user, EstimateSource.user),
    (_, final video?, _) => (video, EstimateSource.videoLength),
    (_, _, final rule?) => (rule, EstimateSource.rule),
    _ => (Defaults.taskEstimateMin[task.kind]!, EstimateSource.kindDefault),
  };
  return (max(0, estimate - (task.spentMin ?? 0)), source);
}
