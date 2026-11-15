import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/lms_sync_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/parsers/todo_list_parser.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

const _semester = '2026-2';
const _older = '2026-1';

LmsTodoRecord _todo(
  String itemId, {
  String course = '10/01',
  String courseName = '자료구조',
  String title = '과제 1',
  String kindCode = 'K1',
  LmsItemKind kind = LmsItemKind.assignment,
  DateTime? dueAt,
  bool dueTimeUnknown = false,
}) => LmsTodoRecord(
  kindCode: kindCode,
  kind: kind,
  courseRemoteId: course,
  courseName: courseName,
  title: title,
  itemId: itemId,
  dueAt: dueAt,
  dueTimeUnknown: dueTimeUnknown,
);

void main() {
  late AppDatabase db;
  late LmsSyncRepository repo;
  final now = DateTime(2026, 11, 15, 9);
  final due = DateTime(2026, 11, 20, 23, 59);

  setUp(() {
    db = AppDatabase.memory();
    repo = LmsSyncRepository(db);
  });
  tearDown(() => db.close());

  Future<T> ok<T>(Future<Result<T>> result) async => switch (await result) {
    Ok(:final value) => value,
    Err(:final error) => fail('$error'),
  };

  Future<int> manualCourse(String name, {String? remoteId, String? semester}) =>
      db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              name: name,
              remoteId: Value(remoteId),
              semester: Value(semester),
            ),
          );

  group('upsertCourses', () {
    test('새 과목은 원본 ID·학기·본 때와 함께 만들고, 같은 과목은 이름과 본 때만 고친다', () async {
      final first = await ok(
        repo.upsertCourses(
          const [
            LmsCourseRecord(remoteId: '10/01', name: '자료구조'),
            LmsCourseRecord(remoteId: '20/02', name: '선형대수'),
          ],
          semester: _semester,
          now: now,
        ),
      );
      final later = now.add(const Duration(hours: 3));
      final second = await ok(
        repo.upsertCourses(
          const [LmsCourseRecord(remoteId: '10/01', name: '자료구조(영어)')],
          semester: _semester,
          now: later,
        ),
      );

      expect(second['10/01'], first['10/01']);
      final rows = await (db.select(
        db.courses,
      )..orderBy([(c) => OrderingTerm(expression: c.id)])).get();
      expect(rows.map((c) => (c.remoteId, c.semester, c.name)), [
        ('10/01', _semester, '자료구조(영어)'),
        ('20/02', _semester, '선형대수'),
      ]);
      expect(rows[0].lastSeenAt, later);
      expect(rows[1].lastSeenAt, now);
    });

    test('가장 최근 학기면 이름이 같은 직접 만든 과목에 원본 ID와 학기를 채워 합친다', () async {
      final manual = await manualCourse('자료구조');
      final other = await manualCourse('운영체제');

      final ids = await ok(
        repo.upsertCourses(
          const [
            LmsCourseRecord(remoteId: '10/01', name: '자료구조'),
            LmsCourseRecord(remoteId: '10/02', name: '자료구조'),
          ],
          semester: _semester,
          now: now,
        ),
      );

      expect(ids['10/01'], manual);
      expect(ids['10/02'], isNot(manual));
      final merged = await (db.select(
        db.courses,
      )..where((c) => c.id.equals(manual))).getSingle();
      expect(
        (merged.remoteId, merged.semester, merged.lastSeenAt),
        ('10/01', _semester, now),
      );
      final untouched = await (db.select(
        db.courses,
      )..where((c) => c.id.equals(other))).getSingle();
      expect(untouched.remoteId, null);
    });

    test('더 최근 학기의 LMS 과목이 있으면 직접 만든 과목과 합치지 않는다', () async {
      final manual = await manualCourse('자료구조');
      await manualCourse('운영체제', remoteId: '30/01', semester: _semester);

      final ids = await ok(
        repo.upsertCourses(
          const [LmsCourseRecord(remoteId: '10/01', name: '자료구조')],
          semester: _older,
          now: now,
        ),
      );

      expect(ids['10/01'], isNot(manual));
      expect(
        (await (db.select(
          db.courses,
        )..where((c) => c.id.equals(manual))).getSingle()).remoteId,
        null,
      );
    });

    test('원본 ID가 같아도 학기가 다르면 다른 과목이다', () async {
      final older = await ok(
        repo.upsertCourses(
          const [LmsCourseRecord(remoteId: '10/01', name: '자료구조')],
          semester: _older,
          now: now,
        ),
      );
      final newer = await ok(
        repo.upsertCourses(
          const [LmsCourseRecord(remoteId: '10/01', name: '자료구조')],
          semester: _semester,
          now: now,
        ),
      );

      expect(newer['10/01'], isNot(older['10/01']));
      expect((await db.select(db.courses).get()).map((c) => c.semester), [
        _older,
        _semester,
      ]);
    });

    test('한 응답에 같은 과목이 두 번 오면 처음 것만 쓴다', () async {
      await ok(
        repo.upsertCourses(
          const [
            LmsCourseRecord(remoteId: '10/01', name: '자료구조'),
            LmsCourseRecord(remoteId: '10/01', name: '다른 이름'),
          ],
          semester: _semester,
          now: now,
        ),
      );

      final rows = await db.select(db.courses).get();
      expect(rows.map((c) => c.name), ['자료구조']);
    });
  });

  group('applyTodoList', () {
    test('새 항목을 넣고 자료가 아닌 항목은 할 일로 만들며, 처음 보는 과목은 만든다', () async {
      final applied = await ok(
        repo.applyTodoList(
          [
            _todo('1', dueAt: due),
            _todo(
              '2',
              title: '1주차 자료',
              kindCode: 'K9',
              kind: LmsItemKind.material,
            ),
            _todo('1', title: '같은 키는 한 번만'),
          ],
          semester: _semester,
          now: now,
        ),
      );

      final course = await db.select(db.courses).getSingle();
      expect(
        (course.remoteId, course.semester, course.name),
        ('10/01', _semester, '자료구조'),
      );
      final items = await (db.select(
        db.lmsItems,
      )..orderBy([(i) => OrderingTerm(expression: i.id)])).get();
      expect(items.map((i) => i.remoteKey), [
        '$_semester:10/01:K1:1',
        '$_semester:10/01:K9:2',
      ]);
      final first = items.first;
      expect(first.courseId, course.id);
      expect(first.title, '과제 1');
      expect(first.dueAt, due);
      expect(
        (first.firstSeenAt, first.lastSeenAt, first.missCount),
        (now, now, 0),
      );
      expect(first.contentHash, lmsListContentHash(_todo('1', dueAt: due)));

      final tasks = await db.select(db.tasks).get();
      expect(tasks.map((t) => (t.lmsKey, t.title, t.kind, t.status)), [
        ('$_semester:10/01:K1:1', '과제 1', TaskKind.assignment, TaskStatus.todo),
      ]);
      expect(tasks.single.dueAt, due);
      expect(applied.changedCount, 2);
      expect(applied.changedCourseIds, {course.id});
    });

    test('마감이 바뀌면 항목과 할 일의 복사 열을 고치고 바뀜을 남기며, 사용자 값은 그대로 둔다', () async {
      await ok(
        repo.applyTodoList(
          [_todo('1', dueAt: due)],
          semester: _semester,
          now: now,
        ),
      );
      await (db.update(db.tasks)).write(
        const TasksCompanion(
          status: Value(TaskStatus.done),
          estimateMin: Value(90),
        ),
      );
      final later = now.add(const Duration(hours: 3));
      final moved = due.add(const Duration(days: 2));

      final applied = await ok(
        repo.applyTodoList(
          [_todo('1', title: '과제 1 (수정)', dueAt: moved)],
          semester: _semester,
          now: later,
        ),
      );

      final item = await db.select(db.lmsItems).getSingle();
      expect(
        (item.title, item.dueAt, item.lastSeenAt, item.firstSeenAt),
        ('과제 1 (수정)', moved, later, now),
      );
      final change = await db.select(db.lmsItemChanges).getSingle();
      expect(
        (change.remoteKey, change.field, change.oldValue, change.newValue),
        (
          item.remoteKey,
          LmsItemChangeField.dueAt,
          encodeDateTime(due),
          encodeDateTime(moved),
        ),
      );
      expect(change.changedAt, later);
      final task = await db.select(db.tasks).getSingle();
      expect(
        (task.title, task.dueAt, task.status, task.estimateMin),
        ('과제 1 (수정)', moved, TaskStatus.done, 90),
      );
      expect(applied.changedCount, 1);
    });

    test('마감이 새로 생기거나 없어져도 바뀜을 남기고(없으면 null), 제목만 바뀌면 남기지 않는다', () async {
      await ok(
        repo.applyTodoList(
          [_todo('1'), _todo('2', dueAt: due)],
          semester: _semester,
          now: now,
        ),
      );

      await ok(
        repo.applyTodoList(
          [_todo('1', dueAt: due), _todo('2', title: '새 제목', dueAt: due)],
          semester: _semester,
          now: now,
        ),
      );
      await ok(
        repo.applyTodoList(
          [_todo('1'), _todo('2', title: '새 제목', dueAt: due)],
          semester: _semester,
          now: now,
        ),
      );

      final changes = await (db.select(
        db.lmsItemChanges,
      )..orderBy([(c) => OrderingTerm(expression: c.id)])).get();
      expect(
        changes.map(
          (c) => (c.remoteKey.endsWith(':1'), c.oldValue, c.newValue),
        ),
        [(true, null, encodeDateTime(due)), (true, encodeDateTime(due), null)],
      );
    });

    test('그대로인 항목은 본 때만 고치고 바뀐 것으로 세지 않는다', () async {
      await ok(
        repo.applyTodoList(
          [_todo('1', dueAt: due)],
          semester: _semester,
          now: now,
        ),
      );
      final later = now.add(const Duration(hours: 3));

      final applied = await ok(
        repo.applyTodoList(
          [_todo('1', dueAt: due)],
          semester: _semester,
          now: later,
        ),
      );

      expect(applied.changedCount, 0);
      expect(applied.changedCourseIds, isEmpty);
      expect((await db.select(db.lmsItems).getSingle()).lastSeenAt, later);
      expect(await db.select(db.lmsItemChanges).get(), isEmpty);
    });

    test(
      '목록에 없는 이 학기 항목은 미발견 횟수를 올리고 정해진 횟수가 되면 사라진 때를 적으며, 다시 보이면 되돌린다',
      () async {
        await ok(
          repo.applyTodoList(
            [_todo('1'), _todo('2')],
            semester: _semester,
            now: now,
          ),
        );
        final courseId = (await db.select(db.courses).getSingle()).id;

        LmsListApplied? last;
        for (var i = 1; i <= Defaults.lmsGoneMissCount; i++) {
          last = await ok(
            repo.applyTodoList(
              [_todo('1')],
              semester: _semester,
              now: now.add(Duration(hours: i)),
            ),
          );
        }
        var gone =
            await (db.select(db.lmsItems)
                  ..where((i) => i.remoteKey.equals('$_semester:10/01:K1:2')))
                .getSingle();
        expect(gone.missCount, Defaults.lmsGoneMissCount);
        expect(
          gone.goneAt,
          now.add(const Duration(hours: Defaults.lmsGoneMissCount)),
        );
        expect(last!.changedCount, 1);
        expect(last.changedCourseIds, {courseId});

        final more = await ok(
          repo.applyTodoList(
            [_todo('1')],
            semester: _semester,
            now: now.add(const Duration(days: 1)),
          ),
        );
        gone = await (db.select(
          db.lmsItems,
        )..where((i) => i.id.equals(gone.id))).getSingle();
        expect(gone.missCount, Defaults.lmsGoneMissCount + 1);
        expect(
          gone.goneAt,
          now.add(const Duration(hours: Defaults.lmsGoneMissCount)),
        );
        expect(more.changedCount, 0);

        final back = await ok(
          repo.applyTodoList(
            [_todo('1'), _todo('2')],
            semester: _semester,
            now: now.add(const Duration(days: 2)),
          ),
        );
        gone = await (db.select(
          db.lmsItems,
        )..where((i) => i.id.equals(gone.id))).getSingle();
        expect((gone.missCount, gone.goneAt), (0, null));
        expect(back.changedCount, 1);
      },
    );

    test('다른 학기 항목은 건드리지 않는다', () async {
      await ok(repo.applyTodoList([_todo('1')], semester: _older, now: now));

      await ok(repo.applyTodoList([_todo('2')], semester: _semester, now: now));

      final older = await (db.select(
        db.lmsItems,
      )..where((i) => i.remoteKey.equals('$_older:10/01:K1:1'))).getSingle();
      expect(older.missCount, 0);
      expect((await db.select(db.courses).get()).map((c) => c.semester), [
        _older,
        _semester,
      ]);
    });

    test('숨긴 LMS 할 일은 다시 만들지 않는다', () async {
      await ok(repo.applyTodoList([_todo('1')], semester: _semester, now: now));
      await (db.update(db.tasks))
          .write(const TasksCompanion(status: Value(TaskStatus.hidden)));

      await ok(
        repo.applyTodoList(
          [_todo('1', title: '새 제목')],
          semester: _semester,
          now: now,
        ),
      );

      final tasks = await db.select(db.tasks).get();
      expect(tasks.map((t) => (t.title, t.status)), [
        ('새 제목', TaskStatus.hidden),
      ]);
    });

    test('빈 목록이면 이 학기 항목이 모두 미발견이다', () async {
      await ok(repo.applyTodoList([_todo('1')], semester: _semester, now: now));

      final applied = await ok(
        repo.applyTodoList(const [], semester: _semester, now: now),
      );

      expect((await db.select(db.lmsItems).getSingle()).missCount, 1);
      expect(applied.changedCount, 0);
    });
  });

  test('fnv1a64Hex는 표준 FNV-1a 64비트 값과 같다', () {
    expect(fnv1a64Hex(''), 'cbf29ce484222325');
    expect(fnv1a64Hex('a'), 'af63dc4c8601ec8c');
    expect(fnv1a64Hex('foobar'), '85944171f73967e8');
  });

  test('lmsListContentHash는 목록의 값마다 다르고 같은 값이면 같다', () {
    final base = _todo('1', dueAt: due);
    final hash = lmsListContentHash(base);

    expect(hash, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(lmsListContentHash(_todo('1', dueAt: due)), hash);
    expect(
      lmsListContentHash(_todo('9', dueAt: due)),
      hash,
      reason: '항목 ID는 키에만',
    );
    for (final other in [
      _todo('1', title: '과제 2', dueAt: due),
      _todo('1', kindCode: 'K2', dueAt: due),
      _todo('1', courseName: '운영체제', dueAt: due),
      _todo('1', dueAt: due.add(const Duration(minutes: 1))),
      _todo('1', dueAt: due, dueTimeUnknown: true),
      _todo('1'),
    ]) {
      expect(lmsListContentHash(other), isNot(hash));
    }
  });

  test('폰 DB를 쓰지 못하면 Err다', () async {
    await db.customSelect('SELECT 1').get();
    await db.close();

    final courses = await repo.upsertCourses(
      const [],
      semester: _semester,
      now: now,
    );
    final todos = await repo.applyTodoList(
      const [],
      semester: _semester,
      now: now,
    );

    expect(
      ((courses as Err).error as StorageError).operation,
      'lmsSync.upsertCourses',
    );
    expect(
      ((todos as Err).error as StorageError).operation,
      'lmsSync.applyTodoList',
    );
  });
}
