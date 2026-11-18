// 할 일 블록 저장소 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 5단계, docs/screens.md
// '제안과 확정'·'옮기기 시트'·'빈 시간에 놓기 시트'·'02 홈'(피드백 카드).

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_block_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  late AppDatabase db;
  late PlanBlockRepository repository;
  late UndoRepository undo;

  // 닫힌 DB 테스트는 AppDatabase를 한 번에 둘 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = PlanBlockRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);
  final reason = BlockReason(
    slackMin: 120,
    dueAt: DateTime(2026, 11, 18, 23, 59),
    gapMin: 90,
    rank: 1,
    factor: BlockFactor.fit,
  );

  Future<int> addTask({int? spentMin}) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          spentMin: Value(spentMin),
        ),
      );

  Future<int> addBlock(
    int taskId,
    DateTime start, {
    int minutes = 60,
    PlanBlockStatus status = PlanBlockStatus.suggested,
    BlockSource source = BlockSource.auto,
    BlockReason? why,
    bool fromBriefing = false,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: start.add(Duration(minutes: minutes)),
          status: status,
          source: source,
          reason: Value(why),
          fromBriefing: Value(fromBriefing),
        ),
      );

  Future<PlanBlock?> block(int id) => (db.select(
    db.planBlocks,
  )..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<Task> task(int id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();

  group('확정', () {
    test('제안 블록만 근거를 그대로 두고 확정하며, 되돌리면 제안으로 돌아간다', () async {
      final taskId = await addTask();
      final a = await addBlock(
        taskId,
        now.add(const Duration(hours: 1)),
        why: reason,
      );
      final b = await addBlock(taskId, now.add(const Duration(hours: 3)));
      final done = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 3)),
        status: PlanBlockStatus.done,
      );

      expect(_ok(await repository.confirm([a, b, done], now: now)), isTrue);
      final confirmed = (await block(a))!;
      expect(confirmed.status, PlanBlockStatus.confirmed);
      expect(confirmed.source, BlockSource.auto);
      expect(confirmed.reason?.slackMin, 120);
      expect((await block(b))!.status, PlanBlockStatus.confirmed);
      expect((await block(done))!.status, PlanBlockStatus.done);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await block(a))!.status, PlanBlockStatus.suggested);
      expect((await block(b))!.status, PlanBlockStatus.suggested);
    });

    test('확정할 제안이 없으면 false이고 이전 되돌리기 기록을 건드리지 않는다', () async {
      final taskId = await addTask();
      final a = await addBlock(taskId, now.add(const Duration(hours: 1)));
      expect(_ok(await repository.dismiss(a, now: now)), isTrue);
      expect(_ok(await repository.confirm([a, 999], now: now)), isFalse);
      // 지우기 기록이 남아 있어 되돌릴 수 있다.
      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await block(a))!.status, PlanBlockStatus.suggested);
    });
  });

  group('직접 놓기와 옮기기', () {
    test('직접 놓은 블록은 근거 없는 확정이고, 되돌리면 지운다', () async {
      final taskId = await addTask();
      final start = now.add(const Duration(hours: 2));
      final id = _ok(
        await repository.place(
          taskId: taskId,
          start: start,
          end: start.add(const Duration(minutes: 45)),
          now: now,
        ),
      )!;
      final placed = (await block(id))!;
      expect(placed.status, PlanBlockStatus.confirmed);
      expect(placed.source, BlockSource.manual);
      expect(placed.reason, isNull);
      expect(placed.fromBriefing, isFalse);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect(await block(id), isNull);
      expect(
        _ok(
          await repository.place(
            taskId: 999,
            start: start,
            end: start.add(const Duration(minutes: 45)),
            now: now,
          ),
        ),
        isNull,
      );
      expect(
        () => repository.place(
          taskId: taskId,
          start: start,
          end: start,
          now: now,
        ),
        throwsArgumentError,
      );
    });

    test('제안을 옮기면 원래 자리는 지운 자리로 남기고 새 확정 블록을 만들며, 되돌리면 둘 다 돌아간다', () async {
      final taskId = await addTask();
      final original = await addBlock(
        taskId,
        now.add(const Duration(hours: 1)),
        why: reason,
      );
      final to = now.add(const Duration(hours: 5));

      final moved = _ok(
        await repository.move(
          original,
          start: to,
          end: to.add(const Duration(hours: 1)),
          now: now,
        ),
      )!;

      expect(moved, isNot(original));
      expect((await block(original))!.status, PlanBlockStatus.dismissed);
      final created = (await block(moved))!;
      expect(created.status, PlanBlockStatus.confirmed);
      expect(created.source, BlockSource.manual);
      expect(created.startAt, to);
      expect(created.reason, isNull);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await block(original))!.status, PlanBlockStatus.suggested);
      expect(await block(moved), isNull);
    });

    test('확정 블록을 옮기면 그 블록의 시각을 바꾸고 직접 정한 자리로 두며, 되돌리면 원래 자리로 간다', () async {
      final taskId = await addTask();
      final from = now.add(const Duration(hours: 1));
      final id = await addBlock(
        taskId,
        from,
        status: PlanBlockStatus.confirmed,
        why: reason,
      );
      final to = now.add(const Duration(hours: 6));

      expect(
        _ok(
          await repository.move(
            id,
            start: to,
            end: to.add(const Duration(minutes: 30)),
            now: now,
          ),
        ),
        id,
      );
      final moved = (await block(id))!;
      expect(moved.startAt, to);
      expect(moved.endAt, to.add(const Duration(minutes: 30)));
      expect(moved.source, BlockSource.manual);
      expect(moved.reason, isNull);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      final back = (await block(id))!;
      expect(back.startAt, from);
      expect(back.source, BlockSource.auto);
      expect(back.reason?.rank, 1);
    });

    test('완료·놓침·지운 블록은 옮기지 않는다', () async {
      final taskId = await addTask();
      final to = now.add(const Duration(hours: 6));
      for (final status in [
        PlanBlockStatus.done,
        PlanBlockStatus.missed,
        PlanBlockStatus.dismissed,
      ]) {
        final id = await addBlock(taskId, now, status: status);
        expect(
          _ok(
            await repository.move(
              id,
              start: to,
              end: to.add(const Duration(hours: 1)),
              now: now,
            ),
          ),
          isNull,
          reason: '$status',
        );
      }
    });
  });

  test('제안·확정 블록만 지우고, 되돌리면 원래 상태로 돌아간다', () async {
    final taskId = await addTask();
    final confirmed = await addBlock(
      taskId,
      now.add(const Duration(hours: 1)),
      status: PlanBlockStatus.confirmed,
    );
    final done = await addBlock(taskId, now, status: PlanBlockStatus.done);

    expect(_ok(await repository.dismiss(confirmed, now: now)), isTrue);
    expect((await block(confirmed))!.status, PlanBlockStatus.dismissed);
    expect(_ok(await repository.dismiss(done, now: now)), isFalse);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await block(confirmed))!.status, PlanBlockStatus.confirmed);
  });

  group('완료', () {
    test('완료하면 블록 길이를 한 만큼에 더하고, 되돌리면 상태와 한 만큼이 함께 돌아간다', () async {
      final taskId = await addTask(spentMin: 30);
      final id = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 2)),
        minutes: 50,
        status: PlanBlockStatus.confirmed,
      );

      expect(_ok(await repository.complete(id, now: now)), isTrue);
      expect((await block(id))!.status, PlanBlockStatus.done);
      expect((await task(taskId)).spentMin, 80);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await block(id))!.status, PlanBlockStatus.confirmed);
      expect((await task(taskId)).spentMin, 30);
    });

    test('놓침 블록도 완료하고, 한 만큼이 없던 할 일은 블록 길이가 된다', () async {
      final taskId = await addTask();
      final id = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 3)),
        minutes: 40,
        status: PlanBlockStatus.missed,
      );
      expect(_ok(await repository.complete(id, now: now)), isTrue);
      expect((await task(taskId)).spentMin, 40);
      expect(_ok(await repository.complete(id, now: now)), isFalse);
    });

    test('제안 블록도 근거 시트에서 바로 완료하고, 지운 블록은 완료하지 않는다', () async {
      final taskId = await addTask();
      final suggested = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 1)),
        minutes: 30,
        status: PlanBlockStatus.suggested,
      );
      expect(_ok(await repository.complete(suggested, now: now)), isTrue);
      expect((await block(suggested))!.status, PlanBlockStatus.done);
      expect((await task(taskId)).spentMin, 30);

      final dismissed = await addBlock(
        taskId,
        now.add(const Duration(hours: 1)),
        minutes: 30,
        status: PlanBlockStatus.dismissed,
      );
      expect(_ok(await repository.complete(dismissed, now: now)), isFalse);
    });

    test('완료를 끄면 확정으로 돌리고 한 만큼에서 빼되 0 아래로 내리지 않는다', () async {
      final taskId = await addTask(spentMin: 20);
      final id = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 2)),
        minutes: 60,
        status: PlanBlockStatus.done,
      );
      expect(_ok(await repository.uncomplete(id, now: now)), isTrue);
      expect((await block(id))!.status, PlanBlockStatus.confirmed);
      expect((await task(taskId)).spentMin, 0);
      expect(_ok(await repository.uncomplete(id, now: now)), isFalse);
    });
  });

  group('피드백 답', () {
    test("'했어요'면 완료와 한 만큼, '못 했어요'면 놓침이고 둘 다 답한 시각을 적는다", () async {
      final taskId = await addTask();
      final yes = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 3)),
        minutes: 30,
        status: PlanBlockStatus.missed,
      );
      final no = await addBlock(
        taskId,
        now.subtract(const Duration(hours: 1)),
        status: PlanBlockStatus.confirmed,
      );

      expect(_ok(await repository.answer(yes, did: true, now: now)), isTrue);
      expect(_ok(await repository.answer(no, did: false, now: now)), isTrue);

      final answeredYes = (await block(yes))!;
      expect(answeredYes.status, PlanBlockStatus.done);
      expect(answeredYes.answeredAt, now);
      final answeredNo = (await block(no))!;
      expect(answeredNo.status, PlanBlockStatus.missed);
      expect(answeredNo.answeredAt, now);
      expect((await task(taskId)).spentMin, 30);

      // 마지막 답('못 했어요')만 되돌린다.
      expect(_ok(await undo.undoLast(now: now)), isTrue);
      final reverted = (await block(no))!;
      expect(reverted.status, PlanBlockStatus.confirmed);
      expect(reverted.answeredAt, isNull);
      expect(_ok(await repository.answer(yes, did: false, now: now)), isFalse);
    });
  });

  group('브리핑 확정', () {
    test('오늘 시작 전인 엔진 자리 확정·브리핑 확정 블록만 새 선택으로 바꾸고, 되돌리면 원래대로 돌아간다', () async {
      final taskId = await addTask();
      final dayStart = DateTime(2026, 11, 15, 4);
      final dayEnd = DateTime(2026, 11, 16, 4);
      final startedAuto = await addBlock(
        taskId,
        now.subtract(const Duration(minutes: 30)),
        status: PlanBlockStatus.confirmed,
      );
      final laterAuto = await addBlock(
        taskId,
        now.add(const Duration(hours: 2)),
        status: PlanBlockStatus.confirmed,
      );
      final laterBriefing = await addBlock(
        taskId,
        now.add(const Duration(hours: 4)),
        status: PlanBlockStatus.confirmed,
        source: BlockSource.manual,
        fromBriefing: true,
      );
      final laterManual = await addBlock(
        taskId,
        now.add(const Duration(hours: 6)),
        status: PlanBlockStatus.confirmed,
        source: BlockSource.manual,
      );
      final tomorrowAuto = await addBlock(
        taskId,
        DateTime(2026, 11, 16, 10),
        status: PlanBlockStatus.confirmed,
      );
      final suggestion = await addBlock(
        taskId,
        now.add(const Duration(hours: 3)),
      );

      final ids = _ok(
        await repository.confirmFromBriefing(
          dayStart: dayStart,
          dayEnd: dayEnd,
          drafts: [
            BlockDraft(
              taskId: taskId,
              startAt: now.add(const Duration(hours: 1)),
              endAt: now.add(const Duration(hours: 2)),
              reason: reason,
            ),
          ],
          now: now,
        ),
      );

      final remaining = {
        for (final b in await db.select(db.planBlocks).get()) b.id,
      };
      expect(remaining, {
        startedAuto,
        laterManual,
        tomorrowAuto,
        suggestion,
        ...ids,
      });
      final created = (await block(ids.single))!;
      expect(created.status, PlanBlockStatus.confirmed);
      expect(created.fromBriefing, isTrue);
      expect(created.source, BlockSource.auto);
      expect(created.reason?.gapMin, 90);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect(
        {for (final b in await db.select(db.planBlocks).get()) b.id},
        {
          startedAuto,
          laterAuto,
          laterBriefing,
          laterManual,
          tomorrowAuto,
          suggestion,
        },
      );
    });
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await PlanBlockRepository(closed).dismiss(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
