import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
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

    test('자정을 넘은 값은 2879까지 받고, 음수와 2880부터는 받지 않는다', () {
      expect(clockText(2879), '오후 11시 59분');
      expect(() => clockText(-1), throwsRangeError);
      expect(() => clockText(2880), throwsRangeError);
    });
  });

  group('hhmmText', () {
    test('화면의 시각은 24시간제 두 자리로 적는다', () {
      expect(hhmmText(0), '00:00');
      expect(hhmmText(5), '00:05');
      expect(hhmmText(570), '09:30');
      expect(hhmmText(780), '13:00');
      expect(hhmmText(1439), '23:59');
    });

    test('자정을 넘는 끝 시각(1440부터)과 음수는 아직 받지 않는다', () {
      expect(() => hhmmText(1440), throwsRangeError);
      expect(() => hhmmText(-1), throwsRangeError);
    });
  });

  group('shortClockText', () {
    test('칩의 시각은 오전·오후와 H:MM으로 적는다', () {
      expect(shortClockText(360), '오전 6:00');
      expect(shortClockText(480), '오전 8:00');
      expect(shortClockText(570), '오전 9:30');
      expect(shortClockText(720), '오후 12:00');
      expect(shortClockText(750), '오후 12:30');
      expect(shortClockText(60), '오전 1:00');
      expect(shortClockText(1439), '오후 11:59');
    });

    test('브리핑 시각 칩은 오전 6:00부터 오후 12:00까지이고 기본은 오전 8:00이다', () {
      final chips = RuleLimits.briefingChoices.map(shortClockText).toList();
      expect(chips.first, '오전 6:00');
      expect(chips[1], '오전 6:30');
      expect(chips.last, '오후 12:00');
      expect(shortClockText(Defaults.briefingMin), '오전 8:00');
    });

    test('자정 무렵(00:00–00:59)과 1440부터는 아직 받지 않는다', () {
      expect(() => shortClockText(0), throwsRangeError);
      expect(() => shortClockText(59), throwsRangeError);
      expect(() => shortClockText(1440), throwsRangeError);
    });
  });

  group('dueText', () {
    final now = DateTime(2026, 10, 12, 12);

    String due(DateTime? at, {bool unknown = false}) => dueText(
      at,
      dueTimeUnknown: unknown,
      now: now,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );

    test("날짜 말과 HH:MM에 '마감'을 붙인다", () {
      expect(due(DateTime(2026, 10, 12, 23, 59)), '오늘 23:59 마감');
      expect(due(DateTime(2026, 10, 13, 9)), '내일 09:00 마감');
      expect(due(DateTime(2026, 10, 16, 18, 30)), '금요일 18:30 마감');
      expect(due(DateTime(2026, 10, 11, 23, 59)), '어제 23:59 마감');
    });

    test('시각을 모르면 시각 미상, 마감이 없으면 마감 없음이다', () {
      // 날짜만 있는 마감은 그날 23:59로 저장하고 시각을 모른다고 표시한다.
      expect(
        due(DateTime(2026, 10, 13, 23, 59), unknown: true),
        '내일 마감 · 시각 미상',
      );
      expect(due(null), '마감 없음');
      expect(due(null, unknown: true), '마감 없음');
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
