// 재계산 결과 쓰기 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 4–5단계.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_apply_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart'
    show TableUpdateQuery, Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const monday = 16;

void main() {
  late AppDatabase db;
  late PlanApplyRepository repository;
  late int task1;
  late int task2;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.memory();
    repository = PlanApplyRepository(db);
    Future<int> task(String title) => db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: title,
            kind: TaskKind.personal,
            dueTimeUnknown: false,
            status: TaskStatus.todo,
          ),
        );
    task1 = await task('보고서');
    task2 = await task('발표 준비');
  });

  tearDown(() => db.close());

  final now = at(monday, 15);

  Future<int> block(
    int taskId,
    DateTime start,
    DateTime end,
    PlanBlockStatus status, {
    BlockReason? reason,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: end,
          status: status,
          source: reason == null ? BlockSource.manual : BlockSource.auto,
          reason: Value(reason),
        ),
      );

  BlockReason reason(int rank) => BlockReason(
    slackMin: 100,
    dueAt: at(monday + 2, 23, 59),
    gapMin: 120,
    rank: rank,
    factor: BlockFactor.fit,
  );

  Future<Map<int, String>> statuses() async => {
    for (final b in await db.select(db.planBlocks).get()) b.id: b.status.name,
  };

  Future<bool> apply(
    List<BlockDraft> suggestions, {
    Set<int> done = const {},
    DateTime? when,
  }) async => _ok(
    await repository.apply(
      suggestions: suggestions,
      doneTaskIds: done,
      now: when ?? now,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    ),
  );

  test('끝나고 30분이 지나도 완료가 아닌 확정 블록은 놓침이고, 할 일을 끝냈으면 지운다', () async {
    final missed = await block(
      task1,
      at(monday, 13),
      at(monday, 14, 30),
      PlanBlockStatus.confirmed,
    );
    final recent = await block(
      task1,
      at(monday, 13, 45),
      at(monday, 14, 31),
      PlanBlockStatus.confirmed,
    );
    await block(
      task2,
      at(monday, 9),
      at(monday, 10),
      PlanBlockStatus.confirmed,
    );
    final finished = await block(
      task1,
      at(monday, 8),
      at(monday, 9),
      PlanBlockStatus.done,
    );
    expect(await apply(const [], done: {task2}), isTrue);
    expect(await statuses(), {
      missed: 'missed',
      recent: 'confirmed',
      finished: 'done',
    });
  });

  test('지운 블록은 그 논리적 하루가 끝나면 없앤다(오늘 것은 둔다)', () async {
    await block(
      task1,
      at(monday - 1, 9),
      at(monday - 1, 10),
      PlanBlockStatus.dismissed,
    );
    // 하루 경계(04:00) 전 새벽은 전날의 논리적 하루다.
    await block(task1, at(monday, 2), at(monday, 3), PlanBlockStatus.dismissed);
    final today = await block(
      task1,
      at(monday, 9),
      at(monday, 10),
      PlanBlockStatus.dismissed,
    );
    expect(await apply(const []), isTrue);
    expect((await statuses()).keys, [today]);
  });

  test('하루 경계 전 새벽에는 전날(논리적 하루)의 지운 블록을 아직 둔다', () async {
    final lastNight = await block(
      task1,
      at(monday - 1, 23),
      at(monday, 0),
      PlanBlockStatus.dismissed,
    );
    expect(await apply(const [], when: at(monday, 3)), isFalse);
    expect((await statuses()).keys, [lastNight]);
    expect(await apply(const [], when: at(monday, 4)), isTrue);
    expect(await statuses(), isEmpty);
  });

  test('새 제안과 같은 자리의 제안은 id를 두고 근거만 고치며, 나머지는 지우고 새 제안을 넣는다', () async {
    final same = await block(
      task1,
      at(monday, 16),
      at(monday, 17),
      PlanBlockStatus.suggested,
      reason: reason(1),
    );
    final stale = await block(
      task2,
      at(monday, 18),
      at(monday, 19),
      PlanBlockStatus.suggested,
      reason: reason(2),
    );
    final duplicate = await block(
      task1,
      at(monday, 16),
      at(monday, 17),
      PlanBlockStatus.suggested,
      reason: reason(1),
    );
    final changed = await apply([
      BlockDraft(
        taskId: task1,
        startAt: at(monday, 16),
        endAt: at(monday, 17),
        reason: reason(3),
      ),
      BlockDraft(
        taskId: task2,
        startAt: at(monday + 1, 9),
        endAt: at(monday + 1, 10),
        reason: reason(4),
      ),
    ]);
    expect(changed, isTrue);
    final rows = await db.select(db.planBlocks).get();
    expect(rows.map((b) => b.id), isNot(contains(stale)));
    expect(rows.map((b) => b.id), isNot(contains(duplicate)));
    final kept = rows.singleWhere((b) => b.id == same);
    expect(kept.reason!.rank, 3);
    final added = rows.singleWhere((b) => b.taskId == task2);
    expect(added.status, PlanBlockStatus.suggested);
    expect(added.source, BlockSource.auto);
    expect(added.startAt, at(monday + 1, 9));
    expect(added.reason!.rank, 4);
  });

  test('바꿀 것이 없으면 아무것도 쓰지 않아 표 바뀜 알림이 없다', () async {
    await block(
      task1,
      at(monday, 16),
      at(monday, 17),
      PlanBlockStatus.suggested,
      reason: reason(1),
    );
    await block(task1, at(monday, 9), at(monday, 10), PlanBlockStatus.done);
    final updates = <void>[];
    final subscription = db
        .tableUpdates(TableUpdateQuery.onTable(db.planBlocks))
        .listen(updates.add);
    final changed = await apply([
      BlockDraft(
        taskId: task1,
        startAt: at(monday, 16),
        endAt: at(monday, 17),
        reason: reason(1),
      ),
    ]);
    await pumpEventQueue();
    await subscription.cancel();
    expect(changed, isFalse);
    expect(updates, isEmpty);
  });

  test('확정·완료·놓침 블록은 제안 바꿔 끼우기에서 건드리지 않는다', () async {
    final confirmed = await block(
      task1,
      at(monday, 16),
      at(monday, 17),
      PlanBlockStatus.confirmed,
    );
    final missed = await block(
      task1,
      at(monday, 9),
      at(monday, 10),
      PlanBlockStatus.missed,
    );
    expect(await apply(const []), isFalse);
    expect(await statuses(), {confirmed: 'confirmed', missed: 'missed'});
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await PlanApplyRepository(closed).apply(
      suggestions: const [],
      doneTaskIds: const {},
      now: now,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
