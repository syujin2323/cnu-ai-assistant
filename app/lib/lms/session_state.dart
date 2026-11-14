// LMS 세션 상태의 전이. docs/lms.md '세션 상태'.
//
// 상태 enum은 domain이 읽으므로 `domain/models/lms_session_state.dart`에 있고, 이 파일은 전이 규칙만 둔다. 로그인
// 시작(`connecting`)과 성공(`active`)은 로그인 흐름(`login_flow.dart`)이 쓰고, 복원 전이는 세션 복원 PR이 더한다.

import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';

/// 로그인 화면을 성공 없이 떠날 때(뒤로 가기, '로그인 없이 둘러보기', 그 화면에서 앱이 꺼진 뒤 다음 시작)의 LMS 상태.
///
/// [LmsSessionState.connecting]으로 남았으면 시작 전 상태로 돌린다. 학번·비밀번호가 저장돼 있으면
/// [LmsSessionState.reconnectRequired], 없으면 [LmsSessionState.disconnected]다(docs/lms.md '세션 상태' 1번). 그 밖의
/// 상태는 그대로 둔다.
LmsSessionState sessionStateLeavingLogin(
  LmsSessionState saved, {
  required bool hasSavedCredentials,
}) {
  if (saved != LmsSessionState.connecting) return saved;
  return hasSavedCredentials
      ? LmsSessionState.reconnectRequired
      : LmsSessionState.disconnected;
}

/// 앱을 시작할 때의 LMS 상태. 로그인 화면에서 앱이 꺼졌을 수 있으므로 [sessionStateLeavingLogin]과 같다.
LmsSessionState sessionStateAtStartup(
  LmsSessionState saved, {
  required bool hasSavedCredentials,
}) => sessionStateLeavingLogin(saved, hasSavedCredentials: hasSavedCredentials);
