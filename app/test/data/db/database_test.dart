import 'dart:convert';
import 'dart:io';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/demo_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart' show NativeDatabase, SqliteException;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart' show TestClock;

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
          // 브리핑 내용은 저장하지 않고 본 것만 기록한다.
          BriefingsCompanion.insert(
            date: '2026-10-29',
            createdAt: at,
            openedAt: Value(at),
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
    expect(briefing.openedAt, at);
    expect(briefing.confirmedAt, isNull);
    expect(
      await rawText('SELECT opened_at FROM briefings'),
      matches(offsetText),
    );

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

    BriefingsCompanion briefing() =>
        BriefingsCompanion.insert(date: '2026-10-29', createdAt: at);
    await db.into(db.briefings).insert(briefing());
    await expectLater(
      db.into(db.briefings).insert(briefing()),
      throwsA(isA<SqliteException>()),
    );
  });

  test('sync_lease와 undo_log는 id를 넣지 않아도 id 1의 한 행만 둔다', () async {
    SyncLeasesCompanion lease(LeaseHolder holder) => SyncLeasesCompanion.insert(
      holder: holder,
      token: 'token-${holder.name}',
      expiresAt: at,
    );
    await db
        .into(db.syncLeases)
        .insertOnConflictUpdate(lease(LeaseHolder.foreground));
    await db
        .into(db.syncLeases)
        .insertOnConflictUpdate(lease(LeaseHolder.background));
    final leases = await db.select(db.syncLeases).get();
    expect(leases.single.id, 1);
    expect(leases.single.holder, LeaseHolder.background);
    expect(leases.single.token, 'token-background');
    expect(await rawText('SELECT holder FROM sync_lease'), 'background');

    // 지운 뒤 다시 넣어도 id는 1이다(자동 증가였을 때는 2가 되어 CHECK에 걸렸다).
    await db.delete(db.syncLeases).go();
    await db.into(db.syncLeases).insert(lease(LeaseHolder.foreground));
    expect((await db.select(db.syncLeases).getSingle()).id, 1);
    // 두 번째 행은 기본 키(id 1)가 겹치고, 다른 id는 CHECK가 막는다.
    await expectLater(
      db.into(db.syncLeases).insert(lease(LeaseHolder.background)),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db
          .into(db.syncLeases)
          .insert(lease(LeaseHolder.background).copyWith(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );

    UndoLogCompanion undo(UndoAction action) => UndoLogCompanion.insert(
      targetTable: 'rules',
      action: action,
      createdAt: at,
    );
    await db.into(db.undoLog).insertOnConflictUpdate(undo(UndoAction.insert));
    await db.into(db.undoLog).insertOnConflictUpdate(undo(UndoAction.delete));
    final undos = await db.select(db.undoLog).get();
    expect(undos.single.id, 1);
    expect(undos.single.action, UndoAction.delete);
    await expectLater(
      db
          .into(db.undoLog)
          .insert(undo(UndoAction.update).copyWith(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );
  });

  test('같은 LMS 항목의 할 일과 같은 학기·LMS 과목 ID의 과목은 두 행이 될 수 없다', () async {
    final courseId = await addCourse();
    await addLmsItem(courseId, '1:1:assignment:1');
    TasksCompanion task(String? lmsKey) => TasksCompanion.insert(
      title: '과제1',
      kind: TaskKind.assignment,
      dueTimeUnknown: false,
      status: TaskStatus.todo,
      lmsKey: Value(lmsKey),
    );
    await db.into(db.tasks).insert(task('1:1:assignment:1'));
    await expectLater(
      db.into(db.tasks).insert(task('1:1:assignment:1')),
      throwsA(isA<SqliteException>()),
    );
    // 직접 만든 할 일(lmsKey null)은 여럿이어도 된다.
    await db.into(db.tasks).insert(task(null));
    await db.into(db.tasks).insert(task(null));

    CoursesCompanion course(String? remoteId, String? semester) =>
        CoursesCompanion.insert(
          name: '과목B',
          remoteId: Value(remoteId),
          semester: Value(semester),
        );
    await db.into(db.courses).insert(course('c1', '2026-2'));
    await expectLater(
      db.into(db.courses).insert(course('c1', '2026-2')),
      throwsA(isA<SqliteException>()),
    );
    // 학기가 다르거나 직접 만든 과목(remoteId null)이면 된다.
    await db.into(db.courses).insert(course('c1', '2026-1'));
    await db.into(db.courses).insert(course(null, null));
    await db.into(db.courses).insert(course(null, null));
  });

  test(
    '자식 키로 찾는 인덱스를 둔다(plan_blocks의 할 일, class_exceptions의 수업 칸·날짜)',
    () async {
      Future<List<String>> columnsOf(String index) async => [
        for (final row
            in await db.customSelect('PRAGMA index_info($index)').get())
          row.read<String>('name'),
      ];
      expect(await columnsOf('plan_blocks_task_id'), ['task_id']);
      expect(await columnsOf('class_exceptions_slot_date'), [
        'class_slot_id',
        'date',
      ]);
    },
  );

  test('수업 칸은 불러온 원래 요일·시각·강의실과 고친 표시를 두고, 직접 넣은 수업은 비어 있다', () async {
    final courseId = await addCourse();
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 1,
            startMin: 540,
            endMin: 600,
            campus: Campus.boun,
            online: false,
            source: SlotSource.manual,
          ),
        );
    // 불러온 수업에서 사용자가 장소와 실시간 온라인을 고쳤다.
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 2,
            startMin: 600,
            endMin: 690,
            place: const Value('강의실B'),
            campus: Campus.daedeok,
            online: true,
            source: SlotSource.auto,
            importedWeekday: const Value(2),
            importedStartMin: const Value(600),
            importedEndMin: const Value(690),
            importedPlace: const Value('강의실A'),
            placeEdited: const Value(true),
            onlineEdited: const Value(true),
          ),
        );

    final slots = await (db.select(
      db.classSlots,
    )..orderBy([(slot) => OrderingTerm(expression: slot.id)])).get();
    final manual = slots.first;
    expect(manual.importedWeekday, isNull);
    expect(manual.importedStartMin, isNull);
    expect(manual.importedEndMin, isNull);
    expect(manual.importedPlace, isNull);
    expect(manual.placeEdited, isFalse);
    expect(manual.onlineEdited, isFalse);
    final imported = slots.last;
    expect(imported.importedWeekday, 2);
    expect(imported.importedStartMin, 600);
    expect(imported.importedEndMin, 690);
    expect(imported.importedPlace, '강의실A');
    expect(imported.place, '강의실B');
    expect(imported.placeEdited, isTrue);
    expect(imported.onlineEdited, isTrue);
  });

  group('CHECK', () {
    /// 확장 결과 코드 275: SQLITE_CONSTRAINT_CHECK.
    final checkFailed = throwsA(
      isA<SqliteException>().having(
        (error) => error.extendedResultCode,
        'extendedResultCode',
        275,
      ),
    );

    /// 넣을 수 있으면 true, CHECK에 걸리면 false.
    Future<bool> accepted(Future<Object?> Function() insert) async {
      try {
        await insert();
        return true;
      } on SqliteException catch (error) {
        expect(error.extendedResultCode, 275, reason: '$error');
        return false;
      }
    }

    test(
      '수업 칸은 요일 1–7, 시작 0–1439, 끝이 시작보다 늦고 하루보다 짧아야 하고 Dart 검사와 같다',
      () async {
        final courseId = await addCourse();
        // (요일, 시작, 끝). 22:00–02:00은 1320–1560으로 적는다.
        const samples = [
          (1, 540, 600),
          (7, 540, 600),
          (0, 540, 600),
          (8, 540, 600),
          (3, 0, 1),
          (3, 1439, 2878),
          (3, 1320, 1560),
          (3, -1, 60),
          (3, 1440, 1500),
          (3, 600, 600),
          (3, 600, 500),
          (3, 600, 2040),
          (3, 600, 2039),
        ];
        for (final (weekday, startMin, endMin) in samples) {
          final dart = checkClassSlot(
            weekday: weekday,
            startMin: startMin,
            endMin: endMin,
          ).isEmpty;
          final db0 = await accepted(
            () => db
                .into(db.classSlots)
                .insert(
                  ClassSlotsCompanion.insert(
                    courseId: courseId,
                    weekday: weekday,
                    startMin: startMin,
                    endMin: endMin,
                    campus: Campus.boun,
                    online: false,
                    source: SlotSource.manual,
                  ),
                ),
          );
          expect(db0, dart, reason: '($weekday, $startMin, $endMin)');
        }
      },
    );

    test('수업 칸의 불러온 원래 요일·시각도 같은 규칙이고, 셋은 함께 있거나 함께 없다', () async {
      final courseId = await addCourse();
      Future<int> slot({int? weekday, int? startMin, int? endMin}) => db
          .into(db.classSlots)
          .insert(
            ClassSlotsCompanion.insert(
              courseId: courseId,
              weekday: 1,
              startMin: 540,
              endMin: 600,
              campus: Campus.boun,
              online: false,
              source: SlotSource.auto,
              importedWeekday: Value(weekday),
              importedStartMin: Value(startMin),
              importedEndMin: Value(endMin),
            ),
          );
      await slot(weekday: 7, startMin: 1320, endMin: 1560);
      await slot();
      await expectLater(
        slot(weekday: 8, startMin: 540, endMin: 600),
        checkFailed,
      );
      await expectLater(
        slot(weekday: 1, startMin: 1440, endMin: 1500),
        checkFailed,
      );
      await expectLater(
        slot(weekday: 1, startMin: 600, endMin: 600),
        checkFailed,
      );
      await expectLater(
        slot(weekday: 1, startMin: 600, endMin: 2040),
        checkFailed,
      );
      await expectLater(slot(weekday: 1), checkFailed);
      await expectLater(slot(weekday: 1, startMin: 540), checkFailed);
    });

    test('고정 일정은 시작 0–1439, 끝이 시작보다 늦고 하루보다 짧고, 앞뒤 여유가 0 이상이어야 하고 Dart 검사가 이를 먼저 본다', () async {
      // (요일들, 시작, 끝, 앞뒤 여유, DB가 받는지). 앞뒤 여유의 위 끝(60)과 요일 값은 DB에 걸지 않고
      // Dart 검사만 본다.
      const samples = [
        ([1, 2, 3, 4, 5], 720, 780, 0, true),
        ([6, 7], 1320, 1560, 60, true),
        ([1], 720, 780, 61, true),
        (<int>[], 720, 780, 10, true),
        ([0, 8], 720, 780, 10, true),
        ([1, 1], 720, 780, 10, true),
        ([1], 720, 780, -1, false),
        ([1], 720, 720, 10, false),
        ([1], 720, 2160, 10, false),
        ([1], 1440, 1500, 10, false),
      ];
      for (final (weekdays, startMin, endMin, bufferMin, dbAccepts)
          in samples) {
        final dart = checkFixedBlock(
          weekdays: weekdays,
          startMin: startMin,
          endMin: endMin,
          bufferMin: bufferMin,
        ).isEmpty;
        final db0 = await accepted(
          () => db
              .into(db.fixedBlocks)
              .insert(
                FixedBlocksCompanion.insert(
                  name: '알바',
                  weekdays: weekdays,
                  startMin: startMin,
                  endMin: endMin,
                  bufferMin: bufferMin,
                  kind: FixedBlockKind.work,
                  source: EntrySource.manual,
                ),
              ),
        );
        final reason = '($weekdays, $startMin, $endMin, $bufferMin)';
        expect(db0, dbAccepts, reason: reason);
        // Dart 검사는 DB보다 넓게 본다: DB가 거절하는 값은 Dart도 거절한다.
        if (!dbAccepts) expect(dart, isFalse, reason: reason);
      }
      // 요일 목록은 JSON 배열이어야 한다(변환기를 거치지 않은 값).
      for (final weekdays in ['not json', '{"1": true}']) {
        await expectLater(
          db.customStatement(
            'INSERT INTO fixed_blocks (name, weekdays, start_min, end_min, '
            "buffer_min, kind, source) VALUES ('x', ?, 720, 780, 0, 'work', "
            "'manual')",
            [weekdays],
          ),
          checkFailed,
          reason: weekdays,
        );
      }
    });

    test('일정·할 일 블록은 끝이 시작보다 이를 수 없다(같으면 된다)', () async {
      final courseId = await addCourse();
      await addLmsItem(courseId, '1:1:quiz:1');
      final taskId = await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: '퀴즈',
              kind: TaskKind.quiz,
              dueTimeUnknown: false,
              status: TaskStatus.todo,
            ),
          );
      Future<int> event(DateTime endAt) => db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: '회의',
              startAt: at,
              endAt: endAt,
              allDay: false,
              source: EventSource.manual,
            ),
          );
      Future<int> block(DateTime endAt) => db
          .into(db.planBlocks)
          .insert(
            PlanBlocksCompanion.insert(
              taskId: taskId,
              startAt: at,
              endAt: endAt,
              status: PlanBlockStatus.confirmed,
              source: BlockSource.manual,
            ),
          );
      final earlier = at.subtract(const Duration(minutes: 1));
      await event(at);
      await block(at);
      await expectLater(event(earlier), checkFailed);
      await expectLater(block(earlier), checkFailed);
    });

    test('LMS 항목의 연속 미발견 횟수는 0 이상이다', () async {
      final courseId = await addCourse();
      await expectLater(
        db
            .into(db.lmsItems)
            .insert(
              LmsItemsCompanion.insert(
                remoteKey: '1:1:video:9',
                courseId: courseId,
                courseName: '과목A',
                title: '영상',
                kind: LmsItemKind.video,
                dueTimeUnknown: false,
                firstSeenAt: at,
                lastSeenAt: at,
                missCount: -1,
                contentHash: 'hash9',
              ),
            ),
        checkFailed,
      );
    });

    test('저장소가 감싼 쓰기가 CHECK에 걸리면 Err(StorageError, 코드 275)다', () async {
      final courseId = await addCourse();
      final result = await guardStorage(
        'classSlots.insert',
        () => db
            .into(db.classSlots)
            .insert(
              ClassSlotsCompanion.insert(
                courseId: courseId,
                weekday: 8,
                startMin: 540,
                endMin: 600,
                campus: Campus.boun,
                online: false,
                source: SlotSource.manual,
              ),
            ),
      );
      expect(
        result,
        const Err<int>(
          StorageError(
            'classSlots.insert',
            causeType: 'SqliteException',
            code: 275,
          ),
        ),
      );
    });
  });

  group('스키마 버전', () {
    // 바깥 setUp의 메모리 DB를 연 채로 다른 파일의 DB를 함께 여므로, 같은 연결을 두 번 쓸 때 내는 drift
    // 경고를 끈다.
    setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

    test('파일이 이 앱보다 새 버전이면 NewerDatabaseException으로 멈추고 파일을 고치지 않는다', () async {
      final file = await _tempDatabaseFile();
      // 새 빌드가 만든 파일 흉내: 이 앱이 모르는 표 하나와 user_version 2.
      await _withoutMigrations(file, (raw) async {
        await raw.customStatement(
          'CREATE TABLE later (id INTEGER PRIMARY KEY)',
        );
        await raw.customStatement('PRAGMA user_version = 2');
      });

      final newer = AppDatabase(NativeDatabase(file));
      await expectLater(
        newer.customSelect('SELECT 1').get(),
        throwsA(
          isA<NewerDatabaseException>()
              .having((error) => error.fileVersion, 'fileVersion', 2)
              .having((error) => error.appVersion, 'appVersion', 1),
        ),
      );
      await newer.close();

      await _withoutMigrations(file, (raw) async {
        expect(await _userVersion(raw), 2);
        expect(await _tableNames(raw), ['later']);
      });
    });

    test('이 앱이 만든 파일은 다시 열어도 이전 단계를 거치지 않는다', () async {
      final file = await _tempDatabaseFile();
      for (var i = 0; i < 2; i++) {
        final db = AppDatabase(NativeDatabase(file));
        await db.customSelect('SELECT 1').get();
        await db.close();
      }
      await _withoutMigrations(file, (raw) async {
        expect(await _userVersion(raw), 1);
      });
    });
  });

  group('데모 시드', () {
    // 바깥 setUp의 메모리 DB를 연 채로 다른 DB를 함께 여므로, 같은 연결을 두 번 쓸 때 내는 drift 경고를
    // 끈다.
    setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

    final day1 = DateTime(2026, 11, 13, 9);
    final day2 = DateTime(2026, 11, 14, 9);

    /// 넣은 때를 적고 과목 하나를 넣는 시드.
    Future<void> Function(AppDatabase, DateTime) seeder(List<DateTime> calls) =>
        (db, now) async {
          calls.add(now);
          await db
              .into(db.courses)
              .insert(CoursesCompanion.insert(name: '샘플 과목'));
        };

    Future<List<String>> courseNames(AppDatabase db) async => [
      for (final course in await db.select(db.courses).get()) course.name,
    ];

    test('표가 모두 비어 있으면 열 때 한 번 넣고, 하루를 넘겨 다시 열어도 다시 넣지 않는다', () async {
      final file = await _tempDatabaseFile();
      final calls = <DateTime>[];

      final first = AppDatabase(
        NativeDatabase(file),
        demoSeeder: seeder(calls),
        clock: TestClock(day1),
      );
      expect(await courseNames(first), ['샘플 과목']);
      await first.close();

      // docs/decisions.md 2026-11-13 '하루를 넘긴 데모의 샘플은 다시 넣지 않는다'.
      final next = AppDatabase(
        NativeDatabase(file),
        demoSeeder: seeder(calls),
        clock: TestClock(day2),
      );
      expect(await courseNames(next), ['샘플 과목']);
      await next.close();

      expect(calls, [day1]);
    });

    test('끝내며 비운 뒤 다시 열면 그때를 기준으로 다시 넣는다', () async {
      final file = await _tempDatabaseFile();
      final calls = <DateTime>[];
      final first = AppDatabase(
        NativeDatabase(file),
        demoSeeder: seeder(calls),
        clock: TestClock(day1),
      );
      await first.select(first.courses).get();
      expect(await DemoRepository(first).clearAll(), isA<Ok<void>>());
      await first.close();

      final again = AppDatabase(
        NativeDatabase(file),
        demoSeeder: seeder(calls),
        clock: TestClock(day2),
      );
      expect(await courseNames(again), ['샘플 과목']);
      await again.close();

      expect(calls, [day1, day2]);
    });

    test('어느 표에든 행이 있으면 넣지 않는다', () async {
      final file = await _tempDatabaseFile();
      // 시드 없이 열어 표를 만들고 설정 한 행만 둔다(과목은 비어 있음).
      final plain = AppDatabase(NativeDatabase(file));
      await plain.customStatement(
        "INSERT INTO settings (key, value) VALUES ('aiEnabled', 'false')",
      );
      await plain.close();

      final calls = <DateTime>[];
      final db = AppDatabase(
        NativeDatabase(file),
        demoSeeder: seeder(calls),
        clock: TestClock(day1),
      );
      expect(await courseNames(db), isEmpty);
      await db.close();
      expect(calls, isEmpty);
    });

    test('넣다가 실패하면 아무것도 남기지 않고 빈 데모로 연다', () async {
      final db = AppDatabase(
        NativeDatabase.memory(),
        demoSeeder: (db, now) async {
          await db
              .into(db.courses)
              .insert(CoursesCompanion.insert(name: '샘플 과목'));
          await db.customStatement('SELECT * FROM no_such_table');
        },
        clock: TestClock(day1),
      );
      addTearDown(db.close);

      expect(await courseNames(db), isEmpty);
    });

    test('시드가 없는 DB(실제 모드)는 넣지 않는다', () async {
      final db = AppDatabase(NativeDatabase.memory(), clock: TestClock(day1));
      addTearDown(db.close);

      expect(await courseNames(db), isEmpty);
    });
  });
}

/// [file]을 drift의 버전 확인과 이전 단계 없이 열어 [action]을 한다(파일의 버전과 표를 보거나 바꿀 때).
Future<void> _withoutMigrations(
  File file,
  Future<void> Function(AppDatabase raw) action,
) async {
  final raw = AppDatabase(NativeDatabase(file, enableMigrations: false));
  try {
    await action(raw);
  } finally {
    await raw.close();
  }
}

Future<int> _userVersion(AppDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

Future<List<String>> _tableNames(AppDatabase db) async => [
  for (final row
      in await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get())
    row.read<String>('name'),
];

Future<File> _tempDatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('database_test');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/app.sqlite');
}
