import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ScheduleRepository repository;

  // 닫힌 DB 테스트는 AppDatabase를 한 번에 둘 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = ScheduleRepository(db);
  });

  tearDown(() => db.close());

  // 2026-10-29(목) 하루 경계 04:00의 논리적 하루.
  final start = DateTime(2026, 10, 29, 4);
  final end = DateTime(2026, 10, 30, 4);

  Future<int> addCourse() =>
      db.into(db.courses).insert(CoursesCompanion.insert(name: '과목A'));

  Future<int> addSlot(int courseId) => db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: 4,
          startMin: 540,
          endMin: 615,
          online: false,
          source: SlotSource.manual,
        ),
      );

  Future<int> addException(int slotId, String date) => db
      .into(db.classExceptions)
      .insert(
        ClassExceptionsCompanion.insert(
          date: date,
          classSlotId: slotId,
          kind: ClassExceptionKind.cancelled,
          source: EntrySource.manual,
        ),
      );

  Future<int> addEvent(DateTime from, DateTime to) => db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '일정',
          startAt: from,
          endAt: to,
          allDay: false,
          source: EventSource.manual,
        ),
      );

  Future<int> addTask() => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );

  Future<int> addBlock(
    int taskId,
    DateTime from,
    DateTime to, {
    PlanBlockStatus status = PlanBlockStatus.confirmed,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: from,
          endAt: to,
          status: status,
          source: BlockSource.auto,
        ),
      );

  Future<Schedule> readOk() async {
    final result = await repository.read(start: start, end: end);
    return switch (result) {
      Ok(:final value) => value,
      Err(:final error) => fail('$error'),
    };
  }

  test('수업 칸과 고정 일정은 모두 읽는다', () async {
    final courseId = await addCourse();
    final slotId = await addSlot(courseId);
    final fixedId = await db
        .into(db.fixedBlocks)
        .insert(
          FixedBlocksCompanion.insert(
            name: '알바',
            weekdays: [6],
            startMin: 840,
            endMin: 1020,
            bufferMin: 0,
            kind: FixedBlockKind.work,
            source: EntrySource.manual,
          ),
        );

    final schedule = await readOk();

    expect(schedule.classSlots.map((s) => s.id), [slotId]);
    expect(schedule.fixedBlocks.map((b) => b.id), [fixedId]);
  });

  test('사용자가 뺀(숨긴) 불러온 수업은 읽지 않는다', () async {
    final courseId = await addCourse();
    final shown = await addSlot(courseId);
    final hidden = await addSlot(courseId);
    await (db.update(db.classSlots)..where((t) => t.id.equals(hidden))).write(
      const ClassSlotsCompanion(hidden: Value(true)),
    );

    final schedule = await readOk();

    expect(schedule.classSlots.map((s) => s.id), [shown]);
  });

  test('수업 예외는 시작 전날부터 끝 날짜까지만 읽는다', () async {
    final slotId = await addSlot(await addCourse());
    await addException(slotId, '2026-10-27');
    final dayBefore = await addException(slotId, '2026-10-28');
    final today = await addException(slotId, '2026-10-29');
    final endDay = await addException(slotId, '2026-10-30');
    await addException(slotId, '2026-10-31');

    final schedule = await readOk();

    expect(schedule.classExceptions.map((e) => e.id), [
      dayBefore,
      today,
      endDay,
    ]);
  });

  test('일정과 블록은 범위와 겹치는 것만 읽고, 끝이 시작에 닿거나 시작이 끝에 닿으면 뺀다', () async {
    final before = await addEvent(
      DateTime(2026, 10, 29, 2),
      DateTime(2026, 10, 29, 4),
    );
    final across = await addEvent(
      DateTime(2026, 10, 29, 3),
      DateTime(2026, 10, 29, 5),
    );
    final inside = await addEvent(
      DateTime(2026, 10, 29, 14),
      DateTime(2026, 10, 29, 15),
    );
    final lateNight = await addEvent(
      DateTime(2026, 10, 30, 1),
      DateTime(2026, 10, 30, 2),
    );
    final after = await addEvent(
      DateTime(2026, 10, 30, 4),
      DateTime(2026, 10, 30, 5),
    );
    final taskId = await addTask();
    final suggested = await addBlock(
      taskId,
      DateTime(2026, 10, 29, 20),
      DateTime(2026, 10, 29, 21),
      status: PlanBlockStatus.suggested,
    );
    final dismissed = await addBlock(
      taskId,
      DateTime(2026, 10, 29, 22),
      DateTime(2026, 10, 29, 23),
      status: PlanBlockStatus.dismissed,
    );
    await addBlock(
      taskId,
      DateTime(2026, 10, 28, 20),
      DateTime(2026, 10, 28, 21),
    );

    final schedule = await readOk();

    expect(schedule.events.map((e) => e.id), [across, inside, lateNight]);
    expect(schedule.events.map((e) => e.id), isNot(contains(before)));
    expect(schedule.events.map((e) => e.id), isNot(contains(after)));
    // 모든 상태의 블록을 읽는다(빈 시간 계산이 확정·완료만 뺌).
    expect(schedule.planBlocks.map((b) => b.id), [suggested, dismissed]);
  });

  test('한국 시각 자정 근처도 그 순간으로 견준다(기기 시간대와 무관)', () async {
    // 한국 시각 04:30은 UTC로 전날 19:30이다. 날짜 문자열로 견주면 빠진다.
    final early = await addEvent(
      DateTime(2026, 10, 29, 4, 30),
      DateTime(2026, 10, 29, 5),
    );

    final schedule = await readOk();

    expect(schedule.events.map((e) => e.id), [early]);
  });

  test('watch는 지금 읽고, 다섯 표 가운데 하나가 바뀌면 다시 읽는다', () async {
    final seen = <List<int>>[];
    final subscription = repository
        .watch(start: start, end: end)
        .listen(
          (schedule) => seen.add(schedule.events.map((e) => e.id).toList()),
        );
    await pumpEventQueue();
    final id = await addEvent(
      DateTime(2026, 10, 29, 10),
      DateTime(2026, 10, 29, 11),
    );
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first, isEmpty);
    expect(seen.last, [id]);
  });

  test('끝이 시작보다 늦지 않으면 ArgumentError다', () {
    expect(
      () => repository.read(start: start, end: start),
      throwsArgumentError,
    );
    expect(() => repository.watch(start: end, end: start), throwsArgumentError);
  });

  test('닫힌 DB에서 읽으면 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();

    final result = await ScheduleRepository(closed)
        .read(start: start, end: end);

    expect(result, isA<Err<Schedule>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
