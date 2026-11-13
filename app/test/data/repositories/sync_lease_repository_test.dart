// 동기화 잠금 저장소 테스트. docs/lms.md '동기화'.

import 'dart:io';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_lease_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/sync_lease.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncLeaseRepository leases;
  final now = DateTime(2026, 11, 13, 9);
  const lease = SyncLeaseRepository.leaseDuration;

  // 두 연결·닫힌 DB 테스트는 AppDatabase를 한 번에 여럿 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    leases = SyncLeaseRepository(db);
  });

  tearDown(() => db.close());

  Future<SyncLease?> row() => db.select(db.syncLeases).getSingleOrNull();

  test('비어 있으면 잡고 5분 뒤 만료로 적으며, 잡혀 있는 동안 다른 쪽은 잡지 못한다', () async {
    final token = _ok(await leases.acquire(LeaseHolder.foreground, now: now));
    expect(token, isNotNull);
    final held = (await row())!;
    expect(held.id, 1);
    expect(held.holder, LeaseHolder.foreground);
    expect(held.token, token);
    expect(held.expiresAt, now.add(lease));

    final justBefore = now.add(lease - const Duration(seconds: 1));
    expect(
      _ok(await leases.acquire(LeaseHolder.background, now: justBefore)),
      isNull,
    );
    expect((await row())!.token, token);
  });

  test('늘리기와 풀기는 자기 토큰일 때만 하고, 푼 뒤에는 다시 잡을 수 있다', () async {
    final token = _ok(await leases.acquire(LeaseHolder.foreground, now: now))!;
    final later = now.add(const Duration(minutes: 1));

    expect(_ok(await leases.extend('other-token', now: later)), isFalse);
    expect(_ok(await leases.release('other-token')), isFalse);
    expect((await row())!.expiresAt, now.add(lease));

    expect(_ok(await leases.extend(token, now: later)), isTrue);
    expect((await row())!.expiresAt, later.add(lease));
    expect(_ok(await leases.release(token)), isTrue);
    expect(await row(), isNull);
    // 이미 풀었으면 false다.
    expect(_ok(await leases.release(token)), isFalse);

    final again = _ok(await leases.acquire(LeaseHolder.background, now: later));
    expect(again, isNot(token));
    expect((await row())!.id, 1);
  });

  test('만료되면 다른 쪽이 새 토큰으로 넘겨받고, 늦게 끝난 쪽은 늘리거나 풀지 못한다', () async {
    final first = _ok(await leases.acquire(LeaseHolder.background, now: now))!;
    // 만료 시각이 되면 지난 것으로 본다.
    final expiry = now.add(lease);
    final second = _ok(
      await leases.acquire(LeaseHolder.foreground, now: expiry),
    )!;
    expect(second, isNot(first));

    expect(_ok(await leases.extend(first, now: expiry)), isFalse);
    expect(_ok(await leases.release(first)), isFalse);
    final held = (await row())!;
    expect(held.holder, LeaseHolder.foreground);
    expect(held.token, second);
  });

  test('같은 쪽(백그라운드 작업 둘)이어도 토큰으로 가린다', () async {
    final first = _ok(await leases.acquire(LeaseHolder.background, now: now))!;
    final second = _ok(
      await leases.acquire(LeaseHolder.background, now: now.add(lease)),
    )!;
    expect(_ok(await leases.release(first)), isFalse);
    expect(_ok(await leases.release(second)), isTrue);
  });

  test('두 연결(앱과 백그라운드 작업처럼)이 함께 잡아도 하나만 잡는다', () async {
    final dir = await Directory.systemTemp.createTemp('sync_lease_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final app = AppDatabase(NativeDatabase.createBackgroundConnection(file));
    addTearDown(app.close);
    // 표를 먼저 만들어 두 연결이 함께 만들지 않게 한다.
    await app.customSelect('SELECT 1').get();
    final worker = AppDatabase(NativeDatabase(file));
    addTearDown(worker.close);
    await worker.customSelect('SELECT 1').get();

    final results = await Future.wait([
      SyncLeaseRepository(app).acquire(LeaseHolder.foreground, now: now),
      SyncLeaseRepository(worker).acquire(LeaseHolder.background, now: now),
    ]);

    final tokens = [
      for (final result in results)
        if (result case Ok(value: final token?)) token,
    ];
    expect(tokens, hasLength(1));
    // 잡지 못한 쪽은 잡혀 있음(null)을 받거나, 기다리지 않아 잠김(코드 5)으로 끝난다.
    for (final result in results) {
      if (result case Ok(value: final token?) when tokens.contains(token)) {
        continue;
      }
      expect(
        result,
        anyOf(
          const Ok<String?>(null),
          const Err<String?>(
            StorageError(
              'syncLease.acquire',
              causeType: 'SqliteException',
              code: 5,
            ),
          ),
        ),
      );
    }
    expect((await app.select(app.syncLeases).getSingle()).token, tokens.single);
  });

  test('폰 DB를 쓰지 못하면(닫힌 DB) 예외 대신 Err다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final closedLeases = SyncLeaseRepository(closed);

    expect(
      await closedLeases.acquire(LeaseHolder.foreground, now: now),
      const Err<String?>(
        StorageError('syncLease.acquire', causeType: 'StateError'),
      ),
    );
    expect(
      await closedLeases.extend('token', now: now),
      const Err<bool>(
        StorageError('syncLease.extend', causeType: 'StateError'),
      ),
    );
    expect(
      await closedLeases.release('token'),
      const Err<bool>(
        StorageError('syncLease.release', causeType: 'StateError'),
      ),
    );
  });
}

/// [result]가 [Ok]면 값을 꺼내고, [Err]면 테스트를 실패시킨다.
T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};
