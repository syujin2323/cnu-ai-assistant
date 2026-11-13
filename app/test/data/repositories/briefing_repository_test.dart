// 아침 브리핑 기록 저장소 테스트. docs/architecture.md '아침 브리핑'.
//
// 그날(논리적 하루) 행의 openedAt으로 본 것을 가르고, 본 것과 확정한 것을 적을 때 처음 본 시각을 지키는지,
// 폰 DB를 쓰지 못하면 예외 대신 Err인지 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/briefing_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/briefing.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BriefingRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = BriefingRepository(db);
  });
  tearDown(() => db.close());

  final day = DateTime(2026, 11, 13);
  final at = DateTime(2026, 11, 13, 7, 30);
  final later = DateTime(2026, 11, 13, 9);

  Future<List<Briefing>> rows() => (db.select(
    db.briefings,
  )..orderBy([(b) => OrderingTerm(expression: b.id)])).get();

  Future<void> addRow(String date, {DateTime? openedAt}) => db
      .into(db.briefings)
      .insert(
        BriefingsCompanion.insert(
          date: date,
          createdAt: at,
          openedAt: Value(openedAt),
        ),
      );

  group('isSeen', () {
    test('그날 행이 없거나 openedAt이 비었으면 보지 않은 것이다', () async {
      expect(await repo.isSeen(day), const Ok(false));

      await addRow('2026-11-13');
      expect(await repo.isSeen(day), const Ok(false));
    });

    test('그날 행의 openedAt이 있으면 본 것이고, 다른 날 행은 보지 않는다', () async {
      await addRow('2026-11-12', openedAt: at);
      expect(await repo.isSeen(day), const Ok(false));

      await addRow('2026-11-13', openedAt: at);
      expect(await repo.isSeen(day), const Ok(true));
      expect(await repo.isSeen(DateTime(2026, 11, 14)), const Ok(false));
    });
  });

  group('markSeen', () {
    test('그날 행이 없으면 만들고 본 시각을 적는다', () async {
      expect(await repo.markSeen(day, at: at), isA<Ok<void>>());

      final [row] = await rows();
      expect(row.date, '2026-11-13');
      expect(row.createdAt, at);
      expect(row.openedAt, at);
      expect(row.confirmedAt, isNull);
    });

    test('이미 본 것으로 적었으면 처음 시각을 그대로 둔다', () async {
      expect(await repo.markSeen(day, at: at), isA<Ok<void>>());
      expect(await repo.markSeen(day, at: later), isA<Ok<void>>());

      final [row] = await rows();
      expect(row.openedAt, at);
    });

    test('openedAt이 빈 행이 있으면 그 행에 적는다', () async {
      await addRow('2026-11-13');

      await repo.markSeen(day, at: later);

      final [row] = await rows();
      expect(row.openedAt, later);
    });
  });

  group('markConfirmed', () {
    test('확정한 시각을 적고, 다시 확정하면 마지막 시각으로 바꾸되 처음 본 시각은 둔다', () async {
      await repo.markSeen(day, at: at);

      await repo.markConfirmed(day, at: later);
      var [row] = await rows();
      expect(row.openedAt, at);
      expect(row.confirmedAt, later);

      final last = DateTime(2026, 11, 13, 10);
      await repo.markConfirmed(day, at: last);
      [row] = await rows();
      expect(row.openedAt, at);
      expect(row.confirmedAt, last);
    });

    test('본 것으로 적지 않았으면 함께 적는다', () async {
      await repo.markConfirmed(day, at: later);

      final [row] = await rows();
      expect(row.openedAt, later);
      expect(row.confirmedAt, later);
    });
  });

  test('폰 DB를 읽거나 쓰지 못하면 예외 대신 Err다', () async {
    await db.customSelect('SELECT 1').get();
    await db.close();

    expect(await repo.isSeen(day), isA<Err<bool>>());
    expect(await repo.markSeen(day, at: at), isA<Err<void>>());
    expect(await repo.markConfirmed(day, at: at), isA<Err<void>>());
  });
}
