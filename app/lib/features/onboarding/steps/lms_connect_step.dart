// 온보딩 3단계: 사캠 연결. `LmsFeature.included`일 때만 보인다. 앱 안 학교 공식 로그인 화면에서
// 직접 로그인하고 '자동 로그인 유지'를 고르며, "로그인하면 PC·웹에서 보던 사캠이 풀릴 수 있어요"를
// 늘 보여 준다. 연결 시트는 `features/lms_connect/`에 두고 사캠 연결 PR에서 만든다.
// 이번 PR에는 단계 이름과 건너뛰기만 있다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 3단계.
class LmsConnectStep extends StatelessWidget {
  const LmsConnectStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingStepPlaceholder(step: OnboardingStep.lmsConnect);
  }
}
