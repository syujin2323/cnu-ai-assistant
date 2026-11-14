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

  /// `parse_failure`면 스키마 검증에 실패한 필드 이름, `skipped`·`cancelled`면 그 이유 코드([SyncRunDetail])다.
  /// 예산 설정을 해석하지 못해 기본값을 쓴 계기 행에는 [SyncRunDetail.budgetParseFailed]를 남긴다. 코드 이름뿐이라
  /// 사용자 내용이 들어가지 않는다.
  final String? detail;
}

/// `sync_runs.detail`에 남기는 이유 코드(docs/architecture.md '폰 DB', docs/lms.md '동기화'). `parse_failure` 행은 스키마
/// 검증에 실패한 필드 이름을, `skipped`·`cancelled` 행은 아래 코드를 남긴다. 예산 설정(`lms_sync_budget`)을 해석하지
/// 못해 기본값을 쓴 계기 행에는 [budgetParseFailed]를 남긴다. 모두 코드 이름뿐이라 로그 규칙(이름 꼴)에 맞는다.
abstract final class SyncRunDetail {
  /// `skipped`: 호출 예산(간격·하루 횟수)에 걸려 LMS를 부르지 않음.
  static const budget = 'budget';

  /// `skipped`: 다른 동기화가 임대(`sync_lease`)를 잡고 있음.
  static const lease = 'lease';

  /// `skipped`·`cancelled`: 원격 스위치(`lms_enabled`)가 꺼짐.
  static const switchOff = 'switch_off';

  /// `skipped`: 조용한 시간(한국 시간 01:00–06:00).
  static const quietHours = 'quiet_hours';

  /// `skipped`: 요청 상수(`lms_request_params`)를 받지 못함.
  static const configMissing = 'config_missing';

  /// `cancelled`: 사용자가 앱 안 WebView로 LMS를 보는 중.
  static const webviewOpen = 'webview_open';

  /// `cancelled`: 데모 모드에 들어감.
  static const demoMode = 'demo_mode';

  /// 예산 설정을 해석하지 못해 기본값을 씀(그 계기 행에 남긴다).
  static const budgetParseFailed = 'budget_parse_failed';

  /// 위 코드 전부(테스트와 로그 검사용).
  static const all = [
    budget,
    lease,
    switchOff,
    quietHours,
    configMissing,
    webviewOpen,
    demoMode,
    budgetParseFailed,
  ];
}
