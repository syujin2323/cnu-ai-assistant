// 빈 시간 계산. docs/architecture.md '도메인 기본값과 배치 엔진' 1단계.
//
// 논리적 하루 하나(하루 경계부터 다음 날 경계 전까지)의 하루 창(`work_window`)에서 바쁜 시간을 빼 빈 구간을
// 만든다. 결과([DayAvailability])에는 하루 창 조각, 빈 구간, 바쁜 구간과 그 이유가 함께 들어, 배치 엔진과
// 02 홈·09 일간·11 주간이 같은 계산을 쓴다.
// - 규칙의 시각 구간(하루 창, 피할 시간, 식사)은 날마다 반복되는 실제 시각이다. 그래서 전날·그날·다음 날의
//   달력 날짜에 놓고 그 논리적 하루에 드는 조각을 쓰며, 요일을 고른 규칙은 구간이 시작하는 달력일의 요일로
//   고른다(docs/decisions.md 2026-11-14 '규칙의 시각 구간은 실제 시각으로 놓는다'). 각 시각은 한 논리적
//   하루에만 들어간다.
// - 수업과 앞뒤 여유(`class_buffer`, 실시간 비대면은 0), 대면 수업의 이동 시간(`travel`). 같은 수업 앞뒤에
//   둘이 함께 걸리면 더하지 않고 큰 값을 쓴다(둘을 따로 담고 합집합을 뺀다). 이동 시간은 그 논리적 하루의
//   요일 규칙이고 그 논리적 하루의 대면 수업에만 건다.
// - 휴강(`cancelled`)한 날의 수업은 평소 시각에 열리지 않고, 보강(`makeup`)은 저장된 보강 시각(없으면 그
//   수업 칸의 평소 시각)에 그 날짜로 연다. 같은 날 휴강과 보강이 함께 있으면 보강 시각에만 연다. R0는 수업
//   칸의 반복 규칙(`repeatRule`, R1)을 읽지 않고 매주 열리는 수업으로 본다. R1의 격주·특정 주 반복은
//   [_occurrences] 한 곳에서 거른다.
// - 피할 시간(`blackout`), 고정 일정과 앞뒤 여유, 일정(종일 일정은 시간을 막지 않는다), 확정·완료 블록.
//   제안·놓침·지운 블록은 시간을 막지 않는다(제안 블록은 재계산 때 다시 만든다).
// - 마지막으로 식사 시간을 비운다([_protectMeals]).
//
// 끌어 옮기는 블록이 놓일 자리를 볼 때는 그 블록을 [Schedule]에서 빼고 다시 계산한다. '이동·점심 시간 표시'
// 설정은 그리기만 바꾸므로 계산의 입력이 아니다.

