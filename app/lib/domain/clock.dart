// 앱의 '지금'과 논리적 하루. docs/architecture.md '앱 코드 규약'의 시각 규칙.
//
// - `DateTime.now()`는 이 파일 밖에서 부르지 않는다. 다른 코드는 [Clock]을 받아 쓴다.
// - 앱의 모든 `DateTime`은 기기 로컬 시각(한국 시간)이고 UTC로 바꾸지 않는다.
// - '오늘'과 '이번 주'(월요일 시작)는 하루 경계(`settings`의 `dayBoundaryMin`)를
//   반영한 아래 함수로만 구한다. 하루 경계 전의 새벽은 전날의 연장이다.

/// 지금 시각을 주는 시계. 테스트에서는 [FixedClock]으로 바꾼다.
class Clock {
  const Clock();

  /// 기기 로컬 시각.
  DateTime now() => DateTime.now();

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

/// [at]이 속한 논리적 하루의 날짜를 돌려준다. 시각을 0으로 둔 로컬 `DateTime`이다.
///
/// 하루는 자정이 아니라 하루 경계 [dayBoundaryMin](자정 기준 분, 0–1439)에서 바뀐다.
/// 예: 하루 경계가 240(04:00)이면 10월 29일 03:59는 10월 28일, 04:00은 10월 29일이다.
/// 하루 경계 전에 시작하는 새벽 블록도 이 함수로 전날에 넣는다.
DateTime logicalDate(DateTime at, {required int dayBoundaryMin}) {
  RangeError.checkValueInInterval(dayBoundaryMin, 0, 1439, 'dayBoundaryMin');
  final local = at.toLocal();
  final minuteOfDay = local.hour * 60 + local.minute;
  final daysBack = minuteOfDay < dayBoundaryMin ? 1 : 0;
  return DateTime(local.year, local.month, local.day - daysBack);
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

/// 날짜를 `YYYY-MM-DD`로 적는다. 폰 DB의 날짜 열, 라우트의 `:date`, 서버 API의
/// 날짜가 모두 이 형식이다. 시각은 보지 않는다.
String isoDate(DateTime d) {
  final year = d.year.toString().padLeft(4, '0');
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
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

final _isoDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
