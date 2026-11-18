// 폰 데이터를 지우는 저장소 테스트. docs/lms.md '로그아웃, 데이터 삭제'.
//
// 로그아웃은 LMS에서 온 행만 자식부터 지우고(외래 키는 NO ACTION) 직접 넣은 것·내 규칙·LMS 과목·기록은 남기는지,
// 데이터 삭제는 모든 표를 비우는지, 하나라도 지우지 못하면 아무것도 지우지 않는지 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/local_data_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalDataRepository repository;
  final at = DateTime(2026, 11, 14, 9);

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = LocalDataRepository(db);
  });

  tearDown(() => db.close());

  /// 남겨야 할 행과 지워야 할 행을 함께 넣고 각 행의 id를 돌려준다.
  Future<Map<String, int>> addRows() async {
    final courseId = await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            name: '과목A',
            remoteId: const Value('1'),
            semester: const Value('1'),
          ),
        );
    Future<int> slot(SlotSource source) => db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 1,
            startMin: 540,
            endMin: 600,
            online: false,
            source: source,
          ),
        );
    final importedSlot = await slot(SlotSource.auto);
    final manualSlot = await slot(SlotSource.manual);
    Future<int> exception(int slotId) => db
        .into(db.classExceptions)
        .insert(
          ClassExceptionsCompanion.insert(
            date: '2026-11-16',
            classSlotId: slotId,
            kind: ClassExceptionKind.cancelled,
            source: EntrySource.manual,
          ),
        );
    final importedException = await exception(importedSlot);
    final manualException = await exception(manualSlot);

    await db
        .into(db.lmsItems)
        .insert(
          LmsItemsCompanion.insert(
            remoteKey: '1:1:assignment:1',
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
    Future<int> task(String? lmsKey, TaskStatus status) => db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '할 일',
            kind: TaskKind.assignment,
            dueTimeUnknown: false,
            status: status,
            lmsKey: Value(lmsKey),
            spentMin: const Value(30),
          ),
        );
    final lmsTask = await task('1:1:assignment:1', TaskStatus.todo);
    final manualTask = await task(null, TaskStatus.todo);
    Future<int> block(int taskId) => db
        .into(db.planBlocks)
        .insert(
          PlanBlocksCompanion.insert(
            taskId: taskId,
            startAt: at,
            endAt: at.add(const Duration(hours: 1)),
            status: PlanBlockStatus.confirmed,
            source: BlockSource.manual,
          ),
        );
    final lmsBlock = await block(lmsTask);
    final manualBlock = await block(manualTask);

    await db
        .into(db.rules)
        .insert(
          RulesCompanion.insert(
            kind: RuleKind.classBuffer,
            params: const RuleParams(minutes: 15),
            active: true,
            source: EntrySource.manual,
            createdAt: at,
            updatedAt: at,
          ),
        );
    await db
        .into(db.lmsItemChanges)
        .insert(
          LmsItemChangesCompanion.insert(
            remoteKey: '1:1:assignment:1',
            field: 'dueAt',
            changedAt: at,
          ),
        );
    await db
        .into(db.syncRuns)
        .insert(
          SyncRunsCompanion.insert(
            startedAt: at,
            trigger: SyncTrigger.open,
            scope: SyncScope.list,
            result: SyncResultKind.normal,
            changedCount: 1,
            elapsedMs: 10,
          ),
        );
    await db.customStatement(
      "INSERT INTO settings (key, value) VALUES ('aiEnabled', 'true')",
    );
    await db
        .into(db.undoLog)
        .insert(
          UndoLogCompanion.insert(
            targetTable: 'tasks',
            action: UndoAction.update,
            createdAt: at,
          ),
        );
    return {
      'course': courseId,
      'importedSlot': importedSlot,
      'manualSlot': manualSlot,
      'importedException': importedException,
      'manualException': manualException,
      'lmsTask': lmsTask,
      'manualTask': manualTask,
      'lmsBlock': lmsBlock,
      'manualBlock': manualBlock,
    };
  }

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  group('deleteLmsData(로그아웃)', () {
    test('불러온 시간표와 그 예외, LMS 할 일과 그 블록, LMS 원본만 지우고 되돌리기 기록을 버린다', () async {
      final ids = await addRows();

      expect(await repository.deleteLmsData(), isA<Ok<void>>());

      expect((await db.select(db.classSlots).get()).map((r) => r.id), [
        ids['manualSlot'],
      ]);
      expect((await db.select(db.classExceptions).get()).map((r) => r.id), [
        ids['manualException'],
      ]);
      expect((await db.select(db.tasks).get()).map((r) => r.id), [
        ids['manualTask'],
      ]);
      expect((await db.select(db.planBlocks).get()).map((r) => r.id), [
        ids['manualBlock'],
      ]);
      expect(await count('lms_items'), 0);
      expect(await count('undo_log'), 0);
      // 직접 넣은 것·내 규칙·LMS 과목·바뀜·동기화 기록·설정은 남긴다.
      expect(await count('courses'), 1);
      expect(await count('rules'), 1);
      expect(await count('lms_item_changes'), 1);
      expect(await count('sync_runs'), 1);
      expect(await count('settings'), 1);
    });

    test('하나라도 지우지 못하면 아무것도 지우지 않고 Err다', () async {
      await addRows();
      // 마지막 단계(되돌리기 기록 지우기)를 막아, 앞에서 지운 행도 되돌려지는지 본다.
      await db.customStatement(
        'CREATE TRIGGER keep_undo BEFORE DELETE ON undo_log '
        "BEGIN SELECT RAISE(ABORT, 'keep'); END",
      );

      final result = await repository.deleteLmsData();

      expect(
        (result as Err<void>).error,
        isA<StorageError>().having(
          (error) => error.operation,
          'operation',
          'localData.deleteLmsData',
        ),
      );
      expect(await count('class_slots'), 2);
      expect(await count('tasks'), 2);
      expect(await count('plan_blocks'), 2);
      expect(await count('lms_items'), 1);
    });
  });

  group('deleteAll(데이터 삭제)', () {
    test('모든 표를 비운다', () async {
      await addRows();

      expect(await repository.deleteAll(), isA<Ok<void>>());

      for (final table in db.allTables) {
        expect(
          await db.select(table).get(),
          isEmpty,
          reason: table.actualTableName,
        );
      }
    });

    test('닫힌 DB면 StorageError를 담은 Err다', () async {
      // 데모를 끝내며 닫은 DB를 받아 둔 저장소를 쓰는 경우. 한 번 연 뒤에 닫는다.
      final closed = AppDatabase.memory();
      await closed.customSelect('SELECT 1').get();
      await closed.close();
      expect(
        (await LocalDataRepository(closed).deleteAll() as Err<void>).error,
        const StorageError('localData.deleteAll', causeType: 'StateError'),
      );
    });
  });
}
