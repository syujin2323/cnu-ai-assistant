import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/retention_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

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

  test('폰 DB를 쓰지 못하면 예외 대신 StorageError를 담은 Err를 돌려준다', () async {
    await db.customStatement('DROP TABLE briefings');

    final result = await RetentionRepository(db).deleteExpired(now: now);

    expect(
      result,
      isA<Err<int>>().having(
        (err) => err.error,
        'error',
        isA<StorageError>().having(
          (error) => error.operation,
          'operation',
          'retention.deleteExpired',
        ),
      ),
    );
  });
}
