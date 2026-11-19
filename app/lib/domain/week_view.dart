// 11 주간에 보일 것. docs/screens.md '11 주간'.
//
// 주 범위와 요약 세 칸, 날짜마다 날짜 줄(하루 막대 8–23시와 '빈 시간 N · 수업 N개 · 할 일 N개')·마감 줄·일정 줄
// (4개까지와 'N개 더 보기')을 정한다. 날짜별 재료는 09 일간과 같은 `dayItems`·`dayView`다. '제안 일정'을 켜면
// 제안 블록을 막대와 목록에 넣고 빈 시간에서 뺀다. 같은 입력이면 늘 같은 결과다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/day_view.dart';
import 'package:cnu_ai_assistant/domain/holidays.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 하루 막대가 보이는 시간대(자정 기준 분). 08:00–23:00.
abstract final class WeekBarRange {
  static const int startMin = 480;
  static const int endMin = 1380;
}

/// 날짜마다 보이는 일정 줄 수. 넘으면 'N개 더 보기'다.
const int weekItemsShown = 4;

/// 막대 조각의 종류.
enum WeekBarKind { classItem, event, block, suggested }

/// 하루 막대의 조각. [from]·[to]는 막대 너비에 대한 비율(0–1)이다.
final class WeekBar {
  const WeekBar({required this.from, required this.to, required this.kind});

  final double from;
  final double to;
  final WeekBarKind kind;
}

/// 일정 줄 하나.
final class WeekItemRow {
  const WeekItemRow({
    required this.item,
    required this.time,
    required this.title,
    this.tag,
    this.dim = false,
    this.allDay,
  });

  /// 시간표 항목. 종일 일정이면 null이고 [allDay]가 있다.
  final DayItem? item;

  /// 종일 일정.
  final Event? allDay;

  /// 'HH:MM'(종일 일정은 '종일').
  final String time;

  final String title;

  /// 꼬리표('제안'·'시험'·'휴강'·'보강'·'완료'·'놓침').
  final String? tag;

  /// 흐리게 쓴다(휴강한 수업, 끝낸·놓친 블록).
  final bool dim;
}

/// 날짜 하나.
final class WeekDay {
  const WeekDay({
    required this.date,
    required this.title,
    required this.today,
    required this.red,
    required this.sub,
    required this.bars,
    required this.dues,
    required this.items,
    required this.more,
    this.holiday,
  });

  /// 그날 0시.
  final DateTime date;

  /// '19일 (목)'. 오늘이면 '오늘 · 19일 (목)'.
  final String title;

  final bool today;

  /// 날짜를 붉게 쓰는 날(일요일과 공휴일).
  final bool red;

  /// 공휴일 이름.
  final String? holiday;

  /// '빈 시간 2시간 · 수업 2개 · 할 일 1개'. 아무것도 없으면 '일정 없음'.
  final String sub;

  final List<WeekBar> bars;
  final List<DayDueRow> dues;

  /// 보이는 일정 줄([weekItemsShown]개까지).
  final List<WeekItemRow> items;

  /// 더 있는 일정 수.
  final int more;
}

/// 요약 칸 하나.
final class WeekCell {
  const WeekCell(this.label, this.value);

  final String label;
  final String value;
}

/// 11 주간.
final class WeekView {
  const WeekView({
    required this.monday,
    required this.label,
    required this.showToday,
    required this.cells,
    required this.days,
  });

  final DateTime monday;

  /// 주 범위('11월 16일 – 22일').
  final String label;

  /// 이번 주가 아니면 '오늘' 알약을 둔다.
  final bool showToday;

  /// 요약 세 칸.
  final List<WeekCell> cells;

  /// 월요일부터 일요일까지.
  final List<WeekDay> days;
}

/// 날짜 하나의 재료.
typedef WeekDayInput = ({
  DateTime date,
  List<DayItem> items,
  List<Event> allDay,
  List<DayDueRow> dues,

  /// 그날의 빈 구간(`DayAvailability.free`).
  List<TimeSpan> free,
});

/// [monday]로 시작하는 주의 11 주간. [days]는 월요일부터 일곱 날의 재료([WeekDayInput.items]는 제안 블록 포함),
/// [estimateOf]는 할 일의 남은 작업 시간(분, 모르면 null), [courseNames]는 과목 id → 이름이다.
WeekView weekView({
  required DateTime monday,
  required List<WeekDayInput> days,
  required DateTime today,
  required DateTime now,
  required bool showSuggested,
  required Map<int, String> courseNames,
  required int? Function(TaskEntry entry) estimateOf,
}) {
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  final past = sunday.isBefore(today);
  final rows = [
    for (final day in days)
      _day(
        day,
        today: today,
        now: now,
        showSuggested: showSuggested,
        courseNames: courseNames,
      ),
  ];
  final dues = [for (final day in days) ...day.dues];
  final blocks = [
    for (final day in days)
      for (final item in day.items)
        if (item is BlockItem) item.block,
  ];
  final List<WeekCell> cells;
  if (past) {
    cells = [
      WeekCell('마감', '${dues.length}개'),
      WeekCell('지킨 마감', '${dues.where((d) => d.finished).length}개'),
      WeekCell(
        '놓친 블록',
        '${blocks.where((b) => b.status == PlanBlockStatus.missed).length}개',
      ),
    ];
  } else {
    final left = [
      for (final due in dues)
        if (!due.finished) due.entry,
    ];
    final estimate = left.fold<int>(
      0,
      (sum, entry) => sum + (estimateOf(entry) ?? 0).clamp(0, 100000),
    );
    var freeMin = 0;
    for (final day in days) {
      if (day.date.isBefore(today)) continue;
      freeMin += _freeMin(
        day,
        now: day.date == today ? now : null,
        showSuggested: showSuggested,
      );
    }
    cells = [
      WeekCell('마감', '${left.length}개'),
      WeekCell('할 일 예상 시간', estimate == 0 ? '없음' : durationText(estimate)),
      WeekCell('빈 시간', freeMin < 10 ? '없음' : durationText(freeMin)),
    ];
  }
  return WeekView(
    monday: monday,
    label: weekRangeText(monday, today: today),
    showToday: today.isBefore(monday) || today.isAfter(sunday),
    cells: cells,
    days: rows,
  );
}

