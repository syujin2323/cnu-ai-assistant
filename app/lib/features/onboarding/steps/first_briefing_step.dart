// 온보딩 8단계: 첫 브리핑 미리보기. 브리핑 PR에서 만든다.
// 이번 PR에는 단계 이름과 건너뛰기만 있고, 건너뛰면 온보딩이 끝난다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 8단계.
class FirstBriefingStep extends StatelessWidget {
  const FirstBriefingStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingStepPlaceholder(step: OnboardingStep.firstBriefing);
  }
}
