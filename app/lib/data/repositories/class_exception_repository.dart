// 수업 예외 저장소(`class_exceptions` 표). docs/architecture.md '폰 DB'·'도메인 기본값과 배치 엔진' 1단계.
//
// 일정 정보 시트의 '{날짜 말} 수업만 바꾸기'(휴강·시험·장소 변경, 다시 누르면 원래대로)와 06 AI 비서의 수업
// 변경이 쓴다. 한 수업의 하루에는 휴강·시험·장소 변경 가운데 하나만 두고([setDayChange]가 바꿔 끼움),
// 보강은 그와 따로 넣는다([addMakeup]). 불러온 수업의 예외도 여기서 쓴다. 기간별 읽기는
// `ScheduleRepository`가 한다. 날짜는 그 수업이 시작하는 달력 날짜다(수업 칸의 요일과 같은 기준). 한
// 동작의 쓰기와 되돌리기 기록은 한 트랜잭션이다. 폰 DB를 읽거나 쓰지 못하면(수업이 없어 넣지 못한 경우
// 포함) [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:drift/drift.dart';

/// 수업 예외 저장소.
class ClassExceptionRepository {
  ClassExceptionRepository(this._db);

  final AppDatabase _db;

  static const _table = 'class_exceptions';

  /// 그날 하루만 바뀌는 종류. 한 수업의 하루에 이 가운데 하나만 둔다. 보강은 [addMakeup]으로 따로 넣는다.
  static const dayChangeKinds = [
    ClassExceptionKind.cancelled,
    ClassExceptionKind.exam,
    ClassExceptionKind.placeChange,
  ];

  /// 수업 [classSlotId]의 [date](날짜만 씀) 하루를 [kind]로 바꾼다. 그날의 이전 휴강·시험·장소 변경은
  /// 지우고(보강은 그대로), [kind]가 null이면 원래대로 돌린다. 되돌리면 이전 상태다. 이미 그 상태면
  /// 아무것도 쓰지 않고 false다. [place]는 장소 변경의 새 장소(꼭 있어야 함)나 시험 장소(없어도 됨)다.
  /// [kind]가 보강이거나, 장소 변경에 [place]가 비었거나, 휴강·원래대로에 [place]를 주면
  /// [ArgumentError]다.
  Future<Result<bool>> setDayChange(
    int classSlotId,
    DateTime date, {
    required ClassExceptionKind? kind,
    String? place,
    required EntrySource source,
    required DateTime now,
  }) {
    if (kind == ClassExceptionKind.makeup) {
      throw ArgumentError.value(kind, 'kind', 'use addMakeup');
    }
    if (kind == ClassExceptionKind.placeChange) {
      if (place == null || place.trim().isEmpty) {
        throw ArgumentError.value(place, 'place');
      }
    } else if (kind != ClassExceptionKind.exam && place != null) {
      throw ArgumentError.value(place, 'place');
    }
    final day = isoDate(date);
    return guardStorage(
      'class_exceptions.setDayChange',
      () => _db.transaction(() async {
        final t = _db.classExceptions;
        final current =
            await (_db.selectOnly(t)
                  ..addColumns([t.id, t.kind, t.place])
                  ..where(
                    t.classSlotId.equals(classSlotId) &
                        t.date.equals(day) &
                        t.kind.isInValues(dayChangeKinds),
                  )
                  ..orderBy([OrderingTerm(expression: t.id)]))
                .get();
        final unchanged = kind == null
            ? current.isEmpty
            : current.length == 1 &&
                  current.single.readWithConverter(t.kind) == kind &&
                  current.single.read(t.place) == place;
        if (unchanged) return false;
        final undo = UndoRecorder(_db);
        final ids = [for (final row in current) row.read(t.id)!];
        for (final id in ids) {
          await undo.before(_table, id);
        }
        await (_db.delete(t)..where((e) => e.id.isIn(ids))).go();
        if (kind != null) {
          final id = await _db
              .into(t)
              .insert(
                ClassExceptionsCompanion.insert(
                  date: day,
                  classSlotId: classSlotId,
                  kind: kind,
                  place: Value(place),
                  source: source,
                ),
              );
          undo.inserted(_table, id);
        }
        await undo.write(
          table: _table,
          action: kind == null
              ? UndoAction.delete
              : ids.isEmpty
              ? UndoAction.insert
              : UndoAction.update,
          now: now,
        );
        return true;
      }),
    );
  }

  /// 수업 [classSlotId]의 보강을 [date](날짜만 씀)에 넣고 id를 돌려준다(되돌리면 지운다). 보강
  /// 시각([startMin]·[endMin], 그 날짜 0시 기준 분)이 없으면 그 수업의 평소 시각에 보강한다.
  /// [checkMakeupTime]에 걸리면 [ArgumentError]다.
  Future<Result<int>> addMakeup(
    int classSlotId,
    DateTime date, {
    int? startMin,
    int? endMin,
    String? place,
    required EntrySource source,
    required DateTime now,
  }) {
    final issues = checkMakeupTime(startMin: startMin, endMin: endMin);
    if (issues.isNotEmpty) {
      throw ArgumentError.value(issues, 'makeup time', 'invalid');
    }
    return guardStorage(
      'class_exceptions.addMakeup',
      () => _db.transaction(() async {
        final id = await _db
            .into(_db.classExceptions)
            .insert(
              ClassExceptionsCompanion.insert(
                date: isoDate(date),
                classSlotId: classSlotId,
                kind: ClassExceptionKind.makeup,
                place: Value(place),
                source: source,
                startMin: Value(startMin),
                endMin: Value(endMin),
              ),
            );
        final undo = UndoRecorder(_db)..inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 수업 예외 [id]를 지운다(되돌리면 되살린다). 없으면 false다.
  Future<Result<bool>> delete(int id, {required DateTime now}) => guardStorage(
    'class_exceptions.delete',
    () => _db.transaction(() async {
      final t = _db.classExceptions;
      final exists =
          await (_db.selectOnly(t)
                ..addColumns([t.id])
                ..where(t.id.equals(id)))
              .getSingleOrNull() !=
          null;
      if (!exists) return false;
      final undo = UndoRecorder(_db);
      await undo.before(_table, id);
      await (_db.delete(t)..where((e) => e.id.equals(id))).go();
      await undo.write(table: _table, action: UndoAction.delete, now: now);
      return true;
    }),
  );
}
