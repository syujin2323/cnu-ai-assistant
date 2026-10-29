import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());

  tearDown(() => db.close());

  final at = DateTime(2026, 10, 29, 9, 30);
  final offsetText = RegExp(r'^2026-10-29T09:30:00\.000 [+-]\d\d:\d\d$');

  Future<String?> rawText(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.single as String?;

  Future<int> addCourse() =>
      db.into(db.courses).insert(CoursesCompanion.insert(name: '과목A'));

  Future<void> addLmsItem(int courseId, String remoteKey) => db
      .into(db.lmsItems)
      .insert(
        LmsItemsCompanion.insert(
          remoteKey: remoteKey,
          courseId: courseId,
          courseName: '과목A',
          title: '과제1',
          kind: LmsItemKind.assignment,
          dueTimeUnknown: false,
          firstSeenAt: at,
          lastSeenAt: at,
          missCount: 0,
          contentHash: 'hash1',
        ),
      );

  test('열 때 외래 키 검사를 켠다', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);
  });

  test('R0 표를 모두 만들고 R1 표는 만들지 않는다', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(
      rows.map((row) => row.read<String>('name')),
      unorderedEquals([
        'courses',
        'class_slots',
        'class_exceptions',
        'fixed_blocks',
        'events',
        'tasks',
        'plan_blocks',
        'rules',
        'lms_items',
        'lms_item_changes',
        'briefings',
        'sync_runs',
        'sync_lease',
        'settings',
        'undo_log',
      ]),
    );
  });

  test('행 클래스로 다시 읽고 열거형·JSON·시각을 문서의 형식으로 저장한다', () async {
    final courseId = await addCourse();
    final slotId = await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 4,
            startMin: 1320,
            endMin: 1560,
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.auto,
          ),
        );
    await db
        .into(db.classExceptions)
        .insert(
          ClassExceptionsCompanion.insert(
            date: '2026-10-29',
            classSlotId: slotId,
            kind: ClassExceptionKind.placeChange,
            source: EntrySource.ai,
          ),
        );
    await db
        .into(db.fixedBlocks)
        .insert(
          FixedBlocksCompanion.insert(
            name: '점심',
            weekdays: [1, 2, 3, 4, 5],
            startMin: 720,
            endMin: 780,
            bufferMin: 0,
            kind: FixedBlockKind.meal,
            source: EntrySource.manual,
          ),
        );
    await addLmsItem(courseId, '1:1:assignment:1');
    final taskId = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '과제1',
            kind: TaskKind.assignment,
            dueAt: Value(at),
            dueTimeUnknown: false,
            status: TaskStatus.todo,
            lmsKey: const Value('1:1:assignment:1'),
          ),
        );
    await db
        .into(db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: at,
            endAt: at.add(const Duration(minutes: 90)),
            status: PlanBlockStatus.suggested,
            source: BlockSource.auto,
            reason: Value(
              BlockReason(
                slackMin: 600,
                dueAt: at,
                gapMin: 90,
                rank: 2,
                factor: BlockFactor.nearClass,
              ),
            ),
          ),
        );
    await db
        .into(db.rules)
        .insert(
          RulesCompanion.insert(
            kind: RuleKind.travel,
            params: const RuleParams(
              minutes: 60,
              position: TravelPosition.dayEdges,
            ),
            weekdays: const Value([1, 3]),
            active: true,
            source: EntrySource.ai,
            createdAt: at,
            updatedAt: at,
          ),
        );
    await db
        .into(db.briefings)
        .insert(
          BriefingsCompanion.insert(
            date: '2026-10-29',
            createdAt: at,
            body: '오늘은 수업이 없어요.',
            cardsJson: '[]',
            usedTemplate: true,
          ),
        );
    await db
        .into(db.syncRuns)
        .insert(
          SyncRunsCompanion.insert(
            startedAt: at,
            trigger: SyncTrigger.open,
            scope: SyncScope.detail,
            result: SyncResultKind.reloginRequired,
            changedCount: 0,
            failedCourseIds: Value([courseId]),
            elapsedMs: 120,
          ),
        );
    await db
        .into(db.undoLog)
        .insert(
          UndoLogCompanion.insert(
            id: const Value(1),
            targetTable: 'plan_blocks',
            action: UndoAction.update,
            createdAt: at,
          ),
        );

    final slot = await db.select(db.classSlots).getSingle();
    expect(slot.endMin, greaterThan(slot.startMin));
    expect(slot.campus, Campus.daedeok);

    final exception = await db.select(db.classExceptions).getSingle();
    expect(exception.kind, ClassExceptionKind.placeChange);
    expect(await rawText('SELECT kind FROM class_exceptions'), 'place_change');

    final fixed = await db.select(db.fixedBlocks).getSingle();
    expect(fixed.weekdays, [1, 2, 3, 4, 5]);
    expect(await rawText('SELECT weekdays FROM fixed_blocks'), '[1,2,3,4,5]');

    final task = await db.select(db.tasks).getSingle();
    expect(task.dueAt, at);
    expect(task.lmsKey, '1:1:assignment:1');
    expect(await rawText('SELECT due_at FROM tasks'), matches(offsetText));

    final block = await db.select(db.planBlocks).getSingle();
    expect(block.reason!.slackMin, 600);
    expect(block.reason!.dueAt, at);
    expect(block.reason!.factor, BlockFactor.nearClass);
    final reasonJson = jsonDecode(
      (await rawText('SELECT reason FROM plan_blocks'))!,
    ) as Map<String, Object?>;
    expect(reasonJson['factor'], 'near_class');

    final rule = await db.select(db.rules).getSingle();
    expect(rule.params.minutes, 60);
    expect(rule.params.position, TravelPosition.dayEdges);
    expect(rule.params.startMin, isNull);
    expect(rule.weekdays, [1, 3]);
    expect(
      await rawText('SELECT params FROM rules'),
      '{"minutes":60,"position":"day_edges"}',
    );

    final briefing = await db.select(db.briefings).getSingle();
    expect(briefing.body, '오늘은 수업이 없어요.');
    expect(await rawText('SELECT text FROM briefings'), '오늘은 수업이 없어요.');

    final run = await db.select(db.syncRuns).getSingle();
    expect(run.result, SyncResultKind.reloginRequired);
    expect(run.failedCourseIds, [courseId]);
    expect(await rawText('SELECT result FROM sync_runs'), 'relogin_required');

    final undo = await db.select(db.undoLog).getSingle();
    expect(undo.targetTable, 'plan_blocks');
    expect(await rawText('SELECT table_name FROM undo_log'), 'plan_blocks');
  });

  test('null을 받는 JSON 열은 null 그대로 둔다', () async {
    final taskId = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '개인 할 일',
            kind: TaskKind.personal,
            dueTimeUnknown: false,
            status: TaskStatus.todo,
          ),
        );
    await db
        .into(db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: at,
            endAt: at,
            status: PlanBlockStatus.confirmed,
            source: BlockSource.manual,
          ),
        );

    expect((await db.select(db.planBlocks).getSingle()).reason, isNull);
    expect(await rawText('SELECT reason FROM plan_blocks'), isNull);
  });

  test('외래 키를 어기는 행은 넣을 수 없다', () async {
    await expectLater(
      db
          .into(db.classSlots)
          .insert(
            ClassSlotsCompanion.insert(
              courseId: 999,
              weekday: 1,
              startMin: 540,
              endMin: 600,
              campus: Campus.boun,
              online: true,
              source: SlotSource.manual,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: '과제1',
              kind: TaskKind.assignment,
              dueTimeUnknown: false,
              status: TaskStatus.todo,
              lmsKey: const Value('없는 키'),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('lms_items.remoteKey와 briefings.date는 겹칠 수 없다', () async {
    final courseId = await addCourse();
    await addLmsItem(courseId, '1:1:video:1');
    await expectLater(
      addLmsItem(courseId, '1:1:video:1'),
      throwsA(isA<SqliteException>()),
    );

    BriefingsCompanion briefing() => BriefingsCompanion.insert(
      date: '2026-10-29',
      createdAt: at,
      body: '오늘은 할 일이 없어요.',
      cardsJson: '[]',
      usedTemplate: true,
    );
    await db.into(db.briefings).insert(briefing());
    await expectLater(
      db.into(db.briefings).insert(briefing()),
      throwsA(isA<SqliteException>()),
    );
  });

  test('sync_lease와 undo_log는 id 1의 한 행만 둔다', () async {
    final lease = SyncLeasesCompanion.insert(
      id: const Value(1),
      holder: LeaseHolder.foreground,
      expiresAt: at,
    );
    await db.into(db.syncLeases).insertOnConflictUpdate(lease);
    await db
        .into(db.syncLeases)
        .insertOnConflictUpdate(
          lease.copyWith(holder: const Value(LeaseHolder.background)),
        );
    final leases = await db.select(db.syncLeases).get();
    expect(leases.single.holder, LeaseHolder.background);
    expect(await rawText('SELECT holder FROM sync_lease'), 'background');

    await expectLater(
      db.into(db.syncLeases).insert(lease.copyWith(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db
          .into(db.undoLog)
          .insert(
            UndoLogCompanion.insert(
              id: const Value(2),
              targetTable: 'rules',
              action: UndoAction.delete,
              createdAt: at,
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
