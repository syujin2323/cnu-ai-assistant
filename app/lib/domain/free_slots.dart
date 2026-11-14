// 빈 시간 계산. docs/architecture.md '도메인 기본값과 배치 엔진' 1단계.
//
// 논리적 하루 하나(하루 경계부터 다음 날 경계 전까지)의 하루 창(`work_window`)에서 바쁜 시간을 빼 빈 구간을
// 만든다.
// - 규칙의 시각 구간(하루 창, 피할 시간, 식사)은 날마다 반복되는 실제 시각이다. 그래서 전날·그날·다음 날의
//   달력 날짜에 놓고 그 논리적 하루에 드는 조각을 쓰며, 요일을 고른 규칙은 구간이 시작하는 달력일의 요일로
//   고른다(docs/decisions.md 2026-11-14 '규칙의 시각 구간은 실제 시각으로 놓는다'). 각 시각은 한 논리적
//   하루에만 들어간다.
// - 수업과 앞뒤 여유(`class_buffer`, 실시간 비대면은 0), 대면 수업의 이동 시간(`travel`). 같은 수업 앞뒤에
//   둘이 함께 걸리면 더하지 않고 큰 값을 쓴다. 이동 시간은 그 논리적 하루의 요일 규칙이고 그 논리적 하루의
//   대면 수업에만 건다.
// - 휴강(`cancelled`)한 날의 수업은 바쁜 시간으로 보지 않고, 보강(`makeup`)은 그 수업 칸의 평소 시각에
//   그 날짜로 넣는다. R0는 수업 칸의 반복 규칙(`repeatRule`, R1)을 읽지 않고 매주 열리는 수업으로 본다.
//   R1의 격주·특정 주 반복은 [_meets] 한 곳에서 거른다.
// - 피할 시간(`blackout`), 고정 일정과 앞뒤 여유, 일정(종일 일정은 시간을 막지 않는다), 확정·완료 블록.
//   제안·놓침·지운 블록은 시간을 막지 않는다(제안 블록은 재계산 때 다시 만든다).
// - 마지막으로 식사 시간을 비운다([_protectMeals]).

