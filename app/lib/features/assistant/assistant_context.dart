// 06 AI 비서 카드가 폰 DB를 보고 정하는 것: 겹치는 일정, 시간 미정 일정의 시간 칩, 질문 답의 내용, 직접 추가
// 폼에서 넣기 전에 보이는 할 일이 놓일 자리. docs/screens.md '06 AI 비서'의 카드 1(겹치면 알리기만 함, 시간
// 미정이면 시간을 고르거나 그대로 넣음)·5(바꾼 뒤와 겹치는 것)·6(질문 답), '직접 추가 폼'(할 일은 놓일 자리를
// 미리 보임).
//
// 한 번뿐인 일정은 그 논리적 하루의 시간표 항목(`dayItems`: 수업·일정·고정 일정·확정 블록)과 견주고, 매주 반복
// 일정은 그 요일의 수업 칸·고정 일정과 견준다(프로토타입처럼 수업 예외는 보지 않음). 바꾸기 카드는 바꿀 일정
// 자신을 빼고 견준다. 질문 답은 할 일·블록·일정과 지금 시각(분마다)으로 다시 계산한다
// (`domain/assistant/assistant_answers.dart`). 일정 표가 바뀌면 다시 계산하고(다른 카드를 넣으면 겹침이 바로
// 바뀜), 아직 읽는 중이면 null이다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_answers.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/assistant/direct_add.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 일정 카드와 겹치는 것 하나.
final class EventOverlap {
  const EventOverlap({
    required this.title,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    required this.minutes,
  });

  /// '데이터구조 수업'·'알바'·'과제 확정 블록'.
  final String title;

  /// 겹치는 날의 요일(1–7).
  final int weekday;

  /// 겹치는 것의 시각(그날 0시 기준 분, 끝은 자정을 넘으면 1440을 더함).
  final int startMin;
  final int endMin;

  /// 겹치는 길이(분).
  final int minutes;
}

/// [draft]와 겹치는 것(시작 순서). 시간 미정이면 빈 목록, 아직 읽는 중이면 null이다.
final eventOverlapsProvider = Provider.autoDispose
    .family<List<EventOverlap>?, EventDraft>(
      (ref, draft) => _overlapsOf(ref, draft),
    );

/// 바꾸기 카드 [card]의 바꾼 뒤와 겹치는 것(바꿀 일정 자신은 뺌). 지우기·종일 일정이면 빈 목록이다.
final changeOverlapsProvider = Provider.autoDispose
    .family<List<EventOverlap>?, ChangeCard>((ref, card) {
      final title = card.target.title;
      final draft = switch (card.after) {
        EventAfter(allDay: false, :final startAt, :final endAt) => EventDraft(
          title: title,
          date: DateTime(startAt.year, startAt.month, startAt.day),
          startMin: startAt.hour * 60 + startAt.minute,
          endMin:
              startAt.hour * 60 +
              startAt.minute +
              endAt.difference(startAt).inMinutes,
        ),
        FixedAfter(:final weekdays, :final startMin, :final endMin) =>
          EventDraft(
            title: title,
            weekdays: weekdays,
            startMin: startMin,
            endMin: endMin,
          ),
        _ => null,
      };
      return draft == null
          ? const []
          : _overlapsOf(ref, draft, skip: card.target);
    });

/// [draft]와 겹치는 것. [skip]은 견주지 않을 일정(바꿀 일정 자신)이다.
List<EventOverlap>? _overlapsOf(
  Ref ref,
  EventDraft draft, {
  ChangeTarget? skip,
}) {
  final skipEvent = skip is EventTarget ? skip.event.id : null;
  final skipFixed = skip is FixedTarget ? skip.block.id : null;
  final start = draft.startMin;
  final end = draft.endMin;
  if (start == null || end == null) return const [];
  final entries = ref.watch(classSlotEntriesProvider).value;
  if (entries == null) return null;
  final courseOfSlot = {
    for (final entry in entries) entry.slot.id: entry.course.name,
  };
  final weekdays = draft.weekdays;
  if (weekdays != null) {
    // 고정 일정은 범위와 관계없이 모두 읽으므로 오늘의 일정에서 꺼낸다.
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final schedule = ref.watch(dayScheduleProvider(today)).value;
    if (schedule == null) return null;
    return [
      for (final weekday in weekdays) ...[
        for (final entry in entries)
          if (entry.slot.weekday == weekday)
            ?_overlap(
              '${entry.course.name} 수업',
              weekday,
              entry.slot.startMin,
              entry.slot.endMin,
              start,
              end,
            ),
        for (final block in schedule.fixedBlocks)
          if (block.weekdays.contains(weekday) && block.id != skipFixed)
            ?_overlap(
              block.name,
              weekday,
              block.startMin,
              block.endMin,
              start,
              end,
            ),
      ],
    ];
  }
  final settings = ref.watch(settingsProvider).value;
  final config = ref.watch(plannerConfigProvider);
  if (settings == null || config == null) return null;
  final boundary = settings.dayBoundaryMin;
  final startAt = draft.startAt!;
  final endAt = draft.endAt!;
  final day = logicalDate(startAt, dayBoundaryMin: boundary);
  final schedule = ref.watch(dayScheduleProvider(day)).value;
  final tasks = ref.watch(taskEntriesProvider).value;
  if (schedule == null || tasks == null) return null;
  final items = dayItems(
    day,
    schedule: schedule,
    availability: dayAvailability(
      day,
      schedule: schedule,
      config: config,
      dayBoundaryMin: boundary,
    ),
    tasks: tasks,
    dayBoundaryMin: boundary,
  );
  final overlaps = <EventOverlap>[];
  for (final item in items) {
    final title = switch (item) {
      ClassItem(cancelled: false, :final slot, :final makeup) =>
        '${courseOfSlot[slot.id] ?? '수업'} ${makeup ? '보강' : '수업'}',
      EventItem(:final event) when event.id != skipEvent => event.title,
      FixedItem(:final block) when block.id != skipFixed => block.name,
      BlockItem(:final block, :final entry)
          when block.status == PlanBlockStatus.confirmed =>
        '${entry?.task.title ?? '할 일'} 확정 블록',
      _ => null,
    };
    if (title == null) continue;
    final from = item.span.start.isAfter(startAt) ? item.span.start : startAt;
    final to = item.span.end.isBefore(endAt) ? item.span.end : endAt;
    final minutes = to.difference(from).inMinutes;
    if (minutes <= 0) continue;
    final itemStart = item.span.start.hour * 60 + item.span.start.minute;
    overlaps.add(
      EventOverlap(
        title: title,
        weekday: item.span.start.weekday,
        startMin: itemStart,
        endMin: itemStart + item.span.end.difference(item.span.start).inMinutes,
        minutes: minutes,
      ),
    );
  }
  return overlaps;
}

