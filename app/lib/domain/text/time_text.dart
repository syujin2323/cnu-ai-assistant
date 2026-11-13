// 시각·길이·요일·날짜 말 표기. docs/screens.md '날짜·시각 표기', docs/architecture.md
// '앱 코드 규약'의 시각 규칙.
//
// 문장 속 시각은 "오전 10시 30분"처럼 12시간제([clockText]), 화면의 시각은 "09:30"처럼 24시간제
// ([hhmmText]), 칩은 "오전 8:00"처럼([shortClockText]), 길이는 "2시간"·"50분"처럼 아라비아 숫자로 쓴다.
// 하루 안의 시각은 폰 DB처럼 자정 기준 분(09:30 → 570)으로 받는다. 자정(00:00·24:00)과 하루 경계 전
// 새벽 시각의 표기는 정하지 않았다(docs/screens.md '날짜·시각 표기'). 정할 때까지 [hhmmText]·
// [shortClockText]는 그 값을 받지 않고, [clockText]·[dueText]는 실제 시각을 그대로 적는다.

import 'package:cnu_ai_assistant/domain/clock.dart';

/// 문장 속 시각. 자정 기준 분을 12시간제로 적는다. 570 → '오전 9시 30분', 780 → '오후 1시',
/// 0 → '오전 12시', 720 → '오후 12시'. 자정을 넘어 1440을 더한 값(2879까지)은 그 시각으로 적는다.
/// 화면의 'HH:MM'은 [hhmmText], 칩은 [shortClockText]다.
String clockText(int minuteOfDay) {
  RangeError.checkValueInInterval(
    minuteOfDay,
    0,
    2 * _minutesPerDay - 1,
    'minuteOfDay',
  );
  final hour = minuteOfDay ~/ 60 % 24;
  final minute = minuteOfDay % 60;
  final period = hour < 12 ? '오전' : '오후';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return minute == 0 ? '$period $hour12시' : '$period $hour12시 $minute분';
}

/// 화면의 시각 'HH:MM'(24시간제). 570 → '09:30', 1439 → '23:59'. 09 일간의 'HH:MM에 놓기', 마감 문구,
/// 하루 경계 같은 자리에 쓴다. 서버·JSON의 시각 변환에는 쓰지 않는다(그쪽은 `schema/`의 시각 꼴을
/// 따르고 24:00을 받지 않는다). 자정을 넘는 끝 시각(1440 이상)의 표기는 정하지 않아 아직 받지 않는다.
String hhmmText(int minuteOfDay) {
  RangeError.checkValueInInterval(
    minuteOfDay,
    0,
    _minutesPerDay - 1,
    'minuteOfDay',
  );
  return '${_twoDigits(minuteOfDay ~/ 60)}:${_twoDigits(minuteOfDay % 60)}';
}

/// 칩의 시각 '오전 8:00'·'오후 12:30'(12시간제). 14 온보딩 5단계·10 나·12 내 규칙의 브리핑 시각 칩이
/// 쓴다. 자정 무렵(00:00–00:59)과 1440 이상의 표기는 정하지 않아 아직 받지 않는다.
String shortClockText(int minuteOfDay) {
  RangeError.checkValueInInterval(
    minuteOfDay,
    60,
    _minutesPerDay - 1,
    'minuteOfDay',
  );
  final hour = minuteOfDay ~/ 60;
  final period = hour < 12 ? '오전' : '오후';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $hour12:${_twoDigits(minuteOfDay % 60)}';
}

/// 마감 문구(docs/screens.md '날짜·시각 표기'). 마감이 없으면 '마감 없음', 시각을 모르면
/// '{날짜 말} 마감 · 시각 미상'(임시), 그 밖에는 '{날짜 말} HH:MM 마감'이다. 날짜 말은 [dayWord]이고
/// [now]에는 [Clock.now]의 값을 넘긴다.
///
/// 정확히 00:00인 마감(24:00 마감)과 하루 경계 전 새벽 마감의 표기는 정하지 않았다. 그때까지는 논리적
/// 하루의 날짜 말에 실제 시각을 붙인다(하루 경계 04:00에서 금요일 01:00 마감은 '목요일 01:00 마감').
String dueText(
  DateTime? dueAt, {
  required bool dueTimeUnknown,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  if (dueAt == null) return '마감 없음';
  final day = dayWord(dueAt, now: now, dayBoundaryMin: dayBoundaryMin);
  if (dueTimeUnknown) return '$day 마감 · 시각 미상';
  return '$day ${hhmmText(dueAt.hour * 60 + dueAt.minute)} 마감';
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

/// 붉게 쓸 마감인지. 오늘·내일 마감만 붉게 쓴다(docs/screens.md '날짜·시각 표기').
/// [days]는 그 마감의 [dayOffset] 값이다.
bool isDueSoon(int days) => days == 0 || days == 1;

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

const int _minutesPerDay = 1440;

String _twoDigits(int value) => value.toString().padLeft(2, '0');
