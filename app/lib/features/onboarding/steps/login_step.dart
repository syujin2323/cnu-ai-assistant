// 온보딩 1단계: LMS 로그인. docs/screens.md '14 온보딩'의 '1단계 · LMS 로그인'.
//
// 앱 이름과 단계 이름 아래에 공용 로그인 폼(`features/lms_connect/login_form.dart`의 처음 로그인 모드)을
// 둔다. 폼은 학번(숫자만)·비밀번호·이 폰에만 둔다는 안내·'개인정보 처리 안내에 동의해요 (필수)'와 '보기'를
// 받고, '로그인'을 누르면 같은 자리에서 진행 줄 셋(LMS 로그인 → 이번 학기 시간표 → LMS 할 일)을 끝낸 뒤
// [LoginStep.onLoggedIn]을 부른다. 아래에는 '로그인 없이 둘러보기 · 샘플 학생의 하루'(데모 모드로 01 아침
// 브리핑)와 '충남대 비공식 앱'을 둔다. 로그인하는 동안에는 둘러보기도 잠근다. debug 빌드에서는 폼 아래에
// 개발용 '로그인 없이 다음으로'가 있다. 이 단계에는 건너뛰기와 뒤로 가기가 없다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/lms_connect/login_form.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:material_ui/material_ui.dart';

/// 1단계.
class LoginStep extends StatefulWidget {
  const LoginStep({
    super.key,
    required this.onLoggedIn,
    required this.onBrowse,
    this.onSkipLoginForDev,
  });

  /// 로그인 흐름이 성공으로 끝났을 때([OnboardingController.loggedIn]).
  final Future<void> Function() onLoggedIn;

  /// '로그인 없이 둘러보기 · 샘플 학생의 하루': 데모 모드로 들어간다.
  final VoidCallback onBrowse;

  /// 개발용 '로그인 없이 다음으로'를 눌렀을 때([OnboardingController.skipLoginForDev]). null이면 버튼이 없다
  /// (debug 빌드가 아니면 [OnboardingScreen]이 넘기지 않음, `devLoginSkipAllowedProvider`).
  final VoidCallback? onSkipLoginForDev;

  @override
  State<LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<LoginStep> {
  /// 로그인 중인지. 그동안 '로그인 없이 둘러보기'를 받지 않는다.
  bool _loggingIn = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return OnboardingStepLayout(
      content: [
        Text(
          AppStrings.appName,
          style: AppText.body.copyWith(
            fontWeight: AppText.semibold,
            color: colors.accent,
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        Semantics(
          header: true,
          child: Text(OnboardingStep.login.title, style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s24),
        LoginForm(
          mode: LoginMode.first,
          onSucceeded: widget.onLoggedIn,
          onRunningChanged: (running) => setState(() => _loggingIn = running),
          onSkipForDev: widget.onSkipLoginForDev,
        ),
      ],
      actions: [
        TextButton(
          onPressed: _loggingIn ? null : widget.onBrowse,
          child: const Text(
            '로그인 없이 둘러보기 · 샘플 학생의 하루',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          AppStrings.unofficialShort,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}
