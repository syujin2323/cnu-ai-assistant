// LMS 로그인 흐름. docs/lms.md '로그인'.
//
// 앱 화면에서 받은 학번·비밀번호로 LMS에 로그인하고, 처음 로그인이면 이어서 이번 학기 시간표와 LMS 할
// 일을, 다시 로그인이면 할 일만 불러온다. 로그인 폼(`features/lms_connect/`)은 이 흐름의 단계를 진행
// 줄로 보이고 결과로 다음 화면을 정한다. 실제 요청·저장(학번·비밀번호, 쿠키, LMS 상태)은 LMS 연동이
// [LoginFlow]의 구현으로 붙인다. 그전까지 기본 구현([loginFlowProvider])은 늘 '해석 실패'를 돌려준다.
// 요청 상수가 없으면 로그인 버튼이 꺼져 있으므로 실제로는 불리지 않는다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 폼의 모드.
enum LoginMode {
  /// 14 온보딩 1단계: 학번·비밀번호와 개인정보 처리 안내 동의를 받는다.
  first,

  /// 다시 로그인: 저장된 학번을 고정하고 비밀번호만 받는다.
  relogin,
}

/// 로그인 흐름의 단계(진행 줄). 처음 로그인은 셋, 다시 로그인은 [login]·[tasks] 둘이다.
enum LoginStage {
  /// LMS 로그인.
  login,

  /// 이번 학기 시간표(통합정보시스템).
  timetable,

  /// LMS 할 일.
  tasks;

  /// [mode]가 지나는 단계.
  static List<LoginStage> of(LoginMode mode) => switch (mode) {
    LoginMode.first => values,
    LoginMode.relogin => const [login, tasks],
  };
}

/// 로그인 흐름. LMS 연동이 구현한다.
abstract interface class LoginFlow {
  /// 저장된 학번. 없으면 null이고, 다시 로그인 화면은 학번 칸도 받는다.
  Future<String?> savedStudentId();

  /// [studentId]·[password]로 로그인하고 [mode]의 단계를 차례로 지나며, 단계를 시작할 때마다
  /// [onStage]를 부른다. 성공이면 [Ok], 실패면 판별 결과([LmsOutcome])를 담은 [Err]다.
  Future<Result<void>> run({
    required LoginMode mode,
    required String studentId,
    required String password,
    required void Function(LoginStage stage) onStage,
  });
}

/// 로그인 흐름. LMS 연동 전에는 [NotConnectedLoginFlow]다. 화면 테스트는 덮어쓴다.
final loginFlowProvider = Provider<LoginFlow>(
  (ref) => const NotConnectedLoginFlow(),
);

/// LMS 연동이 붙기 전의 로그인 흐름. 저장된 학번이 없고, 로그인은 늘 '해석 실패'다.
class NotConnectedLoginFlow implements LoginFlow {
  const NotConnectedLoginFlow();

  @override
  Future<String?> savedStudentId() async => null;

  @override
  Future<Result<void>> run({
    required LoginMode mode,
    required String studentId,
    required String password,
    required void Function(LoginStage stage) onStage,
  }) async => const Err(LmsOutcome(LmsOutcomeKind.parseFailure));
}