/// 시작과 끝이 [start]–[end]와 겹치면 그 겹침. 같은 날 안의 분으로 견준다.
EventOverlap? _overlap(
  String title,
  int weekday,
  int itemStart,
  int itemEnd,
  int start,
  int end,
) {
  final minutes =
      (itemEnd < end ? itemEnd : end) - (itemStart > start ? itemStart : start);
  if (minutes <= 0) return null;
  return EventOverlap(
    title: title,
    weekday: weekday,
    startMin: itemStart,
    endMin: itemEnd,
    minutes: minutes,
  );
}

/// 겹침 한 줄 '{요일}요일 HH:MM–HH:MM'.
String overlapWhenText(EventOverlap overlap) {
  final start = overlap.startMin % 1440;
  final end = start + overlap.endMin - overlap.startMin;
  return '${weekdayText(overlap.weekday)}요일 ${timeRangeText(start, end)}';
}

/// 시간 미정 일정 카드의 시간 칩: [date]의 9–21시 정각 가운데 한 시간이 통째로 비어 있는 시각(자정 기준 분)을
/// 넷까지 고르게 고른다(최종 프로토타입). 오늘이면 지금 뒤만 본다. 아직 읽는 중이면 null이다.
final freeHourChipsProvider = Provider.autoDispose.family<List<int>?, DateTime>(
  (ref, date) {
    final settings = ref.watch(settingsProvider).value;
    final config = ref.watch(plannerConfigProvider);
    final day = DateTime(date.year, date.month, date.day);
    final schedule = ref.watch(dayScheduleProvider(day)).value;
    if (settings == null || config == null || schedule == null) return null;
    final free = dayAvailability(
      day,
      schedule: schedule,
      config: config,
      dayBoundaryMin: settings.dayBoundaryMin,
    ).free;
    final now = ref.watch(clockProvider).now();
    final hours = <int>[];
    for (var hour = 9; hour <= 21; hour++) {
      final start = DateTime(day.year, day.month, day.day, hour);
      final end = start.add(const Duration(hours: 1));
      if (start.isBefore(now)) continue;
      final fits = free.any(
        (span) => !span.start.isAfter(start) && !span.end.isBefore(end),
      );
      if (fits) hours.add(hour * 60);
    }
    if (hours.length <= 4) return hours;
    return {
      hours.first,
      hours[hours.length ~/ 3],
      hours[hours.length * 2 ~/ 3],
      hours.last,
    }.toList();
  },
);

