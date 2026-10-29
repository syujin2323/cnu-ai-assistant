// 온보딩 1단계: 두 약속 소개. 첫 화면이며 '시작하기'와 '둘러보기'(데모), 화면 아래에
// '충남대 비공식 앱 · 학교와 관계없는 학생 프로젝트'를 둔다. 문구와 배치는 캔버스를 참고했다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:material_ui/material_ui.dart';

/// 1단계.
class IntroStep extends StatelessWidget {
  const IntroStep({super.key, required this.onStart, required this.onBrowse});

  /// '시작하기': 다음 단계로 간다.
  final VoidCallback onStart;

  /// '둘러보기': 데모 모드로 들어간다.
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      content: [
        Text(
          AppStrings.appName,
          style: AppText.body.copyWith(
            fontWeight: AppText.semibold,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpace.s24),
        Semantics(
          header: true,
          child: const Text('수업 사이 빈 시간,\n할 일로 채워 둘게요', style: AppText.display),
        ),
        const SizedBox(height: AppSpace.s24),
        const _Promise(
          title: '마감을 놓치지 않게 할게요',
          body: '과제와 영상 마감을 한곳에 모아 미리 알려 드려요',
        ),
        const SizedBox(height: AppSpace.s16),
        const _Promise(
          title: '계획은 직접 짜지 않아도 돼요',
          body: '아침마다 빈 시간에 할 일을 놓아 건네요. 확인하고 확정만 하면 돼요',
        ),
      ],
      actions: [
        FilledButton(onPressed: onStart, child: const Text('시작하기')),
        OutlinedButton(
          onPressed: onBrowse,
          child: const Text('둘러보기 · 샘플 학생의 하루', textAlign: TextAlign.center),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          AppStrings.unofficial,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// 약속 하나(제목과 한 줄 설명).
class _Promise extends StatelessWidget {
  const _Promise({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.body.copyWith(fontWeight: AppText.semibold)),
        const SizedBox(height: AppSpace.s4),
        Text(body, style: AppText.small.copyWith(color: AppColors.muted)),
      ],
    );
  }
}
