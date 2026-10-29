// 온보딩(셸 밖 `/onboarding`). docs/architecture.md '온보딩', '데모 모드'.
//
// `steps/` 아래 단계 파일을 `PageView`로 넘긴다. 단계는 버튼으로만 넘기고(스와이프 없음), 뒤로 가기는
// `PopScope`로 앞 단계에 돌아간다. 2단계부터 화면 위 머리에 '이전 단계', 진행 막대, '건너뛰기'를 둔다.
// 끝내면 시작 위치(redirect)가 브리핑이나 오늘로 보낸다. '둘러보기'는 데모 모드로 들어간다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/ai_consent_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/briefing_time_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/first_briefing_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/fixed_blocks_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/intro_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/lms_connect_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/privacy_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/timetable_step.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 온보딩.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();

  /// 버튼을 두 번 눌러 같은 동작이 겹치지 않게 막는다.
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = OnboardingStep.active;
    final index = ref.watch(onboardingControllerProvider);
    ref.listen(
      onboardingControllerProvider,
      (previous, next) => _showPage(next),
    );
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) ref.read(onboardingControllerProvider.notifier).back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (index > 0)
                _OnboardingHeader(
                  index: index,
                  count: steps.length,
                  onBack: () =>
                      ref.read(onboardingControllerProvider.notifier).back(),
                  onSkip: () => _run((controller) => controller.skip()),
                ),
              Expanded(
                // 머리가 나타나고 사라져도 PageView 상태를 그대로 두도록 키를 단다.
                key: const ValueKey('onboarding-pages'),
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final step in steps) _stepView(step)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepView(OnboardingStep step) {
    Future<void> next() => _run((controller) => controller.next());
    return switch (step) {
      OnboardingStep.intro => IntroStep(onStart: next, onBrowse: _browseDemo),
      OnboardingStep.privacy => PrivacyStep(onConfirm: next),
      OnboardingStep.lmsConnect => const LmsConnectStep(),
      OnboardingStep.timetable => const TimetableStep(),
      OnboardingStep.fixedBlocks => const FixedBlocksStep(),
      OnboardingStep.aiConsent => const AiConsentStep(),
      OnboardingStep.briefingTime => BriefingTimeStep(onNext: next),
      OnboardingStep.firstBriefing => const FirstBriefingStep(),
    };
  }

  void _showPage(int index) {
    if (!_pages.hasClients) return;
    if (ref.read(motionLevelProvider) == MotionLevel.off) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(
        index,
        duration: AppMotion.standard,
        curve: AppEase.standard,
      );
    }
  }

  /// 다음·건너뛰기를 한다. 마지막 단계였으면 시작 위치로 간다.
  Future<void> _run(
    Future<bool> Function(OnboardingController controller) action,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      final finished = await action(
        ref.read(onboardingControllerProvider.notifier),
      );
      if (finished && mounted) context.go(Routes.root);
    } finally {
      _busy = false;
    }
  }

  /// '둘러보기': 데모 모드로 들어간다. 시작 위치가 데모 DB를 보고 브리핑이나 오늘로 보낸다.
  Future<void> _browseDemo() async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(appModeProvider.notifier).enterDemo(DemoEntry.onboarding);
      if (mounted) context.go(Routes.root);
    } finally {
      _busy = false;
    }
  }
}

/// 2단계부터 보이는 머리: 이전 단계, 진행 막대, 건너뛰기.
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.index,
    required this.count,
    required this.onBack,
    required this.onSkip,
  });

  final int index;
  final int count;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Row(
        children: [
          BackButton(onPressed: onBack),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              // 진행 막대의 접근성 값은 숫자(백분율)여야 하므로 단계 위치는 라벨에 넣는다.
              child: LinearProgressIndicator(
                value: (index + 1) / count,
                color: AppColors.accent,
                backgroundColor: AppColors.tint,
                semanticsLabel: '온보딩 $count단계 중 ${index + 1}단계',
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }
}