import 'dart:math' show max, min;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 논리적 하루 [day]의 빈 구간을 시작 순서로 돌려준다. [day]는 시각을 보지 않는다.
///
/// 하루 창은 [ruleSpansInLogicalDay]로 놓으므로 조각이 둘일 수 있다(예: 02:00–10:00 하루 창이면 그날
/// 04:00–10:00과 다음 날 02:00–04:00). 자정을 넘는 수업·고정 일정을 위해 전날과 다음 날의 것도 함께 본다.
/// 돌려주는 목록은 부르는 쪽이 고쳐도 된다. [dayBoundaryMin]이 0–1439 밖이면 [RangeError]다.
List<TimeSpan> freeSlots(
  DateTime day, {
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) {
  RangeError.checkValueInInterval(
    dayBoundaryMin,
    0,
    _minutesPerDay - 1,
    'dayBoundaryMin',
  );
  final date = DateTime(day.year, day.month, day.day);
  final windows = ruleSpansInLogicalDay(
    date,
    dayBoundaryMin: dayBoundaryMin,
    rangesFor: (weekday) => [config.forWeekday(weekday).workWindow],
  );
  if (windows.isEmpty) return <TimeSpan>[];

  final nearbyDates = _nearbyDates(date);
  final busy = <TimeSpan>[
    ..._classSpans(
      nearbyDates,
      date,
      schedule,
      config.classBufferMin,
      config.forWeekday(date.weekday).travel,
      dayBoundaryMin,
    ),
    ...ruleSpansInLogicalDay(
      date,
      dayBoundaryMin: dayBoundaryMin,
      rangesFor: (weekday) => config.forWeekday(weekday).blackouts,
    ),
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
  return _protectMeals(
    nearbyDates,
    _logicalDay(date, dayBoundaryMin),
    [for (final window in windows) ..._subtract(window, busy)],
    config.meals,
    schedule.fixedBlocks,
  );
}

/// 날마다 반복되는 규칙 구간을 논리적 하루 [day]에 놓은 조각을 시작 순서로 돌려준다.
///
/// 전날·그날·다음 날의 달력 날짜마다 그 날짜 요일의 구간([rangesFor])을 그 날짜 0시 기준으로 놓고, [day]의
/// 논리적 하루(하루 경계 [dayBoundaryMin]부터 다음 날 경계 전까지) 안에 드는 부분만 남긴다. 그래서 요일은
/// 구간이 시작하는 달력일의 요일이고(화요일 01:00–03:00은 실제 화요일 새벽, 곧 월요일 논리적 하루의 끝),
/// 각 시각은 한 논리적 하루에만 들어간다. 겹치거나 맞닿은 조각은 합친다. 배치 엔진은 선호 시간대도 이것으로
/// 놓는다.
List<TimeSpan> ruleSpansInLogicalDay(
  DateTime day, {
  required int dayBoundaryMin,
  required Iterable<MinuteRange> Function(int weekday) rangesFor,
}) {
  RangeError.checkValueInInterval(
    dayBoundaryMin,
    0,
    _minutesPerDay - 1,
    'dayBoundaryMin',
  );
  final date = DateTime(day.year, day.month, day.day);
  final logicalDay = _logicalDay(date, dayBoundaryMin);
  return _merge([
    for (final nearby in _nearbyDates(date))
      for (final range in rangesFor(nearby.weekday))
        ?_intersect(_onDate(nearby, range), logicalDay),
  ]);
}

/// 식사 규칙마다 [free]에서 식사 시간을 비운다.
///
/// 식사 시간대도 날마다 반복되는 실제 시각이라 [dates](전날·그날·다음 날)에 놓고, 시간대가 시작하는 시각이
/// [logicalDay] 안에 있는 것 하나만 비운다(한 끼를 두 논리적 하루에서 비우지 않게). 그래서 00:00–01:00
/// 야식은 그날 밤(다음 날 0시)에 비운다. 그 날짜에 그 시간대와 겹치는 식사 고정 일정이 있으면 고정 일정이
/// 대신하므로 비우지 않는다. 그 밖에는 시간대 안의 빈 조각 가운데 식사 시간이 들어가는 가장 이른 조각을,
/// 없으면 가장 긴 조각을 고르고, 그 조각에서 식사 시간(조각이 짧으면 조각 전체)을 비운다. 시간대 안에 빈
/// 조각이 없으면 비울 것이 없다.
List<TimeSpan> _protectMeals(
  List<DateTime> dates,
  TimeSpan logicalDay,
  List<TimeSpan> free,
  List<MealGuard> meals,
  List<FixedBlock> fixedBlocks,
) {
  var result = free;
  for (final meal in meals) {
    if (meal.minutes == 0) continue;
    for (final date in dates) {
      final window = _onDate(date, meal.window);
      if (!_contains(logicalDay, window.start)) continue;
      final coveredByFixedMeal = fixedBlocks.any(
        (block) =>
            block.kind == FixedBlockKind.meal &&
            block.weekdays.contains(date.weekday) &&
            MinuteRange(block.startMin, block.endMin).overlaps(meal.window),
      );
      if (coveredByFixedMeal) continue;
      final reserved = _mealSpan(window, meal.minutes, result);
      if (reserved != null) result = _cut(result, reserved);
    }
  }
  return result;
}

/// [window] 안에서 [minutes]만큼 비울 자리. 빈 구간을 둘로 쪼개지 않도록 바쁜 시간 쪽 끝에
/// 붙이고(수업 직후나 다음 일정 직전), 양쪽이 트여 있으면 시간대 시작에 둔다.
TimeSpan? _mealSpan(TimeSpan window, int minutes, List<TimeSpan> free) {
  final pieces = [
    for (final gap in free)
      if (_intersect(gap, window) case final piece?) (gap: gap, piece: piece),
  ];
  if (pieces.isEmpty) return null;
  final chosen =
      pieces.where((p) => p.piece.minutes >= minutes).firstOrNull ??
      pieces.reduce((a, b) => b.piece.minutes > a.piece.minutes ? b : a);
  final (:gap, :piece) = chosen;
  final length = Duration(minutes: min(minutes, piece.minutes));
  final atEnd = piece.end == gap.end && piece.start != gap.start;
  return atEnd
      ? TimeSpan(piece.end.subtract(length), piece.end)
      : TimeSpan(piece.start, piece.start.add(length));
}

/// [free]의 빈 구간에서 [cut]과 겹치는 부분을 잘라 낸다.
List<TimeSpan> _cut(List<TimeSpan> free, TimeSpan cut) => [
  for (final gap in free) ...[
    if (gap.start.isBefore(cut.start))
      TimeSpan(gap.start, gap.end.isBefore(cut.start) ? gap.end : cut.start),
    if (gap.end.isAfter(cut.end))
      TimeSpan(gap.start.isAfter(cut.end) ? gap.start : cut.end, gap.end),
  ],
];

/// 수업과 그 앞뒤로 막는 시간(여유·이동 시간).
///
/// `day_edges` 이동 시간은 그 논리적 하루의 대면 수업 가운데 하루 첫 수업(시작이 가장 이른 수업) 앞과
/// 마지막 수업(끝이 가장 늦은 수업) 뒤에 건다. 시작이나 끝이 같으면 수업 칸 id로 가려, 수업이 겹치거나
/// 입력 순서가 달라도 같은 결과를 낸다.
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
  final inPerson = [
    for (final c in classes)
      if (!c.slot.online &&
          logicalDate(c.span.start, dayBoundaryMin: dayBoundaryMin) == day)
        c,
  ];
  ({TimeSpan span, ClassSlot slot})? firstClass;
  ({TimeSpan span, ClassSlot slot})? lastClass;
  for (final c in inPerson) {
    if (firstClass == null ||
        c.span.start.isBefore(firstClass.span.start) ||
        (c.span.start.isAtSameMomentAs(firstClass.span.start) &&
            c.slot.id < firstClass.slot.id)) {
      firstClass = c;
    }
    if (lastClass == null ||
        c.span.end.isAfter(lastClass.span.end) ||
        (c.span.end.isAtSameMomentAs(lastClass.span.end) &&
            c.slot.id > lastClass.slot.id)) {
      lastClass = c;
    }
  }

  return classes.map((c) {
    final buffer = c.slot.online ? 0 : bufferMin;
    var before = buffer;
    var after = buffer;
    if (travel != null) {
      final everyClass = travel.position == TravelPosition.everyClass;
      if (everyClass ? inPerson.contains(c) : c == firstClass) {
        before = max(before, travel.minutes);
      }
      if (everyClass ? inPerson.contains(c) : c == lastClass) {
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
///
/// R0는 [ClassSlot.repeatRule](R1)을 읽지 않고 요일이 같으면 매주 열린다고 본다. R1의 격주·특정 주
/// 반복은 여기서 거른다.
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

/// 시작 순서로 늘어놓고 겹치거나 맞닿은 구간을 하나로 합친다.
List<TimeSpan> _merge(List<TimeSpan> spans) {
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <TimeSpan>[];
  for (final span in sorted) {
    final last = merged.lastOrNull;
    if (last == null || span.start.isAfter(last.end)) {
      merged.add(span);
    } else if (span.end.isAfter(last.end)) {
      merged[merged.length - 1] = TimeSpan(last.start, span.end);
    }
  }
  return merged;
}

TimeSpan? _intersect(TimeSpan a, TimeSpan b) {
  final start = a.start.isAfter(b.start) ? a.start : b.start;
  final end = a.end.isBefore(b.end) ? a.end : b.end;
  return end.isAfter(start) ? TimeSpan(start, end) : null;
}

bool _contains(TimeSpan span, DateTime at) =>
    !at.isBefore(span.start) && at.isBefore(span.end);

/// [date]의 논리적 하루: 하루 경계부터 다음 날 하루 경계 전까지.
TimeSpan _logicalDay(DateTime date, int dayBoundaryMin) => TimeSpan(
  _at(date, dayBoundaryMin),
  _at(date, dayBoundaryMin + _minutesPerDay),
);

/// 전날·그날·다음 날.
List<DateTime> _nearbyDates(DateTime date) => [
  for (var offset = -1; offset <= 1; offset++) _addDays(date, offset),
];

TimeSpan _onDate(DateTime date, MinuteRange range) =>
    TimeSpan(_at(date, range.startMin), _at(date, range.endMin));

/// [date] 0시에서 [minutes]분 지난 로컬 시각. 1440 이상이나 음수면 다음 날·전날로 넘어간다.
DateTime _at(DateTime date, int minutes) =>
    DateTime(date.year, date.month, date.day, 0, minutes);

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

const int _minutesPerDay = 1440;
