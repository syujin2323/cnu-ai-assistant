import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clockText', () {
    test('12시간제로 적고 정각이면 분을 뺀다', () {
      expect(clockText(570), '오전 9시 30분');
      expect(clockText(780), '오후 1시');
      expect(clockText(1439), '오후 11시 59분');
    });

    test('자정은 오전 12시, 정오는 오후 12시다', () {
      expect(clockText(0), '오전 12시');
      expect(clockText(720), '오후 12시');
    });

    test('자정을 넘어 1440을 더한 값은 그 시각으로 적는다', () {
      expect(clockText(1560), '오전 2시');
    });

    test('음수는 받지 않는다', () {
      expect(() => clockText(-1), throwsRangeError);
    });
  });

  group('durationText', () {
    test('시간과 분을 아라비아 숫자로 적는다', () {
      expect(durationText(50), '50분');
      expect(durationText(120), '2시간');
      expect(durationText(90), '1시간 30분');
      expect(durationText(0), '0분');
    });

    test('음수는 받지 않는다', () {
      expect(() => durationText(-5), throwsRangeError);
    });
  });

  group('weekdayText', () {
    test('1(월)–7(일)을 한 글자로 적는다', () {
      expect(
        [for (var day = 1; day <= 7; day++) weekdayText(day)],
        ['월', '화', '수', '목', '금', '토', '일'],
      );
    });

    test('범위 밖은 받지 않는다', () {
      expect(() => weekdayText(0), throwsRangeError);
      expect(() => weekdayText(8), throwsRangeError);
    });
  });

  group('dayWord', () {
    // 기본 하루 경계(임시값 240 = 04:00). 기준 시각은 이 값에서 계산해 기본값이 바뀌어도 맞게 둔다.
    const boundary = Defaults.dayBoundaryMin;

    // 그날 0시에서 [minutes]분 지난 로컬 시각.
    DateTime minutesInto(int year, int month, int day, int minutes) =>
        DateTime(year, month, day, 0, minutes);

    // 2026-10-12(월) 낮 12시. 0시는 하루 경계 전이라 전날이 되므로 날짜를 셀 시각에는 시각을 적는다.
    final now = DateTime(2026, 10, 12, 12);

    String word(DateTime at) => dayWord(at, now: now, dayBoundaryMin: boundary);

    test('오늘·내일·모레', () {
      expect(word(DateTime(2026, 10, 12, 23, 59)), '오늘');
      expect(word(DateTime(2026, 10, 13, 23, 59)), '내일');
      expect(word(DateTime(2026, 10, 14, 9)), '모레');
    });

    test('3–6일 뒤는 요일, 7일 뒤부터 N일 뒤', () {
      expect(word(DateTime(2026, 10, 15, 23, 59)), '목요일');
      expect(word(DateTime(2026, 10, 18, 23, 59)), '일요일');
      expect(word(DateTime(2026, 10, 19, 23, 59)), '7일 뒤');
      expect(word(DateTime(2026, 11, 1, 23, 59)), '20일 뒤');
    });

    test('지난 날은 어제·N일 전이고 요일로 적지 않는다', () {
      expect(word(DateTime(2026, 10, 11, 23, 59)), '어제');
      expect(word(DateTime(2026, 10, 10, 23, 59)), '2일 전');
      expect(word(DateTime(2026, 10, 5, 23, 59)), '7일 전');
      expect(word(DateTime(2026, 9, 1, 23, 59)), '41일 전');
    });

    test('날짜 단위로 세므로 오늘 이미 지난 시각도 오늘이다', () {
      expect(word(DateTime(2026, 10, 12, 9)), '오늘');
    });

    test('하루 경계 전의 새벽은 전날로 센다', () {
      // 24:00 마감은 다음 날 00:00으로 저장되지만 그 전날의 마감이다.
      expect(word(DateTime(2026, 10, 13)), '오늘');
      expect(word(minutesInto(2026, 10, 13, boundary - 1)), '오늘');
      expect(word(minutesInto(2026, 10, 13, boundary)), '내일');
      // 같은 달력일이라도 하루 경계 전 새벽(기본값이면 03:00)은 어제다.
      expect(word(minutesInto(2026, 10, 12, boundary - 60)), '어제');
    });

    test('하루 경계 1분 전의 now도 전날로 센다', () {
      final dawn = minutesInto(2026, 10, 13, boundary - 1);
      String fromDawn(DateTime at) =>
          dayWord(at, now: dawn, dayBoundaryMin: boundary);

      expect(fromDawn(DateTime(2026, 10, 12, 23, 59)), '오늘');
      expect(fromDawn(DateTime(2026, 10, 13, 23, 59)), '내일');
      expect(fromDawn(DateTime(2026, 10, 11, 23, 59)), '어제');
    });

    test('달·해가 바뀌어도 달력 일수로 센다', () {
      expect(
        dayWord(
          DateTime(2026, 11, 1, 23, 59),
          now: DateTime(2026, 10, 31, 12),
          dayBoundaryMin: boundary,
        ),
        '내일',
      );
      expect(
        dayWord(
          DateTime(2027, 1, 2, 23, 59),
          now: DateTime(2026, 12, 31, 12),
          dayBoundaryMin: boundary,
        ),
        '모레',
      );
      expect(
        dayWord(
          DateTime(2026, 12, 31, 23, 59),
          now: DateTime(2027, 1, 1, 12),
          dayBoundaryMin: boundary,
        ),
        '어제',
      );
    });
  });

  group('isDueSoon', () {
    test('오늘·내일 마감만 붉게 쓴다', () {
      expect(isDueSoon(0), isTrue);
      expect(isDueSoon(1), isTrue);
    });

    test('지난 마감과 모레부터는 붉게 쓰지 않는다', () {
      for (final days in [-7, -1, 2, 7]) {
        expect(isDueSoon(days), isFalse, reason: '$days');
      }
    });
  });
}
