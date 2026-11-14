// 고정 일정 저장소(`fixed_blocks` 표). 14 온보딩 3단계, 13 시간표·고정 일정, 06 AI 비서·직접 추가 폼의 반복
// 일정이 쓴다. 쓰기 전에 `domain/timetable_checks.dart`의 [checkFixedBlock]으로 보고, 걸리면
// [ArgumentError]다(부르는 쪽이 먼저 같은 검사로 이유를 보인다. CHECK는 마지막 방어선). 요일은 정렬해 둔다.
// 한 동작의 쓰기와 되돌리기 기록은 한 트랜잭션이다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은
// [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:drift/drift.dart';

/// 고정 일정 저장소.
class FixedBlockRepository {
  FixedBlockRepository(this._db);

  final AppDatabase _db;

  static const _table = 'fixed_blocks';

  /// 모든 고정 일정을 지금 읽고 바뀔 때마다 다시 읽는다. 시작 시각 순서이고 같으면 id 순서다.
  Stream<List<FixedBlock>> watch() =>
      (_db.select(_db.fixedBlocks)..orderBy([
            (t) => OrderingTerm(expression: t.startMin),
            (t) => OrderingTerm(expression: t.id),
          ]))
          .watch();

  /// 고정 일정을 넣고 id를 돌려준다(되돌리면 지운다). 이름이 비었거나 [checkFixedBlock]에 걸리면
  /// [ArgumentError]다.
  Future<Result<int>> add({
    required String name,
    required List<int> weekdays,
    required int startMin,
    required int endMin,
    required int bufferMin,
    required FixedBlockKind kind,
    String? prep,
    String? place,
    required EntrySource source,
    required DateTime now,
  }) {
    _check(name, weekdays, startMin, endMin, bufferMin);
    return guardStorage(
      'fixed_blocks.add',
      () => _db.transaction(() async {
        final id = await _db
            .into(_db.fixedBlocks)
            .insert(
              FixedBlocksCompanion.insert(
                name: name,
                weekdays: _sorted(weekdays),
                startMin: startMin,
                endMin: endMin,
                bufferMin: bufferMin,
                kind: kind,
                prep: Value(prep),
                source: source,
                place: Value(place),
              ),
            );
        final undo = UndoRecorder(_db)..inserted(_table, id);
        await undo.write(table: _table, action: UndoAction.insert, now: now);
        return id;
      }),
    );
  }

  /// 고정 일정 [id]의 값을 모두 바꾼다(되돌리면 이전 값). 출처는 바꾸지 않는다. 없으면 false다.
  /// 이름이 비었거나 [checkFixedBlock]에 걸리면 [ArgumentError]다.
  Future<Result<bool>> update(
    int id, {
    required String name,
    required List<int> weekdays,
    required int startMin,
    required int endMin,
    required int bufferMin,
    required FixedBlockKind kind,
    String? prep,
    String? place,
    required DateTime now,
  }) {
    _check(name, weekdays, startMin, endMin, bufferMin);
    return guardStorage(
      'fixed_blocks.update',
      () => _db.transaction(() async {
        if (!await _exists(id)) return false;
        final undo = UndoRecorder(_db);
        await undo.before(_table, id);
        await (_db.update(
          _db.fixedBlocks,
        )..where((t) => t.id.equals(id))).write(
          FixedBlocksCompanion(
            name: Value(name),
            weekdays: Value(_sorted(weekdays)),
            startMin: Value(startMin),
            endMin: Value(endMin),
            bufferMin: Value(bufferMin),
            kind: Value(kind),
            prep: Value(prep),
            place: Value(place),
          ),
        );
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 고정 일정 [id]를 지운다(되돌리면 되살린다). 없으면 false다.
  Future<Result<bool>> delete(int id, {required DateTime now}) => guardStorage(
    'fixed_blocks.delete',
    () => _db.transaction(() async {
      if (!await _exists(id)) return false;
      final undo = UndoRecorder(_db);
      await undo.before(_table, id);
      await (_db.delete(_db.fixedBlocks)..where((t) => t.id.equals(id))).go();
      await undo.write(table: _table, action: UndoAction.delete, now: now);
      return true;
    }),
  );

  Future<bool> _exists(int id) async =>
      await (_db.select(
        _db.fixedBlocks,
      )..where((t) => t.id.equals(id))).getSingleOrNull() !=
      null;

  static List<int> _sorted(List<int> weekdays) => [...weekdays]..sort();

  static void _check(
    String name,
    List<int> weekdays,
    int startMin,
    int endMin,
    int bufferMin,
  ) {
    if (name.trim().isEmpty) throw ArgumentError.value(name, 'name');
    final issues = checkFixedBlock(
      weekdays: weekdays,
      startMin: startMin,
      endMin: endMin,
      bufferMin: bufferMin,
    );
    if (issues.isNotEmpty) {
      throw ArgumentError.value(issues, 'fixed block', 'invalid');
    }
  }
}
