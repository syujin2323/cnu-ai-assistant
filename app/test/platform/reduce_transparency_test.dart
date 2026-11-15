import 'package:cnu_ai_assistant/platform/reduce_transparency.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      accessibilityChannel,
      (call) async => handler(call),
    );
  }

  tearDown(
    () => messenger.setMockMethodCallHandler(accessibilityChannel, null),
  );

  test('reduceTransparency로 묻고 켜져 있으면 true다', () async {
    final calls = <MethodCall>[];
    answer((call) {
      calls.add(call);
      return true;
    });

    expect(await const ReduceTransparency().isEnabled(), isTrue);
    expect(calls.single.method, 'reduceTransparency');
    expect(calls.single.arguments, isNull);
  });

  test('꺼져 있거나 참거짓이 아닌 값이면 false다', () async {
    for (final value in <Object?>[false, 1, 'true', null]) {
      answer((_) => value);

      expect(
        await const ReduceTransparency().isEnabled(),
        isFalse,
        reason: '$value',
      );
    }
  });

  test('네이티브 오류는 false다', () async {
    answer((_) => throw PlatformException(code: 'unavailable'));

    expect(await const ReduceTransparency().isEnabled(), isFalse);
  });

  test('채널이 없으면(Android) false다', () async {
    expect(await const ReduceTransparency().isEnabled(), isFalse);
  });
}
