/// 동기화를 시작한 계기. docs/lms.md '동기화'.
enum SyncTrigger { login, open, periodic, background, manual }

/// 동기화 범위. [full]은 과목 목록 → 할 일 목록 → 과목별 상세, [list]는 할 일 목록과
/// 바뀐 과목의 상세, [detail]은 과목별 상세 조회다.
enum SyncScope { full, list, detail }

/// 동기화 결과의 종류(docs/lms.md의 `SyncResult.kind`). 응답 판별 일곱 가지에
/// [partial](일부 과목 실패), [skipped], [cancelled]를 더한 열 가지다.
enum SyncResultKind {
  normal,
  empty,
  reloginRequired,
  restoreRequired,
  serverError,
  networkFailure,
  parseFailure,
  partial,
  skipped,
  cancelled,
}

/// 동기화 한 번(범위 하나)의 기록. `sync_runs` 표의 한 행.
///
/// 응답 본문은 어디에도 남기지 않는다. 호출 예산의 하루 횟수는 이 표를 세어 구한다.
class SyncRun {
  const SyncRun({
    required this.id,
    required this.startedAt,
    required this.trigger,
    required this.scope,
    required this.result,
    required this.changedCount,
    this.failedCourseIds,
    required this.elapsedMs,
    this.detail,
  });

  final int id;

  final DateTime startedAt;

  final SyncTrigger trigger;

  final SyncScope scope;

  final SyncResultKind result;

  /// 바뀐 항목 수.
  final int changedCount;

  /// 상세 조회에 실패한 과목의 `courses.id`. DB에는 JSON 배열로 둔다.
  final List<int>? failedCourseIds;

  /// 걸린 시간(밀리초).
  final int elapsedMs;

  /// 스키마 검증에 실패한 필드 이름만 담는다.
  final String? detail;
}
