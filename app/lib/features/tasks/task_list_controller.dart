// 03 할 일의 데이터. docs/screens.md '03 할 일'.
//
// 보일 것은 `domain/task_list.dart`의 [taskListContent]가 정하고, 여기서는 그 입력(할 일, 앞으로의 블록, 마감 변경,
// 배치 엔진의 시간 부족, 규칙, 지금 시각과 하루 경계)을 모은다. 블록은 오늘부터 [taskListBlockDays]일의 일정에서
// 읽는다(배치 지평 14일보다 넉넉히. 직접 멀리 놓은 확정 블록도 보이게).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 03 할 일이 블록을 읽는 날 수(오늘부터, 임시).
const int taskListBlockDays = 31;

/// 03 할 일의 보기: 탭(주간이면 [weekly]), 'LMS만', 정렬.
typedef TaskListView = ({bool weekly, bool lmsOnly, TaskListSort sort});

/// 논리적 하루 [day](그날 0시)부터 [taskListBlockDays]일의 일정. 03 할 일의 계획 줄과 '시간표가 있는지'에 쓴다.
/// 설정을 읽지 못하면 기본 하루 경계로 본다.
final taskListScheduleProvider = StreamProvider.family<Schedule, DateTime>((
  ref,
  day,
) {
  final boundary = ref.watch(
    settingsProvider.select(
      (settings) =>
          settings.value?.dayBoundaryMin ??
          (settings.hasError ? Defaults.dayBoundaryMin : null),
    ),
  );
  if (boundary == null) return const Stream.empty();
  final date = DateTime(day.year, day.month, day.day);
  return ref
      .watch(scheduleRepositoryProvider)
      .watch(
        start: logicalDayStart(date, dayBoundaryMin: boundary),
        end: logicalDayEnd(
          DateTime(date.year, date.month, date.day + taskListBlockDays - 1),
          dayBoundaryMin: boundary,
        ),
      );
});

/// LMS 항목마다 마지막 마감 변경 기록. 03 할 일의 '마감이 이틀 늦춰졌어요'에 쓴다.
final taskDueChangesProvider = StreamProvider<Map<String, LmsItemChange>>(
  (ref) => ref.watch(lmsItemChangeRepositoryProvider).watchLatestDueChanges(),
);

/// 03 할 일 목록. 할 일이나 규칙을 아직 읽지 못했으면 불러오는 중이고, 읽지 못했으면 오류다. 일정·마감 변경을 읽지
/// 못하면 그것 없이 그린다(블록이 없는 것으로 봄). 설정을 읽지 못하면 기본 하루 경계로 본다.
final taskListProvider =
    Provider.family<AsyncValue<TaskListContent>, TaskListView>((ref, view) {
      final now = ref.watch(minuteClockProvider);
      final settings = ref.watch(settingsProvider);
      final boundary =
          settings.value?.dayBoundaryMin ??
          (settings.hasError ? Defaults.dayBoundaryMin : null);
      if (boundary == null) return const AsyncLoading();
      final tasks = ref.watch(taskEntriesProvider);
      final rules = ref.watch(rulesProvider);
      final tasksValue = tasks.value;
      final rulesValue = rules.value;
      if (tasksValue == null || rulesValue == null) {
        for (final value in [tasks, rules]) {
          if (value case AsyncError(:final error, :final stackTrace)) {
            return AsyncError(error, stackTrace);
          }
        }
        return const AsyncLoading();
      }
      final today = logicalDate(now, dayBoundaryMin: boundary);
      final schedule = ref.watch(taskListScheduleProvider(today)).value;
      final changes = ref.watch(taskDueChangesProvider).value;
      final plan = ref.watch(planControllerProvider);
      return AsyncData(
        taskListContent(
          entries: tasksValue,
          blocks: schedule?.planBlocks ?? const [],
          shortages: plan?.shortages ?? const [],
          dueChanges: changes ?? const {},
          config: PlannerConfig.from(rulesValue),
          // 일정을 아직 읽지 못했으면 시간표가 있다고 본다(까닭을 잘못 쓰지 않게).
          hasClassSlots: schedule == null || schedule.classSlots.isNotEmpty,
          now: now,
          dayBoundaryMin: boundary,
          weekly: view.weekly,
          lmsOnly: view.lmsOnly,
          sort: view.sort,
        ),
      );
    });
