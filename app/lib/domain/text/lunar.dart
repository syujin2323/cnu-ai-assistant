// 한국 음력 날짜. 월 화면 머리에 '음력 9월 25일'처럼 보인다.
//
// Dart에는 음력 달력이 없어서 ICU dangi 달력으로 만든 표(lunar_data.dart)를 쓴다.
// 표는 음력 각 달이 시작하는 양력 날짜를 담고, 날짜가 든 달을 이진 탐색으로 찾는다.
// 표 범위(양력 1999-12-08–2051-01-12) 밖이면 null이다.

import 'package:cnu_ai_assistant/domain/text/lunar_data.dart';

/// [date]의 양력 연·월·일을 음력으로 바꾼다. 시각과 시간대는 보지 않는다.
/// 2026-11-04 → (month: 9, day: 25, leap: false). 표 범위 밖이면 null.
({int month, int day, bool leap})? koreanLunar(DateTime date) {
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(lunarBase).inDays;
  if (days < 0 || days >= lunarMonthStarts.last >> 5) return null;
  // days 이하에서 시작하는 마지막 달을 찾는다. 첫 값의 날 수는 0이라 늘 하나는 있다.
  var lo = 0;
  var hi = lunarMonthStarts.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (lunarMonthStarts[mid] >> 5 <= days) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final value = lunarMonthStarts[lo];
  return (
    month: (value >> 1) & 15,
    day: days - (value >> 5) + 1,
    leap: value & 1 == 1,
  );
}

/// '음력 9월 25일', 윤달이면 '음력 윤6월 3일'. 표 범위 밖이면 null.
String? lunarText(DateTime date) {
  final lunar = koreanLunar(date);
  if (lunar == null) return null;
  final leap = lunar.leap ? '윤' : '';
  return '음력 $leap${lunar.month}월 ${lunar.day}일';
}
