// 온보딩 화면 테스트. docs/architecture.md '온보딩', '화면 이동'.
//
// 건너뛴 단계는 settings의 onboardingSkipped에 단계 번호로 남고, 돌아와 마친 단계는 빠지며,
// 마지막 단계를 넘기면 shared_preferences의 onboarding_done이 true가 되고 시작 위치로 간다.
// 실제 모드에서 LMS 상태가 disconnected면 시작 위치 규칙이 온보딩으로 돌려보낸다.
// 모든 단계를 지나가므로 글자 배율 2.0에서도 돌려 단계마다 넘침 예외가 없는지 함께 본다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:cnu_ai_assistant/lms/lms_feature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('건너뛴 단계는 onboardingSkipped에 남고 끝내면 onboarding_done이 켜지며, '
          'LMS에 로그인하지 않았으면 온보딩에 머문다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          briefingOpenedToday: false,
          textScale: textScale,
        );
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // 1단계에는 건너뛰기가 없다. '시작하기'로 2단계에 간다.
        expect(find.text('건너뛰기'), findsNothing);
        await _tapInStep(tester, find.text('시작하기'));
        expect(find.text(OnboardingStep.privacy.title), findsOneWidget);

        // 2단계를 건너뛰면 2가 남는다.
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        expect(await _skipped(app), [2]);

        // 이전 단계로 돌아가 '확인했어요'로 마치면 2가 빠진다.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text(OnboardingStep.privacy.title), findsOneWidget);
        await _tapInStep(tester, find.text('확인했어요'));
        expect(await _skipped(app), isEmpty);

        // 3–6단계는 건너뛰고(LMS 연결은 LMS_INCLUDED일 때만 있다), 7단계는 '다음', 8단계는 건너뛴다.
        final placeholders = [
          if (LmsFeature.included) OnboardingStep.lmsConnect,
          OnboardingStep.timetable,
          OnboardingStep.fixedBlocks,
          OnboardingStep.aiConsent,
        ];
        await _skipSteps(tester, placeholders);
        await _finishFromBriefingTime(tester, app);

        expect(app.preferences.getBool('onboarding_done'), isTrue);
        expect(await _skipped(app), [
          for (final step in placeholders) step.number,
          OnboardingStep.firstBriefing.number,
        ]);
        // LMS 상태가 아직 disconnected(로그인 전)라 시작 위치 규칙이 온보딩으로 돌려보낸다.
        expect(await readLmsSessionState(app), LmsSessionState.disconnected);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(BriefingScreen), findsNothing);
        expect(app.router.state.uri.path, Routes.onboarding);

        await app.dispose(tester);
      });
    });
  }
}

/// 실제 모드 DB의 건너뛴 단계 목록.
Future<List<int>> _skipped(TestApp app) async =>
    switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value.onboardingSkipped,
      Err(:final error) => fail('settings를 읽지 못했다: $error'),
    };

/// [steps]를 차례로 건너뛴다(화면 위 머리의 '건너뛰기').
Future<void> _skipSteps(WidgetTester tester, List<OnboardingStep> steps) async {
  for (final step in steps) {
    expect(find.text(step.title), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
  }
}

/// 7단계는 '다음', 8단계는 건너뛰어 온보딩을 끝낸다.
Future<void> _finishFromBriefingTime(WidgetTester tester, TestApp app) async {
  expect(find.text('아침 브리핑을 몇 시에 받을까요?'), findsOneWidget);
  await _tapInStep(tester, find.text('다음'));
  expect(find.text(OnboardingStep.firstBriefing.title), findsOneWidget);
  expect(app.preferences.getBool('onboarding_done'), isNull);

  await tester.tap(find.text('건너뛰기'));
  await tester.pumpAndSettle();
}

/// 지금 단계의 버튼을 누른다. 글자가 크면 버튼이 화면 아래로 밀려 있으므로 먼저 스크롤한다.
Future<void> _tapInStep(WidgetTester tester, Finder button) async {
  await tester.scrollUntilVisible(
    button,
    100,
    scrollable: find
        .descendant(
          of: find.byType(OnboardingStepLayout),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(button);
  await tester.pumpAndSettle();
}
