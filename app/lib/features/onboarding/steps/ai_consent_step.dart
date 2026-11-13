// 온보딩 4단계: AI 사용 동의. docs/screens.md '14 온보딩'의 '4단계 · AI 사용 동의'와 'AI 사용 동의'.
//
// '동의하고 계속'과 '동의하지 않고 계속' 가운데 골라야 넘어간다. AI 사용 동의는 선택 동의라 동의하지 않아도
// 앱을 쓴다(docs/decisions.md 2026-11-06 'AI 사용 동의는 선택 동의다'). 동의하면 `settings`의
// `aiEnabled`를 켜고 동의 시각(`aiConsentAt`)을 적고, 동의하지 않으면 `aiEnabled` false만 쓴다
// ([OnboardingController.consentToAi]·[OnboardingController.declineAi]). 문구는 공용 [AiConsentBody]다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_body.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 4단계.
class AiConsentStep extends StatelessWidget {
  const AiConsentStep({
    super.key,
    required this.onConsent,
    required this.onDecline,
  });

  /// '동의하고 계속'.
  final VoidCallback onConsent;

  /// '동의하지 않고 계속'.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      content: [
        Semantics(
          header: true,
          child: Text(OnboardingStep.aiConsent.title, style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'AI 비서에게 말로 일정·할 일·규칙을 넣을 때 쓰는 기능이에요. 쓰려면 동의가 필요해요.',
          style: AppText.body.copyWith(color: AppColors.of(context).muted),
        ),
        const AiConsentBody(),
      ],
      actions: [
        FilledButton(onPressed: onConsent, child: const Text('동의하고 계속')),
        OutlinedButton(onPressed: onDecline, child: const Text('동의하지 않고 계속')),
      ],
    );
  }
}