/// 그날의 남은 빈 시간(분, 10분 단위로 반올림). [now]가 있으면 그 뒤만 센다. [showSuggested]면 제안 자리를 뺀다.
int _freeMin(WeekDayInput day, {DateTime? now, required bool showSuggested}) {
  final suggested = [
    for (final item in day.items)
      if (item is BlockItem && item.block.status == PlanBlockStatus.suggested)
        item.span,
  ];
  final open = showSuggested
      ? [for (final span in day.free) ...subtractSpans(span, suggested)]
      : day.free;
  final minutes = (now == null ? open : spansFrom(open, now)).fold<int>(
    0,
    (sum, span) => sum + span.minutes,
  );
  return (minutes / 10).round() * 10;
}

WeekDay _day(
  WeekDayInput day, {
  required DateTime today,
  required DateTime now,
  required bool showSuggested,
  required Map<int, String> courseNames,
}) {
  final date = day.date;
  final isToday = date == today;
  final shown = [
    for (final item in day.items)
      if (item is! TravelItem && item is! MealItem)
        if (showSuggested ||
            item is! BlockItem ||
            item.block.status != PlanBlockStatus.suggested)
          item,
  ];
  final classes = shown
      .whereType<ClassItem>()
      .where((item) => !item.cancelled)
      .length;
  final tasks = shown
      .whereType<BlockItem>()
      .where((item) => item.block.status != PlanBlockStatus.missed)
      .length;
  final freeMin = date.isBefore(today)
      ? 0
      : _freeMin(day, now: isToday ? now : null, showSuggested: showSuggested);
  final sub = [
    if (freeMin >= dayViewFreeShownMin) '빈 시간 ${durationText(freeMin)}',
    if (classes > 0) '수업 $classes개',
    if (tasks > 0) '할 일 $tasks개',
  ];
  final rows = [
    for (final event in day.allDay)
      WeekItemRow(item: null, allDay: event, time: '종일', title: event.title),
    for (final item in shown) _row(item, courseNames),
  ];
  final base = DateTime(date.year, date.month, date.day);
  const span = WeekBarRange.endMin - WeekBarRange.startMin;
  final bars = <WeekBar>[];
  for (final item in shown) {
    if (item is ClassItem && item.cancelled) continue;
    final from = item.span.start
        .difference(base)
        .inMinutes
        .clamp(WeekBarRange.startMin, WeekBarRange.endMin);
    final to = item.span.end
        .difference(base)
        .inMinutes
        .clamp(WeekBarRange.startMin, WeekBarRange.endMin);
    if (to <= from) continue;
    bars.add(
      WeekBar(
        from: (from - WeekBarRange.startMin) / span,
        to: (to - WeekBarRange.startMin) / span,
        kind: switch (item) {
          ClassItem() => WeekBarKind.classItem,
          BlockItem(:final block)
              when block.status == PlanBlockStatus.suggested =>
            WeekBarKind.suggested,
          BlockItem() => WeekBarKind.block,
          _ => WeekBarKind.event,
        },
      ),
    );
  }
  final holiday = holidayName(date);
  final label = '${date.day}일 (${weekdayText(date.weekday)})';
  return WeekDay(
    date: date,
    title: isToday ? '오늘 · $label' : label,
    today: isToday,
    red: date.weekday == DateTime.sunday || holiday != null,
    holiday: holiday,
    sub: sub.isEmpty ? '일정 없음' : sub.join(' · '),
    bars: bars,
    dues: day.dues,
    items: rows.take(weekItemsShown).toList(),
    more: rows.length > weekItemsShown ? rows.length - weekItemsShown : 0,
  );
}

WeekItemRow _row(DayItem item, Map<int, String> courseNames) {
  final start = item.span.start;
  final time = hhmmText(start.hour * 60 + start.minute);
  return switch (item) {
    ClassItem(:final slot, :final cancelled, :final exam, :final makeup) =>
      WeekItemRow(
        item: item,
        time: time,
        title: courseNames[slot.courseId] ?? '수업',
        tag: cancelled
            ? '휴강'
            : exam
            ? '시험'
            : makeup
            ? '보강'
            : null,
        dim: cancelled,
      ),
    EventItem(:final event) => WeekItemRow(
      item: item,
      time: time,
      title: event.title,
    ),
    FixedItem(:final block) => WeekItemRow(
      item: item,
      time: time,
      title: block.name,
    ),
    BlockItem(:final block, :final entry) => WeekItemRow(
      item: item,
      time: time,
      title: entry?.task.title ?? '할 일',
      tag: switch (block.status) {
        PlanBlockStatus.suggested => '제안',
        PlanBlockStatus.done => '완료',
        PlanBlockStatus.missed => '놓침',
        _ => null,
      },
      dim:
          block.status == PlanBlockStatus.done ||
          block.status == PlanBlockStatus.missed ||
          entry?.task.status == TaskStatus.done,
    ),
    TravelItem() ||
    MealItem() => WeekItemRow(item: item, time: time, title: ''),
  };
}
