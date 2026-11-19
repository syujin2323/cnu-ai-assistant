// 08 월간의 달력. docs/screens.md '08 월간'.
//
// 이벤트만 보인다: 약속·행사 같은 일정, 종일 일정, 시험인 수업, 공휴일. 달의 주마다 월요일부터 일요일까지 칸을
// 만들고, 일정이 있는 날에 점을, 공휴일에 붉은 날짜와 이름을 둔다. 같은 입력이면 늘 같은 결과다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/holidays.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';

/// 달력의 한 칸.
final class MonthCell {
  const MonthCell({
    required this.date,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.dot,
    this.holiday,
  });

  /// 그날 0시.
  final DateTime date;

  /// 보는 달의 날이다(앞뒤 달의 날은 흐리게 씀).
  final bool inMonth;

  final bool today;
  final bool selected;

  /// 일정·종일 일정·시험이 있다.
  final bool dot;

  /// 공휴일 이름.
  final String? holiday;

  /// 날짜를 붉게 쓰는 날(일요일과 공휴일).
  bool get red => date.weekday == DateTime.sunday || holiday != null;
}

/// 08 월간의 달력.
final class MonthView {
  const MonthView({
    required this.month,
    required this.label,
    required this.weeks,
    required this.showToday,
  });

  /// 보는 달의 1일.
  final DateTime month;

  /// '2026년 11월'.
  final String label;

  /// 주마다 일곱 칸(월–일).
  final List<List<MonthCell>> weeks;

  /// 오늘이 든 달이 아니면 '오늘'을 둔다.
  final bool showToday;
}

/// 달력에 보이는 첫날([month]의 1일이 든 주의 월요일).
DateTime monthGridStart(DateTime month) {
  final first = DateTime(month.year, month.month);
  return DateTime(first.year, first.month, first.day - (first.weekday - 1));
}

/// 달력에 보이는 마지막 날 다음 날([month]의 말일이 든 주의 일요일 다음 날 0시).
DateTime monthGridEnd(DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0);
  return DateTime(last.year, last.month, last.day + (8 - last.weekday));
}

/// [month](그 달의 아무 날)의 달력. [events]는 달력 범위의 일정, [exceptions]는 그 범위의 수업 예외다.
MonthView monthView({
  required DateTime month,
  required DateTime today,
  required DateTime selected,
  required List<Event> events,
  required List<ClassException> exceptions,
  required int dayBoundaryMin,
}) {
  final first = DateTime(month.year, month.month);
  final start = monthGridStart(first);
  final end = monthGridEnd(first);
  final dots = <DateTime>{};
  for (final event in events) {
    if (event.allDay) {
      // 종일 일정의 끝은 마지막 날 다음 날 0시다.
      for (
        var day = DateTime(
          event.startAt.year,
          event.startAt.month,
          event.startAt.day,
        );
        day.isBefore(event.endAt);
        day = DateTime(day.year, day.month, day.day + 1)
      ) {
        dots.add(day);
      }
    } else {
      dots.add(logicalDate(event.startAt, dayBoundaryMin: dayBoundaryMin));
    }
  }
  for (final exception in exceptions) {
    if (exception.kind != ClassExceptionKind.exam) continue;
    final day = DateTime.tryParse(exception.date);
    if (day != null) dots.add(DateTime(day.year, day.month, day.day));
  }
  final weeks = <List<MonthCell>>[];
  for (
    var monday = start;
    monday.isBefore(end);
    monday = DateTime(monday.year, monday.month, monday.day + 7)
  ) {
    weeks.add([
      for (var i = 0; i < 7; i++)
        if (DateTime(monday.year, monday.month, monday.day + i) case final d)
          MonthCell(
            date: d,
            inMonth: d.month == first.month,
            today: d == today,
            selected: d == selected,
            dot: dots.contains(d),
            holiday: holidayName(d),
          ),
    ]);
  }
  return MonthView(
    month: first,
    label: '${first.year}년 ${first.month}월',
    weeks: weeks,
    showToday: today.year != first.year || today.month != first.month,
  );
}
