import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/retention_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  // 닫힌 DB 테스트는 AppDatabase를 한 번에 둘 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => db = AppDatabase.memory());

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 6, 9);
  const retention = Duration(days: Defaults.retentionDays);

  // 같은 시각의 동기화 기록·바뀜 기록·브리핑 기록을 하나씩 넣는다.
  Future<void> addRecords(DateTime at, {required String briefingDate}) async {
    await db
        .into(db.syncRuns)
        .insert(
          SyncRunsCompanion.insert(
            startedAt: at,
            trigger: SyncTrigger.open,
            scope: SyncScope.list,
            result: SyncResultKind.normal,
            changedCount: 0,
            elapsedMs: 10,
          ),
        );
    await db
        .into(db.lmsItemChanges)
        .insert(
          LmsItemChangesCompanion.insert(
            remoteKey: 'a:b:assignment:1',
            field: 'dueAt',
            changedAt: at,
          ),
        );
    await db
        .into(db.briefings)
        .insert(BriefingsCompanion.insert(date: briefingDate, createdAt: at));
  }

  test('보관 기간이 지난 동기화·바뀜·브리핑 기록만 지우고 지운 수를 돌려준다', () async {
    final expired = now.subtract(retention + const Duration(minutes: 1));
    await addRecords(expired, briefingDate: '2026-08-07');
    await addRecords(now, briefingDate: '2026-11-06');

    expect(await RetentionRepository(db).deleteExpired(now: now), const Ok(3));

    expect((await db.select(db.syncRuns).get()).single.startedAt, now);
    expect((await db.select(db.lmsItemChanges).get()).single.changedAt, now);
    expect((await db.select(db.briefings).get()).single.date, '2026-11-06');
  });

  test('보관 기간을 꼭 채운 기록은 남긴다', () async {
    await addRecords(now.subtract(retention), briefingDate: '2026-08-08');

    expect(await RetentionRepository(db).deleteExpired(now: now), const Ok(0));
    expect(await db.select(db.briefings).get(), hasLength(1));
  });

  test('폰 DB를 쓰지 못하면 예외 대신 StorageError를 담은 Err를 돌려주고 앞의 표도 되돌린다', () async {
    await addRecords(now.subtract(retention * 2), briefingDate: '2026-08-01');
    // 세 번째 표(briefings)를 지울 때 실패하게 한다. 1은 SQLITE_ERROR(없는 표)다.
    await db.customStatement('ALTER TABLE briefings RENAME TO briefings_moved');

    final result = await RetentionRepository(db).deleteExpired(now: now);

    expect(
      result,
      const Err<int>(
        StorageError(
          'retention.deleteExpired',
          causeType: 'SqliteException',
          code: 1,
        ),
      ),
    );
    // 한 트랜잭션이라 먼저 지운 동기화·바뀜 기록도 그대로다.
    expect(await db.select(db.syncRuns).get(), hasLength(1));
    expect(await db.select(db.lmsItemChanges).get(), hasLength(1));
  });

  test('닫힌 DB를 받아 둔 저장소도 StateError를 던지지 않고 Err를 돌려준다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();

    expect(
      await RetentionRepository(closed).deleteExpired(now: now),
      const Err<int>(
        StorageError('retention.deleteExpired', causeType: 'StateError'),
      ),
    );
  });
}
