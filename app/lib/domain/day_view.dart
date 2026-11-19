// 09 일간의 시간표 밖에 보일 것. docs/screens.md '09 일간'.
//
// 위 막대의 주 범위와 날짜 줄 7칸(공휴일은 붉게), 머리(날짜와 '오늘 · 수업 N개 · 할 일 N개 · 일정 N개 · 빈 시간 N'),
// 공휴일 카드, 종일 일정, '모두 확정' 띠가 확정할 제안, 빈 날 카드, 마감 줄을 정한다. 시간표는 02 홈과 같은
// `dayItems`와 `DayTimeline`이다(09는 제안 블록도 넣음). 모양과 문구는 최종 프로토타입(09 일간)을 따르고, 문구는 디자인
// 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/holidays.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 머리에 '빈 시간 N'을 쓰는 가장 짧은 빈 시간 합(분, 최종 프로토타입).
const int dayViewFreeShownMin = 30;

/// 날짜 줄의 하루.
final class DayStripDay {
  const DayStripDay({
    required this.date,
    required this.label,
    required this.today,
    required this.selected,
    this.holiday,
  });

  /// 그날 0시.
  final DateTime date;

  /// 요일 한 글자('월'). 오늘이면 '오늘'.
  final String label;

  final bool today;
  final bool selected;

  /// 그날 공휴일의 이름(`domain/holidays.dart`). 공휴일이 아니면 null이다.
  final String? holiday;

  /// 일요일.
  bool get sunday => date.weekday == DateTime.sunday;

  /// 날짜를 붉게 쓰는 날(일요일과 공휴일).
  bool get red => sunday || holiday != null;
}

/// 그날의 공휴일 카드. 공휴일에도 수업은 그대로라(docs/decisions.md 2026-11-19 '학사일정은 넣지 않고 공휴일은 앱 안
/// 표로 둔다') 이름만 알리고, 수업이 있으면 휴강으로 바꾸는 길을 알린다.
final class DayHoliday {
  const DayHoliday({required this.name, required this.meta});

  /// 공휴일 이름('성탄절').
  final String name;

  /// 이름 아래 줄('공휴일', 그날 수업이 있으면 '공휴일 · 쉬는 수업은 눌러서 휴강으로 바꿔요').
  final String meta;
}

/// 마감 줄 하나.
final class DayDueRow {
  const DayDueRow({
    required this.entry,
    required this.time,
    required this.urgent,
    required this.finished,
    this.state,
  });

  final TaskEntry entry;

  /// 마감 시각('23:59', 자정은 '24:00', 시각을 모르면 '시각 미상').
  final String time;

  /// 오늘·내일 마감이고 아직 남았다(붉게 씀).
  final bool urgent;

  /// 끝낸 일(앱에서 끝냄, LMS 제출·출석 인정). 흐리게 줄을 긋는다.
  final bool finished;

  /// 오른쪽에 붙이는 상태('완료', 'LMS 제출 확인', 'LMS 출석 인정', '마감 지남').
  final String? state;

  String get title => entry.task.title;
}

/// 종일 일정 하나.
final class DayAllDay {
  const DayAllDay({required this.event, required this.meta});

  final Event event;

  /// 제목 아래 줄(장소, 없으면 '하루 종일').
  final String meta;
}

/// 빈 날 카드(수업·일정이 없는 날).
final class DayEmptyCard {
  const DayEmptyCard({required this.title, required this.body});

  final String title;
  final String body;
}

/// 09 일간의 시간표 밖에 보일 것.
final class DayView {
  const DayView({
    required this.today,
    required this.weekLabel,
    required this.strip,
    required this.showToday,
    required this.title,
    required this.sub,
    required this.allDay,
    required this.confirmable,
    required this.confirmedToast,
    required this.dues,
    required this.free,
    this.holiday,
    this.empty,
  });

  /// 오늘(논리적 하루, 그날 0시). '오늘' 알약이 이 날로 간다.
  final DateTime today;

  /// 위 막대의 주 범위('11월 16일 – 22일').
  final String weekLabel;

  /// 그 주 월요일부터 일요일까지.
  final List<DayStripDay> strip;

  /// 오늘이 아니면 '오늘' 알약을 둔다.
  final bool showToday;

  /// 머리의 날짜('11월 19일 (목)').
  final String title;

  /// 머리 아래 줄('오늘 · 수업 2개 · 할 일 3개 · 일정 1개 · 빈 시간 2시간 30분', 아무것도 없으면 '일정 없음').
  final String sub;

  /// 그날이 공휴일이면 머리 아래(종일 일정 위)에 둘 카드.
  final DayHoliday? holiday;

  final List<DayAllDay> allDay;

  /// '모두 확정'이 확정할 제안 블록(오늘은 지금 뒤에 끝나는 것만). 비었으면 띠를 두지 않는다.
  final List<PlanBlock> confirmable;

  /// '모두 확정' 뒤 토스트('내일 제안 3개를 확정했어요'). [confirmable]이 비었으면 빈 글자다.
  final String confirmedToast;

  final List<DayDueRow> dues;

  /// 시간표의 빈 시간 카드에 쓸 빈 구간: 그날의 빈 시간에서 제안 자리를 뺀 것(09는 제안을 그리므로 겹치지 않게).
  /// 지난 날은 비어 있다(할 일은 오늘부터 놓음).
  final List<TimeSpan> free;

  final DayEmptyCard? empty;

  /// '모두 확정' 띠의 제목('제안 2개가 확정 전이에요').
  String get confirmTitle => '제안 ${confirmable.length}개가 확정 전이에요';
}

