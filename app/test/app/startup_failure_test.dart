// 시작 실패 이유 나누기 테스트. docs/screens.md '20 시스템'.
//
// 앱의 폰 DB는 백그라운드 연결(별도 isolate)로 열리므로 여는 중의 오류가 DriftRemoteException에 싸여
// 온다. 그래서 실제와 같은 백그라운드 연결로 임시 파일 DB를 열어, 새 버전 파일과 DB가 아닌 파일을
// 알맞은 이유로 나누는지 본다.

import 'dart:io';

import 'package:cnu_ai_assistant/app/startup_failure.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('새 버전 DB만 다시 시도를 두지 않는다', () {
    expect(StartupFailure.newerDatabase.canRetry, isFalse);
    expect(StartupFailure.database.canRetry, isTrue);
    expect(StartupFailure.other.canRetry, isTrue);
  });

  test('싸이지 않은 오류를 나눈다', () {
    expect(
      classifyStartupError(const NewerDatabaseException(2, 1)),
      StartupFailure.newerDatabase,
    );
    expect(
      classifyStartupError(
        SqliteException(extendedResultCode: 26, message: 'not a database'),
      ),
      StartupFailure.database,
    );
    expect(classifyStartupError(StateError('x')), StartupFailure.other);
    expect(classifyStartupError(Exception('x')), StartupFailure.other);
  });

  test('백그라운드 연결로 새 버전 파일을 열면 newerDatabase다', () async {
    final file = await _tempDatabaseFile();
    final writer = AppDatabase(NativeDatabase(file, enableMigrations: false));
    await writer.customStatement('PRAGMA user_version = 2');
    await writer.close();

    final db = AppDatabase(NativeDatabase.createBackgroundConnection(file));
    addTearDown(db.close);

    expect(
      classifyStartupError(await _openError(db)),
      StartupFailure.newerDatabase,
    );
  });

  test('백그라운드 연결로 DB가 아닌 파일을 열면 database다', () async {
    final file = await _tempDatabaseFile();
    await file.writeAsString('SQLite DB가 아닌 파일. ' * 100);

    final db = AppDatabase(NativeDatabase.createBackgroundConnection(file));
    addTearDown(db.close);

    expect(classifyStartupError(await _openError(db)), StartupFailure.database);
  });
}

/// [db]를 열다가 난 오류. 열리면 테스트가 실패한다.
Future<Object> _openError(AppDatabase db) async {
  try {
    await db.customSelect('SELECT 1').get();
  } catch (error) {
    return error;
  }
  fail('열리지 않아야 한다');
}

Future<File> _tempDatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('startup_failure_test');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/app.sqlite');
}
