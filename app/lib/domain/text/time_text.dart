// 시각·길이·요일·날짜 말 표기. docs/screens.md '날짜·시각 표기', docs/architecture.md
// '앱 코드 규약'의 시각 규칙.
//
// 문장 속 시각은 "오전 10시 30분"처럼 12시간제([clockText]), 화면의 시각은 "09:30"처럼 24시간제
// ([hhmmText]), 칩은 "오전 8:00"처럼([shortClockText]), 길이는 "2시간"·"50분"처럼 아라비아 숫자로 쓴다.
// 하루 안의 시각은 폰 DB처럼 자정 기준 분(09:30 → 570)으로 받는다. 자정과 하루 경계 전 새벽 시각은
// docs/decisions.md 2026-11-14 '자정 마감은 전날 24:00, 새벽 마감은 달력 날짜로 쓴다'대로 쓴다. 정확히 00:00에
// 끝나는 것(마감, 시간 범위의 끝)은 전날의 '24:00'(문장 속에서는 '밤 12시')이고, 00:01부터 하루 경계 전까지의
// 마감은 그 달력 날짜의 날짜 말에 실제 시각을 붙인다. 칩([shortClockText])은 브리핑 시각(06:00–12:00)만 쓰므로
// 자정 무렵을 받지 않는다.
// 날짜(해가 다를 때만 연도), 지난 시간, 남은 일, 공개 줄, 02 머리, 주 범위, '불러옴', 시간 범위의 꼴은
// 임시다(docs/decisions.md 2026-11-13 '날짜·시각 표기의 꼴(임시)').

import 'package:cnu_ai_assistant/domain/clock.dart';

/// 문장 속 시각. 자정 기준 분을 12시간제로 적는다. 570 → '오전 9시 30분', 780 → '오후 1시',
/// 720 → '오후 12시'. 정확히 자정(0, 1440)은 '밤 12시'다('오전 12시'는 하루의 시작과 끝을 가르지 못함).
/// 자정을 넘어 1440을 더한 값(2879까지)은 그 시각으로 적는다(1560 → '오전 2시'). 화면의 'HH:MM'은
/// [hhmmText], 칩은 [shortClockText]다.
String clockText(int minuteOfDay) {
  RangeError.checkValueInInterval(
    minuteOfDay,
    0,
    2 * _minutesPerDay - 1,
    'minuteOfDay',
  );
  if (minuteOfDay % _minutesPerDay == 0) return '밤 12시';
  final hour = minuteOfDay ~/ 60 % 24;
  final minute = minuteOfDay % 60;
  final period = hour < 12 ? '오전' : '오후';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return minute == 0 ? '$period $hour12시' : '$period $hour12시 $minute분';
}

/// 화면의 시각 'HH:MM'(24시간제). 570 → '09:30', 1439 → '23:59'. 09 일간의 'HH:MM에 놓기', 마감 문구,
/// 하루 경계 같은 자리에 쓴다. 1440은 정확히 자정에 끝나는 것(마감·시간 범위의 끝)의 '24:00'이다. 자정을
/// 넘는 끝은 실제 시각(1500이면 [timeRangeText]가 '01:00')으로 쓰므로 1440보다 큰 값은 받지 않는다.
/// 서버·JSON의 시각 변환에는 쓰지 않는다(그쪽은 `schema/`의 시각 꼴을 따르고 24:00을 받지 않는다).
String hhmmText(int minuteOfDay) {
  RangeError.checkValueInInterval(
    minuteOfDay,
    0,
    _minutesPerDay,
    'minuteOfDay',
  );
  return '${_twoDigits(minuteOfDay ~/ 60)}:${_twoDigits(minuteOfDay % 60)}';
}

/// 칩의 시각 '오전 8:00'·'오후 12:30'(12시간제). 14 온보딩 5단계·10 나·12 내 규칙의 브리핑 시각 칩이
/// 쓴다. 브리핑 시각(06:00–12:00)만 쓰므로 자정 무렵(00:00–00:59)과 1440 이상은 받지 않는다.
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
/// '{날짜 말} 마감 · 시각 미상'(임시), 그 밖에는 '{날짜 말} HH:MM 마감'이다. [farAsDate]가 true면(03 할 일)
/// 7일 이상 남았거나 이틀 이상 지난 마감은 날짜 말 대신 [monthDayText]를 쓴다. [now]에는 [Clock.now]의 값을
/// 넘긴다.
///
/// 마감 날짜는 [dueDayOffset]의 규칙이다. 정확히 00:00인 마감은 전날의 '24:00 마감'이고(목요일 24:00 마감),
/// 00:01부터 하루 경계 전까지의 마감은 그 달력 날짜의 날짜 말에 실제 시각을 붙인다(하루 경계 04:00에서 금요일
/// 01:30 마감은 목요일 밤에 보면 '내일 01:30 마감').
String dueText(
  DateTime? dueAt, {
  required bool dueTimeUnknown,
  required DateTime now,
  required int dayBoundaryMin,
  bool farAsDate = false,
}) {
  if (dueAt == null) return '마감 없음';
  final date = dueDateOf(dueAt);
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final days = _daysBetween(today, date);
  final day = farAsDate && (days <= -2 || days >= 7)
      ? monthDayText(date, today: today)
      : _dayWordOf(days, date);
  if (dueTimeUnknown) return '$day 마감 · 시각 미상';
  final minute = dueAt.hour * 60 + dueAt.minute;
  return '$day ${hhmmText(minute == 0 ? _minutesPerDay : minute)} 마감';
}