import 'dart:math' show max, min;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 논리적 하루 [day]의 빈 시간 계산 결과. [day]는 시각을 보지 않는다.
///
/// 하루 창은 [ruleSpansInLogicalDay]로 놓으므로 조각이 둘일 수 있다(예: 02:00–10:00 하루 창이면 그날
/// 04:00–10:00과 다음 날 02:00–04:00). 자정을 넘는 수업·고정 일정을 위해 전날과 다음 날의 것도 함께 보고,
/// 바쁜 구간은 그 논리적 하루 안으로 잘라 담는다.
///
/// [nightWindow]면 그날(논리적 하루 [day]의 달력 날짜) 하루 창 끝을 [Defaults.nightWindowEndMin](다음 날
/// 01:00, 임시)까지 늘린다. 배치 6단계의 '밤 시간 쓰기'이고, 하루 창이 이미 더 늦게 끝나면 그대로 둔다. 어느
/// 날이 밤 시간 쓰기인지는 배치 엔진이 저장된 날짜를 보고 넘긴다. [dayBoundaryMin]이 0–1439 밖이면
/// [RangeError]다.
DayAvailability dayAvailability(
  DateTime day, {
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
  bool nightWindow = false,
}) {
  RangeError.checkValueInInterval(
    dayBoundaryMin,
    0,
    _minutesPerDay - 1,
    'dayBoundaryMin',
  );
  final date = DateTime(day.year, day.month, day.day);
  final logicalDay = _logicalDay(date, dayBoundaryMin);
  // 전날·그날·다음 날은 요일이 모두 다르므로 요일로 그날의 하루 창을 가린다.
  final windows = ruleSpansInLogicalDay(
    date,
    dayBoundaryMin: dayBoundaryMin,
    rangesFor: (weekday) {
      final window = config.forWeekday(weekday).workWindow;
      return [
        nightWindow && weekday == date.weekday ? _untilNight(window) : window,
      ];
    },
  );

  final nearbyDates = _nearbyDates(date);
  final busy = <BusySpan>[
    ..._classSpans(
      nearbyDates,
      date,
      schedule,
      config.classBufferMin,
      config.forWeekday(date.weekday).travel,
      dayBoundaryMin,
    ),
    for (final span in ruleSpansInLogicalDay(
      date,
      dayBoundaryMin: dayBoundaryMin,
      rangesFor: (weekday) => config.forWeekday(weekday).blackouts,
    ))
      BusySpan(span, BusyKind.blackout),
    for (final nearby in nearbyDates)
      for (final block in schedule.fixedBlocks)
        if (block.weekdays.contains(nearby.weekday)) ...[
          BusySpan(
            TimeSpan(_at(nearby, block.startMin), _at(nearby, block.endMin)),
            BusyKind.fixedBlock,
            sourceId: block.id,
          ),
          if (block.bufferMin > 0) ...[
            BusySpan(
              TimeSpan(
                _at(nearby, block.startMin - block.bufferMin),
                _at(nearby, block.startMin),
              ),
              BusyKind.fixedBuffer,
              sourceId: block.id,
            ),
            BusySpan(
              TimeSpan(
                _at(nearby, block.endMin),
                _at(nearby, block.endMin + block.bufferMin),
              ),
              BusyKind.fixedBuffer,
              sourceId: block.id,
            ),
          ],
        ],
    for (final event in schedule.events)
      if (!event.allDay)
        BusySpan(
          TimeSpan(event.startAt, event.endAt),
          BusyKind.event,
          sourceId: event.id,
        ),
    for (final block in schedule.planBlocks)
      if (block.status == PlanBlockStatus.confirmed ||
          block.status == PlanBlockStatus.done)
        BusySpan(
          TimeSpan(block.startAt, block.endAt),
          BusyKind.planBlock,
          sourceId: block.id,
        ),
  ];
  final open = [
    for (final window in windows)
      ...subtractSpans(window, [for (final b in busy) b.span]),
  ];
  final (:free, :meals) = _protectMeals(
    nearbyDates,
    logicalDay,
    open,
    config.meals,
    schedule.fixedBlocks,
  );
  return DayAvailability(
    windows: windows,
    free: free,
    busy: [
      for (final b in [
        ...busy,
        for (final meal in meals) BusySpan(meal, BusyKind.meal),
      ])
        if (b.span.intersection(logicalDay) case final clipped?)
          BusySpan(clipped, b.kind, sourceId: b.sourceId),
    ]..sort(_byStart),
  );
}

/// 논리적 하루 [day]의 빈 구간을 시작 순서로 돌려준다([dayAvailability]의 [DayAvailability.free]). 돌려주는
/// 목록은 부르는 쪽이 고쳐도 된다.
List<TimeSpan> freeSlots(
  DateTime day, {
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) => [
  ...dayAvailability(
    day,
    schedule: schedule,
    config: config,
    dayBoundaryMin: dayBoundaryMin,
  ).free,
];

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
  return mergeSpans([
    for (final nearby in _nearbyDates(date))
      for (final range in rangesFor(nearby.weekday))
        ?_onDate(nearby, range).intersection(logicalDay),
  ]);
}

/// 하루 창 끝을 [Defaults.nightWindowEndMin]까지 늘린 것. 이미 더 늦게 끝나면 그대로다.
MinuteRange _untilNight(MinuteRange window) => MinuteRange(
  window.startMin,
  max(window.endMin, Defaults.nightWindowEndMin),
);

