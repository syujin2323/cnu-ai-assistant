// 빈 시간 계산. docs/architecture.md '도메인 기본값과 배치 엔진' 1단계.
//
// 논리적 하루 하나의 하루 창(`work_window`)에서 바쁜 시간을 빼 빈 구간을 만든다.
// - 수업과 앞뒤 여유(`class_buffer`, 실시간 비대면은 0), 대면 수업의 이동 시간(`travel`).
//   같은 수업 앞뒤에 둘이 함께 걸리면 더하지 않고 큰 값을 쓴다.
// - 휴강(`cancelled`)한 수업은 빼고, 보강(`makeup`)은 그 수업 칸의 평소 시각에 그 날짜로 넣는다.
// - 피할 시간(`blackout`), 고정 일정과 앞뒤 여유, 일정(종일 일정은 시간을 막지 않는다),
//   확정·완료 블록.
// 식사 보호는 이 결과 위에서 따로 한다. 제안 블록은 재계산 때 다시 만들므로 빼지 않는다.

import 'dart:math' show max;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 논리적 하루 [day]의 빈 구간을 시작 순서로 돌려준다. [day]는 시각을 보지 않는다.
///
/// 하루 창은 [day] 0시 기준이고, 논리적 하루(하루 경계 [dayBoundaryMin]부터 다음 날 경계 전까지)
/// 밖으로 나간 부분은 자른다. 그래서 한 빈 시간이 두 날에 함께 잡히지 않는다.
/// 자정을 넘는 수업·고정 일정을 위해 전날과 다음 날의 것도 함께 본다.
List<TimeSpan> freeSlots(
  DateTime day, {
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) {
  final date = DateTime(day.year, day.month, day.day);
  final rules = config.forWeekday(date.weekday);
  final window = _intersect(
    _onDate(date, rules.workWindow),
    TimeSpan(
      _at(date, dayBoundaryMin),
      _at(date, dayBoundaryMin + _minutesPerDay),
    ),
  );
  if (window == null) return const [];

  final nearbyDates = [
    for (var offset = -1; offset <= 1; offset++) _addDays(date, offset),
  ];
  final busy = <TimeSpan>[
    ..._classSpans(
      nearbyDates,
      date,
      schedule,
      config.classBufferMin,
      rules.travel,
      dayBoundaryMin,
    ),
    for (final range in rules.blackouts) _onDate(date, range),
    for (final nearby in nearbyDates)
      for (final block in schedule.fixedBlocks)
        if (block.weekdays.contains(nearby.weekday))
          TimeSpan(
            _at(nearby, block.startMin - block.bufferMin),
            _at(nearby, block.endMin + block.bufferMin),
          ),
    for (final event in schedule.events)
      if (!event.allDay) TimeSpan(event.startAt, event.endAt),
    for (final block in schedule.planBlocks)
      if (block.status == PlanBlockStatus.confirmed ||
          block.status == PlanBlockStatus.done)
        TimeSpan(block.startAt, block.endAt),
  ];
  return _subtract(window, busy);
}

/// 수업과 그 앞뒤로 막는 시간(여유·이동 시간).
Iterable<TimeSpan> _classSpans(
  List<DateTime> dates,
  DateTime day,
  Schedule schedule,
  int bufferMin,
  TravelTime? travel,
  int dayBoundaryMin,
) {
  final exceptions = <(String, int), Set<ClassExceptionKind>>{};
  for (final exception in schedule.classExceptions) {
    (exceptions[(exception.date, exception.classSlotId)] ??= {}).add(
      exception.kind,
    );
  }

  final classes = <({TimeSpan span, ClassSlot slot})>[
    for (final date in dates)
      for (final slot in schedule.classSlots)
        if (_meets(slot, date, exceptions[(isoDate(date), slot.id)]))
          (
            span: TimeSpan(_at(date, slot.startMin), _at(date, slot.endMin)),
            slot: slot,
          ),
  ];

  // 이동 시간은 그 논리적 하루의 대면 수업에만 건다.
  final inPerson =
      classes
          .where(
            (c) =>
                !c.slot.online &&
                logicalDate(c.span.start, dayBoundaryMin: dayBoundaryMin) ==
                    day,
          )
          .toList()
        ..sort((a, b) => a.span.start.compareTo(b.span.start));

  return classes.map((c) {
    final buffer = c.slot.online ? 0 : bufferMin;
    var before = buffer;
    var after = buffer;
    if (travel != null && inPerson.isNotEmpty) {
      final everyClass = travel.position == TravelPosition.everyClass;
      if (everyClass ? inPerson.contains(c) : c == inPerson.first) {
        before = max(before, travel.minutes);
      }
      if (everyClass ? inPerson.contains(c) : c == inPerson.last) {
        after = max(after, travel.minutes);
      }
    }
    return TimeSpan(
      c.span.start.subtract(Duration(minutes: before)),
      c.span.end.add(Duration(minutes: after)),
    );
  });
}

/// [slot]이 [date]에 열리는지. 휴강이면 열리지 않고, 보강이면 요일이 달라도 열린다.
bool _meets(ClassSlot slot, DateTime date, Set<ClassExceptionKind>? kinds) {
  if (kinds != null && kinds.contains(ClassExceptionKind.cancelled)) {
    return false;
  }
  return slot.weekday == date.weekday ||
      (kinds != null && kinds.contains(ClassExceptionKind.makeup));
}

/// [window]에서 [busy]를 빼고 남은 구간. 길이가 0이거나 거꾸로 된 바쁜 구간은 무시한다.
List<TimeSpan> _subtract(TimeSpan window, List<TimeSpan> busy) {
  final sorted = busy.where((span) => span.end.isAfter(span.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final free = <TimeSpan>[];
  var cursor = window.start;
  for (final span in sorted) {
    if (!span.start.isBefore(window.end)) break;
    if (!span.end.isAfter(cursor)) continue;
    if (span.start.isAfter(cursor)) free.add(TimeSpan(cursor, span.start));
    cursor = span.end;
  }
  if (cursor.isBefore(window.end)) free.add(TimeSpan(cursor, window.end));
  return free;
}

TimeSpan? _intersect(TimeSpan a, TimeSpan b) {
  final start = a.start.isAfter(b.start) ? a.start : b.start;
  final end = a.end.isBefore(b.end) ? a.end : b.end;
  return end.isAfter(start) ? TimeSpan(start, end) : null;
}

TimeSpan _onDate(DateTime date, MinuteRange range) =>
    TimeSpan(_at(date, range.startMin), _at(date, range.endMin));

/// [date] 0시에서 [minutes]분 지난 로컬 시각. 1440 이상이나 음수면 다음 날·전날로 넘어간다.
DateTime _at(DateTime date, int minutes) =>
    DateTime(date.year, date.month, date.day, 0, minutes);

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

const int _minutesPerDay = 1440;
