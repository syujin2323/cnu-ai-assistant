// 수업 칸 저장소 테스트.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/class_slot_repository.dart';
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
  late ClassSlotRepository repository;
  late UndoRepository undo;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = ClassSlotRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);

  Future<int> course(String name, {String? remoteId, String? semester}) => db
      .into(db.courses)
      .insert(
        CoursesCompanion.insert(
          name: name,
          remoteId: Value(remoteId),
          semester: Value(semester),
        ),
      );

  Future<ClassSlot?> slot(int id) => (db.select(
    db.classSlots,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<String>> courseNames() async => [
    for (final c in await db.select(db.courses).get()) c.name,
  ];

  /// 통합정보시스템에서 불러온 수업(월 09:00–10:15, 공대 5호관 101).
  Future<int> importedSlot(int courseId) => db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: 1,
          startMin: 540,
          endMin: 615,
          place: const Value('공대 5호관 101'),
          online: false,
          source: SlotSource.auto,
          importedWeekday: const Value(1),
          importedStartMin: const Value(540),
          importedEndMin: const Value(615),
          importedPlace: const Value('공대 5호관 101'),
        ),
      );

  Future<Result<int>> add(
    CourseChoice course, {
    int weekday = 3,
    int startMin = 780,
    int endMin = 870,
    String? place = '인문대 201',
    bool online = false,
  }) => repository.add(
    course: course,
    weekday: weekday,
    startMin: startMin,
    endMin: endMin,
    place: place,
    online: online,
    now: now,
  );

  test('고른 과목으로 직접 넣은 수업을 저장하고, 되돌리면 지운다', () async {
    final courseId = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final id = _ok(await add(ChosenCourse(courseId)));
    final saved = (await slot(id))!;
    expect(saved.courseId, courseId);
    expect((saved.weekday, saved.startMin, saved.endMin), (3, 780, 870));
    expect(saved.place, '인문대 201');
    expect(saved.source, SlotSource.manual);
    expect(saved.importedWeekday, isNull);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await slot(id), isNull);
    expect(await courseNames(), ['선형대수']);
  });

  test('직접 입력한 새 과목은 함께 만들고, 되돌리면 과목도 지운다', () async {
    final id = _ok(await add(const TypedCourse('  캡스톤 디자인 ')));
    final saved = (await slot(id))!;
    final created = await (db.select(
      db.courses,
    )..where((t) => t.id.equals(saved.courseId))).getSingle();
    expect(created.name, '캡스톤 디자인');
    expect(created.remoteId, isNull);
    expect(created.semester, isNull);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await slot(id), isNull);
    expect(await courseNames(), isEmpty);
  });

  test('직접 입력한 이름이 고를 수 있는 과목과 같으면 그 과목을 쓴다(LMS 과목 먼저)', () async {
    await course('자료구조', remoteId: 'c0', semester: '2026-1');
    final manual = await course('자료구조');
    final lms = await course('자료구조', remoteId: 'c1', semester: '2026-2');
    final id = _ok(await add(const TypedCourse('자료구조')));
    expect((await slot(id))!.courseId, lms);
    expect((await db.select(db.courses).get()).length, 3);

    // 지난 학기 과목만 같은 이름이면 고를 수 없으므로 새로 만든다.
    await (db.delete(db.courses)..where((t) => t.id.isIn([manual]))).go();
    final other = _ok(await add(const TypedCourse('운영체제')));
    await course('운영체제', remoteId: 'c9', semester: '2026-1');
    expect((await slot(other))!.courseId, isNot(lms));
    expect(
      (await db.select(db.courses).get()).where((c) => c.name == '운영체제'),
      hasLength(2),
    );
  });

  test('watch는 모든 수업을 과목과 함께 요일·시작 시각 순서로 주고 바뀌면 다시 읽는다', () async {
    final math = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final seen = <List<String>>[];
    final subscription = repository.watch().listen(
      (entries) => seen.add([
        for (final e in entries)
          '${e.course.name} ${e.slot.weekday} ${e.slot.startMin} '
              '${e.slot.source.name}',
      ]),
    );
    await pumpEventQueue();
    _ok(await add(ChosenCourse(math), weekday: 3, startMin: 300));
    await importedSlot(math);
    _ok(await add(const TypedCourse('스터디'), weekday: 1, startMin: 420));
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first, isEmpty);
    expect(seen.last, [
      '스터디 1 420 manual',
      '선형대수 1 540 auto',
      '선형대수 3 300 manual',
    ]);
    expect(_ok(await repository.read()).map((e) => e.slot.startMin), [
      420,
      540,
      300,
    ]);
  });

  test('직접 넣은 수업을 고치면 모든 값을 바꾸고 되돌리면 이전 값이며, 없는 수업은 false다', () async {
    final math = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final id = _ok(await add(ChosenCourse(math)));
    expect(
      _ok(
        await repository.update(
          id,
          course: const TypedCourse('선형대수 실습'),
          weekday: 5,
          startMin: 1320,
          endMin: 1500,
          online: true,
          now: now,
        ),
      ),
      isTrue,
    );
    final changed = (await slot(id))!;
    expect(changed.courseId, isNot(math));
    expect(
      (changed.weekday, changed.startMin, changed.endMin),
      (5, 1320, 1500),
    );
    expect(changed.place, isNull);
    expect(changed.online, isTrue);
    expect(changed.source, SlotSource.manual);
    expect((changed.placeEdited, changed.onlineEdited), (false, false));

    // 되돌리면 수업을 되살리고 함께 만든 과목을 지운다.
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    final back = (await slot(id))!;
    expect(back.courseId, math);
    expect(back.place, '인문대 201');
    expect(back.online, isFalse);
    expect(await courseNames(), ['선형대수']);
    expect(
      _ok(
        await repository.update(
          999,
          course: ChosenCourse(math),
          weekday: 1,
          startMin: 540,
          endMin: 600,
          online: false,
          now: now,
        ),
      ),
      isFalse,
    );
  });

  test('불러온 수업을 고치면 출처와 원래 값은 그대로이고 장소·온라인을 바꾼 표시를 켠다', () async {
    final math = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final id = await importedSlot(math);
    Future<void> edit({required String? place, required bool online}) async =>
        expect(
          _ok(
            await repository.update(
              id,
              course: ChosenCourse(math),
              weekday: 1,
              startMin: 570,
              endMin: 645,
              place: place,
              online: online,
              now: now,
            ),
          ),
          isTrue,
        );

    // 시간만 바꾸면 표시를 켜지 않는다.
    await edit(place: '공대 5호관 101', online: false);
    var current = (await slot(id))!;
    expect(current.startMin, 570);
    expect((current.placeEdited, current.onlineEdited), (false, false));
    expect(current.source, SlotSource.auto);
    expect(
      (
        current.importedWeekday,
        current.importedStartMin,
        current.importedEndMin,
        current.importedPlace,
      ),
      (1, 540, 615, '공대 5호관 101'),
    );

    await edit(place: '공대 3호관 B01', online: false);
    current = (await slot(id))!;
    expect((current.placeEdited, current.onlineEdited), (true, false));

    // 되돌리면 표시도 이전 값이다.
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await slot(id))!.placeEdited, isFalse);

    await edit(place: '공대 3호관 B01', online: false);
    await edit(place: '공대 5호관 101', online: true);
    current = (await slot(id))!;
    // 원래 장소로 돌려도 고친 표시는 끄지 않는다.
    expect((current.placeEdited, current.onlineEdited), (true, true));
    expect(current.importedPlace, '공대 5호관 101');
  });

  Future<void> cancel(int slotId, String date) => db
      .into(db.classExceptions)
      .insert(
        ClassExceptionsCompanion.insert(
          date: date,
          classSlotId: slotId,
          kind: ClassExceptionKind.cancelled,
          source: EntrySource.manual,
        ),
      );

  Future<List<(int, String)>> exceptions() async => [
    for (final e in await db.select(db.classExceptions).get())
      (e.classSlotId, e.date),
  ];

  test('직접 넣은 수업을 빼면 행과 수업 예외를 지우고, 되돌리면 함께 되살리며, 과목은 남긴다', () async {
    final math = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final id = _ok(await add(ChosenCourse(math)));
    final other = await importedSlot(math);
    await cancel(id, '2026-11-18');
    await cancel(id, '2026-11-25');
    await cancel(other, '2026-11-16');

    expect(_ok(await repository.delete(id, now: now)), isTrue);
    expect(await slot(id), isNull);
    expect(await exceptions(), [(other, '2026-11-16')]);
    expect(await courseNames(), ['선형대수']);
    expect(_ok(await repository.delete(id, now: now)), isFalse);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await slot(id))!.source, SlotSource.manual);
    expect(
      await exceptions(),
      unorderedEquals([
        (id, '2026-11-18'),
        (id, '2026-11-25'),
        (other, '2026-11-16'),
      ]),
    );
  });

  test('불러온 수업을 빼면 행을 남겨 숨기고 수업 예외를 지우며, 되돌리면 되살린다', () async {
    final math = await course('선형대수', remoteId: 'c1', semester: '2026-2');
    final id = await importedSlot(math);
    final other = await importedSlot(math);
    await cancel(id, '2026-11-16');
    await cancel(other, '2026-11-23');

    expect(_ok(await repository.delete(id, now: now)), isTrue);
    final hidden = (await slot(id))!;
    expect(hidden.hidden, isTrue);
    expect(hidden.source, SlotSource.auto);
    expect(
      (hidden.weekday, hidden.startMin, hidden.importedWeekday),
      (1, 540, 1),
    );
    expect(await exceptions(), [(other, '2026-11-23')]);
    expect(_ok(await repository.read()).map((e) => e.slot.id), [other]);

    // 숨긴 수업은 다시 빼거나 고칠 수 없다.
    expect(_ok(await repository.delete(id, now: now)), isFalse);
    expect(
      _ok(
        await repository.update(
          id,
          course: ChosenCourse(math),
          weekday: 2,
          startMin: 540,
          endMin: 615,
          online: false,
          now: now,
        ),
      ),
      isFalse,
    );
    expect((await slot(id))!.weekday, 1);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await slot(id))!.hidden, isFalse);
    expect(
      await exceptions(),
      unorderedEquals([(id, '2026-11-16'), (other, '2026-11-23')]),
    );
    expect(
      _ok(await repository.read()).map((e) => e.slot.id),
      unorderedEquals([id, other]),
    );
  });

  test('빈 과목 이름이나 시간표 검사에 걸리는 값은 ArgumentError이고 아무것도 쓰지 않는다', () async {
    final math = await course('선형대수');
    expect(() => add(const TypedCourse(' ')), throwsArgumentError);
    expect(() => add(ChosenCourse(math), weekday: 0), throwsArgumentError);
    expect(() => add(ChosenCourse(math), weekday: 8), throwsArgumentError);
    expect(
      () => add(ChosenCourse(math), startMin: 600, endMin: 600),
      throwsArgumentError,
    );
    expect(
      () => add(ChosenCourse(math), startMin: 1440, endMin: 1500),
      throwsArgumentError,
    );
    expect(await db.select(db.classSlots).get(), isEmpty);
    expect(await courseNames(), ['선형대수']);
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await ClassSlotRepository(closed).delete(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