/// 식사 규칙마다 [free]에서 식사 시간을 비우고, 남은 빈 구간과 비운 구간을 돌려준다.
///
/// 식사 시간대도 날마다 반복되는 실제 시각이라 [dates](전날·그날·다음 날)에 놓고, 시간대가 시작하는 시각이
/// [logicalDay] 안에 있는 것 하나만 비운다(한 끼를 두 논리적 하루에서 비우지 않게). 그래서 00:00–01:00
/// 야식은 그날 밤(다음 날 0시)에 비운다. 그 날짜에 그 시간대와 겹치는 식사 고정 일정이 있으면 고정 일정이
/// 대신하므로 비우지 않는다. 그 밖에는 시간대 안의 빈 조각 가운데 식사 시간이 들어가는 가장 이른 조각을,
/// 없으면 가장 긴 조각을 고르고, 그 조각에서 식사 시간(조각이 짧으면 조각 전체)을 비운다. 시간대 안에 빈
/// 조각이 없으면 비울 것이 없다.
({List<TimeSpan> free, List<TimeSpan> meals}) _protectMeals(
  List<DateTime> dates,
  TimeSpan logicalDay,
  List<TimeSpan> free,
  List<MealGuard> meals,
  List<FixedBlock> fixedBlocks,
) {
  var result = free;
  final reservedSpans = <TimeSpan>[];
  for (final meal in meals) {
    if (meal.minutes == 0) continue;
    for (final date in dates) {
      final window = _onDate(date, meal.window);
      if (!logicalDay.contains(window.start)) continue;
      final coveredByFixedMeal = fixedBlocks.any(
        (block) =>
            block.kind == FixedBlockKind.meal &&
            block.weekdays.contains(date.weekday) &&
            MinuteRange(block.startMin, block.endMin).overlaps(meal.window),
      );
      if (coveredByFixedMeal) continue;
      final reserved = _mealSpan(window, meal.minutes, result);
      if (reserved != null) {
        result = cutSpans(result, reserved);
        reservedSpans.add(reserved);
      }
    }
  }
  return (free: result, meals: reservedSpans);
}

