// 대한민국 공휴일. docs/decisions.md 2026-11-19 '학사일정은 넣지 않고 공휴일은 앱 안 표로 둔다'.
//
// 「관공서의 공휴일에 관한 규정」의 공휴일(설날·추석 연휴, 대체공휴일, 선거일 포함)을 2026–2027년만 앱 안 Dart
// 표로 둔다. 2026년부터 노동절(5월 1일)과 제헌절(7월 17일)이 공휴일이다. Dart 상수라 Shorebird 패치로 고치고,
// 임시공휴일이 생기거나 다음 해를 더할 때도 이 표만 고친다. 학사일정은 넣지 않는다.
//
// 공휴일에도 수업은 그대로다(쉬면 사용자가 휴강을 넣음). 그래서 배치 엔진과 빈 시간 계산은 이 표를 보지 않고,
// 08 월간·11 주간·09 일간이 날짜에 이름을 붙이는 데만 쓴다.

/// 공휴일 하루.
final class Holiday {
  const Holiday(this.date, this.name);

  /// 그날 0시(달력 날짜).
  final DateTime date;

  /// 짧은 이름(설날·추석은 연휴 사흘 모두 같은 이름, 대체공휴일은 '대체공휴일').
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Holiday && other.date == date && other.name == name;

  @override
  int get hashCode => Object.hash(date, name);

  @override
  String toString() => 'Holiday($date, $name)';
}

/// 표가 담은 첫 해와 마지막 해. 이 밖의 해에는 공휴일을 보이지 않는다.
const int holidayTableFirstYear = 2026;
const int holidayTableLastYear = 2027;

/// 대체공휴일의 이름.
const String substituteHolidayName = '대체공휴일';

/// 공휴일 표. 키는 `YYYY-MM-DD`(달력 날짜)다.
const Map<String, String> _holidays = {
  // 2026년
  '2026-01-01': '신정',
  '2026-02-16': '설날',
  '2026-02-17': '설날',
  '2026-02-18': '설날',
  '2026-03-01': '삼일절',
  '2026-03-02': substituteHolidayName,
  '2026-05-01': '노동절',
  '2026-05-05': '어린이날',
  '2026-05-24': '부처님오신날',
  '2026-05-25': substituteHolidayName,
  '2026-06-03': '지방선거일',
  '2026-06-06': '현충일',
  '2026-07-17': '제헌절',
  '2026-08-15': '광복절',
  '2026-08-17': substituteHolidayName,
  '2026-09-24': '추석',
  '2026-09-25': '추석',
  '2026-09-26': '추석',
  '2026-10-03': '개천절',
  '2026-10-05': substituteHolidayName,
  '2026-10-09': '한글날',
  '2026-12-25': '성탄절',
  // 2027년
  '2027-01-01': '신정',
  '2027-02-06': '설날',
  '2027-02-07': '설날',
  '2027-02-08': '설날',
  '2027-02-09': substituteHolidayName,
  '2027-03-01': '삼일절',
  '2027-05-01': '노동절',
  '2027-05-03': substituteHolidayName,
  '2027-05-05': '어린이날',
  '2027-05-13': '부처님오신날',
  '2027-06-06': '현충일',
  '2027-07-17': '제헌절',
  '2027-07-19': substituteHolidayName,
  '2027-08-15': '광복절',
  '2027-08-16': substituteHolidayName,
  '2027-09-14': '추석',
  '2027-09-15': '추석',
  '2027-09-16': '추석',
  '2027-10-03': '개천절',
  '2027-10-04': substituteHolidayName,
  '2027-10-09': '한글날',
  '2027-10-11': substituteHolidayName,
  '2027-12-25': '성탄절',
  '2027-12-27': substituteHolidayName,
};

String _key(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// [date]가 든 달력 날짜의 공휴일 이름. 공휴일이 아니거나 표 밖의 해면 null이다. 시각은 보지 않는다.
String? holidayName(DateTime date) => _holidays[_key(date)];

/// [from]부터 [to]까지(두 날짜 포함, 달력 날짜로 셈)의 공휴일을 날짜 순서로.
List<Holiday> holidaysBetween(DateTime from, DateTime to) {
  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  return [
    for (
      var day = first;
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      if (_holidays[_key(day)] case final name?) Holiday(day, name),
  ];
}
