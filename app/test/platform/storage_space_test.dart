import 'package:cnu_ai_assistant/platform/storage_space.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(
      storageSpaceChannel,
      (call) async => handler(call),
    );
  }

  tearDown(() => messenger.setMockMethodCallHandler(storageSpaceChannel, null));

  test('남은 바이트를 freeBytes로 묻고 그대로 돌려준다', () async {
    final calls = <MethodCall>[];
    answer((call) {
      calls.add(call);
      return 5 * 1024 * 1024 * 1024;
    });

    expect(await const StorageSpace().freeBytes(), 5 * 1024 * 1024 * 1024);
    expect(calls.single.method, 'freeBytes');
    expect(calls.single.arguments, isNull);
  });

  test('0바이트도 그대로 돌려준다', () async {
    answer((_) => 0);

    expect(await const StorageSpace().freeBytes(), 0);
  });

  test('음수나 정수가 아닌 값은 읽지 못한 것으로 본다', () async {
    for (final value in <Object?>[-1, 1.5, '1024', null]) {
      answer((_) => value);

      expect(await const StorageSpace().freeBytes(), isNull, reason: '$value');
    }
  });

  test('네이티브 오류는 null이다', () async {
    answer((_) => throw PlatformException(code: 'unavailable'));

    expect(await const StorageSpace().freeBytes(), isNull);
  });

  test('채널이 없으면 null이다', () async {
    expect(await const StorageSpace().freeBytes(), isNull);
  });
}
