// 온보딩 3단계: LMS 연결. `LmsFeature.included`일 때만 보인다. 앱 안 학교 공식 로그인 화면에서
// 직접 로그인하고 '자동 로그인 유지'를 고르며, "로그인하면 PC·웹에서 보던 LMS가 풀릴 수 있어요"를
// 늘 보여 준다. 연결 시트는 `features/lms_connect/`에 두고 LMS 연결 PR에서 만든다.
// 지금은 단계 이름과 건너뛰기, debug 빌드에서만 보이는 개발용 '로그인 없이 다음으로'만 있다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';

/// 3단계.
class LmsConnectStep extends StatelessWidget {
  const LmsConnectStep({
    super.key,
    required this.onSkipLoginForDev,
    this.showDevSkip = true,
  });

  /// 개발용 '로그인 없이 다음으로'를 눌렀을 때([OnboardingController.skipLoginForDev]).
  final VoidCallback onSkipLoginForDev;

  /// 개발용 버튼을 보일지. 이 값이 true여도 debug 빌드에서만 보인다. 테스트는 false로 두어
  /// release·profile 빌드처럼 버튼이 없는 화면을 본다.
  final bool showDevSkip;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPlaceholder(
      step: OnboardingStep.lmsConnect,
      actions: [
        if (kDebugMode && showDevSkip)
          OutlinedButton(
            onPressed: onSkipLoginForDev,
            child: const Text('로그인 없이 다음으로'),
          ),
      ],
    );
  }
}
