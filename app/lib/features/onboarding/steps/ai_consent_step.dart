// 온보딩 6단계: AI 사용 동의. 동의 문장은 docs/architecture.md '온보딩'에 있고, 모델이 정해지면
// 제공사 이름·국가와 보관 기간을 넣는다. AI 동의 PR에서 만든다.
// 이번 PR에는 단계 이름과 건너뛰기만 있다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 6단계.
class AiConsentStep extends StatelessWidget {
  const AiConsentStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingStepPlaceholder(step: OnboardingStep.aiConsent);
  }
}
