// 미배정 할 일 목록. docs/architecture.md '도메인 기본값, 빈 시간과 여유도' 3단계.
//
// 시간이 덜 정해진 할 일(남은 시간 > 0, 완료 안 함)을 여유도가 작은 순서로 돌려준다.
// 남은 시간과 여유도는 `domain/planner/workload.dart`, 빈 시간은 `domain/free_slots.dart`가 계산한다.
// 빈 시간은 지금이 속한 논리적 하루부터 가장 늦은 마감까지(최대 배치 지평) 하루씩 이어 붙인다.

import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/planner/workload.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 미배정 할 일의 급한 정도. 여유도로 정한다(경계값은 [Defaults]의 임시값).
enum Urgency { high, medium, low }

/// 미배정 할 일 하나.
final class UnassignedTask {
  const UnassignedTask({
    required this.task,
    required this.workload,
    required this.slackMin,
    required this.urgency,
  });

  final Task task;
  final Workload workload;

  /// 여유도(분). 마감이 없으면 null이다.
  final int? slackMin;

  final Urgency urgency;

  /// 정해야 할 남은 시간(분).
  int get remainingMin => workload.toPlaceMin;

  /// 마감 전 빈 시간이 남은 시간보다 모자란지(여유도 < 0).
  bool get shortOfTime => (slackMin ?? 0) < 0;
}

/// 미배정 할 일을 여유도가 작은 순서로 돌려준다. 같으면 마감이 이른 것, 그래도 같으면 남은
/// 시간이 큰 것부터다. 마감이 없는 할 일은 맨 뒤다.
List<UnassignedTask> unassignedTasks(
  CalendarData data, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final config = PlannerConfig.from(data.rules);
  final lmsByKey = {for (final item in data.lmsItems) item.remoteKey: item};
  final todo = [
    for (final task in data.tasks)
      if (task.status == TaskStatus.todo)
        (
          task: task,
          item: lmsByKey[task.lmsKey],
          workload: workloadOf(
            task,
            item: lmsByKey[task.lmsKey],
            config: config,
            blocks: data.schedule.planBlocks,
            now: now,
          ),
        ),
  ].where((t) => t.workload.toPlaceMin > 0).toList();
  if (todo.isEmpty) return const [];

  final free = _freeUntilLastDue(
    data,
    config: config,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
    dues: todo.map((t) => t.task.dueAt).whereType<DateTime>(),
  );
  final result = [
    for (final t in todo)
      _withSlack(
        t.task,
        t.workload,
        slackMin(
          t.task,
          item: t.item,
          workload: t.workload,
          free: free,
          now: now,
        ),
      ),
  ];
  result.sort((a, b) {
    final slackA = a.slackMin, slackB = b.slackMin;
    if (slackA == null || slackB == null) {
      if (slackA != slackB) return slackA == null ? 1 : -1;
    } else if (slackA != slackB) {
      return slackA.compareTo(slackB);
    }
    final dueA = a.task.dueAt, dueB = b.task.dueAt;
    if (dueA != null && dueB != null && dueA != dueB) {
      return dueA.compareTo(dueB);
    }
    return b.remainingMin.compareTo(a.remainingMin);
  });
  return result;
}

/// 오늘 해야 할 미배정 할 일: 마감이 다음 논리적 하루가 끝나기 전이거나 등급이 높음인 것.
List<UnassignedTask> todayUnassigned(
  List<UnassignedTask> all, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final tomorrowEnd = DateTime(
    today.year,
    today.month,
    today.day + 2,
  ).add(Duration(minutes: dayBoundaryMin));
  return [
    for (final u in all)
      if (u.urgency == Urgency.high ||
          (u.task.dueAt != null && u.task.dueAt!.isBefore(tomorrowEnd)))
        u,
  ];
}

UnassignedTask _withSlack(Task task, Workload workload, int? slack) {
  final urgency = slack == null
      ? Urgency.low
      : slack < Defaults.urgencyHighSlackMin
      ? Urgency.high
      : slack < Defaults.urgencyMediumSlackMin
      ? Urgency.medium
      : Urgency.low;
  return UnassignedTask(
    task: task,
    workload: workload,
    slackMin: slack,
    urgency: urgency,
  );
}

List<TimeSpan> _freeUntilLastDue(
  CalendarData data, {
  required PlannerConfig config,
  required DateTime now,
  required int dayBoundaryMin,
  required Iterable<DateTime> dues,
}) {
  final first = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final lastDue = dues.isEmpty
      ? first
      : logicalDate(
          dues.reduce((a, b) => a.isAfter(b) ? a : b),
          dayBoundaryMin: dayBoundaryMin,
        );
  final days = lastDue
      .difference(first)
      .inDays
      .clamp(0, Defaults.planHorizonDays);
  return [
    for (var i = 0; i <= days; i++)
      ...freeSlots(
        DateTime(first.year, first.month, first.day + i),
        schedule: data.schedule,
        config: config,
        dayBoundaryMin: dayBoundaryMin,
      ),
  ];
}
