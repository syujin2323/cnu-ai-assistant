// 수업 칸 저장소(`class_slots` 표). docs/architecture.md '폰 DB'.
//
// 13 시간표·고정 일정의 수업 시트와 14 온보딩 2단계가 쓴다. 읽기는 출처와 관계없이 숨기지 않은 모든 수업을 과목과
// 함께 준다. 넣기는 직접 넣은 수업(`source` `manual`)만이다.
// 통합정보시스템에서 불러온 수업(`auto`)을 넣는 일과 새로 고침의 비교·반영은 LMS의 시간표 불러오기가 한다.
// 사용자가 불러온 수업을 고치면 출처와 불러온 원래 값(`imported*`)은 그대로 두고, 장소나 실시간 온라인을
// 바꿨으면 그 표시(`placeEdited`·`onlineEdited`)를 켠다. 새로 고침이 고친 값을 덮어쓰지 않게 하려는
// 것이다(docs/lms.md '시간표 (통합정보시스템)'). 수업을 빼면 직접 넣은 수업은 행을 지우고, 불러온 수업은 행을 남겨
// 숨긴다(`hidden`. 새로 고침이 학교 시간표의 그 수업을 다시 넣지 않게. 시간표 새로 고침의 비교는 숨긴 수업까지
// `LmsSyncRepository.importedSlots`로 읽는다). 수업 시트의 [직접 입력] 과목은 같은 트랜잭션에서
// `remoteId` 없이 만들고(되돌리면 함께 지움), 고를 수 있는 과목 가운데 이름이 같은 것이 있으면 그 과목을
// 쓴다. 쓰기 전에 `domain/timetable_checks.dart`의 [checkClassSlot]으로 보고, 걸리면 [ArgumentError]다
// (화면이 먼저 같은 검사로 이유를 보인다). 한 동작의 쓰기와 되돌리기 기록은 한 트랜잭션이다. 폰 DB를
// 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/course_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot_entry.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:drift/drift.dart';

/// 수업 시트에서 고른 과목.
sealed class CourseChoice {
  const CourseChoice();
}

/// 이미 있는 과목(과목 칩).
final class ChosenCourse extends CourseChoice {
  const ChosenCourse(this.id);

  /// `courses.id`.
  final int id;
}

/// [직접 입력]한 과목 이름. 앞뒤 공백을 지우고 쓴다.
final class TypedCourse extends CourseChoice {
  const TypedCourse(this.name);

  final String name;
}

/// 수업 칸 저장소.
class ClassSlotRepository {
  ClassSlotRepository(this._db);

  final AppDatabase _db;

  static const _table = 'class_slots';

  /// 숨기지 않은 모든 수업을 과목과 함께 지금 읽고, 수업이나 과목이 바뀔 때마다 다시 읽는다. 요일·시작 시각
  /// 순서이고 같으면 id 순서다.
  Stream<List<ClassSlotEntry>> watch() => _query().watch().map(_entries);

  /// [watch]와 같은 목록을 한 번 읽는다.
  Future<Result<List<ClassSlotEntry>>> read() => guardStorage(
    'class_slots.read',
    () async => _entries(await _query().get()),
  );

