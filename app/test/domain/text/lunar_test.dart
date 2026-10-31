import 'package:cnu_ai_assistant/domain/text/lunar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lunarShort', () {
    test('월 그리드 칸의 짧은 꼴', () {
      expect(lunarShort(DateTime(2026, 11, 1)), '9.22');
      expect(lunarShort(DateTime(2026, 10, 11)), '9.1');
      expect(lunarShort(DateTime(2025, 7, 27)), '윤6.3');
    });

    test('표 밖이면 null', () {
      expect(lunarShort(DateTime(1999, 12, 7)), isNull);
      expect(lunarShort(DateTime(2051, 1, 13)), isNull);
      expect(lunarShort(DateTime(2051, 1, 12)), '11.30');
    });
  });

  group('lunarText', () {
    test('삼성 폰 달력과 같은 날', () {
      expect(lunarText(DateTime(2026, 11, 4)), '음력 9월 25일');
      expect(lunarText(DateTime(2026, 10, 29)), '음력 9월 19일');
    });

    test('윤달은 달 앞에 윤을 붙인다', () {
      expect(lunarText(DateTime(2025, 7, 25)), '음력 윤6월 1일');
      expect(lunarText(DateTime(2025, 7, 27)), '음력 윤6월 3일');
      expect(lunarText(DateTime(2033, 12, 22)), '음력 윤11월 1일');
      expect(koreanLunar(DateTime(2025, 8, 1)), (month: 6, day: 8, leap: true));
    });

    test('달 경계', () {
      expect(lunarText(DateTime(2025, 7, 24)), '음력 6월 30일');
      expect(lunarText(DateTime(2025, 8, 22)), '음력 윤6월 29일');
      expect(lunarText(DateTime(2025, 8, 23)), '음력 7월 1일');
      // 설날과 그 전날(해가 바뀐다).
      expect(lunarText(DateTime(2025, 1, 28)), '음력 12월 29일');
      expect(lunarText(DateTime(2025, 1, 29)), '음력 1월 1일');
      expect(lunarText(DateTime(2026, 2, 16)), '음력 12월 29일');
      expect(lunarText(DateTime(2026, 2, 17)), '음력 1월 1일');
    });

    test('시각은 보지 않는다', () {
      expect(lunarText(DateTime(2026, 11, 4, 23, 59)), '음력 9월 25일');
      expect(lunarText(DateTime.utc(2026, 11, 4, 0, 1)), '음력 9월 25일');
    });

    test('표의 양 끝', () {
      expect(lunarText(DateTime(1999, 12, 8)), '음력 11월 1일');
      expect(lunarText(DateTime(2000, 1, 1)), '음력 11월 25일');
      expect(lunarText(DateTime(2050, 12, 31)), '음력 11월 18일');
      expect(lunarText(DateTime(2051, 1, 12)), '음력 11월 30일');
    });

    test('표 밖이면 null', () {
      expect(lunarText(DateTime(1999, 12, 7)), isNull);
      expect(koreanLunar(DateTime(1999, 12, 7)), isNull);
      expect(lunarText(DateTime(2051, 1, 13)), isNull);
      expect(koreanLunar(DateTime(2051, 1, 13)), isNull);
      expect(lunarText(DateTime(1900, 1, 1)), isNull);
      expect(lunarText(DateTime(2100, 1, 1)), isNull);
    });

    // 기대값은 테스트를 쓸 때 Node Intl(ko-KR-u-ca-dangi)로 뽑아 적었다.
    test('Node Intl dangi 달력과 표본 50개가 같다', () {
      const samples = [
        (2000, 11, 2, '음력 10월 7일'),
        (2000, 6, 28, '음력 5월 27일'),
        (2002, 10, 12, '음력 9월 7일'),
        (2003, 10, 27, '음력 10월 3일'),
        (2004, 2, 10, '음력 1월 20일'),
        (2005, 1, 16, '음력 12월 7일'),
        (2007, 3, 28, '음력 2월 10일'),
        (2010, 5, 31, '음력 4월 18일'),
        (2013, 3, 23, '음력 2월 12일'),
        (2013, 4, 28, '음력 3월 19일'),
        (2013, 8, 3, '음력 6월 27일'),
        (2014, 1, 4, '음력 12월 4일'),
        (2014, 3, 15, '음력 2월 15일'),
        (2014, 7, 28, '음력 7월 2일'),
        (2015, 3, 18, '음력 1월 28일'),
        (2015, 3, 20, '음력 2월 1일'),
        (2016, 1, 13, '음력 12월 4일'),
        (2016, 5, 6, '음력 3월 30일'),
        (2019, 6, 13, '음력 5월 11일'),
        (2019, 7, 6, '음력 6월 4일'),
        (2019, 9, 3, '음력 8월 5일'),
        (2020, 5, 12, '음력 4월 20일'),
        (2020, 9, 13, '음력 7월 26일'),
        (2021, 1, 25, '음력 12월 13일'),
        (2021, 5, 17, '음력 4월 6일'),
        (2021, 5, 29, '음력 4월 18일'),
        (2023, 10, 18, '음력 9월 4일'),
        (2024, 7, 23, '음력 6월 18일'),
        (2025, 2, 9, '음력 1월 12일'),
        (2026, 6, 26, '음력 5월 12일'),
        (2028, 4, 20, '음력 3월 26일'),
        (2030, 4, 13, '음력 3월 11일'),
        (2030, 4, 16, '음력 3월 14일'),
        (2031, 10, 7, '음력 8월 21일'),
        (2032, 8, 11, '음력 7월 6일'),
        (2033, 10, 7, '음력 9월 15일'),
        (2033, 10, 9, '음력 9월 17일'),
        (2033, 3, 23, '음력 2월 23일'),
        (2035, 9, 27, '음력 8월 26일'),
        (2037, 10, 4, '음력 8월 25일'),
        (2037, 8, 13, '음력 7월 3일'),
        (2038, 5, 17, '음력 4월 14일'),
        (2039, 12, 21, '음력 11월 6일'),
        (2040, 8, 15, '음력 7월 8일'),
        (2042, 12, 13, '음력 11월 2일'),
        (2044, 1, 14, '음력 12월 15일'),
        (2044, 4, 15, '음력 3월 18일'),
        (2047, 5, 6, '음력 4월 12일'),
        (2047, 7, 17, '음력 윤5월 25일'),
        (2048, 8, 8, '음력 6월 29일'),
      ];
      for (final (y, m, d, expected) in samples) {
        expect(lunarText(DateTime(y, m, d)), expected, reason: '$y-$m-$d');
      }
    });
  });
}
