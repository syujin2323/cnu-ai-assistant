// 온보딩 4단계: AI 사용 동의. docs/screens.md '14 온보딩'의 '4단계 · AI 사용 동의'와 'AI 사용 동의'.
//
// '동의하고 계속'과 '동의하지 않고 계속' 가운데 골라야 넘어간다. AI 사용 동의는 선택 동의라 동의하지 않아도
// 앱을 쓰고, '동의하지 않고 계속'은 `settings`의 `aiEnabled` false만 쓴다(docs/decisions.md 2026-11-06 'AI
// 사용 동의는 선택 동의다'). 동의 문구는 실제로 보내는 항목만 적고, 모델이 정해지면 제공사 이름·나라·보관
// 기간·학습 여부를 넣는다. 동의 문구와 두 버튼은 4·5단계 저장 PR에서 만들고, 지금은 '다음'으로 넘어간다
// (`aiEnabled`는 기본값 false 그대로).

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 4단계.
class AiConsentStep extends StatelessWidget {
  const AiConsentStep({super.key, required this.onNext});

  /// '다음': 다음 단계로 간다.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPlaceholder(
      step: OnboardingStep.aiConsent,
      actions: [FilledButton(onPressed: onNext, child: const Text('다음'))],
    );
  }
}
