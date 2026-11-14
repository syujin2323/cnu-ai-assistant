// 시각·길이·요일·날짜 말 표기. docs/screens.md '날짜·시각 표기', docs/architecture.md
// '앱 코드 규약'의 시각 규칙.
//
// 문장 속 시각은 "오전 10시 30분"처럼 12시간제([clockText]), 화면의 시각은 "09:30"처럼 24시간제
// ([hhmmText]), 칩은 "오전 8:00"처럼([shortClockText]), 길이는 "2시간"·"50분"처럼 아라비아 숫자로 쓴다.
// 하루 안의 시각은 폰 DB처럼 자정 기준 분(09:30 → 570)으로 받는다. 자정(00:00·24:00)과 하루 경계 전
// 새벽 시각의 표기는 정하지 않았다(docs/screens.md '날짜·시각 표기'). 정할 때까지 00:00과 새벽 시각은 실제
// 시각을 그대로 적는다([hhmmText]는 0–1439, [shortClockText]는 60–1439를 받고 그 밖은 받지 않음). 그래서
// [hhmmText]를 거치는 [dueText]·[opensText]·[homeSummaryText]·[timeRangeText]도 새벽 시각을 그대로 쓰고,
// 표기를 정하는 PR이 이 함수들을 함께 고친다.
// 날짜(해가 다를 때만 연도), 지난 시간, 남은 일, 공개 줄, 02 머리, 주 범위, '불러옴', 시간 범위의 꼴은
// 임시다(docs/decisions.md 2026-11-13 '날짜·시각 표기의 꼴(임시)').

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
/// '{날짜 말} 마감 · 시각 미상'(임시), 그 밖에는 '{날짜 말} HH:MM 마감'이다. 날짜 말은 [dayWord]이고,
/// [farAsDate]가 true면(03 할 일) [taskDayText]다. [now]에는 [Clock.now]의 값을 넘긴다.
///
/// 정확히 00:00인 마감(24:00 마감)과 하루 경계 전 새벽 마감의 표기는 정하지 않았다. 그때까지는 논리적
/// 하루의 날짜 말에 실제 시각을 붙인다(하루 경계 04:00에서 금요일 01:00 마감은 '목요일 01:00 마감').
String dueText(
  DateTime? dueAt, {
  required bool dueTimeUnknown,
  required DateTime now,
  required int dayBoundaryMin,
  bool farAsDate = false,
}) {
  if (dueAt == null) return '마감 없음';
  final day = farAsDate
      ? taskDayText(dueAt, now: now, dayBoundaryMin: dayBoundaryMin)
      : dayWord(dueAt, now: now, dayBoundaryMin: dayBoundaryMin);
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
  return _dayWordOf(
    dayOffset(at, now: now, dayBoundaryMin: dayBoundaryMin),
    logicalDate(at, dayBoundaryMin: dayBoundaryMin),
  );
}

/// 오늘에서 [days]일 떨어진 날 [date]의 날짜 말([dayWord]의 규칙).
String _dayWordOf(int days, DateTime date) => switch (days) {
  -1 => '어제',
  < -1 => '${-days}일 전',
  0 => '오늘',
  1 => '내일',
  2 => '모레',
  >= 3 && <= 6 => '${weekdayText(date.weekday)}요일',
  _ => '$days일 뒤',
};

/// 날짜 '10월 21일 (수)'. 해가 [today]와 다르면 연도를 붙인다('2027년 1월 5일 (화)', 임시). 두 값 모두
/// 날짜만 본다. 마감·블록처럼 시각이 있는 값은 [logicalDate]로 바꾼 논리적 날짜를 넘기고(24:00 마감인 다음 날
/// 00:00은 그 전날), [today]에는 오늘의 논리적 날짜를 넘긴다. 02 홈 머리의 날짜도 이 꼴이다(임시).
String monthDayText(DateTime date, {required DateTime today}) =>
    '${_yearPrefix(date, today)}${date.month}월 ${date.day}일 '
    '(${weekdayText(date.weekday)})';

/// 03 할 일의 날짜. 7일 이상 남았거나 이틀 이상 지난 날은 [monthDayText], 그 밖에는 [dayWord]다
/// (docs/screens.md '날짜·시각 표기'). 날은 [dayOffset]으로 센다. [now]에는 [Clock.now]의 값을 넘긴다.
String taskDayText(
  DateTime at, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final days = dayOffset(at, now: now, dayBoundaryMin: dayBoundaryMin);
  if (days > -2 && days < 7) {
    return dayWord(at, now: now, dayBoundaryMin: dayBoundaryMin);
  }
  return monthDayText(
    logicalDate(at, dayBoundaryMin: dayBoundaryMin),
    today: logicalDate(now, dayBoundaryMin: dayBoundaryMin),
  );
}

/// 지난 시간 'N분 전'·'N시간 전'(docs/screens.md 'LMS 상태 줄과 다시 로그인'). 1시간(60분)까지는 분, 그
/// 뒤는 시간(내림)이다. 분은 정수로 세므로 60분 59초는 '60분 전', 61분은 '1시간 전', 1500분은 '25시간 전'이다.
/// 1분이 안 되면 '0분 전'(임시)이고, 음수(기기 시각이 뒤로 감)는 0으로 본다.
String elapsedText(Duration since) {
  final minutes = since.isNegative ? 0 : since.inMinutes;
  return minutes <= 60 ? '$minutes분 전' : '${minutes ~/ 60}시간 전';
}

