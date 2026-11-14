// LMS 세션 상태. docs/lms.md '세션 상태'.
//
// 값은 폰 DB `settings`의 `lmsSessionState`에 두어 백그라운드 isolate도 같은 값을 읽는다.
// 그 값을 읽는 `AppSettings`(domain)가 이 enum을 쓰고 domain은 `lms/`를 import할 수 없으므로
// enum은 여기 둔다. 전이 규칙은 `lms/session_state.dart`(LMS PR)가 맡고, 그 파일은 이 enum을
// 다시 정의하지 않고 가져다 쓴다.

/// LMS 세션 상태. docs/lms.md '세션 상태' 도식의 미연결·연결중·활성·복원중·다시 로그인 필요.
enum LmsSessionState {
  disconnected,
  connecting,
  active,
  restoring,
  reconnectRequired;

  /// 아직 로그인하지 않았는지(로그인 정보가 없거나 로그인하는 중). 시작 위치 규칙과 온보딩은 이 상태를
  /// 로그인하지 않은 것으로 본다. `connecting`은 로그인에 실패해도 로그인 화면에 있는 동안 그대로 남으므로
  /// (docs/lms.md '세션 상태' 1번) 로그인한 것으로 보면, 실패한 뒤 '로그인 없이 둘러보기' → '끝내기'로 로그인
  /// 없이 실제 모드에 들어가게 된다(docs/decisions.md 2026-11-14 '로그인하는 중은 로그인 전으로 본다').
  bool get beforeLogin => this == disconnected || this == connecting;
}
