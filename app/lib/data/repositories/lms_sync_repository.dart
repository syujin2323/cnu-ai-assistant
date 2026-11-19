// LMS 동기화가 받은 원본을 폰 DB에 쓰는 저장소. docs/lms.md '동기화', docs/architecture.md '폰 DB'.
//
// 동기화가 쓰는 표는 `courses`, `lms_items`, `lms_item_changes`와 `tasks`의 복사 열(제목·종류·마감·마감 시각
// 모름)뿐이다. 시간표 불러오기는 여기에 더해 불러온 수업 칸(`class_slots`의 `source` `auto`)을 넣는다. 사용자의 계획(블록)과 사용자 값(상태·예상 시간 등)은 바꾸지 않고 되돌리기 기록도 남기지 않는다.
// 응답 하나를 한 트랜잭션으로 쓰고 그 안에서 네트워크를 기다리지 않는다. LMS 데이터는 앱 모드와 관계없이 실제
// DB(`app.sqlite`)에 있다(데모에서는 동기화하지 않음). 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은
// [Err]다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/lms_to_task.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart' show LmsItemKind;
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/parsers/todo_list_parser.dart';
import 'package:drift/drift.dart';

/// 할 일 목록을 쓴 결과.
final class LmsListApplied {
  const LmsListApplied({
    required this.changedCount,
    required this.changedCourseIds,
  });

  /// 새로 보였거나, 내용이 바뀌었거나, 사라졌다가 다시 보였거나, 이번에 사라진 것으로 본 항목 수.
  final int changedCount;

  /// 그 항목들의 과목(`courses.id`). 갱신(`list`) 동기화가 이 과목만 상세를 이어서 한다.
  final Set<int> changedCourseIds;
}

/// LMS 원본 저장소.
class LmsSyncRepository {
  LmsSyncRepository(this._db);

  final AppDatabase _db;

  /// 이번 학기([semester]) LMS 과목(`courses.id`)과 그 과목들의 불러온 수업(`source` `auto`). 시간표 새로 고침이
  /// 견줄 때 쓴다(`domain/timetable_refresh.dart`). 사용자가 뺀(숨긴) 수업도 넣어, 새로 고침이 그 수업을 새 수업으로
  /// 다시 넣지 않게 한다.
  Future<Result<({Set<int> courseIds, List<ClassSlot> slots})>> importedSlots({
    required String semester,
  }) => guardStorage(
    'lmsSync.importedSlots',
    () => _db.transaction(() async {
      final courses = _db.courses;
      final courseIds =
          (await (_db.selectOnly(courses)
                    ..addColumns([courses.id])
                    ..where(
                      courses.semester.equals(semester) &
                          courses.remoteId.isNotNull(),
                    ))
                  .map((row) => row.read(courses.id)!)
                  .get())
              .toSet();
      final slots =
          await (_db.select(_db.classSlots)..where(
                (t) =>
                    t.source.equalsValue(SlotSource.auto) &
                    t.courseId.isIn(courseIds),
              ))
              .get();
      return (courseIds: courseIds, slots: slots);
    }),
  );

  /// 시간표 불러오기가 정한 새 수업 칸 [slotsByCourse](`courses.id` → 칸)를 불러온 수업(`source` `auto`)으로 넣는다.
  /// 돌려주는 값은 넣은 칸 수다.
  ///
  /// 어떤 칸을 넣을지는 견준 결과(`domain/timetable_refresh.dart`의 [TimetableDiff.added])가 정한다. 넣는 칸의 불러온
  /// 원래 값(`imported*`)은 그 칸의 값과 같고, 실시간 온라인은 아님이다(시간표에 없어 사용자가 13 시간표에서 고침).
  /// 사용자 동작이 아니므로 되돌리기 기록은 남기지 않는다.
  Future<Result<int>> addImportedSlots(
    Map<int, List<ImportedClassSlot>> slotsByCourse,
  ) => guardStorage(
    'lmsSync.addImportedSlots',
    () => _db.transaction(() async {
      var added = 0;
      for (final MapEntry(key: courseId, value: slots)
          in slotsByCourse.entries) {
        for (final slot in slots) {
          await _db
              .into(_db.classSlots)
              .insert(
                ClassSlotsCompanion.insert(
                  courseId: courseId,
                  weekday: slot.weekday,
                  startMin: slot.startMin,
                  endMin: slot.endMin,
                  place: Value(slot.place),
                  online: false,
                  source: SlotSource.auto,
                  importedWeekday: Value(slot.weekday),
                  importedStartMin: Value(slot.startMin),
                  importedEndMin: Value(slot.endMin),
                  importedPlace: Value(slot.place),
                ),
              );
          added++;
        }
      }
      return added;
    }),
  );

