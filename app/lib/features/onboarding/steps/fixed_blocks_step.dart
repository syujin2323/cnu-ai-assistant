// 온보딩 3단계: 고정 일정. docs/screens.md '14 온보딩'의 '3단계 · 고정 일정'.
//
// '빠르게 더하기'(점심·알바·운동·통학·기타)를 누르면 작은 폼(이름, 요일, 시간, 준비물)이 열리고, 넣은 시간에는
// 할 일을 놓지 않는다. 점심·알바·운동·기타는 고정 일정(`fixed_blocks`, 운동의 준비물 기본값은 '운동복')이다.
// '통학'은 시간 칩(20·30·40·60분, 기본 40분, 임시)으로 골라 내 규칙의 이동 시간(`travel`, 하루 첫 수업 전·
// 마지막 수업 뒤)으로 저장하며, 13 시간표·고정 일정의 '통학'(매주 정해진 시각의 고정 일정)과 다르다.
// 온보딩에서 건너뛸 수 있는 단계는 이 단계뿐이고, 건너뛰면 4단계로 가며 고정 일정은 나중에 10 나에서 넣는다.
// 빠르게 더하기와 폼은 3단계 화면 PR에서 만든다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 3단계.
class FixedBlocksStep extends StatelessWidget {
  const FixedBlocksStep({super.key, required this.onNext});

  /// '다음': 다음 단계로 간다. 건너뛰기는 화면 위 머리에 있다.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPlaceholder(
      step: OnboardingStep.fixedBlocks,
      actions: [FilledButton(onPressed: onNext, child: const Text('다음'))],
    );
  }
}
