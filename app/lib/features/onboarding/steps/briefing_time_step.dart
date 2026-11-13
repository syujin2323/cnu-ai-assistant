// 온보딩 5단계(마지막): 아침 브리핑 시각. docs/screens.md '14 온보딩'의 '5단계 · 아침 브리핑 시각'.
// 오전 6:00–오후 12:00, 30분 단위 칩(기본 오전 8:00, 임시)에서 고르고 내 규칙 '알림'의 브리핑 시각으로
// 저장한다. 01 아침 브리핑은 이 시각과 관계없이 그날 아직 보지 않았으면 앱을 열 때 뜬다. 이 시각의 쓰임과
// 알림 권한 안내는 알림 재설계 때 정한다(알림은 재설계 예정). '다음'을 누르면 온보딩을 끝낸다.
//
// 칩은 `RuleLimits.briefingChoices`(13개, 임시)이고 처음에는 기본값(`Defaults.briefingMin`)을 고른다. '다음'을
// 누르면 고른 시각을 내 규칙 `notify`로 저장하고 온보딩을 끝낸다([OnboardingController.finishWithBriefingTime]).
// 알림 권한 안내와 이 시각의 쓰임은 알림 재설계 때 정하므로 옛 틀의 '알림 허용' 버튼은 두지 않는다(알림
// 코드는 지우지 않음).

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 5단계.
class BriefingTimeStep extends StatefulWidget {
  const BriefingTimeStep({super.key, required this.onDone});

  /// '다음': 고른 브리핑 시각(자정 기준 분)을 받아 저장하고 온보딩을 끝낸다.
  final ValueChanged<int> onDone;

  @override
  State<BriefingTimeStep> createState() => _BriefingTimeStepState();
}

class _BriefingTimeStepState extends State<BriefingTimeStep> {
  int _selected = Defaults.briefingMin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return OnboardingStepLayout(
      content: [
        Text(
          OnboardingStep.briefingTime.title,
          style: AppText.small.copyWith(
            fontWeight: AppText.semibold,
            color: colors.accent,
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
          style: AppText.body.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpace.s24),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final minute in RuleLimits.briefingChoices)
              ChoiceChip(
                label: Text(shortClockText(minute)),
                selected: minute == _selected,
                onSelected: (_) => setState(() => _selected = minute),
              ),
          ],
        ),
      ],
      actions: [
        FilledButton(
          onPressed: () => widget.onDone(_selected),
          child: const Text('다음'),
        ),
      ],
    );
  }
}