  /// 과목 목록 [records]를 학기 값 [semester]로 쓴다. 돌려주는 값은 과목 원본 ID → `courses.id`다.
  ///
  /// 원본 ID와 학기가 같은 과목은 이름과 [now](마지막으로 본 때)만 고친다. 없으면, 이 학기가 폰 DB의 LMS
  /// 과목 가운데 가장 최근(정렬했을 때 가장 큰) 학기일 때 이름이 같고 원본 ID가 없는 과목(직접 만든 과목)에
  /// 원본 ID와 학기를 채워 합치고, 그런 과목도 없으면 새로 만든다. 한 응답에 같은 과목이 두 번 오면 처음
  /// 것만 쓴다.
  Future<Result<Map<String, int>>> upsertCourses(
    List<LmsCourseRecord> records, {
    required String semester,
    required DateTime now,
  }) => guardStorage(
    'lmsSync.upsertCourses',
    () => _db.transaction(() async {
      final existing = await _db.select(_db.courses).get();
      final known = existing.map((c) => c.semester).nonNulls;
      final latest = known.every((s) => semester.compareTo(s) >= 0);
      final merged = <int>{};
      final ids = <String, int>{};
      for (final record in records) {
        if (ids.containsKey(record.remoteId)) continue;
        final same = existing
            .where(
              (c) => c.remoteId == record.remoteId && c.semester == semester,
            )
            .firstOrNull;
        if (same != null) {
          await _updateCourse(
            same.id,
            CoursesCompanion(name: Value(record.name), lastSeenAt: Value(now)),
          );
          ids[record.remoteId] = same.id;
          continue;
        }
        final manual = latest
            ? existing
                  .where(
                    (c) =>
                        c.remoteId == null &&
                        c.name == record.name &&
                        !merged.contains(c.id),
                  )
                  .firstOrNull
            : null;
        if (manual != null) {
          merged.add(manual.id);
          await _updateCourse(
            manual.id,
            CoursesCompanion(
              remoteId: Value(record.remoteId),
              semester: Value(semester),
              lastSeenAt: Value(now),
            ),
          );
          ids[record.remoteId] = manual.id;
          continue;
        }
        ids[record.remoteId] = await _insertCourse(
          remoteId: record.remoteId,
          name: record.name,
          semester: semester,
          now: now,
        );
      }
      return ids;
    }),
  );

