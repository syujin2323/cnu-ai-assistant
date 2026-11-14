// 동기화 기록 저장소(`sync_runs` 표). docs/lms.md '동기화'·'호출 예산', docs/screens.md 'LMS 상태 줄과
// '다시 로그인''.
//
// 동기화(세션 관리자·SyncCoordinator)가 범위 하나마다 한 행을 남기고, 호출 예산의 하루 횟수와 '실패 뒤
// 간격'은 메모리가 아니라 이 표를 세어 구한다(isolate가 달라도 같은 값). 화면은 마지막 시도와 마지막
// 성공을 본다. 결과를 고르는 조건은 저장된 값으로 견준다. `detail`에는 이름 꼴(이유 코드·필드 이름)만
// 넣는다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다. 90일이 지난 행은
// `RetentionRepository`가 지운다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:drift/drift.dart';

/// 동기화 기록 저장소.
class SyncRunRepository {
  SyncRunRepository(this._db);

  final AppDatabase _db;

  /// 호출 예산을 세는 자동 계기. 사용자 새로 고침과 로그인 직후 조회는 세지 않는다.
  static const autoTriggers = {
    SyncTrigger.open,
    SyncTrigger.periodic,
    SyncTrigger.background,
  };

  /// 성공으로 보는 결과(마지막 확인 시각을 올리는 결과).
  static const successResults = {
    SyncResultKind.normal,
    SyncResultKind.empty,
    SyncResultKind.partial,
  };

  static final _namePattern = RegExp(r'^[A-Za-z0-9_.,]+$');

  /// 동기화 한 번(범위 하나)의 기록을 넣고 id를 돌려준다. [changedCount]·[elapsedMs]가 음수이거나
  /// [detail]이 이름 꼴(영문·숫자·`_`·`.`·`,`)이 아니면 [ArgumentError]다(로그 규칙: 사용자 내용을 남기지
  /// 않음).
  Future<Result<int>> add({
    required DateTime startedAt,
    required SyncTrigger trigger,
    required SyncScope scope,
    required SyncResultKind result,
    int changedCount = 0,
    List<int>? failedCourseIds,
    required int elapsedMs,
    String? detail,
  }) {
    if (changedCount < 0) {
      throw ArgumentError.value(changedCount, 'changedCount');
    }
    if (elapsedMs < 0) throw ArgumentError.value(elapsedMs, 'elapsedMs');
    if (detail != null && !_namePattern.hasMatch(detail)) {
      throw ArgumentError.value(detail, 'detail', 'must be a name');
    }
    return guardStorage(
      'sync_runs.add',
      () => _db
          .into(_db.syncRuns)
          .insert(
            SyncRunsCompanion.insert(
              startedAt: startedAt,
              trigger: trigger,
              scope: scope,
              result: result,
              changedCount: changedCount,
              failedCourseIds: Value(failedCourseIds),
              elapsedMs: elapsedMs,
              detail: Value(detail),
            ),
          ),
    );
  }

  /// 마지막 시도(건너뛴 기록 제외)를 지금 읽고 기록이 바뀔 때마다 다시 읽는다. LMS 상태 줄의 실패
  /// 상태(점검·연결 실패)에 쓴다. 기록이 없으면 null이다.
  Stream<SyncRun?> watchLatestAttempt() =>
      _latest(_db.syncRuns.result.equalsValue(SyncResultKind.skipped).not())
          .watchSingleOrNull();

  /// 마지막으로 성공한(`normal`·`empty`·`partial`) 기록을 지금 읽고 바뀔 때마다 다시 읽는다. LMS 상태
  /// 줄의 '방금'(계기가 `manual`)과 '확인 못 함'(`partial`의 `failedCourseIds`)에 쓴다.
  Stream<SyncRun?> watchLatestSuccess() =>
      _latest(_db.syncRuns.result.isInValues(successResults))
          .watchSingleOrNull();

  /// 마지막 자동 계기(`open`·`periodic`·`background`)의 `list` 기록(건너뛴 기록 제외). 호출 예산의
  /// '실패 뒤 다시 조회하기까지의 최소 간격'에 쓴다. 없으면 null이다.
  Future<Result<SyncRun?>> lastAutoList() => guardStorage(
    'sync_runs.lastAutoList',
    () => _latest(
      _db.syncRuns.trigger.isInValues(autoTriggers) &
          _db.syncRuns.scope.equalsValue(SyncScope.list) &
          _db.syncRuns.result.equalsValue(SyncResultKind.skipped).not(),
    ).getSingleOrNull(),
  );

  /// 오늘(한국 시각 달력 날짜 00:00부터) 자동 계기로 LMS를 부른 기록(건너뛴 기록만 빼고 취소된 기록은
  /// 셈)을 범위별로 센다. 없는 범위는 0이다. 호출 예산의 하루 최대 횟수에 쓴다.
  Future<Result<Map<SyncScope, int>>> countAutoCallsToday({
    required DateTime now,
  }) => guardStorage('sync_runs.countAutoCallsToday', () async {
    final dayStart = kstToUtc(DateTime(now.year, now.month, now.day));
    final rows =
        await (_db.select(_db.syncRuns)..where(
              (t) =>
                  t.trigger.isInValues(autoTriggers) &
                  t.result.equalsValue(SyncResultKind.skipped).not() &
                  t.startedAt.isBiggerOrEqualValue(dayStart),
            ))
            .get();
    final counts = {for (final scope in SyncScope.values) scope: 0};
    for (final row in rows) {
      counts[row.scope] = counts[row.scope]! + 1;
    }
    return counts;
  });

  SimpleSelectStatement<$SyncRunsTable, SyncRun> _latest(
    Expression<bool> condition,
  ) => (_db.select(_db.syncRuns)
    ..where((_) => condition)
    ..orderBy([
      (t) => OrderingTerm.desc(t.startedAt),
      (t) => OrderingTerm.desc(t.id),
    ])
    ..limit(1));
}
