// 시간표 새로 고침의 반영 테스트. docs/lms.md '시간표 (통합정보시스템)', docs/screens.md '13 시간표·고정 일정'.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/timetable_refresh_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TimetableRefreshRepository repo;
  late int course;
  final now = DateTime(2026, 11, 15, 15);

  setUp(() async {
    db = AppDatabase.memory();
    repo = TimetableRefreshRepository(db);
    course = await db
        .into(db.courses)
        .insert(
          CoursesCompanion.insert(
            name: '과목A',
            remoteId: const Value('A/1'),
            semester: const Value('2026-20'),
          ),
        );
  });
  tearDown(() => db.close());

  Future<T> ok<T>(Future<Result<T>> result) async => switch (await result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$error'),
  };

  Future<ClassSlot> slotRow(int id) =>
      (db.select(db.classSlots)..where((t) => t.id.equals(id))).getSingle();

  Future<ClassSlot> importedSlot({
    int weekday = 1,
    String? place = '합성관101',
  }) async {
    final id = await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: course,
            weekday: weekday,
            startMin: 540,
            endMin: 615,
            place: Value(place),
            online: false,
            source: SlotSource.auto,
            importedWeekday: Value(weekday),
            importedStartMin: const Value(540),
            importedEndMin: const Value(615),
            importedPlace: Value(place),
          ),
        );
    return slotRow(id);
  }

  Future<List<ClassSlot>> slots() => db.select(db.classSlots).get();

  test(
    '고치면 요일·시각·장소와 원래 값을 바꾸고 출처·캠퍼스·실시간 온라인·고친 표시는 두며, 되돌리면 이전 값이다',
    () async {
      final before = await importedSlot();
      const to = ImportedClassSlot(
        weekday: 3,
        startMin: 600,
        endMin: 690,
        place: '합성관202',
      );

      final applied = await ok(
        repo.apply([
          TimetableSlotUpdate(
            before,
            to: to,
            imported: to,
            reasons: const {TimetableUpdateReason.schoolTime},
          ),
        ], now: now),
      );

      expect(applied, 1);
      final after = await slotRow(before.id);
      expect(
        (after.weekday, after.startMin, after.endMin, after.place),
        (3, 600, 690, '합성관202'),
      );
      expect(
        (
          after.importedWeekday,
          after.importedStartMin,
          after.importedEndMin,
          after.importedPlace,
        ),
        (3, 600, 690, '합성관202'),
      );
      expect(
        (after.source, after.online, after.placeEdited),
        (SlotSource.auto, false, false),
      );

      expect(await ok(UndoRepository(db).undoLast(now: now)), isTrue);
      final undone = await slotRow(before.id);
      expect(
        (undone.weekday, undone.startMin, undone.place, undone.importedWeekday),
        (1, 540, '합성관101', 1),
      );
    },
  );

  test('지우면 그 수업 예외부터 함께 지우고, 되돌리면 함께 되살린다', () async {
    final slot = await importedSlot();
    await db
        .into(db.classExceptions)
        .insert(
          ClassExceptionsCompanion.insert(
            date: '2026-11-17',
            classSlotId: slot.id,
            kind: ClassExceptionKind.cancelled,
            source: EntrySource.manual,
          ),
        );

    expect(await ok(repo.apply([TimetableSlotRemoval(slot)], now: now)), 1);
    expect(await slots(), isEmpty);
    expect(await db.select(db.classExceptions).get(), isEmpty);

    expect(await ok(UndoRepository(db).undoLast(now: now)), isTrue);
    expect((await slots()).single.id, slot.id);
    expect(
      (await db.select(db.classExceptions).get()).single.classSlotId,
      slot.id,
    );
  });

  test('견준 뒤 바뀌었거나 지워진 칸은 건너뛰고, 하나도 반영하지 않으면 되돌리기 기록을 바꾸지 않는다', () async {
    final edited = await importedSlot();
    final gone = await importedSlot(weekday: 2);
    final earlier = await importedSlot(weekday: 5);
    // 앞선 동작의 되돌리기 기록(금요일 칸을 지움). 건너뛴 반영이 이 기록을 지우면 안 된다.
    expect(await ok(repo.apply([TimetableSlotRemoval(earlier)], now: now)), 1);
    await (db.update(
      db.classSlots,
    )..where((t) => t.id.equals(edited.id))).write(
      const ClassSlotsCompanion(
        place: Value('내가 고친 곳'),
        placeEdited: Value(true),
      ),
    );
    await (db.delete(db.classSlots)..where((t) => t.id.equals(gone.id))).go();

    final applied = await ok(
      repo.apply([
        TimetableSlotUpdate(
          edited,
          to: const ImportedClassSlot(weekday: 1, startMin: 540, endMin: 615),
          imported: const ImportedClassSlot(
            weekday: 1,
            startMin: 540,
            endMin: 615,
          ),
          reasons: const {TimetableUpdateReason.schoolPlace},
        ),
        TimetableSlotRemoval(gone),
      ], now: now),
    );

    expect(applied, 0);
    expect((await slotRow(edited.id)).place, '내가 고친 곳');
    expect(await ok(UndoRepository(db).undoLast(now: now)), isTrue);
    expect((await slots()).map((s) => s.weekday), contains(5));
  });

  test('견준 뒤 사용자가 뺀(숨긴) 칸은 건너뛴다', () async {
    final slot = await importedSlot();
    await (db.update(db.classSlots)..where((t) => t.id.equals(slot.id))).write(
      const ClassSlotsCompanion(hidden: Value(true)),
    );

    final applied = await ok(
      repo.apply([TimetableSlotRemoval(slot)], now: now),
    );

    expect(applied, 0);
    expect((await slotRow(slot.id)).hidden, isTrue);
  });

  test('여러 바뀜을 한 번에 되돌린다', () async {
    final first = await importedSlot();
    final second = await importedSlot(weekday: 2);
    const to = ImportedClassSlot(weekday: 4, startMin: 540, endMin: 615);

    expect(
      await ok(
        repo.apply([
          TimetableSlotUpdate(
            first,
            to: to,
            imported: to,
            reasons: const {TimetableUpdateReason.schoolTime},
          ),
          TimetableSlotRemoval(second),
        ], now: now),
      ),
      2,
    );
    expect((await slots()).map((s) => s.weekday), [4]);

    expect(await ok(UndoRepository(db).undoLast(now: now)), isTrue);
    expect((await slots()).map((s) => s.weekday).toList()..sort(), [1, 2]);
  });
}
