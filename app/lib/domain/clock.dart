// 앱의 '지금'과 논리적 하루. docs/architecture.md '앱 코드 규약'의 시각 규칙.
//
// - `DateTime.now()`는 이 파일 밖에서 부르지 않는다. 다른 코드는 [Clock]을 받아 쓴다.
// - 앱의 모든 `DateTime`은 기기 시간대와 관계없이 한국 시각(UTC+9, 서머타임 없음)의 벽시계 값을 담은 로컬
//   `DateTime`(`isUtc` false)이다(docs/decisions.md 2026-11-14 '기기 시간대와 관계없이 한국 시각을 쓴다').
//   [Clock.now]가 그 꼴로 지금을 주고, 실제 순간(UTC 값 등)은 [seoulWallClock]으로 바꾼다. 폰 DB에는
//   `data/db/kst_date_time_converter.dart`가 그 순간의 UTC 값으로 저장한다([kstToUtc]).
// - '오늘'과 '이번 주'(월요일 시작)는 하루 경계(`settings`의 `dayBoundaryMin`)를 반영한 아래 함수로만 구한다.
//   하루 경계 전의 새벽은 전날의 연장이다.

/// 지금 시각을 주는 시계. 테스트에서는 [FixedClock]으로 바꾼다.
class Clock {
  const Clock();

  /// 지금의 한국 시각([seoulWallClock]). 기기 시간대가 한국이 아니어도 한국 시각이다.
  DateTime now() => seoulWallClock(DateTime.now());

  /// 지금이 속한 논리적 하루(날짜만 남긴 값).
  DateTime today({required int dayBoundaryMin}) =>
      logicalDate(now(), dayBoundaryMin: dayBoundaryMin);
}

/// 늘 같은 시각을 주는 시계(테스트용).
class FixedClock extends Clock {
  const FixedClock(this.fixedNow);

  final DateTime fixedNow;

  @override
  DateTime now() => fixedNow;
}

/// 실제 순간 [instant]의 한국 시각. 앱이 쓰는 꼴(벽시계 값을 담은 로컬 `DateTime`)로 돌려준다.
///
/// [instant]는 실제 순간을 가리키는 값이다(`DateTime.now()`의 값, UTC 값, 오프셋을 붙여 읽은 값). 앱의 다른
/// 로컬 값은 이미 한국 시각이므로 이 함수에 넘기지 않는다. 기기 시간대에 서머타임이 있으면 그 시간대에 없는 벽시계
/// 시각(봄에 건너뛰는 한 시간)은 한 시간 밀려 만들어질 수 있다(해외에서만 생기는 가장자리. 받아들인 점).
DateTime seoulWallClock(DateTime instant) {
  final kst = instant.toUtc().add(_kstOffset);
  return DateTime(
    kst.year,
    kst.month,
    kst.day,
    kst.hour,
    kst.minute,
    kst.second,
    kst.millisecond,
    kst.microsecond,
  );
}

/// 앱의 시각 [wallClock](한국 시각 벽시계 값)이 가리키는 순간을 UTC 값으로 돌려준다. 폰 DB에 저장할 때와 SQL에서
/// 시각 열과 견줄 값에 쓴다. UTC 값을 넘기면 이미 순간이므로 그대로 돌려준다.
DateTime kstToUtc(DateTime wallClock) {
  if (wallClock.isUtc) return wallClock;
  return DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
    wallClock.microsecond,
  ).subtract(_kstOffset);
}

