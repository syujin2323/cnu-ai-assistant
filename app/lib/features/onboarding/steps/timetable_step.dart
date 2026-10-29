// 온보딩 4단계: 시간표. 사캠 과목 목록에서 고르면 통합정보시스템에서 요일·시각·강의실을 받아
// 채우고 확인·수정한다. 자동으로 못 채운 과목이나 사캠 연결을 건너뛰었으면 직접 입력한다.
// 시간표 PR에서 만든다. 이번 PR에는 단계 이름과 건너뛰기만 있다.

import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 4단계.
class TimetableStep extends StatelessWidget {
  const TimetableStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingStepPlaceholder(step: OnboardingStep.timetable);
  }
}
