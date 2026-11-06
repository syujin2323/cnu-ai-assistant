import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:drift/drift.dart';

/// 보관 기간이 지난 기록을 지우는 저장소(docs/architecture.md '폰 DB').
///
/// `sync_runs`·`lms_item_changes`·`briefings`는 [Defaults.retentionDays]가 지난 행을 앱 시작 때
/// 지운다. 앱을 열 때 기다리지 않는 작업으로 부른다(`app/startup.dart`).
class RetentionRepository {
  RetentionRepository(this._db);

  final AppDatabase _db;

  /// [now]보다 보관 기간 넘게 오래된 행을 지우고 지운 행 수를 돌려준다. 기준 시각은
  /// `sync_runs.startedAt`, `lms_item_changes.changedAt`, `briefings.createdAt`이다.
  Future<Result<int>> deleteExpired({required DateTime now}) async {
    final cutoff = now.subtract(const Duration(days: Defaults.retentionDays));
    try {
      final deleted = await _db.transaction(() async {
        final runs = await (_db.delete(
          _db.syncRuns,
        )..where((t) => t.startedAt.isSmallerThanValue(cutoff))).go();
        final changes = await (_db.delete(
          _db.lmsItemChanges,
        )..where((t) => t.changedAt.isSmallerThanValue(cutoff))).go();
        final briefings = await (_db.delete(
          _db.briefings,
        )..where((t) => t.createdAt.isSmallerThanValue(cutoff))).go();
        return runs + changes + briefings;
      });
      return Ok(deleted);
    } on Exception catch (error) {
      return Err(
        StorageError(
          'retention.deleteExpired',
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }
}
