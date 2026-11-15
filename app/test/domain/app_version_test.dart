import 'package:cnu_ai_assistant/domain/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAppVersion', () {
    test('X.Y.Z를 세 숫자로 읽고 빌드 번호와 꼬리는 버린다', () {
      expect(parseAppVersion('0.1.2'), (major: 0, minor: 1, patch: 2));
      expect(parseAppVersion(' 1.10.3 '), (major: 1, minor: 10, patch: 3));
      expect(parseAppVersion('0.1.2+7'), (major: 0, minor: 1, patch: 2));
      expect(parseAppVersion('0.1.2-debugkey'), (major: 0, minor: 1, patch: 2));
    });

    test('꼴이 맞지 않으면 null이다', () {
      for (final text in [
        '',
        '1',
        '1.2',
        '1.2.3.4',
        'v1.2.3',
        '1.2.x',
        '1..3',
        '-1.2.3',
        '1.2.3debug',
        '1234567.0.0',
      ]) {
        expect(parseAppVersion(text), isNull, reason: text);
      }
    });
  });

  group('isBelowMinVersion', () {
    test('세 숫자를 앞에서부터 차례로 견준다', () {
      for (final (current, minimum, below) in [
        ('0.1.0', '0.1.0', false),
        ('0.1.0', '0.1.1', true),
        ('0.1.9', '0.2.0', true),
        ('0.2.0', '0.1.9', false),
        ('0.9.9', '1.0.0', true),
        ('1.0.0', '0.9.9', false),
        ('1.2.10', '1.2.9', false),
        ('1.2.9', '1.2.10', true),
        ('1.10.0', '1.9.0', false),
        ('0.1.0+3', '0.1.0', false),
        ('0.1.0-debugkey', '0.1.1', true),
        ('0.1.0', '0.0.0', false),
      ]) {
        expect(
          isBelowMinVersion(current: current, minimum: minimum),
          below,
          reason: '$current < $minimum',
        );
      }
    });

    test('둘 중 하나라도 꼴이 맞지 않으면 막지 않는다', () {
      expect(isBelowMinVersion(current: '0.1.0', minimum: ''), isFalse);
      expect(isBelowMinVersion(current: '0.1.0', minimum: 'latest'), isFalse);
      expect(isBelowMinVersion(current: 'dev', minimum: '9.9.9'), isFalse);
    });
  });
}
