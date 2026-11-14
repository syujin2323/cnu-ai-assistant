// 고정 일정 저장소 테스트.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/fixed_block_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  late AppDatabase db;
  late FixedBlockRepository repository;
  late UndoRepository undo;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = FixedBlockRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);

  Future<FixedBlock?> block(int id) => (db.select(
    db.fixedBlocks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> addWork({List<int> weekdays = const [7, 6]}) async => _ok(
    await repository.add(
      name: '알바',
      weekdays: weekdays,
      startMin: 840,
      endMin: 1020,
      bufferMin: 10,
      kind: FixedBlockKind.work,
      place: '카페',
      source: EntrySource.ai,
      now: now,
    ),
  );

  test('넣으면 요일을 정렬해 저장하고, 되돌리면 지운다', () async {
    final id = await addWork();
    final saved = (await block(id))!;
    expect(saved.weekdays, [6, 7]);
    expect(saved.place, '카페');
    expect(saved.source, EntrySource.ai);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await block(id), isNull);
  });

  test('watch는 시작 시각 순서로 주고 바뀌면 다시 읽는다', () async {
    final seen = <List<String>>[];
    final subscription = repository.watch().listen(
      (blocks) => seen.add([for (final b in blocks) b.name]),
    );
    await pumpEventQueue();
    await addWork();
    _ok(
      await repository.add(
        name: '점심',
        weekdays: const [1, 2, 3, 4, 5],
        startMin: 720,
        endMin: 780,
        bufferMin: 0,
        kind: FixedBlockKind.meal,
        source: EntrySource.manual,
        now: now,
      ),
    );
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first, isEmpty);
    expect(seen.last, ['점심', '알바']);
  });

  test('고치면 모든 값을 바꾸되 출처는 그대로이고, 되돌리면 이전 값이며, 없는 고정 일정은 false다', () async {
    final id = await addWork();
    expect(
      _ok(
        await repository.update(
          id,
          name: '과외',
          weekdays: const [5, 3],
          startMin: 900,
          endMin: 1080,
          bufferMin: 0,
          kind: FixedBlockKind.other,
          prep: '교재',
          now: now,
        ),
      ),
      isTrue,
    );
    final changed = (await block(id))!;
    expect(changed.name, '과외');
    expect(changed.weekdays, [3, 5]);
    expect(
      (changed.startMin, changed.endMin, changed.bufferMin),
      (900, 1080, 0),
    );
    expect(changed.kind, FixedBlockKind.other);
    expect(changed.prep, '교재');
    expect(changed.place, isNull);
    expect(changed.source, EntrySource.ai);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    final back = (await block(id))!;
    expect(back.name, '알바');
    expect(back.place, '카페');
    expect(
      _ok(
        await repository.update(
          999,
          name: '과외',
          weekdays: const [5],
          startMin: 900,
          endMin: 1080,
          bufferMin: 0,
          kind: FixedBlockKind.other,
          now: now,
        ),
      ),
      isFalse,
    );
  });

  test('지우면 되돌릴 수 있고, 없는 고정 일정은 false다', () async {
    final id = await addWork();
    expect(_ok(await repository.delete(id, now: now)), isTrue);
    expect(await block(id), isNull);
    expect(_ok(await repository.delete(id, now: now)), isFalse);
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await block(id))!.name, '알바');
  });

  test('빈 이름이나 시간표 검사에 걸리는 값은 ArgumentError다', () async {
    Future<Result<int>> add({
      String name = '운동',
      List<int> weekdays = const [1],
      int startMin = 1200,
      int endMin = 1260,
      int bufferMin = 0,
    }) => repository.add(
      name: name,
      weekdays: weekdays,
      startMin: startMin,
      endMin: endMin,
      bufferMin: bufferMin,
      kind: FixedBlockKind.exercise,
      source: EntrySource.manual,
      now: now,
    );
    expect(() => add(name: ''), throwsArgumentError);
    expect(() => add(weekdays: const []), throwsArgumentError);
    expect(() => add(weekdays: const [1, 1]), throwsArgumentError);
    expect(() => add(endMin: 1200), throwsArgumentError);
    expect(() => add(bufferMin: 61), throwsArgumentError);
    expect(await db.select(db.fixedBlocks).get(), isEmpty);
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await FixedBlockRepository(closed).delete(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
