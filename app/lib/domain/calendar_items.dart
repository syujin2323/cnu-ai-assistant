// 캘린더 보기가 날짜마다 그리는 항목. docs/architecture.md '화면 이동'(월간 + 선택일 패널).
//
// 폰 DB의 수업·고정 일정·일정·블록·할 일 마감을 한 날짜의 목록으로 펼친다. 화면은 이 결과만
// 그리고 표를 직접 읽지 않는다. 수업이 그날 열리는지는 빈 시간 계산과 같은 [classMeets]로 본다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';

/// 캘린더 항목의 종류. 색과 모양을 고르는 데 쓴다.
enum CalendarItemKind {
  /// 수업.
  classSession,

  /// 고정 일정(알바·운동 등).
  fixed,

  /// 일정.
  event,

  /// 할 일에 정한 시간(확정·완료·놓친 블록).
  block,

  /// 할 일 마감.
  deadline,
}

/// 한 날짜에 그리는 항목 하나.
final class CalendarItem {
  const CalendarItem({
    required this.kind,
    required this.title,
    this.start,
    this.end,
    this.place,
    this.taskId,
    this.placed = false,
  });

  final CalendarItemKind kind;
  final String title;

  /// 시작 시각. 종일 일정이면 null이다. 마감은 마감 시각이다.
  final DateTime? start;

  /// 끝 시각. 종일 일정과 마감은 null이다.
  final DateTime? end;

  final String? place;

  /// 블록·마감의 할 일 id.
  final int? taskId;

  /// 마감이면 그 할 일에 정한 시간(끝나지 않은 확정 블록)이 있는지. 다른 종류는 늘 false다.
  final bool placed;

  /// 종일 항목인지(시각 없음).
  bool get allDay => start == null;
}

/// 캘린더가 읽는 폰 DB 묶음. 저장소가 한 번에 읽어 넘긴다.
final class CalendarData {
  const CalendarData({
    this.schedule = const Schedule(),
    this.courses = const [],
    this.tasks = const [],
  });

  final Schedule schedule;
  final List<Course> courses;
  final List<Task> tasks;
}

/// [date](시각은 보지 않음)에 그릴 항목. 종일 항목이 먼저, 그다음 시작 시각 순이다.
List<CalendarItem> itemsOn(DateTime date, CalendarData data) {
  final day = DateTime(date.year, date.month, date.day);
  final next = DateTime(day.year, day.month, day.day + 1);
  final iso = isoDate(day);
  final schedule = data.schedule;
  final courseNames = {
    for (final course in data.courses) course.id: course.alias ?? course.name,
  };
  final taskById = {for (final task in data.tasks) task.id: task};
  DateTime at(int minutes) => day.add(Duration(minutes: minutes));
  bool overlapsDay(DateTime start, DateTime end) =>
      start.isBefore(next) && end.isAfter(day);

  final exceptionKinds = <int, Set<ClassExceptionKind>>{};
  final placeChange = <int, String?>{};
  for (final exception in schedule.classExceptions) {
    if (exception.date != iso) continue;
    (exceptionKinds[exception.classSlotId] ??= {}).add(exception.kind);
    if (exception.kind == ClassExceptionKind.placeChange) {
      placeChange[exception.classSlotId] = exception.place;
    }
  }

  // 끝나지 않은 확정 블록이 있는 할 일은 '배치됨'이다.
  final placedTaskIds = {
    for (final block in schedule.planBlocks)
      if (block.status == PlanBlockStatus.confirmed) block.taskId,
  };

  final items = <CalendarItem>[
    for (final slot in schedule.classSlots)
      if (classMeets(slot, day, exceptionKinds[slot.id]))
        CalendarItem(
          kind: CalendarItemKind.classSession,
          title: courseNames[slot.courseId] ?? '수업',
          start: at(slot.startMin),
          end: at(slot.endMin),
          place: placeChange[slot.id] ?? slot.place,
        ),
    for (final block in schedule.fixedBlocks)
      if (block.weekdays.contains(day.weekday))
        CalendarItem(
          kind: CalendarItemKind.fixed,
          title: block.name,
          start: at(block.startMin),
          end: at(block.endMin),
        ),
    for (final event in schedule.events)
      if (overlapsDay(event.startAt, event.endAt))
        CalendarItem(
          kind: CalendarItemKind.event,
          title: event.title,
          start: event.allDay ? null : event.startAt,
          end: event.allDay ? null : event.endAt,
          place: event.place,
        ),
    for (final block in schedule.planBlocks)
      if (block.status == PlanBlockStatus.confirmed ||
          block.status == PlanBlockStatus.done ||
          block.status == PlanBlockStatus.missed)
        if (overlapsDay(block.startAt, block.endAt))
          CalendarItem(
            kind: CalendarItemKind.block,
            title: taskById[block.taskId]?.title ?? '할 일',
            start: block.startAt,
            end: block.endAt,
            taskId: block.taskId,
          ),
    for (final task in data.tasks)
      if (task.status == TaskStatus.todo &&
          task.dueAt != null &&
          !task.dueAt!.isBefore(day) &&
          task.dueAt!.isBefore(next))
        CalendarItem(
          kind: CalendarItemKind.deadline,
          title: task.title,
          start: task.dueAt,
          taskId: task.id,
          placed: placedTaskIds.contains(task.id),
        ),
  ];
  items.sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    if (a.allDay) return 0;
    return a.start!.compareTo(b.start!);
  });
  return items;
}
