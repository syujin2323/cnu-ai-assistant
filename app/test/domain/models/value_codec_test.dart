// 열거형·시각을 폰 DB(JSON 값 포함)에 적는 형식 테스트. docs/architecture.md '폰 DB'의 공통 규칙.

import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('열거형', () {
    test('Dart 이름을 snake_case로 적고 되읽으며, 모르는 값은 FormatException 또는 null이다', () {
      expect(snakeName(ClassExceptionKind.placeChange), 'place_change');
      expect(
        enumFromSnake(ClassExceptionKind.values, 'place_change'),
        ClassExceptionKind.placeChange,
      );
      expect(
        () => enumFromSnake(ClassExceptionKind.values, 'placeChange'),
        throwsFormatException,
      );
      expect(tryEnumFromSnake(ClassExceptionKind.values, 'nap'), isNull);
      expect(tryEnumFromSnake(ClassExceptionKind.values, 1), isNull);
    });
  });

  group('시각', () {
    // docs/decisions.md 2026-11-14 '기기 시간대와 관계없이 한국 시각을 쓴다'. CI(UTC)와 개발 기기(KST)에서 함께 돈다.
    final wall = DateTime(2026, 10, 29, 9, 30);

    test("앱의 시각(한국 시각)에 '+09:00'을 붙여 적고, UTC 값은 한국 시각으로 바꿔 적는다", () {
      expect(encodeDateTime(wall), '2026-10-29T09:30:00.000 +09:00');
      expect(
        encodeDateTime(DateTime.utc(2026, 10, 29, 0, 30)),
        '2026-10-29T09:30:00.000 +09:00',
      );
      expect(
        encodeDateTime(DateTime(2026, 10, 29, 9, 30, 0, 0, 5)),
        '2026-10-29T09:30:00.000005 +09:00',
      );
    });

    test('오프셋이 있는 시각을 한국 시각의 로컬 값으로 읽는다', () {
      for (final text in [
        '2026-10-29T09:30:00.000 +09:00',
        '2026-10-29T00:30:00.000Z',
        '2026-10-28T20:30:00.000-04:00',
      ]) {
        final read = decodeDateTime(text);
        expect(read, wall, reason: text);
        expect(read.isUtc, isFalse, reason: text);
        expect(tryDecodeDateTime(text), wall, reason: text);
      }
      expect(decodeDateTime(encodeDateTime(wall)), wall);
    });

    test('오프셋이 없거나 꼴이 틀리면 읽지 않는다', () {
      expect(
        () => decodeDateTime('2026-10-29T09:30:00'),
        throwsFormatException,
      );
      expect(() => decodeDateTime('어제'), throwsFormatException);
      expect(tryDecodeDateTime('2026-10-29'), isNull);
      expect(tryDecodeDateTime('어제'), isNull);
      expect(tryDecodeDateTime(20261029), isNull);
      expect(tryDecodeDateTime(null), isNull);
    });
  });
}