/// 논리적 하루 [date](그날 0시)의 09 일간. [items]는 `dayItems`(제안 블록 포함), [allDayEvents]는 그날에 걸친
/// 종일 일정, [entries]는 모든 할 일, [free]는 그날의 빈 구간(`DayAvailability.free`)이다.
DayView dayView({
  required DateTime date,
  required List<DayItem> items,
  required List<Event> allDayEvents,
  required List<TaskEntry> entries,
  required List<TimeSpan> free,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final offset = _daysBetween(today, day);
  final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));

  final blocks = [
    for (final item in items)
      if (item is BlockItem) item.block,
  ];
  final classes = items
      .whereType<ClassItem>()
      .where((item) => !item.cancelled)
      .length;
  final events =
      items.where((item) => item is EventItem || item is FixedItem).length +
      allDayEvents.length;
  final tasks = blocks
      .where((block) => block.status != PlanBlockStatus.missed)
      .length;
  final suggested = [
    for (final block in blocks)
      if (block.status == PlanBlockStatus.suggested) block,
  ];
  final confirmable = [
    for (final block in suggested)
      if (offset != 0 || block.endAt.isAfter(now)) block,
  ];

  final suggestedSpans = [
    for (final block in suggested) TimeSpan(block.startAt, block.endAt),
  ];
  final open = offset < 0
      ? const <TimeSpan>[]
      : [for (final span in free) ...subtractSpans(span, suggestedSpans)];
  final freeMin = (offset == 0 ? spansFrom(open, now) : open).fold<int>(
    0,
    (sum, span) => sum + span.minutes,
  );

  final sub = [
    ?switch (offset) {
      -1 => '어제',
      0 => '오늘',
      1 => '내일',
      _ => null,
    },
    if (classes > 0) '수업 $classes개',
    if (tasks > 0) '할 일 $tasks개',
    if (events > 0) '일정 $events개',
    if (freeMin >= dayViewFreeShownMin)
      '빈 시간 ${durationText((freeMin / 10).round() * 10)}',
  ];

  return DayView(
    today: today,
    weekLabel: weekRangeText(monday, today: today),
    strip: [
      for (var i = 0; i < 7; i++)
        if (DateTime(monday.year, monday.month, monday.day + i) case final d)
          DayStripDay(
            date: d,
            label: d == today ? '오늘' : weekdayText(d.weekday),
            today: d == today,
            selected: d == day,
            holiday: holidayName(d),
          ),
    ],
    showToday: offset != 0,
    title: monthDayText(day, today: today),
    sub: sub.isEmpty ? '일정 없음' : sub.join(' · '),
    holiday: switch (holidayName(day)) {
      final name? => DayHoliday(
        name: name,
        meta: classes > 0 ? '공휴일 · 쉬는 수업은 눌러서 휴강으로 바꿔요' : '공휴일',
      ),
      null => null,
    },
    allDay: [
      for (final event in allDayEvents)
        DayAllDay(
          event: event,
          meta: event.place?.trim().isNotEmpty == true
              ? event.place!.trim()
              : '하루 종일',
        ),
    ],
    confirmable: confirmable,
    confirmedToast: confirmable.isEmpty
        ? ''
        : '${dayWord(confirmable.first.startAt, now: now, dayBoundaryMin: dayBoundaryMin)} '
              '제안 ${confirmable.length}개를 확정했어요',
    dues: _dues(day, entries, now: now, offset: offset),
    free: open,
    empty: classes > 0 || events > 0
        ? null
        : DayEmptyCard(
            title: '수업·일정이 없는 날이에요',
            body: offset < 0
                ? '지난 날이에요. 할 일은 오늘부터 놓을 수 있어요'
                : confirmable.isNotEmpty
                ? '제안 ${confirmable.length}개는 아래 시간표에 있어요. 빈 시간을 눌러 더 놓을 수도 있어요'
                : '빈 시간을 눌러 할 일을 놓을 수 있어요',
          ),
  );
}

/// 그날 마감인 할 일(숨긴 일과 LMS에서 사라진 일은 빼고, 끝낸 일은 흐리게). 마감 시각 순서, 같으면 id 순서다.
List<DayDueRow> _dues(
  DateTime day,
  List<TaskEntry> entries, {
  required DateTime now,
  required int offset,
}) {
  final due =
      [
        for (final entry in entries)
          if (entry.task.dueAt case final dueAt?)
            if (dueDateOf(dueAt) == day &&
                entry.task.status != TaskStatus.hidden &&
                !entry.isGone)
              entry,
      ]..sort((a, b) {
        final byDue = a.task.dueAt!.compareTo(b.task.dueAt!);
        return byDue != 0 ? byDue : a.task.id.compareTo(b.task.id);
      });
  return [
    for (final entry in due)
      if (entry.task.dueAt case final dueAt?)
        _dueRow(entry, dueAt, now: now, offset: offset),
  ];
}

DayDueRow _dueRow(
  TaskEntry entry,
  DateTime dueAt, {
  required DateTime now,
  required int offset,
}) {
  final task = entry.task;
  final finished = entry.isDone;
  final past = !dueAt.isAfter(now);
  final lms = entry.lmsItem;
  final minute = dueAt.hour * 60 + dueAt.minute;
  return DayDueRow(
    entry: entry,
    time: task.dueTimeUnknown ? '시각 미상' : hhmmText(minute == 0 ? 1440 : minute),
    urgent: !finished && !past && offset <= 1,
    finished: finished,
    state: lms?.officiallyDone == true
        ? 'LMS 출석 인정'
        : lms?.submitted == true
        ? 'LMS 제출 확인'
        : task.status == TaskStatus.done
        ? '완료'
        : past
        ? '마감 지남'
        : null,
  );
}

/// [from]에서 [to]까지의 날 수(날짜만 본다).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