/// 오늘(논리적 날짜)에서 마감 날짜까지의 날 수. 마감 문구([dueText])의 날짜와 같은 규칙이라 붉게 쓸지
/// ([isDueSoon])도 이것으로 본다. 정확히 00:00인 마감은 전날(24:00 마감)이고, 그 밖에는 마감의 달력 날짜다
/// (하루 경계 전 새벽 마감도 그 달력 날짜. docs/decisions.md 2026-11-14 '자정 마감은 전날 24:00, 새벽 마감은
/// 달력 날짜로 쓴다'). [now]에는 [Clock.now]의 값을 넘긴다.
int dueDayOffset(
  DateTime dueAt, {
  required DateTime now,
  required int dayBoundaryMin,
}) => _daysBetween(
  logicalDate(now, dayBoundaryMin: dayBoundaryMin),
  dueDateOf(dueAt),
);

/// 마감 날짜(그날 0시): 정확히 00:00이면 전날, 그 밖에는 달력 날짜. 마감 문구([dueText])와 09 일간의 마감 줄이
/// 같은 날짜를 쓴다.
DateTime dueDateOf(DateTime dueAt) => DateTime(
  dueAt.year,
  dueAt.month,
  dueAt.hour == 0 && dueAt.minute == 0 ? dueAt.day - 1 : dueAt.day,
);

/// [from]에서 [to]까지의 날 수(날짜만 본다).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// 길이를 적는다. 50 → '50분', 120 → '2시간', 90 → '1시간 30분', 0 → '0분'.
String durationText(int minutes) {
  RangeError.checkNotNegative(minutes, 'minutes');
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest분';
  return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
}

/// 남은 시간 '1일 15시간'·'3시간 20분'·'40분'(근거 시트의 '마감까지 … 남았어요', 임시). 하루가 넘으면 날과
/// 시간, 한 시간이 넘으면 시간과 분, 그 밖에는 분이고 0인 단위는 쓰지 않는다. 음수는 0분으로 본다.
String remainingText(int minutes) {
  final total = minutes < 0 ? 0 : minutes;
  final days = total ~/ 1440;
  final hours = total % 1440 ~/ 60;
  final rest = total % 60;
  if (days > 0) return hours == 0 ? '$days일' : '$days일 $hours시간';
  if (hours > 0) return rest == 0 ? '$hours시간' : '$hours시간 $rest분';
  return '$rest분';
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
  return 'LMS 정보 ${lastCheckedText(lastSuccessAt: lastSuccessAt, now: now, byUserRefresh: byUserRefresh)}';
}

/// 03 할 일 LMS 정보 시트의 '마지막 확인' 값(임시). [lmsInfoText]와 같은 규칙으로 '방금'·'N분 전'·'N시간 전'이고,
/// 확인에 성공한 적이 없으면 '없음'이다.
String lastCheckedText({
  required DateTime? lastSuccessAt,
  required DateTime now,
  bool byUserRefresh = false,
}) {
  if (lastSuccessAt == null) return '없음';
  final since = now.difference(lastSuccessAt);
  if (byUserRefresh && since < _justNow) return '방금';
  return elapsedText(since);
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
/// 열려요'). [openAt]이 [now]보다 뒤인 공개 전 항목에만 쓴다. 공개는 끝이 아니라 시작이라 00:00 공개도 그날
/// '00:00'이고, 하루 경계 전 새벽 공개는 마감처럼 그 달력 날짜에 실제 시각을 쓴다.
String opensText(
  DateTime openAt, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final openDay = logicalDate(openAt, dayBoundaryMin: 0);
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final days = _daysBetween(today, openDay);
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

/// 시간 범위 'HH:MM–HH:MM'(근거 시트, 12 내 규칙의 짧은 값. 임시). 시각은 폰 DB처럼 자정 기준 분이고, 자정을
/// 넘는 끝은 1440을 더해 받는다. 끝이 정확히 자정이면 '24:00', 그 뒤면 실제 시각이다(1320–1560 →
/// '22:00–02:00'). [startMin]은 0–1439, [endMin]은 [startMin]보다 크고 하루(1440분) 안이어야 한다.
String timeRangeText(int startMin, int endMin) {
  RangeError.checkValueInInterval(startMin, 0, _minutesPerDay - 1, 'startMin');
  RangeError.checkValueInInterval(
    endMin,
    startMin + 1,
    startMin + _minutesPerDay - 1,
    'endMin',
  );
  final end = endMin == _minutesPerDay ? endMin : endMin % _minutesPerDay;
  return '${hhmmText(startMin)}–${hhmmText(end)}';
}

/// 붉게 쓸 마감인지. 오늘·내일 마감만 붉게 쓴다(docs/screens.md '날짜·시각 표기').
/// [days]는 그 마감의 [dueDayOffset] 값이다(마감 문구의 날짜 말과 같은 날).
bool isDueSoon(int days) => days == 0 || days == 1;

const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 'LMS 정보 방금'을 보이는 시간(사용자가 새로 고친 뒤).
const Duration _justNow = Duration(minutes: 10);

/// 해가 [today]와 다르면 '2027년 '을, 같으면 빈 글자를 돌려준다.
String _yearPrefix(DateTime date, DateTime today) =>
    date.year == today.year ? '' : '${date.year}년 ';

const int _minutesPerDay = 1440;

String _twoDigits(int value) => value.toString().padLeft(2, '0');
