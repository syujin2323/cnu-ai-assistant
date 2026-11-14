// 시각 구간과 구간 연산 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 1단계.

import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-12 하루 안의 시각. 분은 생략하면 0이다.
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 10, 12, hour, minute);

  TimeSpan span(int startHour, int endHour) =>
      TimeSpan(at(startHour), at(endHour));

  group('TimeSpan', () {
    test('contains는 시작을 넣고 끝을 넣지 않는다', () {
      final s = span(9, 10);
      expect(s.contains(at(9)), isTrue);
      expect(s.contains(at(9, 59)), isTrue);
      expect(s.contains(at(10)), isFalse);
      expect(s.contains(at(8, 59)), isFalse);
    });

    test('intersection은 겹치는 부분이고, 맞닿기만 하거나 떨어져 있으면 null이다', () {
      expect(span(9, 12).intersection(span(11, 14)), span(11, 12));
      expect(span(9, 12).intersection(span(10, 11)), span(10, 11));
      expect(span(9, 12).intersection(span(12, 13)), isNull);
      expect(span(9, 10).intersection(span(11, 12)), isNull);
    });
  });

  group('subtractSpans', () {
    test('하루 창에서 바쁜 구간을 빼고, 순서 없는 입력과 겹치는 바쁜 구간도 한 번만 뺀다', () {
      expect(
        subtractSpans(span(9, 18), [span(13, 14), span(10, 11), span(10, 12)]),
        [span(9, 10), span(12, 13), span(14, 18)],
      );
    });

    test('창 밖의 바쁜 구간과 길이가 0 이하인 바쁜 구간은 무시한다', () {
      expect(
        subtractSpans(span(9, 12), [
          span(7, 8),
          span(13, 14),
          TimeSpan(at(10), at(10)),
          TimeSpan(at(11), at(10)),
        ]),
        [span(9, 12)],
      );
    });

    test('창을 다 덮으면 빈 목록이고, 창 끝에 걸친 바쁜 구간은 그 앞까지 남긴다', () {
      expect(subtractSpans(span(9, 12), [span(8, 13)]), isEmpty);
      expect(subtractSpans(span(9, 12), [span(8, 10), span(11, 13)]), [
        span(10, 11),
      ]);
    });
  });

  group('mergeSpans', () {
    test('겹치거나 맞닿은 구간은 합치고 떨어진 구간은 시작 순서로 둔다', () {
      expect(
        mergeSpans([span(14, 15), span(9, 11), span(10, 12), span(12, 13)]),
        [span(9, 13), span(14, 15)],
      );
      expect(mergeSpans([span(9, 12), span(10, 11)]), [span(9, 12)]);
      expect(mergeSpans(const []), isEmpty);
    });
  });

  group('cutSpans', () {
    test('가운데에 걸리면 둘로 나누고, 걸친 쪽은 잘라 내고, 덮으면 지운다', () {
      expect(cutSpans([span(9, 12)], span(10, 11)), [
        span(9, 10),
        span(11, 12),
      ]);
      expect(cutSpans([span(9, 12)], span(11, 13)), [span(9, 11)]);
      expect(cutSpans([span(9, 12)], span(8, 10)), [span(10, 12)]);
      expect(cutSpans([span(9, 12)], span(8, 13)), isEmpty);
    });

    test('겹치지 않거나 맞닿기만 한 구간과, 길이가 0 이하인 자르기는 그대로 둔다', () {
      expect(cutSpans([span(9, 10), span(13, 14)], span(10, 13)), [
        span(9, 10),
        span(13, 14),
      ]);
      expect(cutSpans([span(9, 12)], TimeSpan(at(10), at(10))), [span(9, 12)]);
      expect(cutSpans([span(9, 12)], TimeSpan(at(11), at(10))), [span(9, 12)]);
    });
  });

  group('spansFrom', () {
    test('그 시각까지 끝난 구간은 버리고, 걸친 구간은 그 시각부터 남기고, 뒤의 구간은 그대로 둔다', () {
      expect(
        spansFrom([
          span(8, 9),
          span(9, 10),
          span(10, 12),
          span(13, 14),
        ], at(11)),
        [TimeSpan(at(11), at(12)), span(13, 14)],
      );
      expect(spansFrom([span(9, 10)], at(10)), isEmpty);
      expect(spansFrom([span(9, 10)], at(9)), [span(9, 10)]);
    });
  });
}
