// LMS 날짜·시각 읽기 테스트. docs/lms.md '응답 해석'.
//
// 여러 꼴의 글자를 한국 시각 벽시계 값으로 읽는지, 날짜만 있는 마감·23:59:59·24:00·시간대가 붙은 값을 문서대로 다루는지 본다.

import 'package:cnu_ai_assistant/lms/parsers/lms_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('날짜와 시각의 여러 꼴을 한국 시각으로 읽고 초는 버린다', () {
    for (final text in [
      '2026-11-20 23:15:00',
      '2026-11-20 23:15',
      '2026-11-20T23:15:00',
      '2026-11-20T23:15:42.123',
      '20261120231500',
      '202611202315',
      '  2026-11-20 23:15:59 ',
    ]) {
      final parsed = parseLmsDateTime(text);
      expect(parsed?.at, DateTime(2026, 11, 20, 23, 15), reason: text);
      expect(parsed?.timeUnknown, isFalse, reason: text);
      expect(parsed?.at.isUtc, isFalse, reason: text);
    }
  });

  test('23:59:59는 23:59, 24:00은 다음 날 00:00이다(달·해를 넘김)', () {
    expect(
      parseLmsDateTime('2026-11-20 23:59:59')?.at,
      DateTime(2026, 11, 20, 23, 59),
    );
    expect(parseLmsDateTime('2026-11-30 24:00')?.at, DateTime(2026, 12, 1));
    expect(parseLmsDateTime('20261231240000')?.at, DateTime(2027));
    expect(parseLmsDateTime('2026-11-30 24:00')?.timeUnknown, isFalse);
  });

  test('날짜만 있으면 그날 23:59이고 시각을 모른다', () {
    for (final text in ['2026-11-22', '20261122']) {
      final parsed = parseLmsDateTime(text)!;
      expect(parsed.at, DateTime(2026, 11, 22, 23, 59), reason: text);
      expect(parsed.timeUnknown, isTrue, reason: text);
    }
  });

  test('시간대가 붙은 값은 그 순간의 한국 시각이다', () {
    expect(
      parseLmsDateTime('2026-11-20T14:15:00Z')?.at,
      DateTime(2026, 11, 20, 23, 15),
    );
    expect(
      parseLmsDateTime('2026-11-20T23:15:00+09:00')?.at,
      DateTime(2026, 11, 20, 23, 15),
    );
    expect(
      parseLmsDateTime('2026-11-20 10:15:00-05:00')?.at,
      DateTime(2026, 11, 21, 0, 15),
    );
    // 시간대가 붙은 값도 초는 버린다.
    expect(
      parseLmsDateTime('2026-11-20T14:15:42Z')?.at,
      DateTime(2026, 11, 20, 23, 15),
    );
  });

  test('시간대가 붙었는데 시각이 없으면 읽지 않는다', () {
    for (final text in ['2026-11-20Z', '2026-11-20+09:00', '20261120Z']) {
      expect(parseLmsDateTime(text), isNull, reason: text);
    }
  });

  test('비었거나 꼴이 다르거나 없는 날짜·시각이면 null이다', () {
    for (final text in <String?>[
      null,
      '',
      '  ',
      '마감 없음',
      '2026/11/20',
      '2026-02-30',
      '2026-13-01',
      '2026-11-20 25:00',
      '2026-11-20 24:01',
      '2026-11-20 23:60',
      '2026-11-20 23:59:60',
      '2026-11-20T99:00:00Z',
      '2611200000',
    ]) {
      expect(parseLmsDateTime(text), isNull, reason: '$text');
    }
  });
}
