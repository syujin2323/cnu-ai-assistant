import 'package:cnu_ai_assistant/platform/device_integrity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      deviceIntegrityChannel,
      (call) async => handler(call),
    );
  }

  tearDown(
    () => messenger.setMockMethodCallHandler(deviceIntegrityChannel, null),
  );

  test('isCompromised로 묻고 참거짓을 그대로 돌려준다', () async {
    final calls = <MethodCall>[];
    for (final value in [true, false]) {
      answer((call) {
        calls.add(call);
        return value;
      });

      expect(await const DeviceIntegrity().isCompromised(), value);
    }
    expect(calls.map((call) => call.method), [
      'isCompromised',
      'isCompromised',
    ]);
    expect(calls.map((call) => call.arguments), [null, null]);
  });

  test('참거짓이 아닌 값은 확인하지 못한 것으로 본다', () async {
    for (final value in <Object?>[1, 'true', null]) {
      answer((_) => value);

      expect(
        await const DeviceIntegrity().isCompromised(),
        isNull,
        reason: '$value',
      );
    }
  });

  test('네이티브 오류는 null이다', () async {
    answer((_) => throw PlatformException(code: 'unavailable'));

    expect(await const DeviceIntegrity().isCompromised(), isNull);
  });

  test('채널이 없으면 null이다', () async {
    expect(await const DeviceIntegrity().isCompromised(), isNull);
  });
}
