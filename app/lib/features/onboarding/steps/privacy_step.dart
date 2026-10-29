// 온보딩 2단계: 개인정보 한 장. 문장은 docs/architecture.md '온보딩'의 문장 그대로다.
// 문장을 바꾸면 그 문서와 개인정보 처리방침을 같은 PR에서 고친다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 2단계.
class PrivacyStep extends StatelessWidget {
  const PrivacyStep({super.key, required this.onConfirm});

  /// '확인했어요': 다음 단계로 간다.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      content: [
        Semantics(
          header: true,
          child: Text(OnboardingStep.privacy.title, style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s12),
        const Text(
          '로그인은 학교 공식 화면에서 하고, 자동 로그인을 켜면 비밀번호를 이 기기에만 저장해요. '
          '서버로 보내지 않아요',
          style: AppText.bodyLarge,
        ),
      ],
      actions: [FilledButton(onPressed: onConfirm, child: const Text('확인했어요'))],
    );
  }
}
