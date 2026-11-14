// 할 일 저장소(`tasks` 표). docs/architecture.md '폰 DB'·'도메인 기본값과 배치 엔진' 5단계.
//
// 목록은 숨긴 LMS 할 일을 뺀 할 일을 LMS 원본·과목과 함께 [TaskEntry]로 준다(끝냈는지·사라졌는지는
// [TaskEntry]가 판단). 동기화가 `title`·`kind`·`dueAt`·`dueTimeUnknown`을 다시 복사하므로, 고치는 동작은
// 바꾸는 사용자 열만 [UndoRecorder.beforeColumns]로 담아 되돌릴 때 그사이 동기화가 바꾼 복사 열을 되돌리지
// 않는다. 할 일을 끝내거나 지우면 아직 시작하지 않은 확정 블록을 지운다(제안 블록은 다음 재계산이 다시
// 만든다). 한 동작의 쓰기와 되돌리기 기록은 한 트랜잭션이다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를
// 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart';

/// 할 일 저장소.
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  static const _table = 'tasks';

  /// 숨기지 않은 할 일을 LMS 원본·과목과 함께 지금 읽고, 할 일·LMS 원본·과목이 바뀔 때마다 다시 읽는다.
  /// 마감순(마감 없는 일은 맨 뒤)이고 같으면 id 순서다.
  Stream<List<TaskEntry>> watch() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.tasks, _db.lmsItems, _db.courses},
      )
      .watch()
      .asyncMap((_) => _read());

  /// [watch]와 같은 목록을 한 번 읽는다.
  Future<Result<List<TaskEntry>>> read() =>
      guardStorage('tasks.read', () => _db.transaction(_read));

  /// 직접 추가 폼·06 AI 비서가 만든 할 일을 넣고 id를 돌려준다(되돌리면 지운다).
  ///
  /// 제목이 비었거나, LMS '자료'이거나, 예상 시간이 0 이하이거나, 개인 할 일에 과목을 두면
  /// [ArgumentError]다(개인 할 일은 과목이 없고 과목 할 일의 종류에 '개인'이 없다).
  Future<Result<int>> add({
    required String title,
    required TaskKind kind,
    DateTime? dueAt,
    bool dueTimeUnknown = false,
    int? estimateMin,
    int? courseId,
    required EntrySource source,
    required DateTime now,
  }) {
    if (title.trim().isEmpty) throw ArgumentError.value(title, 'title');
    if (kind == TaskKind.material) throw ArgumentError.value(kind, 'kind');
    if (estimateMin != null && estimateMin <= 0) {
      throw ArgumentError.value(estimateMin, 'estimateMin');
    }
    if (kind == TaskKind.personal && courseId != null) {
      throw ArgumentError.value(courseId, 'courseId', 'personal task');
    }
    return guardStorage(
      'tasks.add',
      () => _db.transaction(() async {
        final id = await _db
            .into(_db.tasks)
            .insert(
              TasksCompanion.insert(
                title: title,
                kind: kind,
                dueAt: Value(dueAt),
                dueTimeUnknown: dueTimeUnknown,
                estimateMin: Value(estimateMin),
                status: TaskStatus.todo,
                courseId: Value(courseId),
                source: Value(source),
              ),
            );
        final undo = UndoRecorder(_db)..inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 할 일을 끝낸다(03 할 일의 동그라미). 끝낸 시각을 [now]로 적고 아직 시작하지 않은 확정 블록을
  /// 지운다. 할 일이 없거나 남은 일(`todo`)이 아니면 false다.
  Future<Result<bool>> complete(int id, {required DateTime now}) =>
      guardStorage(
        'tasks.complete',
        () => _db.transaction(() async {
          final task = await _byId(id);
          if (task == null || task.status != TaskStatus.todo) return false;
          final undo = UndoRecorder(_db);
          await undo.beforeColumns(_table, id, const {
            'status',
            'completed_at',
          });
          await _write(
            id,
            TasksCompanion(
              status: const Value(TaskStatus.done),
              completedAt: Value(now),
            ),
          );
          await _deleteUpcomingConfirmed(id, now, undo);
          await undo.write(table: _table, action: UndoAction.update, now: now);
          return true;
        }),
      );

  /// 끝낸 할 일을 다시 남은 일로 돌린다(동그라미를 다시 누름). 지운 블록은 되살리지 않고 다음 재계산이
  /// 다시 놓는다. 할 일이 없거나 끝낸 일이 아니면 false다.
  Future<Result<bool>> reopen(int id, {required DateTime now}) => guardStorage(
    'tasks.reopen',
    () => _db.transaction(() async {
      final task = await _byId(id);
      if (task == null || task.status != TaskStatus.done) return false;
      final undo = UndoRecorder(_db);
      await undo.beforeColumns(_table, id, const {'status', 'completed_at'});
      await _write(
        id,
        const TasksCompanion(
          status: Value(TaskStatus.todo),
          completedAt: Value(null),
        ),
      );
      await undo.write(table: _table, action: UndoAction.update, now: now);
      return true;
    }),
  );

  /// '얼마나 걸렸어요?'에 답한 걸린 시간(분)을 적는다. [minutes]가 0 이하면 [ArgumentError]다. 할 일이
  /// 없으면 false다.
  Future<Result<bool>> setActualMin(
    int id,
    int minutes, {
    required DateTime now,
  }) {
    if (minutes <= 0) throw ArgumentError.value(minutes, 'minutes');
    return guardStorage(
      'tasks.setActualMin',
      () => _db.transaction(() async {
        if (await _byId(id) == null) return false;
        final undo = UndoRecorder(_db);
        await undo.beforeColumns(_table, id, const {'actual_min'});
        await _write(id, TasksCompanion(actualMin: Value(minutes)));
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 할 일을 지운다. LMS 할 일은 행을 남기고 숨기며(`hidden`. 동기화가 다시 만들지 않음), 직접 넣은
  /// 할 일은 그 블록과 함께 행을 지운다. LMS 할 일도 아직 시작하지 않은 확정 블록은 지운다. 할 일이
  /// 없거나 이미 숨겼으면 false다.
  Future<Result<bool>> remove(int id, {required DateTime now}) => guardStorage(
    'tasks.remove',
    () => _db.transaction(() async {
      final task = await _byId(id);
      if (task == null || task.status == TaskStatus.hidden) return false;
      final undo = UndoRecorder(_db);
      if (task.lmsKey != null) {
        await undo.beforeColumns(_table, id, const {'status'});
        await _write(
          id,
          const TasksCompanion(status: Value(TaskStatus.hidden)),
        );
        await _deleteUpcomingConfirmed(id, now, undo);
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }
      final blocks = await (_db.select(
        _db.planBlocks,
      )..where((b) => b.taskId.equals(id))).get();
      for (final block in blocks) {
        await undo.before('plan_blocks', block.id);
      }
      await (_db.delete(
        _db.planBlocks,
      )..where((b) => b.taskId.equals(id))).go();
      await undo.before(_table, id);
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
      await undo.write(table: _table, action: UndoAction.delete, now: now);
      return true;
    }),
  );

  Future<List<TaskEntry>> _read() async {
    final rows =
        await (_db.select(_db.tasks).join([
                leftOuterJoin(
                  _db.lmsItems,
                  _db.lmsItems.remoteKey.equalsExp(_db.tasks.lmsKey),
                ),
              ])
              ..where(_db.tasks.status.equalsValue(TaskStatus.hidden).not())
              ..orderBy([
                OrderingTerm(expression: _db.tasks.dueAt.isNull()),
                OrderingTerm(expression: _db.tasks.dueAt),
                OrderingTerm(expression: _db.tasks.id),
              ]))
            .get();
    final courses = <int, Course>{
      for (final course in await _db.select(_db.courses).get())
        course.id: course,
    };
    return [
      for (final row in rows)
        _entry(
          row.readTable(_db.tasks),
          row.readTableOrNull(_db.lmsItems),
          courses,
        ),
    ];
  }

  static TaskEntry _entry(
    Task task,
    LmsItem? lmsItem,
    Map<int, Course> courses,
  ) {
    final courseId = task.courseIdWith(lmsItem);
    return TaskEntry(
      task: task,
      lmsItem: lmsItem,
      course: courseId == null ? null : courses[courseId],
    );
  }

  Future<Task?> _byId(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _write(int id, TasksCompanion values) =>
      (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(values);

  /// [taskId]의 확정 블록 가운데 [now]보다 늦게 시작하는 것을 담고 지운다.
  Future<void> _deleteUpcomingConfirmed(
    int taskId,
    DateTime now,
    UndoRecorder undo,
  ) async {
    final upcoming =
        await (_db.select(_db.planBlocks)..where(
              (b) =>
                  b.taskId.equals(taskId) &
                  b.status.equalsValue(PlanBlockStatus.confirmed) &
                  b.startAt.isBiggerThanValue(kstToUtc(now)),
            ))
            .get();
    if (upcoming.isEmpty) return;
    for (final block in upcoming) {
      await undo.before('plan_blocks', block.id);
    }
    await (_db.delete(
      _db.planBlocks,
    )..where((b) => b.id.isIn([for (final block in upcoming) block.id]))).go();
  }
}
