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

  group('dueLabel', () {
    // 2026-10-12는 월요일이다.
    final today = DateTime(2026, 10, 12);
    const boundary = Defaults.dayBoundaryMin;

    String label(DateTime dueAt) =>
        dueLabel(dueAt, today: today, dayBoundaryMin: boundary);

    test('오늘·내일·모레', () {
      expect(label(DateTime(2026, 10, 12, 23, 59)), '오늘');
      expect(label(DateTime(2026, 10, 13, 23, 59)), '내일');
      expect(label(DateTime(2026, 10, 14, 9)), '모레');
    });

    test('6일 안이면 요일, 그보다 멀면 N일 뒤', () {
      expect(label(DateTime(2026, 10, 15, 23, 59)), '목요일');
      expect(label(DateTime(2026, 10, 18, 23, 59)), '일요일');
      expect(label(DateTime(2026, 10, 19, 23, 59)), '7일 뒤');
      expect(label(DateTime(2026, 11, 1, 23, 59)), '20일 뒤');
    });

    test('하루 경계 전의 새벽 마감은 전날로 센다', () {
      // 24:00 마감은 다음 날 00:00으로 저장되지만 그 전날의 마감이다.
      expect(label(DateTime(2026, 10, 13)), '오늘');
      expect(label(DateTime(2026, 10, 13, 0, boundary)), '내일');
    });

    test('달이 바뀌어도 달력 일수로 센다', () {
      final lastDay = DateTime(2026, 10, 31);
      expect(
        dueLabel(
          DateTime(2026, 11, 1, 23, 59),
          today: lastDay,
          dayBoundaryMin: boundary,
        ),
        '내일',
      );
    });

    test('이미 지난 마감은 받지 않는다', () {
      expect(() => label(DateTime(2026, 10, 11, 23, 59)), throwsArgumentError);
    });
  });
}
