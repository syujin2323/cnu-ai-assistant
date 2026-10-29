// 온보딩 5단계: 고정 일정(점심·알바·운동). 시간표 PR에서 만든다.
// 이번 PR에는 단계 이름과 건너뛰기만 있다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 5단계.
class FixedBlocksStep extends StatelessWidget {
  const FixedBlocksStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingStepPlaceholder(step: OnboardingStep.fixedBlocks);
  }
}
