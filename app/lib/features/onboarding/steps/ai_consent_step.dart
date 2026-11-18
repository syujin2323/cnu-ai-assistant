// 온보딩 4단계: AI 사용 동의. docs/screens.md '14 온보딩'의 '4단계 · AI 사용 동의'와 'AI 사용 동의'.
//
// '동의하고 계속'과 '동의하지 않고 계속' 가운데 골라야 넘어간다. AI 사용 동의는 선택 동의라 동의하지 않아도
// 앱을 쓴다(docs/decisions.md 2026-11-06 'AI 사용 동의는 선택 동의다'). 동의하면 `settings`의
// `aiEnabled`를 켜고 동의 시각(`aiConsentAt`)을 적고, 동의하지 않으면 `aiEnabled` false만 쓴다
// ([OnboardingController.consentToAi]·[OnboardingController.declineAi]). 문구는 공용 [AiConsentBody]다.
// '동의하지 않고 계속'을 누르면 바로 넘어가지 않고 'AI 없이 시작할까요?' 시트로 한 번 더 묻는다([showDeclineAiSheet],
// docs/decisions.md 2026-11-19 '온보딩에서 AI 사용에 동의하지 않으면 한 번 더 묻는다'). 시트의 주 버튼은
// [동의하고 계속]이고, 닫으면 이 단계에 남는다. 시트 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_body.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 4단계.
class AiConsentStep extends ConsumerWidget {
  const AiConsentStep({
    super.key,
    required this.onConsent,
    required this.onDecline,
  });

  /// '동의하고 계속'(단계의 버튼과 다시 묻는 시트의 주 버튼).
  final VoidCallback onConsent;

  /// 다시 묻는 시트에서도 '동의하지 않고 계속'을 골랐을 때.
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        OutlinedButton(
          onPressed: () => _confirmDecline(context, ref),
          child: const Text('동의하지 않고 계속'),
        ),
      ],
    );
  }

  /// 동의하지 않기 전에 한 번 더 묻는다. 닫으면 아무것도 하지 않는다.
  Future<void> _confirmDecline(BuildContext context, WidgetRef ref) async {
    final consent = await showDeclineAiSheet(
      context,
      ref.read(motionLevelProvider),
    );
    switch (consent) {
      case true:
        onConsent();
      case false:
        onDecline();
      case null:
        break;
    }
  }
}

/// 'AI 없이 시작할까요?' 시트를 연다. [동의하고 계속]이면 true, [동의하지 않고 계속]이면 false, 닫으면 null이다.
Future<bool?> showDeclineAiSheet(BuildContext context, MotionLevel motion) =>
    showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _DeclineAiSheet(),
    );

/// 동의하지 않으면 무엇을 못 쓰고 무엇은 그대로인지 알리고 한 번 더 묻는 시트.
class _DeclineAiSheet extends StatelessWidget {
  const _DeclineAiSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text('AI 없이 시작할까요?', style: AppText.title),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            '동의하지 않으면 AI 비서에게 말로 일정·할 일·규칙을 넣을 수 없어요. '
            '직접 추가는 그대로 쓸 수 있고, 나중에 나 › AI에서 켤 수 있어요.',
            style: AppText.body.copyWith(color: AppColors.of(context).ink2),
          ),
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('동의하고 계속'),
          ),
          const SizedBox(height: AppSpace.s8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSize.minTouch),
            ),
            child: const Text('동의하지 않고 계속'),
          ),
        ],
      ),
    );
  }
}
