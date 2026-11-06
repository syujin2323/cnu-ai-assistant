// 시각·길이·요일·날짜 말 표기. docs/screens.md '날짜·시각 표기', docs/architecture.md
// '앱 코드 규약'의 시각 규칙.
//
// 문장 속 시각은 "오전 10시 30분"처럼 12시간제, 길이는 "2시간"·"50분"처럼 아라비아 숫자로 쓴다.
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

/// 날짜 말. 오늘·내일·모레, 3–6일 뒤는 '{요일}요일', 7일 뒤부터 'N일 뒤', 지난 날은
/// '어제'·'N일 전'이다('그저께'는 쓰지 않는다). 마감뿐 아니라 블록·수업 날짜에도 쓴다.
///
/// 날은 [dayOffset]으로 센다. [at]과 [now]를 모두 [dayBoundaryMin]을 반영한 논리적 하루로
/// 바꿔 날짜 단위로 세므로, 오늘 이미 지난 마감도 '오늘'이고 하루 경계 전의 새벽은 전날이다
/// (24:00 마감인 다음 날 00:00은 그 전날의 마감이다). [now]에는 [Clock.now]의 값을 넘긴다.
String dayWord(
  DateTime at, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final days = dayOffset(at, now: now, dayBoundaryMin: dayBoundaryMin);
  return switch (days) {
    -1 => '어제',
    < -1 => '${-days}일 전',
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    >= 3 && <= 6 =>
      '${weekdayText(logicalDate(at, dayBoundaryMin: dayBoundaryMin).weekday)}요일',
    _ => '$days일 뒤',
  };
}

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