/// 질문 답 카드 [card]의 내용. 할 일·블록·일정이 바뀌거나 분이 바뀌면 다시 계산하고, 아직 읽는 중이면 null이다.
final answerContentProvider = Provider.autoDispose
    .family<AnswerContent?, AnswerCard>((ref, card) {
      final now = ref.watch(minuteClockProvider);
      final settings = ref.watch(settingsProvider).value;
      final tasks = ref.watch(taskEntriesProvider).value;
      if (settings == null || tasks == null) return null;
      final boundary = settings.dayBoundaryMin;
      switch (card.type) {
        case ParseQueryType.deadlinesThisWeek:
          // 할 일의 다음 블록은 마감 전에 있으므로 오늘부터 기간 끝까지의 블록을 본다.
          final today = logicalDate(now, dayBoundaryMin: boundary);
          final last = card.to.isAfter(today) ? card.to : today;
          final range = ref
              .watch(
                _rangeScheduleProvider((
                  logicalDayStart(today, dayBoundaryMin: boundary),
                  logicalDayEnd(last, dayBoundaryMin: boundary),
                )),
              )
              .value;
          if (range == null) return null;
          return deadlineAnswer(
            card,
            tasks: tasks,
            blocks: range.planBlocks,
            now: now,
            dayBoundaryMin: boundary,
          );
        case ParseQueryType.todayPlan || ParseQueryType.freeTime:
          final config = ref.watch(plannerConfigProvider);
          final day = DateTime(card.from.year, card.from.month, card.from.day);
          final schedule = ref.watch(dayScheduleProvider(day)).value;
          final entries = ref.watch(classSlotEntriesProvider).value;
          if (config == null || schedule == null || entries == null) {
            return null;
          }
          final availability = dayAvailability(
            day,
            schedule: schedule,
            config: config,
            dayBoundaryMin: boundary,
          );
          final items = dayItems(
            day,
            schedule: schedule,
            availability: availability,
            tasks: tasks,
            dayBoundaryMin: boundary,
            includeSuggested: true,
          );
          if (card.type == ParseQueryType.todayPlan) {
            return dayPlanAnswer(
              card,
              items: items,
              courseNames: {
                for (final entry in entries) entry.course.id: entry.course.name,
              },
              now: now,
              dayBoundaryMin: boundary,
            );
          }
          return freeTimeAnswer(
            card,
            free: availability.free,
            items: items,
            now: now,
            dayBoundaryMin: boundary,
          );
      }
    });

/// 직접 추가 폼에서 할 일 [draft]를 넣으면 놓일 자리(`domain/assistant/direct_add.dart`의 [taskPreview]). 그 할 일을
/// 넣었다고 보고 오늘부터 배치 지평의 일정·할 일·규칙으로 배치 엔진을 돌린다(저장하지 않음). 아직 읽는 중이면
/// null이다.
final directTaskPreviewProvider = Provider.autoDispose
    .family<({String text, bool alert})?, TaskDraft>((ref, draft) {
      final now = ref.watch(clockProvider).now();
      final settings = ref.watch(settingsProvider).value;
      final config = ref.watch(plannerConfigProvider);
      final tasks = ref.watch(taskEntriesProvider).value;
      final slots = ref.watch(classSlotEntriesProvider).value;
      final courses = draft.courseName == null
          ? const <Course>[]
          : ref.watch(selectableCoursesProvider).value;
      if (settings == null ||
          config == null ||
          tasks == null ||
          slots == null ||
          courses == null) {
        return null;
      }
      final boundary = settings.dayBoundaryMin;
      final course = courses
          .where((course) => course.name == draft.courseName)
          .firstOrNull;
      final estimate = taskEstimateOf(
        draft,
        courseId: course?.id,
        config: config,
      ).minutes;
      // 배치 엔진 없이 정해지는 것(마감 없음, 지난 마감, 예상 시간 모름, 시간표 없음)은 먼저 답한다.
      final quick = taskPreview(
        draft: draft,
        taskId: _previewTaskId,
        estimate: estimate,
        plan: null,
        hasTimetable: slots.isNotEmpty,
        now: now,
        dayBoundaryMin: boundary,
      );
      if (quick != null) return quick;
      final today = logicalDate(now, dayBoundaryMin: boundary);
      final last = DateTime(
        today.year,
        today.month,
        today.day + Defaults.planHorizonDays - 1,
      );
      final schedule = ref
          .watch(
            _rangeScheduleProvider((
              logicalDayStart(today, dayBoundaryMin: boundary),
              logicalDayEnd(last, dayBoundaryMin: boundary),
            )),
          )
          .value;
      if (schedule == null) return null;
      final probe = Task(
        id: _previewTaskId,
        title: draft.title,
        kind: draft.kind,
        dueAt: draft.dueAt,
        dueTimeUnknown: draft.dueTimeUnknown,
        estimateMin: draft.estimateToStore,
        status: TaskStatus.todo,
        courseId: course?.id,
        source: EntrySource.manual,
      );
      return taskPreview(
        draft: draft,
        taskId: _previewTaskId,
        estimate: estimate,
        plan: planRange(
          now: now,
          from: today,
          schedule: schedule,
          tasks: [
            ...tasks,
            TaskEntry(task: probe, course: course),
          ],
          config: config,
          dayBoundaryMin: boundary,
        ),
        hasTimetable: true,
        now: now,
        dayBoundaryMin: boundary,
      );
    });

/// 미리 보기에서 넣었다고 보는 할 일의 id(폰 DB의 id와 겹치지 않음).
const _previewTaskId = -1;

/// [start]부터 [end] 전까지의 일정(`ScheduleRepository.watch`).
final _rangeScheduleProvider = StreamProvider.autoDispose
    .family<Schedule, (DateTime, DateTime)>(
      (ref, range) => ref
          .watch(scheduleRepositoryProvider)
          .watch(start: range.$1, end: range.$2),
    );
