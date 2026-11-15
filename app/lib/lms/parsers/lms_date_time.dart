// LMS 응답의 날짜·시각 읽기. docs/lms.md '응답 해석'.
//
// LMS의 날짜·시각은 한국 시간이다. 시간대가 없는 글자는 한국 시각 벽시계 값으로 읽고, 시간대가 붙은 값은 그 순간을
// 한국 시각으로 바꾼다(`seoulWallClock`). 앱은 분 단위로 다루므로 초는 버린다(`23:59:59`는 23:59). `24:00`은 다음 날
// 00:00이고, 날짜만 있으면 그날 23:59에 시각을 모른다는 표시를 붙인다. 기기 시간대는 쓰지 않는다.

import 'package:cnu_ai_assistant/domain/clock.dart';

/// [parseLmsDateTime]의 결과.
typedef LmsDateTime = ({DateTime at, bool timeUnknown});

final _dateTime = RegExp(
  r'^(\d{4})-?(\d{2})-?(\d{2})(?:[ T]?(\d{2}):?(\d{2})(?::?(\d{2})(?:\.\d+)?)?)?$',
);

final _zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// LMS의 날짜·시각 글자 [text]를 읽는다. 꼴: `2026-11-20 23:59:00`, `2026-11-20 23:59`, `2026-11-20T23:59:00`,
/// `20261120235900`, `202611202359`, 날짜만 `2026-11-20`·`20261120`, 시간대(`Z`, `+09:00`)가 붙은 시각. 비었거나 읽을 수
/// 없거나 없는 날짜(2월 30일 등)·시각이면 null이다(Dart의 `DateTime.parse`는 범위 밖 값을 넘겨 받으므로 먼저 확인한다).
/// 던지지 않는다.
LmsDateTime? parseLmsDateTime(String? text) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final zone = _zoned.firstMatch(trimmed);
  final match = _dateTime.firstMatch(
    zone == null ? trimmed : trimmed.substring(0, zone.start),
  );
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  if (match[4] == null) {
    if (zone != null) return null;
    return (at: DateTime(year, month, day, 23, 59), timeUnknown: true);
  }
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6] ?? '0');
  final midnight = hour == 24 && minute == 0 && second == 0;
  if (!midnight && (hour > 23 || minute > 59 || second > 59)) return null;
  if (zone != null) {
    final instant = DateTime.tryParse(trimmed);
    if (instant == null) return null;
    final kst = seoulWallClock(instant);
    return (
      at: DateTime(kst.year, kst.month, kst.day, kst.hour, kst.minute),
      timeUnknown: false,
    );
  }
  if (midnight) return (at: DateTime(year, month, day + 1), timeUnknown: false);
  return (at: DateTime(year, month, day, hour, minute), timeUnknown: false);
}
