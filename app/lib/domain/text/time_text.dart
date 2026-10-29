// 시각·길이·요일·마감 표기. docs/architecture.md '앱 코드 규약', '브리핑 초안과 템플릿',
// `POST /v1/briefing`의 `dueLabel`.
//
// 앱 문장의 시각은 "오후 1시"처럼 12시간제, 길이는 "2시간"·"50분"처럼 아라비아 숫자로 쓴다.
// 하루 안의 시각은 폰 DB처럼 자정 기준 분(09:30 → 570)으로 받는다.

import 'package:cnu_ai_assistant/domain/clock.dart';

/// 자정 기준 분을 12시간제로 적는다. 570 → '오전 9시 30분', 780 → '오후 1시',
/// 0 → '오전 12시', 720 → '오후 12시'. 자정을 넘어 1440을 더한 값은 그 시각으로 적는다.
String clockText(int minuteOfDay) {
  RangeError.checkNotNegative(minuteOfDay, 'minuteOfDay');
  final hour = minuteOfDay ~/ 60 % 24;
  final minute = minuteOfDay % 60;
  final period = hour < 12 ? '오전' : '오후';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return minute == 0 ? '$period $hour12시' : '$period $hour12시 $minute분';
}

/// 길이를 적는다. 50 → '50분', 120 → '2시간', 90 → '1시간 30분', 0 → '0분'.
String durationText(int minutes) {
  RangeError.checkNotNegative(minutes, 'minutes');
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest분';
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}

/// 요일 한 글자. [weekday]는 1(월)–7(일)이다. 서버 API의 `weekday` 값도 이것이다.
String weekdayText(int weekday) {
  RangeError.checkValueInInterval(
    weekday,
    DateTime.monday,
    DateTime.sunday,
    'weekday',
  );
  return _weekdays[weekday - DateTime.monday];
}

/// 마감까지 남은 날을 적는다. 오늘·내일·모레, 6일 안이면 '{요일}요일', 그보다 멀면 'N일 뒤'.
///
/// 날은 논리적 하루로 센다. [today]는 [Clock.today]의 값이고, [dueAt]도 [dayBoundaryMin]을
/// 반영해 그 마감이 속한 논리적 하루로 바꿔 센다(24:00 마감인 다음 날 00:00은 그 전날이다).
/// 이미 지난 마감은 넣지 않는다.
String dueLabel(
  DateTime dueAt, {
  required DateTime today,
  required int dayBoundaryMin,
}) {
  final dueDate = logicalDate(dueAt, dayBoundaryMin: dayBoundaryMin);
  final days = _daysBetween(today, dueDate);
  if (days < 0) {
    throw ArgumentError.value(dueAt, 'dueAt', 'is before today');
  }
  return switch (days) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    <= 6 => '${weekdayText(dueDate.weekday)}요일',
    _ => '$days일 뒤',
  };
}

/// 두 날짜 사이의 달력 일수. 시각은 보지 않는다.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