  /// 직접 넣은 수업을 넣고 id를 돌려준다(되돌리면 지우고, 함께 만든 과목도 지운다). [course]가 빈
  /// 이름이거나 [checkClassSlot]에 걸리면 [ArgumentError]다.
  Future<Result<int>> add({
    required CourseChoice course,
    required int weekday,
    required int startMin,
    required int endMin,
    String? place,
    required bool online,
    required DateTime now,
  }) {
    _check(course, weekday, startMin, endMin);
    return guardStorage(
      'class_slots.add',
      () => _db.transaction(() async {
        final undo = UndoRecorder(_db);
        final courseId = await _courseId(course, undo);
        final id = await _db
            .into(_db.classSlots)
            .insert(
              ClassSlotsCompanion.insert(
                courseId: courseId,
                weekday: weekday,
                startMin: startMin,
                endMin: endMin,
                place: Value(place),
                online: online,
                source: SlotSource.manual,
              ),
            );
        undo.inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 수업 [id]의 과목·요일·시각·장소·실시간 온라인을 모두 바꾼다(되돌리면 이전 값). 출처와 불러온 원래 값은
  /// 바꾸지 않고, 불러온 수업이면 장소·실시간 온라인을 바꿨을 때 그 표시를 켠다(끄지는 않음). 수업이 없거나
  /// 숨긴 수업이면 false다. [course]가 빈 이름이거나 [checkClassSlot]에 걸리면 [ArgumentError]다.
  Future<Result<bool>> update(
    int id, {
    required CourseChoice course,
    required int weekday,
    required int startMin,
    required int endMin,
    String? place,
    required bool online,
    required DateTime now,
  }) {
    _check(course, weekday, startMin, endMin);
    return guardStorage(
      'class_slots.update',
      () => _db.transaction(() async {
        final current = await (_db.select(
          _db.classSlots,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (current == null || current.hidden) return false;
        final undo = UndoRecorder(_db);
        final courseId = await _courseId(course, undo);
        await undo.before(_table, id);
        final imported = current.source == SlotSource.auto;
        await (_db.update(_db.classSlots)..where((t) => t.id.equals(id))).write(
          ClassSlotsCompanion(
            courseId: Value(courseId),
            weekday: Value(weekday),
            startMin: Value(startMin),
            endMin: Value(endMin),
            place: Value(place),
            online: Value(online),
            placeEdited: imported && place != current.place
                ? const Value(true)
                : const Value.absent(),
            onlineEdited: imported && online != current.online
                ? const Value(true)
                : const Value.absent(),
          ),
        );
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 수업 [id]를 시간표에서 뺀다. 직접 넣은 수업은 행을 지우고, 불러온 수업(`source` `auto`)은 행을 남겨 숨긴다
  /// ([ClassSlot.hidden]. docs/decisions.md 2026-11-19 '뺀 불러온 수업은 숨겨 두고 새로 고침이 다시 넣지 않는다').
  /// 어느 쪽이든 그 수업의 수업 예외는 지우고(외래 키 때문에 예외부터), 되돌리면 함께 되살린다. 과목은 지우지
  /// 않는다. 수업이 없거나 이미 숨긴 수업이면 false다.
  Future<Result<bool>> delete(int id, {required DateTime now}) => guardStorage(
    'class_slots.delete',
    () => _db.transaction(() async {
      final current = await (_db.select(
        _db.classSlots,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (current == null || current.hidden) return false;
      final undo = UndoRecorder(_db);
      final exceptions = _db.classExceptions;
      final exceptionIds =
          await (_db.selectOnly(exceptions)
                ..addColumns([exceptions.id])
                ..where(exceptions.classSlotId.equals(id))
                ..orderBy([OrderingTerm(expression: exceptions.id)]))
              .map((row) => row.read(exceptions.id)!)
              .get();
      for (final exceptionId in exceptionIds) {
        await undo.before('class_exceptions', exceptionId);
      }
      await (_db.delete(
        exceptions,
      )..where((t) => t.classSlotId.equals(id))).go();
      await undo.before(_table, id);
      if (current.source == SlotSource.auto) {
        await (_db.update(_db.classSlots)..where((t) => t.id.equals(id))).write(
          const ClassSlotsCompanion(hidden: Value(true)),
        );
      } else {
        await (_db.delete(_db.classSlots)..where((t) => t.id.equals(id))).go();
      }
      await undo.write(table: _table, action: UndoAction.delete, now: now);
      return true;
    }),
  );

  JoinedSelectStatement<HasResultSet, dynamic> _query() =>
      _db.select(_db.classSlots).join([
          innerJoin(
            _db.courses,
            _db.courses.id.equalsExp(_db.classSlots.courseId),
          ),
        ])
        ..where(_db.classSlots.hidden.equals(false))
        ..orderBy([
          OrderingTerm(expression: _db.classSlots.weekday),
          OrderingTerm(expression: _db.classSlots.startMin),
          OrderingTerm(expression: _db.classSlots.id),
        ]);

  List<ClassSlotEntry> _entries(List<TypedResult> rows) => [
    for (final row in rows)
      ClassSlotEntry(
        slot: row.readTable(_db.classSlots),
        course: row.readTable(_db.courses),
      ),
  ];

  /// [course]의 과목 id. [직접 입력]이면 고를 수 있는 같은 이름 과목(LMS 과목 먼저)을 쓰고, 없으면 새로
  /// 만들어 [undo]에 담는다.
  Future<int> _courseId(CourseChoice course, UndoRecorder undo) async {
    switch (course) {
      case ChosenCourse(:final id):
        return id;
      case TypedCourse(:final name):
        final trimmed = name.trim();
        final same = await (selectableCourses(
          _db,
          name: trimmed,
        )..limit(1)).getSingleOrNull();
        if (same != null) return same.id;
        final id = await _db
            .into(_db.courses)
            .insert(CoursesCompanion.insert(name: trimmed));
        undo.inserted('courses', id);
        return id;
    }
  }

  static void _check(
    CourseChoice course,
    int weekday,
    int startMin,
    int endMin,
  ) {
    if (course case TypedCourse(:final name) when name.trim().isEmpty) {
      throw ArgumentError.value(name, 'course');
    }
    final issues = checkClassSlot(
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
    );
    if (issues.isNotEmpty) {
      throw ArgumentError.value(issues, 'class slot', 'invalid');
    }
  }
}
