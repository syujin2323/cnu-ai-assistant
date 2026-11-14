// 일정 저장소(`events` 표). 06 AI 비서·직접 추가 폼이 넣고, 일정 정보 시트가 고치고 지운다. 기간별
// 읽기는 `ScheduleRepository`(겹치는 일정)가 한다. 한 동작의 쓰기와 되돌리기 기록은 한 트랜잭션이다.
// 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart';

/// 일정 저장소.
class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  static const _table = 'events';

  /// 일정을 넣고 id를 돌려준다(되돌리면 지운다). 제목이 비었거나 끝이 시작보다 이르면
  /// [ArgumentError]다. [reminderMinutes]는 값만 저장한다(알림은 재설계 예정).
  Future<Result<int>> add({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    bool allDay = false,
    String? place,
    String? prep,
    int? reminderMinutes,
    required EventSource source,
    required DateTime now,
  }) {
    _check(title, startAt, endAt);
    return guardStorage(
      'events.add',
      () => _db.transaction(() async {
        final id = await _db
            .into(_db.events)
            .insert(
              EventsCompanion.insert(
                title: title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                place: Value(place),
                prep: Value(prep),
                reminderMinutes: Value(reminderMinutes),
                source: source,
              ),
            );
        final undo = UndoRecorder(_db)..inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 일정 [id]의 고칠 수 있는 값을 모두 바꾼다(되돌리면 이전 값). 일정이 없으면 false다. 제목이
  /// 비었거나 끝이 시작보다 이르면 [ArgumentError]다.
  Future<Result<bool>> update(
    int id, {
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required bool allDay,
    String? place,
    String? prep,
    int? reminderMinutes,
    required DateTime now,
  }) {
    _check(title, startAt, endAt);
    return guardStorage(
      'events.update',
      () => _db.transaction(() async {
        if (!await _exists(id)) return false;
        final undo = UndoRecorder(_db);
        await undo.before(_table, id);
        await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
          EventsCompanion(
            title: Value(title),
            startAt: Value(startAt),
            endAt: Value(endAt),
            allDay: Value(allDay),
            place: Value(place),
            prep: Value(prep),
            reminderMinutes: Value(reminderMinutes),
          ),
        );
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 일정 [id]를 지운다(되돌리면 되살린다). 일정이 없으면 false다.
  Future<Result<bool>> delete(int id, {required DateTime now}) => guardStorage(
    'events.delete',
    () => _db.transaction(() async {
      if (!await _exists(id)) return false;
      final undo = UndoRecorder(_db);
      await undo.before(_table, id);
      await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
      await undo.write(table: _table, action: UndoAction.delete, now: now);
      return true;
    }),
  );

  Future<bool> _exists(int id) async =>
      await (_db.select(
        _db.events,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  static void _check(String title, DateTime startAt, DateTime endAt) {
    if (title.trim().isEmpty) throw ArgumentError.value(title, 'title');
    if (endAt.isBefore(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'must not be before startAt');
    }
  }
}
