// 온보딩 1단계: LMS 로그인. docs/screens.md '14 온보딩'의 '1단계 · LMS 로그인'.
//
// 학번(숫자만)·비밀번호 폼, 이 폰에만 둔다는 안내, '개인정보 처리 안내에 동의해요 (필수)'와 '보기',
// 진행 줄 셋(LMS 로그인 → 이번 학기 시간표 → LMS 할 일)은 LMS 로그인 PR에서 `features/lms_connect/`의
// 공용 로그인 폼으로 만든다. 지금은 단계 이름, 아래의 '로그인 없이 둘러보기 · 샘플 학생의 하루'(데모 모드로
// 01 아침 브리핑)와 '충남대 비공식 앱', debug 빌드에서만 보이는 개발용 '로그인 없이 다음으로'가 있다.
// 이 단계에는 건너뛰기와 뒤로 가기가 없다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';

/// 1단계.
class LoginStep extends StatelessWidget {
  const LoginStep({
    super.key,
    required this.onBrowse,
    required this.onSkipLoginForDev,
    this.showDevSkip = true,
  });

  /// '로그인 없이 둘러보기 · 샘플 학생의 하루': 데모 모드로 들어간다.
  final VoidCallback onBrowse;

  /// 개발용 '로그인 없이 다음으로'를 눌렀을 때([OnboardingController.skipLoginForDev]).
  final VoidCallback onSkipLoginForDev;

  /// 개발용 버튼을 보일지. 이 값이 true여도 debug 빌드에서만 보인다. 테스트는 false로 두어
  /// release·profile 빌드처럼 버튼이 없는 화면을 본다.
  final bool showDevSkip;

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
        const SizedBox(height: AppSpace.s8),
        Text(
          AppStrings.inProgress,
          style: AppText.body.copyWith(color: colors.muted),
        ),
      ],
      actions: [
        if (kDebugMode && showDevSkip)
          OutlinedButton(
            onPressed: onSkipLoginForDev,
            child: const Text('로그인 없이 다음으로'),
          ),
        TextButton(
          onPressed: onBrowse,
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
