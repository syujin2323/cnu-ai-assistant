// 할 일 저장소 테스트. docs/architecture.md '폰 DB'(동기화·되돌리기), docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
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
  late TaskRepository repository;
  late UndoRepository undo;

  // 닫힌 DB 테스트는 AppDatabase를 한 번에 둘 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = TaskRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);
  const key = '1:1:assignment:1';

  Future<int> addCourse(String name) =>
      db.into(db.courses).insert(CoursesCompanion.insert(name: name));

  Future<void> addLmsItem(int courseId, {bool? submitted}) => db
      .into(db.lmsItems)
      .insert(
        LmsItemsCompanion.insert(
          remoteKey: key,
          courseId: courseId,
          courseName: '자료구조',
          title: '과제1',
          kind: LmsItemKind.assignment,
          dueTimeUnknown: false,
          firstSeenAt: now,
          lastSeenAt: now,
          missCount: 0,
          contentHash: 'h',
          submitted: Value(submitted),
        ),
      );

  Future<int> addTask({
    String title = '할 일',
    TaskKind kind = TaskKind.assignment,
    DateTime? dueAt,
    String? lmsKey,
    int? courseId,
    TaskStatus status = TaskStatus.todo,
  }) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: title,
          kind: kind,
          dueAt: Value(dueAt),
          dueTimeUnknown: false,
          status: status,
          lmsKey: Value(lmsKey),
          courseId: Value(courseId),
        ),
      );

  Future<int> addBlock(
    int taskId,
    DateTime start, {
    PlanBlockStatus status = PlanBlockStatus.confirmed,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
          status: status,
          source: BlockSource.auto,
        ),
      );

  Future<Task?> taskById(int id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Set<int>> blockIds() async => {
    for (final block in await db.select(db.planBlocks).get()) block.id,
  };

  group('목록', () {
    test('숨긴 할 일을 빼고 LMS 원본과 과목을 함께 주며, 마감순(마감 없는 일은 맨 뒤)이다', () async {
      final lmsCourse = await addCourse('자료구조');
      final ownCourse = await addCourse('선형대수');
      await addLmsItem(lmsCourse, submitted: true);
      final noDue = await addTask(title: '언젠가');
      final lms = await addTask(
        title: '과제1',
        dueAt: DateTime(2026, 11, 20, 23, 59),
        lmsKey: key,
      );
      final mine = await addTask(
        title: '퀴즈 공부',
        kind: TaskKind.quiz,
        dueAt: DateTime(2026, 11, 18, 9),
        courseId: ownCourse,
      );
      await addTask(title: '숨김', status: TaskStatus.hidden);

      final entries = _ok(await repository.read());

      expect(entries.map((e) => e.task.id), [mine, lms, noDue]);
      final lmsEntry = entries.firstWhere((e) => e.task.id == lms);
      expect(lmsEntry.lmsItem?.remoteKey, key);
      expect(lmsEntry.course?.name, '자료구조');
      // LMS가 제출을 알려 준 할 일은 끝낸 일이다.
      expect(lmsEntry.isDone, isTrue);
      expect(entries.firstWhere((e) => e.task.id == mine).course?.name, '선형대수');
      expect(entries.firstWhere((e) => e.task.id == noDue).course, isNull);
    });

    test('watch는 할 일·LMS 원본·과목이 바뀌면 다시 읽는다', () async {
      final seen = <List<String>>[];
      final subscription = repository.watch().listen(
        (entries) => seen.add([for (final e in entries) e.task.title]),
      );
      await pumpEventQueue();
      await addTask(title: '새 할 일');
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen.first, isEmpty);
      expect(seen.last, ['새 할 일']);
    });

    test('일정 스트림을 먼저 보고 있어도 할 일이 바뀌면 다시 읽고, 일정 스트림은 일정 표만 본다', () async {
      // 같은 쿼리 문장이면 drift가 스트림을 하나로 묶어 먼저 만든 쪽의 표만 본다(02 홈이 둘을 함께 봄).
      var schedules = 0;
      final schedule = ScheduleRepository(db)
          .watch(start: DateTime(2026, 11, 16), end: DateTime(2026, 11, 17))
          .listen((_) => schedules++);
      final seen = <List<String>>[];
      final tasks = repository.watch().listen(
        (entries) => seen.add([for (final e in entries) e.task.title]),
      );
      await pumpEventQueue();
      final schedulesBefore = schedules;
      await addTask(title: '새 할 일');
      await pumpEventQueue();
      await tasks.cancel();
      await schedule.cancel();

      expect(seen.last, ['새 할 일']);
      expect(schedules, schedulesBefore);
    });
  });

  group('넣기', () {
    test('직접 넣은 할 일을 저장하고, 되돌리면 지운다', () async {
      final courseId = await addCourse('자료구조');
      final id = _ok(
        await repository.add(
          title: '보고서',
          kind: TaskKind.assignment,
          dueAt: DateTime(2026, 11, 20, 18),
          estimateMin: 90,
          courseId: courseId,
          source: EntrySource.ai,
          now: now,
        ),
      );

      final task = (await taskById(id))!;
      expect(task.status, TaskStatus.todo);
      expect(task.source, EntrySource.ai);
      expect(task.courseId, courseId);
      expect(task.estimateMin, 90);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect(await taskById(id), isNull);
    });

    test('빈 제목·자료·0 이하 예상 시간·과목 있는 개인 할 일은 ArgumentError다', () async {
      Future<Result<int>> add({
        String title = '할 일',
        TaskKind kind = TaskKind.assignment,
        int? estimateMin,
        int? courseId,
      }) => repository.add(
        title: title,
        kind: kind,
        estimateMin: estimateMin,
        courseId: courseId,
        source: EntrySource.manual,
        now: now,
      );
      expect(() => add(title: '  '), throwsArgumentError);
      expect(() => add(kind: TaskKind.material), throwsArgumentError);
      expect(() => add(estimateMin: 0), throwsArgumentError);
      final courseId = await addCourse('자료구조');
      expect(
        () => add(kind: TaskKind.personal, courseId: courseId),
        throwsArgumentError,
      );
      expect(await db.select(db.tasks).get(), isEmpty);
    });
  });

  group('끝내기', () {
    test('끝낸 시각을 적고 아직 시작하지 않은 확정 블록만 지우며, 되돌리면 모두 되살린다', () async {
      final id = await addTask();
      final past = await addBlock(id, now.subtract(const Duration(hours: 3)));
      final running = await addBlock(
        id,
        now.subtract(const Duration(minutes: 30)),
      );
      final upcoming = await addBlock(id, now.add(const Duration(hours: 2)));
      final suggested = await addBlock(
        id,
        now.add(const Duration(hours: 4)),
        status: PlanBlockStatus.suggested,
      );

      expect(_ok(await repository.complete(id, now: now)), isTrue);

      final done = (await taskById(id))!;
      expect(done.status, TaskStatus.done);
      expect(done.completedAt, now);
      expect(await blockIds(), {past, running, suggested});

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      final reverted = (await taskById(id))!;
      expect(reverted.status, TaskStatus.todo);
      expect(reverted.completedAt, isNull);
      expect(await blockIds(), {past, running, upcoming, suggested});
    });

    test('되돌릴 때 그사이 동기화가 바꾼 복사 열은 그대로 둔다', () async {
      final courseId = await addCourse('자료구조');
      await addLmsItem(courseId);
      final id = await addTask(title: '과제1', lmsKey: key);
      expect(_ok(await repository.complete(id, now: now)), isTrue);
      // 동기화가 제목을 다시 복사한다.
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
        const TasksCompanion(title: Value('과제1 (수정)')),
      );

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      final task = (await taskById(id))!;
      expect(task.status, TaskStatus.todo);
      expect(task.title, '과제1 (수정)');
    });

    test('끝낸 일·숨긴 일·없는 할 일은 false이고 기록을 남기지 않는다', () async {
      final done = await addTask(status: TaskStatus.done);
      final hidden = await addTask(status: TaskStatus.hidden);
      expect(_ok(await repository.complete(done, now: now)), isFalse);
      expect(_ok(await repository.complete(hidden, now: now)), isFalse);
      expect(_ok(await repository.complete(999, now: now)), isFalse);
      expect(await db.select(db.undoLog).getSingleOrNull(), isNull);
    });

    test('다시 남은 일로 돌리면 끝낸 시각을 지우고, 되돌리면 끝낸 상태로 돌아간다', () async {
      final id = await addTask();
      expect(_ok(await repository.complete(id, now: now)), isTrue);
      final later = now.add(const Duration(minutes: 1));
      expect(_ok(await repository.reopen(id, now: later)), isTrue);
      final reopened = (await taskById(id))!;
      expect(reopened.status, TaskStatus.todo);
      expect(reopened.completedAt, isNull);
      expect(_ok(await repository.reopen(id, now: later)), isFalse);

      expect(_ok(await undo.undoLast(now: later)), isTrue);
      final task = (await taskById(id))!;
      expect(task.status, TaskStatus.done);
      expect(task.completedAt, now);
    });
  });

  group("'얼마나 걸렸어요?'", () {
    test('걸린 시간을 적고 되돌리면 지우며, 0 이하는 ArgumentError다', () async {
      final id = await addTask(status: TaskStatus.done);
      expect(_ok(await repository.setActualMin(id, 75, now: now)), isTrue);
      expect((await taskById(id))!.actualMin, 75);
      expect(_ok(await repository.setActualMin(999, 30, now: now)), isFalse);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await taskById(id))!.actualMin, isNull);
      expect(
        () => repository.setActualMin(id, 0, now: now),
        throwsArgumentError,
      );
    });
  });

  group('지우기', () {
    test('LMS 할 일은 숨기고 아직 시작하지 않은 확정 블록만 지우며, 되돌리면 되살린다', () async {
      final courseId = await addCourse('자료구조');
      await addLmsItem(courseId);
      final id = await addTask(lmsKey: key);
      final past = await addBlock(id, now.subtract(const Duration(hours: 3)));
      final upcoming = await addBlock(id, now.add(const Duration(hours: 2)));

      expect(_ok(await repository.remove(id, now: now)), isTrue);
      expect((await taskById(id))!.status, TaskStatus.hidden);
      expect(await blockIds(), {past});
      expect(_ok(await repository.remove(id, now: now)), isFalse);

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await taskById(id))!.status, TaskStatus.todo);
      expect(await blockIds(), {past, upcoming});
    });

    test('직접 넣은 할 일은 그 블록과 함께 지우고, 되돌리면 할 일과 블록을 되살린다', () async {
      final id = await addTask(title: '보고서');
      final other = await addTask(title: '다른 일');
      final past = await addBlock(id, now.subtract(const Duration(hours: 3)));
      final upcoming = await addBlock(id, now.add(const Duration(hours: 2)));
      final keep = await addBlock(other, now.add(const Duration(hours: 5)));

      expect(_ok(await repository.remove(id, now: now)), isTrue);
      expect(await taskById(id), isNull);
      expect(await blockIds(), {keep});

      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await taskById(id))!.title, '보고서');
      expect(await blockIds(), {past, upcoming, keep});
    });
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await TaskRepository(closed).complete(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
