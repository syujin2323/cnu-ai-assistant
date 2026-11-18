// 시간표 새로 고침의 반영. docs/lms.md '시간표 (통합정보시스템)', docs/screens.md '13 시간표·고정 일정'.
//
// 13 시간표·고정 일정의 '새로 고침'이 보인 바뀜(`domain/timetable_refresh.dart`의 [TimetableChange]) 가운데 사용자가
// [반영하기]로 고른 것을 한 트랜잭션에서 쓰고 되돌리기를 한 번에 남긴다. 고치는 칸은 요일·시각·장소와 불러온 원래 값을
// 바꾸고(출처·장소를 고친 표시·실시간 온라인은 그대로), 지우는 칸은 그 수업 예외부터 지운다(외래 키). 견준 뒤
// 사용자가 그 칸을 고쳤거나 지웠거나 숨겼으면 그 바뀜은 건너뛴다. 빈 시간 재계산은 재계산 서비스가 표가 바뀐 것을 보고 한다
// (확정 블록은 그대로). 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:drift/drift.dart';

/// 시간표 새로 고침의 반영 저장소.
class TimetableRefreshRepository {
  TimetableRefreshRepository(this._db);

  final AppDatabase _db;

  static const _table = 'class_slots';

  /// [changes]를 반영한다. 돌려주는 값은 반영한 바뀜 수다(건너뛴 것 제외). 하나도 반영하지 않으면 되돌리기 기록을
  /// 남기지 않는다.
  Future<Result<int>> apply(
    List<TimetableChange> changes, {
    required DateTime now,
  }) => guardStorage(
    'timetableRefresh.apply',
    () => _db.transaction(() async {
      final undo = UndoRecorder(_db);
      var applied = 0;
      for (final change in changes) {
        final id = change.slot.id;
        final current = await (_db.select(
          _db.classSlots,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (current == null || !_unchanged(current, change.slot)) continue;
        switch (change) {
          case TimetableSlotUpdate(:final to, :final imported):
            await undo.before(_table, id);
            await (_db.update(
              _db.classSlots,
            )..where((t) => t.id.equals(id))).write(
              ClassSlotsCompanion(
                weekday: Value(to.weekday),
                startMin: Value(to.startMin),
                endMin: Value(to.endMin),
                place: Value(to.place),
                importedWeekday: Value(imported.weekday),
                importedStartMin: Value(imported.startMin),
                importedEndMin: Value(imported.endMin),
                importedPlace: Value(imported.place),
              ),
            );
          case TimetableSlotRemoval():
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
            await (_db.delete(
              _db.classSlots,
            )..where((t) => t.id.equals(id))).go();
        }
        applied++;
      }
      if (applied > 0) {
        await undo.write(table: _table, action: UndoAction.update, now: now);
      }
      return applied;
    }),
  );

  /// 견줄 때의 칸 [before]와 지금 칸 [now]가 반영에 쓰는 값까지 같은지.
  static bool _unchanged(ClassSlot now, ClassSlot before) =>
      now.courseId == before.courseId &&
      now.weekday == before.weekday &&
      now.startMin == before.startMin &&
      now.endMin == before.endMin &&
      now.place == before.place &&
      now.online == before.online &&
      now.placeEdited == before.placeEdited &&
      now.hidden == before.hidden &&
      now.source == before.source &&
      now.importedWeekday == before.importedWeekday &&
      now.importedStartMin == before.importedStartMin &&
      now.importedEndMin == before.importedEndMin &&
      now.importedPlace == before.importedPlace;
}
