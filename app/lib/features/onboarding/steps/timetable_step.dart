// 온보딩 2단계: 불러온 시간표 확인. docs/screens.md '14 온보딩'의 '2단계 · 불러온 시간표 확인'.
//
// 1단계에서 로그인할 때 통합정보시스템에서 불러온 이번 학기 시간표를 월–금 격자로 보이고 '통합정보시스템에서
// 불러옴'을 적는다. 수업을 누르면 실시간 온라인과 장소만 고치고, '맞아요'로 넘어간다. 건너뛰기와 뒤로 가기는
// 없다(시스템 뒤로 가기도 받지 않음). 로그아웃 뒤 로그인했으면 이 단계를 거치지 않는다. 격자와 수업 시트는
// 2단계 화면 PR에서 만든다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 2단계.
class TimetableStep extends StatelessWidget {
  const TimetableStep({super.key, required this.onConfirm});

  /// '맞아요': 다음 단계로 간다.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepPlaceholder(
      step: OnboardingStep.timetable,
      actions: [FilledButton(onPressed: onConfirm, child: const Text('맞아요'))],
    );
  }
}
