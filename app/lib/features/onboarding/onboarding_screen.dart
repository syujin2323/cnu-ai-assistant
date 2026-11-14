// 온보딩(셸 밖 `/onboarding`). docs/screens.md '14 온보딩', docs/architecture.md '온보딩', '데모 모드'.
//
// `steps/` 아래 다섯 단계 파일을 `PageView`로 넘긴다. 단계는 버튼으로만 넘기고(스와이프 없음), 2단계부터 화면
// 위 머리에 진행 막대를 둔다. 뒤로 가기는 3단계부터, '건너뛰기'는 3단계에만 있다. 시스템 뒤로 가기는 1단계에서는
// 화면을 닫고(앱을 나감), 2단계에서는 받지 않으며, 3–5단계에서는 앞 단계로 간다. 저장 같은 일이 진행 중이면
// 다음·건너뛰기·뒤로 가기를 받지 않는다([OnboardingState.busy]). 5단계를 마치거나 로그아웃 뒤 1단계에서
// 로그인하면 `/`로 가고, 시작 위치(redirect)가 브리핑이나 오늘로 보낸다. 실제 모드에서 LMS 상태가 아직
// `disconnected`면(로그인 전) 온보딩에 머문다. '로그인 없이 둘러보기'는 데모 모드로 들어간다. 처음 열 때
// 컨트롤러가 시작 단계(로그인한 뒤 끝내기 전에 꺼졌으면 2단계)를 정하는 동안은 빈 화면이다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/ai_consent_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/briefing_time_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/fixed_blocks_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/login_step.dart';
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
  /// 처음 그릴 때 지금 단계로 만든다.
  PageController? _pages;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      onboardingControllerProvider.select((state) => state.value?.step),
      (previous, next) {
        // 처음 읽기가 끝난 때(null → 단계)는 PageController가 그 단계로 만들어진다.
        if (previous != null && next != null) _showPage(next.index);
      },
    );
    final state = ref.watch(onboardingControllerProvider).value;
    // 시작 단계를 정하려고 settings를 읽는 동안(아주 잠깐)은 빈 화면이다.
    if (state == null) return const Scaffold(body: SizedBox.shrink());
    final pages = _pages ??= PageController(initialPage: state.step.index);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final step = state.step;
    return PopScope(
      canPop: step == OnboardingStep.login && !state.busy,
      // 2단계는 받지 않고 3–5단계는 앞 단계로 간다([OnboardingController.back]이 가른다).
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) controller.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (step != OnboardingStep.login)
                _OnboardingHeader(
                  step: step,
                  onBack: step.canGoBack ? controller.back : null,
                  onSkip: step.skippable
                      ? () => _run((controller) => controller.skip())
                      : null,
                ),
              Expanded(
                // 머리가 나타나고 사라져도 PageView 상태를 그대로 두도록 키를 단다.
                key: const ValueKey('onboarding-pages'),
                child: PageView(
                  controller: pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final step in OnboardingStep.values) _stepView(step),
                  ],
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
      OnboardingStep.login => LoginStep(
        onLoggedIn: () => _run((controller) => controller.loggedIn()),
        onBrowse: () => _run((controller) => controller.browseDemo()),
        onSkipLoginForDev: ref.watch(devLoginSkipAllowedProvider)
            ? () => _run((controller) => controller.skipLoginForDev())
            : null,
      ),
      OnboardingStep.timetable => TimetableStep(onConfirm: next),
      OnboardingStep.fixedBlocks => FixedBlocksStep(onNext: next),
      OnboardingStep.aiConsent => AiConsentStep(
        onConsent: () => _run((controller) => controller.consentToAi()),
        onDecline: () => _run((controller) => controller.declineAi()),
      ),
      OnboardingStep.briefingTime => BriefingTimeStep(
        onDone: (briefingMin) => _run(
          (controller) => controller.finishWithBriefingTime(briefingMin),
        ),
      ),
    };
  }

  void _showPage(int index) {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    if (ref.read(motionLevelProvider) == MotionLevel.off) {
      pages.jumpToPage(index);
    } else {
      pages.animateToPage(
        index,
        duration: AppMotion.standard,
        curve: AppEase.standard,
      );
    }
  }

  /// 단계 동작을 한다. 온보딩을 끝냈거나, 로그아웃 뒤 1단계에서 로그인했거나, 데모로 들어갔으면 시작
  /// 위치로 간다.
  Future<void> _run(
    Future<bool> Function(OnboardingController controller) action,
  ) async {
    final finished = await action(
      ref.read(onboardingControllerProvider.notifier),
    );
    if (finished && mounted) context.go(Routes.root);
  }
}

/// 2단계부터 보이는 머리: 앞 단계(3단계부터), 진행 막대, 건너뛰기(3단계만).
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.step, this.onBack, this.onSkip});

  final OnboardingStep step;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = OnboardingStep.values.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: ConstrainedBox(
        // 버튼이 없는 단계에서도 머리 높이가 같게 둔다(글자가 커지면 늘어남).
        constraints: const BoxConstraints(minHeight: AppSize.minTouch),
        child: Row(
          children: [
            if (onBack case final onBack?)
              BackButton(onPressed: onBack)
            else
              const SizedBox(width: AppSpace.s16),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                // 진행 막대의 접근성 값은 숫자(백분율)여야 하므로 단계 위치는 라벨에 넣는다.
                child: LinearProgressIndicator(
                  value: step.number / count,
                  color: colors.accent,
                  backgroundColor: colors.tint2,
                  semanticsLabel: '온보딩 $count단계 중 ${step.number}단계',
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            if (onSkip case final onSkip?)
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(foregroundColor: colors.muted),
                child: const Text('건너뛰기'),
              )
            else
              const SizedBox(width: AppSpace.s16),
          ],
        ),
      ),
    );
  }
}
