// 대한민국 공휴일 표. docs/decisions.md 2026-11-19 '학사일정은 넣지 않고 공휴일은 앱 안 표로 둔다'.

import 'package:cnu_ai_assistant/domain/holidays.dart';
import 'package:flutter_test/flutter_test.dart';

/// 대체공휴일이 붙는 공휴일(토·일이나 다른 공휴일과 겹치면 다음 첫 비공휴일). 신정·현충일·선거일은 붙지 않는다.
const _substitutable = {
  '삼일절',
  '노동절',
  '어린이날',
  '부처님오신날',
  '제헌절',
  '광복절',
  '개천절',
  '한글날',
  '성탄절',
};

/// 연휴 사흘이 일요일과 겹치면 연휴 다음 첫 비공휴일이 대체공휴일인 설날·추석(토요일은 해당 없음).
const _lunarBreaks = {'설날', '추석'};

bool _weekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

String _ymd(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

List<Holiday> _year(int year) =>
    holidaysBetween(DateTime(year, 1, 1), DateTime(year, 12, 31));

void main() {
  test('2026년 공휴일(노동절·제헌절·지방선거일과 대체공휴일 넷)', () {
    expect(
      [for (final h in _year(2026)) '${_ymd(h.date)} ${h.name}'],
      [
        '2026-01-01 신정',
        '2026-02-16 설날',
        '2026-02-17 설날',
        '2026-02-18 설날',
        '2026-03-01 삼일절',
        '2026-03-02 대체공휴일',
        '2026-05-01 노동절',
        '2026-05-05 어린이날',
        '2026-05-24 부처님오신날',
        '2026-05-25 대체공휴일',
        '2026-06-03 지방선거일',
        '2026-06-06 현충일',
        '2026-07-17 제헌절',
        '2026-08-15 광복절',
        '2026-08-17 대체공휴일',
        '2026-09-24 추석',
        '2026-09-25 추석',
        '2026-09-26 추석',
        '2026-10-03 개천절',
        '2026-10-05 대체공휴일',
        '2026-10-09 한글날',
        '2026-12-25 성탄절',
      ],
    );
  });

  test('2027년 공휴일(대체공휴일 여덟)', () {
    expect(
      [for (final h in _year(2027)) '${_ymd(h.date)} ${h.name}'],
      [
        '2027-01-01 신정',
        '2027-02-06 설날',
        '2027-02-07 설날',
        '2027-02-08 설날',
        '2027-02-09 대체공휴일',
        '2027-03-01 삼일절',
        '2027-05-01 노동절',
        '2027-05-03 대체공휴일',
        '2027-05-05 어린이날',
        '2027-05-13 부처님오신날',
        '2027-06-06 현충일',
        '2027-07-17 제헌절',
        '2027-07-19 대체공휴일',
        '2027-08-15 광복절',
        '2027-08-16 대체공휴일',
        '2027-09-14 추석',
        '2027-09-15 추석',
        '2027-09-16 추석',
        '2027-10-03 개천절',
        '2027-10-04 대체공휴일',
        '2027-10-09 한글날',
        '2027-10-11 대체공휴일',
        '2027-12-25 성탄절',
        '2027-12-27 대체공휴일',
      ],
    );
  });

  test('대체공휴일은 규칙대로 붙어 있다(표의 날짜·요일이 맞는지 스스로 확인)', () {
    for (
      var year = holidayTableFirstYear;
      year <= holidayTableLastYear;
      year++
    ) {
      final days = _year(year);
      final names = {for (final h in days) h.date: h.name};
      bool holiday(DateTime day) => names.containsKey(day);
      final expected = <DateTime>{};
      DateTime nextFree(DateTime after) {
        var day = DateTime(after.year, after.month, after.day + 1);
        while (_weekend(day) ||
            (holiday(day) && names[day] != substituteHolidayName) ||
            expected.contains(day)) {
          day = DateTime(day.year, day.month, day.day + 1);
        }
        return day;
      }

      for (final h in days) {
        if (_substitutable.contains(h.name) && _weekend(h.date)) {
          expected.add(nextFree(h.date));
        }
      }
      for (final name in _lunarBreaks) {
        final streak = [
          for (final h in days)
            if (h.name == name) h.date,
        ];
        expect(streak, hasLength(3), reason: '$year $name');
        for (var i = 1; i < streak.length; i++) {
          expect(
            streak[i].difference(streak[i - 1]).inHours,
            24,
            reason: '$year $name 연휴는 이어진 사흘',
          );
        }
        if (streak.any((day) => day.weekday == DateTime.sunday)) {
          expected.add(nextFree(streak.last));
        }
      }
      expect(
        {
          for (final h in days)
            if (h.name == substituteHolidayName) h.date,
        },
        expected,
        reason: '$year',
      );
      // 대체공휴일은 평일이다.
      for (final h in days.where((h) => h.name == substituteHolidayName)) {
        expect(_weekend(h.date), isFalse, reason: _ymd(h.date));
      }
    }
  });

  test('날짜의 공휴일 이름은 시각과 관계없이 달력 날짜로 찾고, 표 밖의 해는 없다', () {
    expect(holidayName(DateTime(2026, 9, 25, 23, 59)), '추석');
    expect(holidayName(DateTime(2026, 7, 17)), '제헌절');
    expect(holidayName(DateTime(2026, 7, 16)), isNull);
    expect(holidayName(DateTime(2025, 12, 25)), isNull);
    expect(holidayName(DateTime(2028, 1, 1)), isNull);
  });

  test('기간의 공휴일은 두 날짜를 넣고 시각을 보지 않으며 해를 넘어도 잇는다', () {
    expect(
      holidaysBetween(DateTime(2026, 9, 24, 18), DateTime(2026, 9, 26, 1)),
      [
        Holiday(DateTime(2026, 9, 24), '추석'),
        Holiday(DateTime(2026, 9, 25), '추석'),
        Holiday(DateTime(2026, 9, 26), '추석'),
      ],
    );
    expect(
      [
        for (final h in holidaysBetween(
          DateTime(2026, 12, 20),
          DateTime(2027, 1, 3),
        ))
          _ymd(h.date),
      ],
      ['2026-12-25', '2027-01-01'],
    );
    expect(holidaysBetween(DateTime(2026, 4, 1), DateTime(2026, 4, 30)), []);
  });
}
