// 온보딩 단계 하나의 틀. 단계 파일들이 함께 쓴다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:material_ui/material_ui.dart';

/// 내용은 위에서부터 놓고, 버튼은 남는 공간이 있으면 화면 아래에 붙인다.
/// 글자가 커져 화면을 넘으면 내용과 버튼이 함께 스크롤된다.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.content,
    this.actions = const [],
  });

  /// 단계 내용(위에서 아래 순서).
  final List<Widget> content;

  /// 화면 아래 버튼(위에서 아래 순서).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s24,
            AppSpace.screen,
            AppSpace.s24,
          ),
          sliver: SliverList.list(children: content),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.screen,
              0,
              AppSpace.screen,
              AppSpace.s24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s8),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 아직 만들지 않은 단계의 자리. 단계 이름만 보이고, 건너뛰기는 화면 위 머리에 있다.
class OnboardingStepPlaceholder extends StatelessWidget {
  const OnboardingStepPlaceholder({super.key, required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      content: [
        Semantics(
          header: true,
          child: Text(step.title, style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          AppStrings.inProgress,
          style: AppText.body.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
