// 온보딩 7단계: 브리핑 시각과 알림 권한의 틀. 문구와 배치는 캔버스를 참고했다.
//
// 이번 PR에는 틀만 있다. 두 버튼은 아래 PR에서 붙이고, 그전까지는 누를 수 없게 둔다.
// - '시각 고르기': 고른 브리핑 시각을 `notify` 규칙(`source` `manual`)으로 `rules`에 저장한다.
//   기본값은 `domain/defaults.dart`의 `Defaults.briefingMin`(임시값)이고, 시각 표기는
//   `domain/text/`의 함수를 쓴다(내 규칙·rules 저장소 PR).
// - '알림 허용': 알림 권한을 묻는다(Android 13 이상 `POST_NOTIFICATIONS`, iOS 권한 창).
//   권한 요청과 예약은 `platform/notifications.dart`가 맡는다(알림 PR).

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 7단계.
class BriefingTimeStep extends StatelessWidget {
  const BriefingTimeStep({super.key, required this.onNext});

  /// '다음': 다음 단계로 간다.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      content: [
        Text(
          OnboardingStep.briefingTime.title,
          style: AppText.small.copyWith(
            fontWeight: AppText.semibold,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Semantics(
          header: true,
          child: const Text('아침 브리핑을 몇 시에 받을까요?', style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          "고른 시각은 '내 규칙'에 저장해요. 나중에 언제든 바꿀 수 있어요.",
          style: AppText.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.s24),
        const OutlinedButton(onPressed: null, child: Text('시각 고르기')),
        const SizedBox(height: AppSpace.s8),
        const OutlinedButton(onPressed: null, child: Text('알림 허용')),
      ],
      actions: [FilledButton(onPressed: onNext, child: const Text('다음'))],
    );
  }
}
