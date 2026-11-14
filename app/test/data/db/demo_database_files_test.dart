// 데모 DB 파일 지우기 테스트. docs/architecture.md '데모 모드', docs/decisions.md 2026-11-14 '앱을 켤 때 데모 DB를
// 열지 못하면 실제 모드로 돌아간다'.
//
// 앱 문서 폴더는 path_provider 채널을 흉내 내 임시 폴더로 돌린다.

import 'dart:io';

import 'package:cnu_ai_assistant/data/db/demo_database_files.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('앱 문서 폴더의 데모 DB와 곁 파일만 지우고 실제 DB는 두며, 없는 파일은 건너뛴다', () async {
    final directory = await Directory.systemTemp.createTemp('demo_files');
    addTearDown(() => directory.delete(recursive: true));
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? directory.path
          : null,
    );
    // 저널 파일(-journal)은 없다.
    for (final name in [
      'app_demo.sqlite',
      'app_demo.sqlite-wal',
      'app_demo.sqlite-shm',
      'app.sqlite',
      'app.sqlite-wal',
    ]) {
      await File('${directory.path}/$name').writeAsString('x');
    }

    expect(await const DemoDatabaseFiles().delete(), isA<Ok<void>>());

    final left = {
      for (final entity in directory.listSync()) entity.uri.pathSegments.last,
    };
    expect(left, {'app.sqlite', 'app.sqlite-wal'});
  });

  test('앱 문서 폴더를 알 수 없으면 던지지 않고 Err(StorageError)다', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'unavailable'),
    );

    expect(
      await const DemoDatabaseFiles().delete(),
      isA<Err<void>>().having(
        (err) => err.error,
        'error',
        isA<StorageError>().having(
          (error) => error.operation,
          'operation',
          'demo.deleteFiles',
        ),
      ),
    );
  });
}
