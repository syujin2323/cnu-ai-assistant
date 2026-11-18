// 폰 데이터를 지우는 저장소. docs/lms.md '로그아웃, 데이터 삭제', docs/architecture.md '폰 DB'.
//
// 표 사이 외래 키는 모두 기본 동작(NO ACTION)이라 자식 행이 남은 부모 행은 지울 수 없다. 그래서 로그아웃은 한
// 트랜잭션에서 자식부터 지운다(LMS 할 일의 블록 → LMS 할 일 → LMS 원본, 불러온 수업의 예외 → 불러온 수업).
// 부모 표를 `INSERT OR REPLACE`로 쓰지 않는 규칙과 함께, 사용자의 할 일·블록이 말없이 사라지지 않게 하려는 것이다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';

/// 폰 데이터를 지우는 저장소.
class LocalDataRepository {
  LocalDataRepository(this._db);

  final AppDatabase _db;

  /// 로그아웃 때 LMS에서 온 행을 지운다. 불러온 시간표(`class_slots`의 `source` `auto`)와 거기에 붙은 수업 예외,
  /// LMS 할 일(`tasks.lmsKey`가 있는 행. 걸린 시간 기록 포함)과 그 블록, LMS 원본(`lms_items`)이다. 직접 넣은
  /// 일정·고정 일정·수업·할 일과 내 규칙, LMS 과목(`courses`), `lms_item_changes`·`sync_runs`, 설정은 남긴다. 지운
  /// 행을 되살리지 않도록 되돌리기 기록도 버린다. 한 트랜잭션이라 하나라도 지우지 못하면 아무것도 지우지 않고
  /// [StorageError]를 담은 [Err]다. LMS 상태(`disconnected`)는 부르는 쪽이 `SettingsRepository`로 쓴다.
  Future<Result<void>> deleteLmsData() => guardStorage(
    'localData.deleteLmsData',
    () => _db.transaction(() async {
      final lmsTaskIds = _db.selectOnly(_db.tasks)
        ..addColumns([_db.tasks.id])
        ..where(_db.tasks.lmsKey.isNotNull());
      await (_db.delete(
        _db.planBlocks,
      )..where((block) => block.taskId.isInQuery(lmsTaskIds))).go();
      await (_db.delete(
        _db.tasks,
      )..where((task) => task.lmsKey.isNotNull())).go();
      await _db.delete(_db.lmsItems).go();

      final importedSlotIds = _db.selectOnly(_db.classSlots)
        ..addColumns([_db.classSlots.id])
        ..where(_db.classSlots.source.equalsValue(SlotSource.auto));
      await (_db.delete(_db.classExceptions)..where(
            (exception) => exception.classSlotId.isInQuery(importedSlotIds),
          ))
          .go();
      await (_db.delete(
        _db.classSlots,
      )..where((slot) => slot.source.equalsValue(SlotSource.auto))).go();

      await _db.delete(_db.undoLog).go();
    }),
  );

  /// 데이터 삭제 때 폰 DB의 모든 표를 비운다. 설치 표식(`installedAt`)도 지우므로 부르는 쪽이 첫 실행처럼 새로
  /// 적는다. 하나라도 지우지 못하면 아무것도 지우지 않고 [StorageError]를 담은 [Err]다.
  Future<Result<void>> deleteAll() =>
      guardStorage('localData.deleteAll', () => clearAllTables(_db));
}

/// 모든 표를 한 트랜잭션으로 비운다. 표 사이 외래 키가 지우는 순서에 걸리지 않게 검사를 트랜잭션 끝으로 미룬다.
/// 데이터 삭제([LocalDataRepository.deleteAll])와 데모 끝내기(`DemoRepository.clearAll`)가 쓴다.
Future<void> clearAllTables(AppDatabase db) => db.transaction(() async {
  await db.customStatement('PRAGMA defer_foreign_keys = ON');
  for (final table in db.allTables) {
    await db.delete(table).go();
  }
});