/// [window] 안에서 [minutes]만큼 비울 자리. 빈 구간을 둘로 쪼개지 않도록 바쁜 시간 쪽 끝에
/// 붙이고(수업 직후나 다음 일정 직전), 양쪽이 트여 있으면 시간대 시작에 둔다.
TimeSpan? _mealSpan(TimeSpan window, int minutes, List<TimeSpan> free) {
  final pieces = [
    for (final gap in free)
      if (gap.intersection(window) case final piece?) (gap: gap, piece: piece),
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

/// 수업과 그 앞뒤로 막는 시간(여유·이동 시간). 여유와 이동 시간은 따로 담고, 같은 수업 앞뒤에 함께 걸리면
/// 합집합이 큰 값이 된다.
///
/// `day_edges` 이동 시간은 그 논리적 하루의 대면 수업 가운데 하루 첫 수업(시작이 가장 이른 수업) 앞과
/// 마지막 수업(끝이 가장 늦은 수업) 뒤에 건다. 시작이나 끝이 같으면 수업 칸 id로 가려, 수업이 겹치거나
/// 입력 순서가 달라도 같은 결과를 낸다. 다른 수업 시간과 겹치는 이동은 놓지 않는다.
List<BusySpan> _classSpans(
  List<DateTime> dates,
  DateTime day,
  Schedule schedule,
  int bufferMin,
  TravelTime? travel,
  int dayBoundaryMin,
) {
  final exceptions = <(String, int), List<ClassException>>{};
  for (final exception in schedule.classExceptions) {
    (exceptions[(exception.date, exception.classSlotId)] ??= []).add(exception);
  }

  final classes = <({TimeSpan span, ClassSlot slot})>[
    for (final date in dates)
      for (final slot in schedule.classSlots)
        for (final time in _occurrences(
          slot,
          date,
          exceptions[(isoDate(date), slot.id)] ?? const [],
        ))
          (span: _onDate(date, time), slot: slot),
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

  BusySpan before(
    ({TimeSpan span, ClassSlot slot}) c,
    int minutes,
    BusyKind kind,
  ) => BusySpan(
    TimeSpan(c.span.start.subtract(Duration(minutes: minutes)), c.span.start),
    kind,
    sourceId: c.slot.id,
  );
  BusySpan after(
    ({TimeSpan span, ClassSlot slot}) c,
    int minutes,
    BusyKind kind,
  ) => BusySpan(
    TimeSpan(c.span.end, c.span.end.add(Duration(minutes: minutes))),
    kind,
    sourceId: c.slot.id,
  );

  // 다른 수업 시간과 겹치는 이동은 놓지 않는다(대면 수업 바로 뒤에 실시간 온라인 수업이 이어지는 날처럼 이동할
  // 틈이 없는 때. docs/decisions.md 2026-11-19 '수업과 겹치는 이동 시간은 놓지 않는다').
  bool clear(BusySpan travelSpan) => !classes.any(
    (other) =>
        other.span.start.isBefore(travelSpan.span.end) &&
        travelSpan.span.start.isBefore(other.span.end),
  );

  return [
    for (final c in classes) ...[
      BusySpan(c.span, BusyKind.classTime, sourceId: c.slot.id),
      if (!c.slot.online && bufferMin > 0) ...[
        before(c, bufferMin, BusyKind.classBuffer),
        after(c, bufferMin, BusyKind.classBuffer),
      ],
      if (travel != null && travel.minutes > 0) ...[
        if (travel.position == TravelPosition.everyClass
            ? inPerson.contains(c)
            : c == firstClass)
          if (before(c, travel.minutes, BusyKind.travel) case final span
              when clear(span))
            span,
        if (travel.position == TravelPosition.everyClass
            ? inPerson.contains(c)
            : c == lastClass)
          if (after(c, travel.minutes, BusyKind.travel) case final span
              when clear(span))
            span,
      ],
    ],
  ];
}

/// [slot]이 [date]에 열리는 시각(그 날짜 0시 기준 분). [exceptions]는 그 날짜·그 칸의 예외다.
///
/// 평소 요일이고 그날 휴강이 없으면 평소 시각에 한 번, 보강마다 저장된 보강 시각(없으면 평소 시각)에 한 번
/// 열린다(휴강과 관계없이). 같은 시각은 한 번만 센다. R0는 [ClassSlot.repeatRule](R1)을 읽지 않고 요일이
/// 같으면 매주 열린다고 본다. R1의 격주·특정 주 반복은 여기서 거른다.
Set<MinuteRange> _occurrences(
  ClassSlot slot,
  DateTime date,
  List<ClassException> exceptions,
) => {
  if (slot.weekday == date.weekday &&
      !exceptions.any((e) => e.kind == ClassExceptionKind.cancelled))
    MinuteRange(slot.startMin, slot.endMin),
  for (final exception in exceptions)
    if (exception.kind == ClassExceptionKind.makeup)
      MinuteRange(
        exception.startMin ?? slot.startMin,
        exception.endMin ?? slot.endMin,
      ),
};

int _byStart(BusySpan a, BusySpan b) {
  final byStart = a.span.start.compareTo(b.span.start);
  if (byStart != 0) return byStart;
  final byEnd = a.span.end.compareTo(b.span.end);
  if (byEnd != 0) return byEnd;
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  return (a.sourceId ?? -1).compareTo(b.sourceId ?? -1);
}

/// [date]의 논리적 하루: 하루 경계부터 다음 날 하루 경계 전까지(`domain/clock.dart`).
TimeSpan _logicalDay(DateTime date, int dayBoundaryMin) => TimeSpan(
  logicalDayStart(date, dayBoundaryMin: dayBoundaryMin),
  logicalDayEnd(date, dayBoundaryMin: dayBoundaryMin),
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
