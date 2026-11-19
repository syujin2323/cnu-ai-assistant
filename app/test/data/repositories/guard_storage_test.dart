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

  group('저장 공간 부족', () {
    tearDown(StorageFullSignal.take);

    test('저장 공간이 부족해 실패하면 isFull이고 신호에 한 번 적는다', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      // 지금 크기보다 커지지 못하게 막아 저장 공간 부족(SQLITE_FULL 13)을 낸다.
      final pages = await db.customSelect('PRAGMA page_count').getSingle();
      await db.customStatement(
        'PRAGMA max_page_count = ${pages.read<int>('page_count')}',
      );

      final result = await guardStorage(
        'test.write',
        () => db.customStatement(
          "INSERT INTO settings (key, value) VALUES ('big', ?)",
          ['x' * 200000],
        ),
      );

      final error = _errorOf(result);
      expect(
        error,
        const StorageError(
          'test.write',
          causeType: 'SqliteException',
          code: 13,
        ),
      );
      expect((error! as StorageError).isFull, isTrue);
      expect(StorageFullSignal.take(), isTrue);
      expect(StorageFullSignal.take(), isFalse);
    });

    test('트랜잭션 안에서 저장 공간이 부족하면 되돌리기 실패의 포장을 벗겨 원인을 담는다', () async {
      for (final background in [false, true]) {
        final db = background
            ? AppDatabase(
                NativeDatabase.createBackgroundConnection(
                  await _tempDatabaseFile(),
                ),
              )
            : AppDatabase.memory();
        addTearDown(db.close);
        final pages = await db.customSelect('PRAGMA page_count').getSingle();
        await db.customStatement(
          'PRAGMA max_page_count = ${pages.read<int>('page_count')}',
        );

        final result = await guardStorage(
          'test.write',
          () => db.transaction(
            () => db.customStatement(
              "INSERT INTO settings (key, value) VALUES ('big', ?)",
              ['x' * 200000],
            ),
          ),
        );

        expect(
          _errorOf(result),
          const StorageError(
            'test.write',
            causeType: 'SqliteException',
            code: 13,
          ),
          reason: background ? '백그라운드 연결' : '메모리',
        );
        expect(StorageFullSignal.take(), isTrue);
      }
    });

    test('그 밖의 실패는 신호에 적지 않는다', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await guardStorage(
        'test.read',
        () => db.customSelect('SELECT * FROM no_such_table').get(),
      );
      await guardStorage<void>(
        'test.write',
        () async => throw const FileSystemException('disk'),
      );
      expect(StorageFullSignal.take(), isFalse);
    });

    test('isFull은 확장 결과 코드의 아래 8비트가 13인지로 본다', () {
      bool full(int? code) => StorageError(
        'test.write',
        causeType: 'SqliteException',
        code: code,
      ).isFull;
      expect([full(13), full(13 | 0x100)], [true, true]);
      expect([
        full(null),
        full(5),
        full(1),
        full(10 | 0x300),
      ], everyElement(isFalse));
    });

    test('적은 지 window가 지난 표시는 버린다', () {
      final original = StorageFullSignal.elapsed;
      addTearDown(() => StorageFullSignal.elapsed = original);
      var now = Duration.zero;
      StorageFullSignal.elapsed = () => now;

      StorageFullSignal.mark();
      now = StorageFullSignal.window;
      expect(StorageFullSignal.take(), isTrue);

      StorageFullSignal.mark();
      now += StorageFullSignal.window + const Duration(milliseconds: 1);
      expect(StorageFullSignal.take(), isFalse);
    });
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