  /// '정상'이나 '빈 목록'으로 끝난 할 일 목록 조회의 결과 [todos]를 학기 값 [semester]로 쓴다.
  ///
  /// - 새 항목은 넣고, 있던 항목은 [now](마지막으로 본 때)를 고치고 연속 미발견 횟수를 0으로 되돌린다. 목록의
  ///   내용(제목·종류 코드·과목명·마감·마감 시각 모름, [lmsListContentHash])이 바뀌었으면 그 값도 고치고, 마감이
  ///   바뀌었으면 `lms_item_changes`에 남긴다(값은 [encodeDateTime] 꼴, 없으면 null).
  /// - 이 학기 항목 가운데 목록에 없는 것은 연속 미발견 횟수를 1 올리고, [Defaults.lmsGoneMissCount]가 되면
  ///   사라진 때를 적는다. LMS가 제출·출석 인정을 알려 준 항목은 끝나서 목록에서 빠질 수 있으므로 세지 않는다.
  ///   다른 학기 항목은 건드리지 않는다.
  /// - 과목 목록에 없던 과목의 항목이면 그 과목을 만든다(갱신은 과목 목록을 받지 않으므로).
  /// - 마지막에 [tasksFromLmsItems]로 할 일을 만들거나 복사 열을 다시 복사한다.
  Future<Result<LmsListApplied>> applyTodoList(
    List<LmsTodoRecord> todos, {
    required String semester,
    required DateTime now,
  }) => guardStorage(
    'lmsSync.applyTodoList',
    () => _db.transaction(() async {
      final courseIds = {
        for (final c in await (_db.select(
          _db.courses,
        )..where((c) => c.semester.equals(semester))).get())
          ?c.remoteId: c.id,
      };
      final prefix = '$semester:';
      final existing = {
        for (final item in await _db.select(_db.lmsItems).get())
          if (item.remoteKey.startsWith(prefix)) item.remoteKey: item,
      };
      final seen = <String>{};
      final changedCourses = <int>{};
      var changed = 0;

      for (final todo in todos) {
        final key = todo.remoteKey(semester);
        if (!seen.add(key)) continue;
        final courseId = courseIds[todo.courseRemoteId] ??= await _insertCourse(
          remoteId: todo.courseRemoteId,
          name: todo.courseName,
          semester: semester,
          now: now,
        );
        final hash = lmsListContentHash(todo);
        final old = existing[key];
        if (old == null) {
          await _db
              .into(_db.lmsItems)
              .insert(
                LmsItemsCompanion.insert(
                  remoteKey: key,
                  courseId: courseId,
                  courseName: todo.courseName,
                  title: todo.title,
                  kind: todo.kind,
                  dueAt: Value(todo.dueAt),
                  dueTimeUnknown: todo.dueTimeUnknown,
                  firstSeenAt: now,
                  lastSeenAt: now,
                  missCount: 0,
                  contentHash: hash,
                ),
              );
          changed++;
          changedCourses.add(courseId);
          continue;
        }
        final contentChanged = old.contentHash != hash;
        var update = LmsItemsCompanion(
          lastSeenAt: Value(now),
          missCount: const Value(0),
          goneAt: const Value(null),
        );
        if (contentChanged) {
          update = update.copyWith(
            courseId: Value(courseId),
            courseName: Value(todo.courseName),
            title: Value(todo.title),
            kind: Value(todo.kind),
            dueAt: Value(todo.dueAt),
            dueTimeUnknown: Value(todo.dueTimeUnknown),
            contentHash: Value(hash),
          );
          if (old.dueAt != todo.dueAt) {
            await _db
                .into(_db.lmsItemChanges)
                .insert(
                  LmsItemChangesCompanion.insert(
                    remoteKey: key,
                    field: LmsItemChangeField.dueAt,
                    oldValue: Value(_encodeDue(old.dueAt)),
                    newValue: Value(_encodeDue(todo.dueAt)),
                    changedAt: now,
                  ),
                );
          }
        }
        await (_db.update(
          _db.lmsItems,
        )..where((i) => i.id.equals(old.id))).write(update);
        if (contentChanged || old.goneAt != null) {
          changed++;
          changedCourses.add(courseId);
        }
      }

      for (final item in existing.values) {
        if (seen.contains(item.remoteKey)) continue;
        // 끝낸 항목은 '진행 중' 목록에서 빠져도 사라진 것이 아니다(끝낸 목록이 다시 본 것으로 적음).
        if (item.submitted == true || item.officiallyDone == true) continue;
        final missCount = item.missCount + 1;
        final goneNow =
            item.goneAt == null && missCount >= Defaults.lmsGoneMissCount;
        await (_db.update(
          _db.lmsItems,
        )..where((i) => i.id.equals(item.id))).write(
          LmsItemsCompanion(
            missCount: Value(missCount),
            goneAt: goneNow ? Value(now) : const Value.absent(),
          ),
        );
        if (goneNow) {
          changed++;
          changedCourses.add(item.courseId);
        }
      }

      await _applyTasks(seen);
      return LmsListApplied(
        changedCount: changed,
        changedCourseIds: changedCourses,
      );
    }),
  );

