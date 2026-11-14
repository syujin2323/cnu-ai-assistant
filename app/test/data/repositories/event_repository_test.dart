// 일정 저장소 테스트.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/event_repository.dart';
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
  late EventRepository repository;
  late UndoRepository undo;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = EventRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  final now = DateTime(2026, 11, 15, 12);
  final start = DateTime(2026, 11, 20, 15);
  final end = DateTime(2026, 11, 20, 16);

  Future<Event?> event(int id) =>
      (db.select(db.events)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> addMeeting() async => _ok(
    await repository.add(
      title: '회의',
      startAt: start,
      endAt: end,
      place: '공대 5호관',
      reminderMinutes: 30,
      source: EventSource.ai,
      now: now,
    ),
  );

  test('넣은 일정을 저장하고 되돌리면 지운다', () async {
    final id = await addMeeting();
    final saved = (await event(id))!;
    expect(saved.title, '회의');
    expect(saved.startAt, start);
    expect(saved.place, '공대 5호관');
    expect(saved.reminderMinutes, 30);
    expect(saved.source, EventSource.ai);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect(await event(id), isNull);
  });

  test('고치면 모든 값을 바꾸고 되돌리면 이전 값으로 돌아간다', () async {
    final id = await addMeeting();
    final later = start.add(const Duration(hours: 2));
    expect(
      _ok(
        await repository.update(
          id,
          title: '회의(변경)',
          startAt: later,
          endAt: later.add(const Duration(hours: 1)),
          allDay: true,
          prep: '노트북',
          now: now,
        ),
      ),
      isTrue,
    );
    final changed = (await event(id))!;
    expect(changed.title, '회의(변경)');
    expect(changed.startAt, later);
    expect(changed.endAt, later.add(const Duration(hours: 1)));
    expect(changed.allDay, isTrue);
    expect(changed.place, isNull);
    expect(changed.prep, '노트북');
    expect(changed.reminderMinutes, isNull);
    expect(changed.source, EventSource.ai);

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    final back = (await event(id))!;
    expect(back.title, '회의');
    expect(back.place, '공대 5호관');
    expect(
      _ok(
        await repository.update(
          999,
          title: 'x',
          startAt: start,
          endAt: end,
          allDay: false,
          now: now,
        ),
      ),
      isFalse,
    );
  });

  test('지우면 되돌릴 수 있고, 없는 일정은 false다', () async {
    final id = await addMeeting();
    expect(_ok(await repository.delete(id, now: now)), isTrue);
    expect(await event(id), isNull);
    expect(_ok(await repository.delete(id, now: now)), isFalse);
    // 없는 일정 지우기는 기록을 건드리지 않아 앞의 지우기를 되돌릴 수 있다.
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await event(id))!.title, '회의');
  });

  test('빈 제목이나 시작보다 이른 끝은 ArgumentError이고, 끝이 시작과 같으면 받는다', () async {
    expect(
      () => repository.add(
        title: ' ',
        startAt: start,
        endAt: end,
        source: EventSource.manual,
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.add(
        title: '회의',
        startAt: end,
        endAt: start,
        source: EventSource.manual,
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      _ok(
        await repository.add(
          title: '마감 알림',
          startAt: start,
          endAt: start,
          source: EventSource.manual,
          now: now,
        ),
      ),
      isA<int>(),
    );
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await EventRepository(closed).delete(1, now: now);
    expect(result, isA<Err<bool>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
