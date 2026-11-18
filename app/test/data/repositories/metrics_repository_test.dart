// 사용 지표 저장소 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/metrics_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_run_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

DateTime at(int date, int hour, [int minute = 0]) =>
    DateTime(2026, 11, date, hour, minute);

T ok<T>(Result<T> result) => (result as Ok<T>).value;

void main() {
  late AppDatabase db;
  late MetricsRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = MetricsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> briefing(String date, {DateTime? openedAt}) => db
      .into(db.briefings)
      .insert(
        BriefingsCompanion.insert(
          date: date,
          createdAt: openedAt ?? at(1, 0),
          openedAt: Value(openedAt),
        ),
      );

  Future<void> block(
    DateTime start,
    BlockSource source,
    PlanBlockStatus s,
  ) async {
    final taskId = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '할 일',
            kind: TaskKind.assignment,
            dueTimeUnknown: false,
            status: TaskStatus.todo,
          ),
        );
    await db
        .into(db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
            status: s,
            source: source,
          ),
        );
  }

  test('앱을 쓴 날은 브리핑을 본 것으로 적은 날 가운데 주어진 날부터다', () async {
    await briefing('2026-11-12', openedAt: at(12, 9));
    await briefing('2026-11-13', openedAt: at(13, 9));
    await briefing('2026-11-14');
    await briefing('2026-11-15', openedAt: at(15, 9));

    expect(
      ok(await repo.activeDaysFrom('2026-11-13')),
      unorderedEquals(['2026-11-13', '2026-11-15']),
    );
  });

  test('자동 블록이 있는지는 상태와 관계없이 시작 시각으로 보고, 직접 놓은 블록은 보지 않는다', () async {
    await block(at(18, 10), BlockSource.manual, PlanBlockStatus.confirmed);
    expect(
      ok(await repo.hasAutoBlocks(start: at(18, 4), end: at(19, 4))),
      isFalse,
    );

    await block(at(19, 4), BlockSource.auto, PlanBlockStatus.suggested);
    expect(
      ok(await repo.hasAutoBlocks(start: at(18, 4), end: at(19, 4))),
      isFalse,
      reason: '끝은 들지 않는다',
    );

    await block(at(18, 4), BlockSource.auto, PlanBlockStatus.dismissed);
    expect(
      ok(await repo.hasAutoBlocks(start: at(18, 4), end: at(19, 4))),
      isTrue,
    );
  });

  test('보고에 쓸 브리핑·자동 블록·동기화 기록을 범위만큼 읽는다', () async {
    await briefing('2026-11-17', openedAt: at(17, 9));
    await briefing('2026-11-18', openedAt: at(18, 9));
    await briefing('2026-11-16', openedAt: at(16, 9));
    await block(at(17, 10), BlockSource.auto, PlanBlockStatus.done);
    await block(at(18, 10), BlockSource.manual, PlanBlockStatus.confirmed);
    await block(at(16, 10), BlockSource.auto, PlanBlockStatus.missed);
    final runs = SyncRunRepository(db);
    for (final startedAt in [
      at(17, 3, 59),
      at(17, 4),
      at(19, 3, 59),
      at(19, 4),
    ]) {
      await runs.add(
        startedAt: startedAt,
        trigger: SyncTrigger.open,
        scope: SyncScope.list,
        result: SyncResultKind.normal,
        elapsedMs: 10,
      );
    }

    final source = ok(
      await repo.read(
        days: ['2026-11-17', '2026-11-18'],
        from: at(17, 4),
        to: at(19, 4),
      ),
    );

    expect(
      source.briefings.keys,
      unorderedEquals(['2026-11-17', '2026-11-18']),
    );
    expect(source.briefings['2026-11-17']!.openedAt, at(17, 9));
    expect(source.autoBlockStarts, [at(17, 10)]);
    expect([
      for (final run in source.syncRuns) run.startedAt,
    ], unorderedEquals([at(17, 4), at(19, 3, 59)]));
  });

  test('폰 DB를 읽지 못하면 예외 대신 Err다', () async {
    // 연 뒤 닫은 DB를 받아 둔 저장소(데모를 끝내며 닫은 DB와 같은 경우).
    expect(await repo.activeDaysFrom('2026-11-13'), isA<Ok<List<String>>>());
    await db.close();
    expect(await repo.activeDaysFrom('2026-11-13'), isA<Err<List<String>>>());
    expect(
      await repo.hasAutoBlocks(start: at(18, 4), end: at(19, 4)),
      isA<Err<bool>>(),
    );
    expect(
      await repo.read(days: const [], from: at(18, 4), to: at(19, 4)),
      isA<Err<MetricsSource>>(),
    );
  });
}