  /// 끝낸 할 일 목록(할 일 목록을 '완료' 필터로 받은 것, docs/lms.md '동기화')을 쓴다. 바뀐 항목 수를 돌려준다.
  ///
  /// - 목록의 항목 가운데 이미 받은 이 학기 항목만 LMS가 끝냈다고 적는다. 영상은 출석 인정(`officiallyDone`), 그 밖은
  ///   제출(`submitted`)이고, 바뀌면 `lms_item_changes`에 남긴다(`true`).
  /// - 그 항목은 LMS에 있으므로 다시 본 것으로 둔다(연속 미발견 0, 사라진 때 지움).
  /// - 받은 적 없는 항목은 넣지 않는다(끝낸 일을 새 할 일로 만들지 않음). 목록에 없다고 끝냄을 되돌리지 않는다.
  Future<Result<int>> applyCompletion(
    List<LmsTodoRecord> done, {
    required String semester,
    required DateTime now,
  }) => guardStorage(
    'lmsSync.applyCompletion',
    () => _db.transaction(() async {
      final keys = {for (final todo in done) todo.remoteKey(semester)};
      if (keys.isEmpty) return 0;
      final items = await (_db.select(
        _db.lmsItems,
      )..where((i) => i.remoteKey.isIn(keys))).get();
      var changed = 0;
      for (final item in items) {
        final video = item.kind == LmsItemKind.video;
        final already = video ? item.officiallyDone : item.submitted;
        final markDone = already != true;
        final restored = item.goneAt != null;
        var update = LmsItemsCompanion(
          lastSeenAt: Value(now),
          missCount: const Value(0),
          goneAt: const Value(null),
        );
        if (markDone) {
          update = video
              ? update.copyWith(officiallyDone: const Value(true))
              : update.copyWith(submitted: const Value(true));
          await _db
              .into(_db.lmsItemChanges)
              .insert(
                LmsItemChangesCompanion.insert(
                  remoteKey: item.remoteKey,
                  field: video
                      ? LmsItemChangeField.officiallyDone
                      : LmsItemChangeField.submitted,
                  oldValue: Value(already?.toString()),
                  newValue: const Value('true'),
                  changedAt: now,
                ),
              );
        }
        await (_db.update(
          _db.lmsItems,
        )..where((i) => i.id.equals(item.id))).write(update);
        if (markDone || restored) changed++;
      }
      return changed;
    }),
  );

  /// 목록에서 본 항목 [keys]로 할 일을 만들거나 복사 열을 다시 복사한다.
  Future<void> _applyTasks(Set<String> keys) async {
    if (keys.isEmpty) return;
    final items = await (_db.select(
      _db.lmsItems,
    )..where((i) => i.remoteKey.isIn(keys))).get();
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.lmsKey.isNotNull())).get();
    final changes = tasksFromLmsItems(items, tasks);
    for (final draft in changes.inserts) {
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              title: draft.title,
              kind: draft.kind,
              dueAt: Value(draft.dueAt),
              dueTimeUnknown: draft.dueTimeUnknown,
              status: TaskStatus.todo,
              lmsKey: Value(draft.lmsKey),
            ),
          );
    }
    for (final copy in changes.copies) {
      await (_db.update(
        _db.tasks,
      )..where((t) => t.id.equals(copy.taskId))).write(
        TasksCompanion(
          title: Value(copy.title),
          kind: Value(copy.kind),
          dueAt: Value(copy.dueAt),
          dueTimeUnknown: Value(copy.dueTimeUnknown),
        ),
      );
    }
  }

  Future<int> _insertCourse({
    required String remoteId,
    required String name,
    required String semester,
    required DateTime now,
  }) => _db
      .into(_db.courses)
      .insert(
        CoursesCompanion.insert(
          name: name,
          remoteId: Value(remoteId),
          semester: Value(semester),
          lastSeenAt: Value(now),
        ),
      );

  Future<void> _updateCourse(int id, CoursesCompanion values) =>
      (_db.update(_db.courses)..where((c) => c.id.equals(id))).write(values);

  static String? _encodeDue(DateTime? value) =>
      value == null ? null : encodeDateTime(value);
}

/// 할 일 목록에서 받은 값(제목·종류 코드·과목명·마감·마감 시각 모름)의 해시. `lms_items.contentHash`에 두고
/// 다음 동기화에서 바뀐 항목을 가린다(같은 값이면 늘 같은 해시).
String lmsListContentHash(LmsTodoRecord todo) => fnv1a64Hex(
  [
    todo.title,
    todo.kindCode,
    todo.courseName,
    todo.dueAt == null ? '' : encodeDateTime(todo.dueAt!),
    todo.dueTimeUnknown ? '1' : '0',
  ].join('\u0000'),
);

/// [text]의 UTF-8 바이트로 구한 FNV-1a 64비트 해시를 16진수 16자리로 적는다.
String fnv1a64Hex(String text) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(text)) {
    hash ^= byte;
    hash *= 0x100000001b3;
  }
  // int는 부호 있는 64비트라 위아래 32비트를 따로 적는다.
  return '${_hex32(hash >> 32)}${_hex32(hash)}';
}

String _hex32(int value) =>
    (value & 0xffffffff).toRadixString(16).padLeft(8, '0');
