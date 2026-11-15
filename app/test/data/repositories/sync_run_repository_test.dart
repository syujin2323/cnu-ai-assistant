// 동기화 기록 저장소 테스트. docs/lms.md '동기화'·'호출 예산', docs/screens.md 'LMS 상태 줄과 '다시 로그인''.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_run_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  late AppDatabase db;
  late SyncRunRepository repository;

  // 닫힌 DB 테스트는 AppDatabase를 한 번에 둘 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = SyncRunRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 9, 30);

  Future<int> add(
    DateTime at, {
    SyncTrigger trigger = SyncTrigger.open,
    SyncScope scope = SyncScope.list,
    SyncResultKind result = SyncResultKind.normal,
    List<int>? failed,
    String? detail,
  }) async => _ok(
    await repository.add(
      startedAt: at,
      trigger: trigger,
      scope: scope,
      result: result,
      failedCourseIds: failed,
      elapsedMs: 120,
      detail: detail,
    ),
  );

  test('한 행을 넣고 detail은 이름 꼴만 받는다', () async {
    final id = await add(
      now,
      result: SyncResultKind.parseFailure,
      detail: 'items.dueAt,items.title',
    );
    final row = await db.select(db.syncRuns).getSingle();
    expect(row.id, id);
    expect(row.detail, 'items.dueAt,items.title');
    expect(
      () => repository.add(
        startedAt: now,
        trigger: SyncTrigger.open,
        scope: SyncScope.list,
        result: SyncResultKind.parseFailure,
        elapsedMs: 1,
        detail: '마감 2026-11-20',
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.add(
        startedAt: now,
        trigger: SyncTrigger.open,
        scope: SyncScope.list,
        result: SyncResultKind.normal,
        elapsedMs: -1,
      ),
      throwsArgumentError,
    );
  });

  test(
    '마지막 시도는 건너뛴 기록을 빼고, 마지막 성공은 normal·empty·partial 가운데 가장 늦은 것이다',
    () async {
      final attempts = <SyncRun?>[];
      final successes = <SyncRun?>[];
      final a = repository.watchLatestAttempt().listen(attempts.add);
      final b = repository.watchLatestSuccess().listen(successes.add);
      await pumpEventQueue();
      final partial = await add(
        now.subtract(const Duration(hours: 2)),
        trigger: SyncTrigger.manual,
        result: SyncResultKind.partial,
        failed: [3],
      );
      final failure = await add(
        now.subtract(const Duration(hours: 1)),
        result: SyncResultKind.serverError,
      );
      await add(now, result: SyncResultKind.skipped, detail: 'budget');
      await pumpEventQueue();
      await a.cancel();
      await b.cancel();

      expect(attempts.first, isNull);
      expect(attempts.last?.id, failure);
      expect(successes.last?.id, partial);
      expect(successes.last?.trigger, SyncTrigger.manual);
      expect(successes.last?.failedCourseIds, [3]);
    },
  );

  test('마지막 자동 list 기록은 자동 계기·list·건너뛰지 않은 것만 본다', () async {
    expect(_ok(await repository.lastAutoList()), isNull);
    final periodic = await add(
      now.subtract(const Duration(hours: 3)),
      trigger: SyncTrigger.periodic,
      result: SyncResultKind.networkFailure,
    );
    await add(
      now.subtract(const Duration(hours: 2)),
      trigger: SyncTrigger.manual,
    );
    await add(
      now.subtract(const Duration(hours: 1)),
      trigger: SyncTrigger.login,
    );
    await add(
      now.subtract(const Duration(minutes: 30)),
      scope: SyncScope.detail,
    );
    await add(now, result: SyncResultKind.skipped, detail: 'quiet_hours');

    final last = _ok(await repository.lastAutoList())!;
    expect(last.id, periodic);
    expect(last.result, SyncResultKind.networkFailure);
  });

  test('오늘(한국 시각 00:00부터) 자동 계기 호출을 범위별로 세고, 건너뛴 기록만 빼며 취소된 기록은 센다', () async {
    final midnight = DateTime(2026, 11, 15);
    await add(midnight.subtract(const Duration(minutes: 1))); // 어제 23:59
    await add(midnight); // 오늘 00:00
    await add(now, trigger: SyncTrigger.background);
    await add(now, result: SyncResultKind.cancelled, detail: 'switch_off');
    await add(now, scope: SyncScope.detail);
    await add(now, result: SyncResultKind.skipped, detail: 'budget');
    await add(now, trigger: SyncTrigger.manual);
    await add(now, trigger: SyncTrigger.login, scope: SyncScope.full);

    expect(_ok(await repository.countAutoCallsToday(now: now)), {
      SyncScope.full: 0,
      SyncScope.list: 3,
      SyncScope.detail: 1,
      // 시간표 불러오기는 동기화 기록에 남기지 않아 늘 0이다.
      SyncScope.timetable: 0,
    });
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await SyncRunRepository(closed).lastAutoList();
    expect(result, isA<Err<SyncRun?>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
