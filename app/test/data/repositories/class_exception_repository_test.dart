// 수업 예외 저장소 테스트.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/class_exception_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  late AppDatabase db;
  late ClassExceptionRepository repository;
  late UndoRepository undo;
  late int slotId;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.memory();
    repository = ClassExceptionRepository(db);
    undo = UndoRepository(db);
    final courseId = await db
        .into(db.courses)
        .insert(CoursesCompanion.insert(name: '선형대수'));
    slotId = await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 5,
            startMin: 600,
            endMin: 675,
            place: const Value('공대 5호관 101'),
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.auto,
          ),
        );
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);
  // 금요일 수업의 날. 시각은 버리고 날짜만 쓴다.
  final friday = DateTime(2026, 11, 20, 23, 30);

  /// 저장된 예외를 '날짜 종류 장소' 꼴로 읽는다.
  Future<List<String>> rows() async => [
    for (final e in await (db.select(
      db.classExceptions,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get())
      '${e.date} ${e.kind.name} ${e.place ?? '-'}',
  ];

  Future<bool> change(ClassExceptionKind? kind, {String? place}) async => _ok(
    await repository.setDayChange(
      slotId,
      friday,
      kind: kind,
      place: place,
      source: EntrySource.manual,
      now: now,
    ),
  );

  test('그날 휴강을 넣고, 같은 상태를 다시 넣으면 false이며 앞 동작을 되돌릴 수 있다', () async {
    expect(await change(ClassExceptionKind.cancelled), isTrue);
    expect(await rows(), ['2026-11-20 cancelled -']);
    final saved = await db.select(db.classExceptions).getSingle();
    expect(saved.classSlotId, slotId);
    expect(saved.source, EntrySource.manual);

    expect(await change(ClassExceptionKind.cancelled), isFalse);
    expect(await rows(), ['2026-11-20 cancelled -']);
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await rows(), isEmpty);
  });

  test('다른 종류로 바꾸면 그날의 이전 상태를 바꿔 끼우고, 되돌리면 이전 상태다', () async {
    await change(ClassExceptionKind.cancelled);
    expect(
      await change(ClassExceptionKind.placeChange, place: '공대 3호관 B01'),
      isTrue,
    );
    expect(await rows(), ['2026-11-20 placeChange 공대 3호관 B01']);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await rows(), ['2026-11-20 cancelled -']);
  });

  test('시험은 장소가 있어도 없어도 되고, 장소가 바뀌면 바꿔 끼운다', () async {
    expect(await change(ClassExceptionKind.exam), isTrue);
    expect(await change(ClassExceptionKind.exam), isFalse);
    expect(await change(ClassExceptionKind.exam, place: '대강당'), isTrue);
    expect(await change(ClassExceptionKind.exam, place: '대강당'), isFalse);
    expect(await rows(), ['2026-11-20 exam 대강당']);
  });

  test('원래대로 돌리면 그날의 바뀐 상태만 지우고 보강은 남기며, 바뀐 것이 없으면 false다', () async {
    expect(await change(null), isFalse);
    _ok(
      await repository.addMakeup(
        slotId,
        friday,
        startMin: 1140,
        endMin: 1215,
        source: EntrySource.ai,
        now: now,
      ),
    );
    await change(ClassExceptionKind.cancelled);
    // 다른 날과 다른 수업의 예외는 건드리지 않는다.
    final otherSlot = await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: (await db.select(db.courses).getSingle()).id,
            weekday: 5,
            startMin: 780,
            endMin: 855,
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.manual,
          ),
        );
    for (final (slot, date) in [
      (slotId, '2026-11-27'),
      (otherSlot, '2026-11-20'),
    ]) {
      await db
          .into(db.classExceptions)
          .insert(
            ClassExceptionsCompanion.insert(
              date: date,
              classSlotId: slot,
              kind: ClassExceptionKind.cancelled,
              source: EntrySource.manual,
            ),
          );
    }
    expect(await change(null), isTrue);
    expect(await rows(), [
      '2026-11-20 makeup -',
      '2026-11-27 cancelled -',
      '2026-11-20 cancelled -',
    ]);
    expect(await change(null), isFalse);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await rows(), [
      '2026-11-20 makeup -',
      '2026-11-20 cancelled -',
      '2026-11-27 cancelled -',
      '2026-11-20 cancelled -',
    ]);
  });

  test('그날 바뀐 상태가 여럿이면 하나로 바꿔 끼운다', () async {
    for (final kind in [
      ClassExceptionKind.cancelled,
      ClassExceptionKind.exam,
    ]) {
      await db
          .into(db.classExceptions)
          .insert(
            ClassExceptionsCompanion.insert(
              date: '2026-11-20',
              classSlotId: slotId,
              kind: kind,
              source: EntrySource.ai,
            ),
          );
    }
    expect(await change(ClassExceptionKind.cancelled), isTrue);
    expect(await rows(), ['2026-11-20 cancelled -']);
  });

  test('종류와 장소가 맞지 않으면 ArgumentError다', () async {
    Future<Result<bool>> call(ClassExceptionKind? kind, String? place) =>
        repository.setDayChange(
          slotId,
          friday,
          kind: kind,
          place: place,
          source: EntrySource.manual,
          now: now,
        );
    expect(() => call(ClassExceptionKind.makeup, null), throwsArgumentError);
    expect(
      () => call(ClassExceptionKind.placeChange, null),
      throwsArgumentError,
    );
    expect(
      () => call(ClassExceptionKind.placeChange, ' '),
      throwsArgumentError,
    );
    expect(() => call(ClassExceptionKind.cancelled, '공대'), throwsArgumentError);
    expect(() => call(null, '공대'), throwsArgumentError);
    expect(await rows(), isEmpty);
  });

  test('보강은 시각과 함께 또는 평소 시각으로 넣고 되돌리면 지우며, 시각 하나만 주면 ArgumentError다', () async {
    final id = _ok(
      await repository.addMakeup(
        slotId,
        friday,
        startMin: 1140,
        endMin: 1215,
        place: '공대 3호관 B01',
        source: EntrySource.ai,
        now: now,
      ),
    );
    final saved = await (db.select(
      db.classExceptions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(saved.kind, ClassExceptionKind.makeup);
    expect(
      (saved.date, saved.startMin, saved.endMin),
      ('2026-11-20', 1140, 1215),
    );
    expect(saved.place, '공대 3호관 B01');
    expect(saved.source, EntrySource.ai);
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await rows(), isEmpty);

    _ok(
      await repository.addMakeup(
        slotId,
        friday,
        source: EntrySource.manual,
        now: now,
      ),
    );
    final usual = await db.select(db.classExceptions).getSingle();
    expect((usual.startMin, usual.endMin), (null, null));

    expect(
      () => repository.addMakeup(
        slotId,
        friday,
        startMin: 1140,
        source: EntrySource.manual,
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.addMakeup(
        slotId,
        friday,
        startMin: 1200,
        endMin: 1140,
        source: EntrySource.manual,
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test('지우면 되돌릴 수 있고, 없는 예외는 false다', () async {
    final id = _ok(
      await repository.addMakeup(
        slotId,
        friday,
        source: EntrySource.manual,
        now: now,
      ),
    );
    expect(_ok(await repository.delete(id, now: now)), isTrue);
    expect(await rows(), isEmpty);
    expect(_ok(await repository.delete(id, now: now)), isFalse);
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await rows(), ['2026-11-20 makeup -']);
  });

  test('없는 수업에는 넣지 못해 Err(StorageError)이고, 원래대로는 false다', () async {
    final result = await repository.setDayChange(
      999,
      friday,
      kind: ClassExceptionKind.cancelled,
      source: EntrySource.manual,
      now: now,
    );
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
    expect(
      _ok(
        await repository.setDayChange(
          999,
          friday,
          kind: null,
          source: EntrySource.manual,
          now: now,
        ),
      ),
      isFalse,
    );
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await ClassExceptionRepository(closed).delete(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
