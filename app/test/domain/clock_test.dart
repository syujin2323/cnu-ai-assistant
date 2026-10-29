import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 기본 하루 경계(임시값 240 = 04:00). 기준 시각은 이 값에서 계산해 기본값이 바뀌어도 맞게 둔다.
  const boundary = Defaults.dayBoundaryMin;

  // 그날 0시에서 [minutes]분 지난 로컬 시각. 달력 계산이라 일광 절약 시간과 무관하다.
  DateTime minutesInto(int year, int month, int day, int minutes) =>
      DateTime(year, month, day, 0, minutes);

  group('logicalDate', () {
    test('하루 경계 1분 전은 전날이다', () {
      final at = minutesInto(2026, 10, 29, boundary - 1);
      expect(logicalDate(at, dayBoundaryMin: boundary), DateTime(2026, 10, 28));
    });

    test('하루 경계 정각부터는 그날이다', () {
      final at = minutesInto(2026, 10, 29, boundary);
      expect(logicalDate(at, dayBoundaryMin: boundary), DateTime(2026, 10, 29));
    });

    test('하루 경계 직전의 초·밀리초도 전날로 본다', () {
      final before = minutesInto(2026, 10, 29, boundary - 1);
      final at = before.copyWith(
        second: 59,
        millisecond: 999,
        microsecond: 999,
      );
      expect(logicalDate(at, dayBoundaryMin: boundary), DateTime(2026, 10, 28));
    });

    test('자정 직후 새벽은 전날의 연장이다', () {
      expect(
        logicalDate(DateTime(2026, 10, 29), dayBoundaryMin: boundary),
        DateTime(2026, 10, 28),
      );
    });

    test('밤 23:59는 그날이다', () {
      expect(
        logicalDate(DateTime(2026, 10, 29, 23, 59), dayBoundaryMin: boundary),
        DateTime(2026, 10, 29),
      );
    });

    test('달·해가 바뀌는 새벽과 윤년 2월 말도 전날로 넘긴다', () {
      expect(
        logicalDate(minutesInto(2026, 11, 1, 0), dayBoundaryMin: boundary),
        DateTime(2026, 10, 31),
      );
      expect(
        logicalDate(minutesInto(2027, 1, 1, 0), dayBoundaryMin: boundary),
        DateTime(2026, 12, 31),
      );
      expect(
        logicalDate(minutesInto(2028, 3, 1, 0), dayBoundaryMin: boundary),
        DateTime(2028, 2, 29),
      );
    });

    test('결과는 시각을 0으로 둔 로컬 날짜다', () {
      final result = logicalDate(
        DateTime(2026, 10, 29, 15, 42, 7, 8, 9),
        dayBoundaryMin: boundary,
      );
      expect(result, DateTime(2026, 10, 29));
      expect(result.isUtc, isFalse);
    });

    test('UTC로 받은 시각은 로컬 시각으로 바꿔 계산한다', () {
      final noon = DateTime(2026, 10, 29, 12);
      expect(
        logicalDate(noon.toUtc(), dayBoundaryMin: boundary),
        DateTime(2026, 10, 29),
      );
    });

    test('하루 경계가 0이면 달력 날짜와 같다', () {
      expect(
        logicalDate(DateTime(2026, 10, 29), dayBoundaryMin: 0),
        DateTime(2026, 10, 29),
      );
    });

    test('하루 경계가 하루 밖(0–1439 밖)이면 RangeError다', () {
      final at = DateTime(2026, 10, 29, 12);
      expect(() => logicalDate(at, dayBoundaryMin: -1), throwsRangeError);
      expect(() => logicalDate(at, dayBoundaryMin: 1440), throwsRangeError);
    });
  });

  group('logicalWeekStart', () {
    test('목요일이 속한 주는 그 주 월요일에 시작한다', () {
      // 2026-10-29는 목요일, 2026-10-26은 월요일이다.
      expect(
        logicalWeekStart(DateTime(2026, 10, 29, 12), dayBoundaryMin: boundary),
        DateTime(2026, 10, 26),
      );
    });

    test('월요일 하루 경계 전 새벽은 지난주에 속한다', () {
      final at = minutesInto(2026, 10, 26, boundary - 1);
      expect(
        logicalWeekStart(at, dayBoundaryMin: boundary),
        DateTime(2026, 10, 19),
      );
    });

    test('월요일 하루 경계부터는 그 주다', () {
      final at = minutesInto(2026, 10, 26, boundary);
      expect(
        logicalWeekStart(at, dayBoundaryMin: boundary),
        DateTime(2026, 10, 26),
      );
    });

    test('일요일 밤은 그 주 월요일에 시작한 주다', () {
      expect(
        logicalWeekStart(DateTime(2026, 11, 1, 23), dayBoundaryMin: boundary),
        DateTime(2026, 10, 26),
      );
    });
  });

  group('isoDate', () {
    test('YYYY-MM-DD로 적고 한 자리 월·일은 0을 채운다', () {
      expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('시각은 보지 않는다', () {
      expect(isoDate(DateTime(2026, 10, 29, 23, 59, 59)), '2026-10-29');
    });

    test('logicalDate와 함께 쓰면 하루 경계 전 새벽은 전날 날짜가 된다', () {
      final at = minutesInto(2026, 10, 29, boundary - 1);
      expect(isoDate(logicalDate(at, dayBoundaryMin: boundary)), '2026-10-28');
      final after = minutesInto(2026, 10, 29, boundary);
      expect(
        isoDate(logicalDate(after, dayBoundaryMin: boundary)),
        '2026-10-29',
      );
    });
  });

  group('tryParseIsoDate', () {
    test('isoDate로 적은 날짜를 그날 0시로 되읽는다', () {
      final date = tryParseIsoDate('2026-10-29');
      expect(date, DateTime(2026, 10, 29));
      expect(isoDate(date!), '2026-10-29');
    });

    test('형식이 다르거나 없는 날짜면 null이다', () {
      for (final text in [
        '',
        '2026-1-5',
        '2026/10/29',
        '2026-10-29T00:00',
        '2026-02-30',
        '2026-13-01',
      ]) {
        expect(tryParseIsoDate(text), isNull, reason: text);
      }
    });
  });

  group('Clock', () {
    test('today는 지금이 속한 논리적 하루다', () {
      final clock = FixedClock(minutesInto(2026, 10, 29, boundary - 1));
      expect(clock.today(dayBoundaryMin: boundary), DateTime(2026, 10, 28));
    });

    test('기본 Clock은 로컬 시각을 준다', () {
      expect(const Clock().now().isUtc, isFalse);
    });
  });
}
