// 과목 저장소 테스트.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/course_repository.dart';
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
  late CourseRepository repository;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repository = CourseRepository(db);
  });

  tearDown(() => db.close());

  Future<int> course(String name, {String? remoteId, String? semester}) => db
      .into(db.courses)
      .insert(
        CoursesCompanion.insert(
          name: name,
          remoteId: Value(remoteId),
          semester: Value(semester),
        ),
      );

  List<String> labels(List<Course> courses) => [
    for (final c in courses) '${c.name}/${c.semester ?? '직접'}',
  ];

  test('고를 수 있는 과목은 직접 만든 과목과 가장 최근 학기의 LMS 과목이고 이름순이다', () async {
    await course('자료구조', remoteId: 'c1', semester: '2026-1');
    await course('자료구조', remoteId: 'c2', semester: '2026-2');
    await course('선형대수', remoteId: 'c3', semester: '2026-2');
    await course('알고리즘 스터디');
    await course('자료구조');

    expect(labels(_ok(await repository.readSelectable())), [
      '선형대수/2026-2',
      '알고리즘 스터디/직접',
      // 이름이 같으면 LMS 과목이 먼저다.
      '자료구조/2026-2',
      '자료구조/직접',
    ]);
  });

  test('LMS 과목이 없으면 직접 만든 과목만이고, watch는 과목이 바뀌면 다시 읽는다', () async {
    final seen = <List<String>>[];
    final subscription = repository.watchSelectable().listen(
      (courses) => seen.add(labels(courses)),
    );
    await pumpEventQueue();
    await course('스터디');
    await pumpEventQueue();
    await course('자료구조', remoteId: 'c1', semester: '2026-1');
    await course('선형대수', remoteId: 'c2', semester: '2026-2');
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen.first, isEmpty);
    expect(seen, anyElement(equals(['스터디/직접'])));
    // 더 최근 학기 과목이 생기면 지난 학기 과목은 빠진다.
    expect(seen.last, ['선형대수/2026-2', '스터디/직접']);
  });

  test('이름을 주면 그 이름의 고를 수 있는 과목만 읽는다', () async {
    await course('자료구조', remoteId: 'c1', semester: '2026-1');
    await course('자료구조', remoteId: 'c2', semester: '2026-2');
    await course('선형대수');
    final found = await selectableCourses(db, name: '자료구조').get();
    expect(labels(found), ['자료구조/2026-2']);
    expect(await selectableCourses(db, name: '없는 과목').get(), isEmpty);
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await CourseRepository(closed).readSelectable();
    expect(result, isA<Err<List<Course>>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
