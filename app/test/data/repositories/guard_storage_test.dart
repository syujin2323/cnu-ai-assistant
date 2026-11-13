// guardStorage 테스트. docs/architecture.md '앱 코드 규약'의 오류 처리.
//
// 저장소가 폰 DB 실패를 예외 대신 StorageError로 돌려주는지, 그때 예외 메시지(SQL과 바인딩 값이
// 들어감) 대신 원인의 타입 이름과 SQLite 확장 결과 코드만 담는지 본다. 앱의 폰 DB는 백그라운드
// 연결이라 오류가 DriftRemoteException에 싸여 오므로 그 경로도 임시 파일 DB로 본다.

import 'dart:io';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('성공하면 값을 Ok로 돌려준다', () async {
    expect(await guardStorage('test.read', () async => 3), const Ok(3));
  });

  test('SQLite 오류는 원인의 타입 이름과 확장 결과 코드만 담는다', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final result = await guardStorage(
      'test.read',
      () => db.customSelect('SELECT * FROM no_such_table').get(),
    );

    // 1: SQLITE_ERROR(없는 표).
    expect(
      _errorOf(result),
      const StorageError('test.read', causeType: 'SqliteException', code: 1),
    );
  });

  test('백그라운드 연결의 SQLite 오류는 DriftRemoteException을 풀어 원인을 담는다', () async {
    final db = AppDatabase(
      NativeDatabase.createBackgroundConnection(await _tempDatabaseFile()),
    );
    addTearDown(db.close);

    final result = await guardStorage(
      'test.read',
      () => db.customSelect('SELECT * FROM no_such_table').get(),
    );

    expect(
      _errorOf(result),
      const StorageError('test.read', causeType: 'SqliteException', code: 1),
    );
  });

  test('닫힌 DB는 StateError를 던지지 않고 Err다', () async {
    final db = AppDatabase.memory();
    await db.customSelect('SELECT 1').get();
    await db.close();

    final result = await guardStorage(
      'test.read',
      () => db.customSelect('SELECT 1').get(),
    );

    expect(
      _errorOf(result),
      const StorageError('test.read', causeType: 'StateError'),
    );
  });

  test('닫힌 백그라운드 연결도 Err다(그 StateError 메시지에는 SQL과 값이 들어 있다)', () async {
    final db = AppDatabase(
      NativeDatabase.createBackgroundConnection(await _tempDatabaseFile()),
    );
    await db.customSelect('SELECT 1').get();
    await db.close();
    Future<void> insert() => db.customStatement(
      'INSERT INTO settings (key, value) VALUES (?, ?)',
      ['aiEnabled', 'true'],
    );

    // 원래 예외의 메시지에는 SQL과 바인딩 값이 들어 있다.
    await expectLater(
      insert,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('INSERT INTO settings'), contains('aiEnabled')),
        ),
      ),
    );

    final result = await guardStorage('test.write', insert);

    expect(
      _errorOf(result),
      const StorageError('test.write', causeType: 'StateError'),
    );
    expect('${_errorOf(result)}', isNot(contains('aiEnabled')));
  });

  test('SQLite 밖의 예외는 타입 이름만 담는다', () async {
    final result = await guardStorage<void>(
      'test.write',
      () async => throw const FileSystemException('disk'),
    );

    expect(
      _errorOf(result),
      const StorageError('test.write', causeType: 'FileSystemException'),
    );
  });

  test('StorageError는 동작·원인 타입·코드가 모두 같아야 같고, 문자열에는 이 셋만 있다', () {
    // 이 파일과 저장소 테스트는 ==로 코드까지 비교하므로 ==가 코드를 봐야 그 확인이 뜻을 가진다.
    const busy = StorageError(
      'settings.write',
      causeType: 'SqliteException',
      code: 5,
    );
    expect(
      busy,
      const StorageError(
        'settings.write',
        causeType: 'SqliteException',
        code: 5,
      ),
    );
    expect(
      busy,
      isNot(
        const StorageError(
          'settings.write',
          causeType: 'SqliteException',
          code: 517,
        ),
      ),
    );
    expect(
      busy,
      isNot(const StorageError('settings.write', causeType: 'SqliteException')),
    );
    expect(
      '$busy',
      'StorageError(operation: settings.write, causeType: SqliteException, '
          'code: 5)',
    );
  });

  test('ArgumentError·TypeError 같은 프로그래밍 오류는 그대로 던진다', () async {
    await expectLater(
      guardStorage<void>('test.write', () async => throw ArgumentError('key')),
      throwsArgumentError,
    );
    await expectLater(
      guardStorage<int>('test.read', () async {
        final Object value = 'not a number';
        return value as int;
      }),
      throwsA(isA<TypeError>()),
    );
  });
}

/// [result]가 [Err]면 그 오류, [Ok]면 null.
AppError? _errorOf(Result<Object?> result) => switch (result) {
  Ok() => null,
  Err(:final error) => error,
};

/// 테스트마다 새 임시 폴더의 DB 파일(앱처럼 파일에 연다). 테스트가 끝나면 폴더를 지운다.
Future<File> _tempDatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('guard_storage_test');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/app.sqlite');
}
