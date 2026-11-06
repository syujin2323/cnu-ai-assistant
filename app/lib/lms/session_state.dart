// 사캠 세션 상태의 전이. docs/lms.md '세션 상태'.
//
// 상태 enum은 domain이 읽으므로 `domain/models/lms_session_state.dart`에 있고, 이 파일은 전이 규칙만
// 둔다. 지금은 앱을 시작할 때의 정리만 있고, 로그인·복원 전이는 사캠 연동 PR이 이 파일에 더한다.

import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';

/// 앱을 시작할 때의 사캠 상태.
///
/// 로그인 화면에서 앱이 꺼져 [LmsSessionState.connecting]으로 남았으면 시작 전 상태로 돌린다.
/// 학번·비밀번호가 저장돼 있으면 [LmsSessionState.reconnectRequired], 없으면
/// [LmsSessionState.disconnected]다(docs/lms.md '세션 상태' 1번). 그 밖의 상태는 그대로 둔다.
LmsSessionState sessionStateAtStartup(
  LmsSessionState saved, {
  required bool hasSavedCredentials,
}) {
  if (saved != LmsSessionState.connecting) return saved;
  return hasSavedCredentials
      ? LmsSessionState.reconnectRequired
      : LmsSessionState.disconnected;
}