/// LMS 상태 줄의 마지막 확인(임시). 확인에 성공한 적이 없으면 'LMS 정보 받기 전', 마지막 확인을 남긴 동기화가
/// 사용자 새로 고침이면 그 뒤 10분 동안 'LMS 정보 방금', 그 밖에는 'LMS 정보 {[elapsedText]}'다.
/// [lastSuccessAt]은 `settings`의 `lmsLastSuccessAt`(그 동기화의 시작 시각)이고, [byUserRefresh]는 그 값을
/// 남긴 동기화의 계기가 사용자 새로 고침(`sync_runs.trigger`의 `manual`)이었는지다. 새로 고침이 실패한 뒤 자동
/// 동기화가 성공했으면 false다. 상태별 뒷말(' · 다시 로그인' 등)은 화면이 붙인다.
String lmsInfoText({
  required DateTime? lastSuccessAt,
  required DateTime now,
  bool byUserRefresh = false,
}) {
  if (lastSuccessAt == null) return 'LMS 정보 받기 전';
  final since = now.difference(lastSuccessAt);
  if (byUserRefresh && since < _justNow) return 'LMS 정보 방금';
  return 'LMS 정보 ${elapsedText(since)}';
}

/// 03 할 일 요약 줄 '남은 일 {…}'의 길이(임시). 1시간이 안 되면 '1시간 미만', 그 밖에는 시간 단위로
/// 반올림해(30분부터 올림) '약 N시간'이다. 89 → '약 1시간', 90 → '약 2시간'.
String approxHoursText(int minutes) {
  RangeError.checkNotNegative(minutes, 'minutes');
  if (minutes < 60) return '1시간 미만';
  return '약 ${(minutes + 30) ~/ 60}시간';
}

/// 공개 전 할 일의 '{날짜} HH:MM에 열려요'(임시). 공개는 한 순간이라 공개 날짜는 논리적 하루가 아니라 달력으로
/// 본다(00:00 공개는 그날). 오늘은 다른 표기처럼 [dayBoundaryMin]을 반영한 논리적 하루로 세어 같은 줄의 마감
/// 날짜 말과 어긋나지 않게 한다. 7일 뒤부터는 날짜 말 대신 [monthDayText]를 쓴다('11월 28일 (토) 09:00에
/// 열려요'). [openAt]이 [now]보다 뒤인 공개 전 항목에만 쓴다. 하루 경계 전 새벽 공개의 표기는 자정 표기와 함께
/// 정하지 않았다.
String opensText(
  DateTime openAt, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final openDay = logicalDate(openAt, dayBoundaryMin: 0);
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final days = DateTime.utc(
    openDay.year,
    openDay.month,
    openDay.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  final day = days >= 7
      ? monthDayText(openDay, today: today)
      : _dayWordOf(days, openDay);
  return '$day ${hhmmText(openAt.hour * 60 + openAt.minute)}에 열려요';
}

/// 02 홈 머리의 둘째 줄 'HH:MM · 남은 일정 N개 · 할 일 N개'(임시). [now]의 실제 시각을 적는다.
String homeSummaryText({
  required DateTime now,
  required int events,
  required int tasks,
}) => '${hhmmText(now.hour * 60 + now.minute)} · 남은 일정 $events개 · 할 일 $tasks개';

/// 11 주간·09 일간 위 막대의 주 범위(임시). [monday]부터 그 주 일요일까지이고, 달이 같으면 '11월 9일 –
/// 15일', 달이 바뀌면 '10월 26일 – 11월 1일'이다. 해가 [today]와 다른 시작일, 해가 바뀌는 끝 날은 연도를
/// 붙인다('12월 28일 – 2027년 1월 3일').
String weekRangeText(DateTime monday, {required DateTime today}) {
  if (monday.weekday != DateTime.monday) {
    throw ArgumentError.value(monday, 'monday', 'not a Monday');
  }
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  final start = '${_yearPrefix(monday, today)}${monday.month}월 ${monday.day}일';
  final end = sunday.year != monday.year
      ? '${sunday.year}년 ${sunday.month}월 ${sunday.day}일'
      : sunday.month != monday.month
      ? '${sunday.month}월 ${sunday.day}일'
      : '${sunday.day}일';
  return '$start – $end';
}

/// 13 시간표·고정 일정의 '{날짜} 불러옴'(임시). [day]는 불러온 날이고, 해가 [today]와 다르면 연도를 붙인다.
String importedOnText(DateTime day, {required DateTime today}) =>
    '${_yearPrefix(day, today)}${day.month}월 ${day.day}일 불러옴';

/// 근거 시트의 'HH:MM–HH:MM'(임시). 자정을 넘는 끝(1440부터)은 [hhmmText]처럼 아직 받지 않는다.
String timeRangeText(int startMin, int endMin) =>
    '${hhmmText(startMin)}–${hhmmText(endMin)}';

/// 붉게 쓸 마감인지. 오늘·내일 마감만 붉게 쓴다(docs/screens.md '날짜·시각 표기').
/// [days]는 그 마감의 [dayOffset] 값이다.
bool isDueSoon(int days) => days == 0 || days == 1;

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 'LMS 정보 방금'을 보이는 시간(사용자가 새로 고친 뒤).
const Duration _justNow = Duration(minutes: 10);

/// 해가 [today]와 다르면 '2027년 '을, 같으면 빈 글자를 돌려준다.
String _yearPrefix(DateTime date, DateTime today) =>
    date.year == today.year ? '' : '${date.year}년 ';

const int _minutesPerDay = 1440;

String _twoDigits(int value) => value.toString().padLeft(2, '0');
