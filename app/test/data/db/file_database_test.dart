// 파일 DB 테스트. docs/architecture.md '폰 DB'·'앱 코드 규약'의 백그라운드 작업.
//
// 앱과 같은 백그라운드 연결(별도 isolate, `AppDatabase.open`)로 임시 폴더에 파일 DB를 열어, 메모리 DB에서는 볼 수
// 없는 것(파일 이름, WAL·외래 키·busy_timeout, 두 연결이 함께 쓸 때 기다림, 백그라운드 연결의 오류 풀기, 다시 연
// 파일의 시각)을 본다.

import 'dart:async';
import 'dart:io';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_flutter/drift_flutter.dart' show DriftNativeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  final opened = <AppDatabase>[];

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => dir = Directory.systemTemp.createTempSync('cnu_file_db_'));

  tearDown(() async {
    for (final db in opened) {
      await db.close();
    }
    opened.clear();
    dir.deleteSync(recursive: true);
  });

  AppDatabase open([AppMode mode = AppMode.real]) {
    final db = AppDatabase.open(
      mode,
      native: DriftNativeOptions(
        databaseDirectory: () async => dir.path,
        tempDirectoryPath: () async => dir.path,
      ),
    );
    opened.add(db);
    return db;
  }

  Future<Object?> pragma(AppDatabase db, String name) async =>
      (await db.customSelect('PRAGMA $name').getSingle()).data.values.single;

  Future<int> addSetting(AppDatabase db, String key) => db
      .into(db.settings)
      .insert(SettingsCompanion.insert(key: key, value: '1'));

  /// [first]가 쓰기 트랜잭션을 잡고 [release]가 끝날 때까지 놓지 않는다. 잡은 뒤에 돌아온다.
  Future<Future<void>> holdWriteLock(
    AppDatabase first,
    Future<void> release,
  ) async {
    final holding = Completer<void>();
    final done = first.transaction(() async {
      await addSetting(first, 'first');
      holding.complete();
      await release;
    });
    await holding.future;
    return done;
  }

  test('앱 모드의 파일 이름으로 열고 WAL·외래 키·busy_timeout을 건다', () async {
    final real = open();
    expect(await pragma(real, 'journal_mode'), 'wal');
    expect(await pragma(real, 'foreign_keys'), 1);
    expect(await pragma(real, 'busy_timeout'), AppDatabase.busyTimeoutMs);
    await pragma(open(AppMode.demo), 'journal_mode');
    expect(File('${dir.path}/app.sqlite').existsSync(), isTrue);
    expect(File('${dir.path}/app_demo.sqlite').existsSync(), isTrue);
  });

  test('다른 연결이 쓰는 동안 쓰기는 실패하지 않고 기다렸다가 성공한다', () async {
    final first = open();
    final second = open();
    await pragma(second, 'journal_mode');
    final release = Completer<void>();
    final firstDone = await holdWriteLock(first, release.future);

    final watch = Stopwatch()..start();
    var secondElapsed = Duration.zero;
    final secondWrite = guardStorage(
      'settings.write',
      () => second.transaction(() => addSetting(second, 'second')),
    ).whenComplete(() => secondElapsed = watch.elapsed);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    release.complete();
    await firstDone;

    final result = await secondWrite;
    if (result is Err<int>) {
      final version = await second
          .customSelect('SELECT sqlite_version() AS v')
          .getSingle();
      final options = await second.customSelect('PRAGMA compile_options').get();
      printOnFailure(
        'sqlite ${version.data['v']}, busy_timeout '
        '${await pragma(second, 'busy_timeout')}, failed after '
        '${secondElapsed.inMilliseconds} ms, options '
        '${options.map((row) => row.data.values.single).where((o) => '$o'.contains('LOCK') || '$o'.contains('WAL') || '$o'.contains('THREAD')).toList()}',
      );
    }
    expect(result, isA<Ok<int>>());
    expect(
      watch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 250)),
    );
    expect(
      (await second.select(second.settings).get()).map((row) => row.key),
      unorderedEquals(['first', 'second']),
    );
  });

  test(
    '기다리지 않으면(busy_timeout 0) 곧바로 실패하고, 백그라운드 연결의 오류는 SQLite 코드로 풀어 담는다',
    () async {
      final first = open();
      final second = open();
      await second.customStatement('PRAGMA busy_timeout = 0');
      final release = Completer<void>();
      final firstDone = await holdWriteLock(first, release.future);

      final result = await guardStorage(
        'settings.write',
        () => addSetting(second, 'second'),
      );
      release.complete();
      await firstDone;

      final error = (result as Err<int>).error as StorageError;
      expect(error.operation, 'settings.write');
      expect(error.causeType, 'SqliteException');
      // SQLITE_BUSY(5). 확장 결과 코드의 아래 8비트가 기본 결과 코드다.
      expect(error.code! & 0xff, 5);
    },
  );

  test('CHECK에 걸린 쓰기도 원인 타입과 확장 결과 코드만 담는다', () async {
    final db = open();
    final result = await guardStorage(
      'fixedBlocks.write',
      () => db
          .into(db.fixedBlocks)
          .insert(
            FixedBlocksCompanion.insert(
              name: '알바',
              weekdays: [1],
              startMin: 600,
              endMin: 500,
              bufferMin: 0,
              kind: FixedBlockKind.work,
              source: EntrySource.manual,
            ),
          ),
    );
    final error = (result as Err<int>).error as StorageError;
    expect(error.causeType, 'SqliteException');
    expect(error.code, 275);
  });

  test('시각은 파일에 UTC 문자열로 저장하고, 다시 열어도 같은 한국 시각으로 읽는다', () async {
    final at = DateTime(2026, 10, 29, 9, 30);
    final db = open();
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            title: '회의',
            startAt: at,
            endAt: at.add(const Duration(hours: 1)),
            allDay: false,
            source: EventSource.manual,
          ),
        );
    expect(
      (await db.customSelect('SELECT start_at FROM events').getSingle())
          .data
          .values
          .single,
      '2026-10-29T00:30:00.000Z',
    );
    await db.close();
    opened.remove(db);

    final again = open();
    final event = await again.select(again.events).getSingle();
    expect(event.startAt, at);
    expect(event.endAt, DateTime(2026, 10, 29, 10, 30));
  });
}
