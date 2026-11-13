// 온보딩 5단계(마지막): 아침 브리핑 시각. docs/screens.md '14 온보딩'의 '5단계 · 아침 브리핑 시각'.
// 오전 6:00–오후 12:00, 30분 단위 칩(기본 오전 8:00, 임시)에서 고르고 내 규칙 '알림'의 브리핑 시각으로
// 저장한다. 01 아침 브리핑은 이 시각과 관계없이 그날 아직 보지 않았으면 앱을 열 때 뜬다. 이 시각의 쓰임과
// 알림 권한 안내는 알림 재설계 때 정한다(알림은 재설계 예정). '다음'을 누르면 온보딩을 끝낸다.
//
// 지금은 틀만 있다. 두 버튼은 아래 PR에서 붙이고, 그전까지는 누를 수 없게 둔다.
// - '시각 고르기': 고른 브리핑 시각을 `notify` 규칙(`source` `manual`)으로 `rules`에 저장한다.
//   기본값은 `domain/defaults.dart`의 `Defaults.briefingMin`(임시값)이고, 시각 표기는
//   `domain/text/`의 함수를 쓴다(4·5단계 저장 PR).
// - '알림 허용': (알림은 재설계 예정) 재설계 때 이 버튼을 둘지부터 정한다. 그전까지 알림 코드를 붙이지 않는다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 5단계.
class BriefingTimeStep extends StatelessWidget {
  const BriefingTimeStep({super.key, required this.onNext});

  /// '다음': 온보딩을 끝낸다.
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
