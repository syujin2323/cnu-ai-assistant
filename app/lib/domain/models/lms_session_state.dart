// 사캠 세션 상태. docs/lms.md '세션 상태'.
//
// 값은 폰 DB `settings`의 `lmsSessionState`에 두어 백그라운드 isolate도 같은 값을 읽는다.
// 그 값을 읽는 `AppSettings`(domain)가 이 enum을 쓰고 domain은 `lms/`를 import할 수 없으므로
// enum은 여기 둔다. 전이 규칙은 `lms/session_state.dart`(사캠 PR)가 맡고, 그 파일은 이 enum을
// 다시 정의하지 않고 가져다 쓴다.

/// 사캠 세션 상태. 도식의 미연결·연결중·활성·복원중·재연결필요.
enum LmsSessionState {
  disconnected,
  connecting,
  active,
  restoring,
  reconnectRequired,
}