/// [at]이 속한 논리적 하루의 날짜를 돌려준다. 시각을 0으로 둔 로컬 `DateTime`이다.
///
/// 하루는 자정이 아니라 하루 경계 [dayBoundaryMin](자정 기준 분, 0–1439)에서 바뀐다.
/// 예: 하루 경계가 240(04:00)이면 10월 29일 03:59는 10월 28일, 04:00은 10월 29일이다.
/// 하루 경계 전에 시작하는 새벽 블록도 이 함수로 전날에 넣는다. UTC 값은 한국 시각으로 바꿔 본다.
DateTime logicalDate(DateTime at, {required int dayBoundaryMin}) {
  RangeError.checkValueInInterval(dayBoundaryMin, 0, 1439, 'dayBoundaryMin');
  final wall = _wallClock(at);
  final minuteOfDay = wall.hour * 60 + wall.minute;
  final daysBack = minuteOfDay < dayBoundaryMin ? 1 : 0;
  return DateTime(wall.year, wall.month, wall.day - daysBack);
}

/// 논리적 하루 [date]가 시작하는 시각(그 날짜의 하루 경계). [date]는 시각을 보지 않는다.
DateTime logicalDayStart(DateTime date, {required int dayBoundaryMin}) {
  RangeError.checkValueInInterval(dayBoundaryMin, 0, 1439, 'dayBoundaryMin');
  return DateTime(date.year, date.month, date.day, 0, dayBoundaryMin);
}

/// 논리적 하루 [date]가 끝나는 시각(다음 날의 하루 경계). 이 시각부터는 다음 논리적 하루다. [date]는 시각을
/// 보지 않는다.
DateTime logicalDayEnd(DateTime date, {required int dayBoundaryMin}) {
  RangeError.checkValueInInterval(dayBoundaryMin, 0, 1439, 'dayBoundaryMin');
  return DateTime(date.year, date.month, date.day + 1, 0, dayBoundaryMin);
}

/// [at]이 속한 논리적 주의 월요일(날짜만 남긴 값). 주는 월요일에 시작한다.
DateTime logicalWeekStart(DateTime at, {required int dayBoundaryMin}) {
  final day = logicalDate(at, dayBoundaryMin: dayBoundaryMin);
  return DateTime(
    day.year,
    day.month,
    day.day - (day.weekday - DateTime.monday),
  );
}

/// [at]이 속한 논리적 하루가 [now]가 속한 논리적 하루에서 며칠 뒤인지 센다.
/// 0은 오늘, 1은 내일, -1은 어제다.
///
/// 두 값을 모두 [logicalDate]로 바꾼 뒤 달력 일수로 세므로 시각은 보지 않는다. [now]에는
/// [Clock.now]의 값을 그대로 넘긴다. 예: 하루 경계가 240(04:00)이고 [now]가 10월 13일
/// 02:00(논리적 하루 10월 12일)이면 10월 13일 23:59는 1, 10월 13일 03:59는 0이다.
int dayOffset(
  DateTime at, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final from = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final to = logicalDate(at, dayBoundaryMin: dayBoundaryMin);
  // 일수 계산에만 UTC 자정을 쓴다. 일광 절약 시간이 있는 시간대에서도 하루가 24시간이다.
  return DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// 날짜를 `YYYY-MM-DD`로 적는다. 폰 DB의 날짜 열, 라우트의 `:date`, 서버 API의
/// 날짜가 모두 이 형식이다. 시각은 보지 않고, UTC 값은 한국 시각의 날짜로 적는다.
String isoDate(DateTime d) {
  final wall = _wallClock(d);
  final year = wall.year.toString().padLeft(4, '0');
  final month = wall.month.toString().padLeft(2, '0');
  final day = wall.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// `YYYY-MM-DD`를 그날 0시의 로컬 `DateTime`으로 읽는다.
/// 형식이 다르거나 없는 날짜(예: `2026-02-30`)면 null이다.
DateTime? tryParseIsoDate(String text) {
  final match = _isoDatePattern.firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// 앱의 시각 꼴(한국 시각 벽시계 값). UTC 값만 [seoulWallClock]으로 바꾼다.
DateTime _wallClock(DateTime at) => at.isUtc ? seoulWallClock(at) : at;

const Duration _kstOffset = Duration(hours: 9);

final _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
