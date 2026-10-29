// 온보딩 화면 테스트. docs/architecture.md '온보딩'.
//
// 건너뛴 단계는 settings의 onboardingSkipped에 단계 번호로 남고, 돌아와 마친 단계는 빠지며,
// 마지막 단계를 넘기면 shared_preferences의 onboarding_done이 true가 되고 시작 위치로 간다.
// 모든 단계를 지나가므로 글자 배율 2.0에서도 돌려 단계마다 넘침 예외가 없는지 함께 본다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:cnu_ai_assistant/lms/lms_feature.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('건너뛴 단계는 onboardingSkipped에 남고, 끝내면 onboarding_done이 켜진다'
        '(글자 배율 $textScale)', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      final settings = SettingsRepository(db);
      Future<List<int>> skipped() async => switch (await settings.read()) {
        Ok(:final value) => value.onboardingSkipped,
        Err(:final error) => fail('settings를 읽지 못했다: $error'),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            databaseProvider.overrideWithValue(db),
            motionLevelProvider.overrideWithValue(MotionLevel.off),
            briefingOpenedTodayProvider.overrideWithValue(() async => false),
          ],
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: const RootApp(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);

      // 1단계에는 건너뛰기가 없다. '시작하기'로 2단계에 간다.
      expect(find.text('건너뛰기'), findsNothing);
      await _tapInStep(tester, find.text('시작하기'));
      expect(find.text(OnboardingStep.privacy.title), findsOneWidget);

      // 2단계를 건너뛰면 2가 남는다.
      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();
      expect(await skipped(), [2]);

      // 이전 단계로 돌아가 '확인했어요'로 마치면 2가 빠진다.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(OnboardingStep.privacy.title), findsOneWidget);
      await _tapInStep(tester, find.text('확인했어요'));
      expect(await skipped(), isEmpty);

      // 3–6단계는 건너뛰고(사캠 연결은 LMS_INCLUDED일 때만 있다), 7단계는 '다음', 8단계는 건너뛴다.
      final placeholders = [
        if (LmsFeature.included) OnboardingStep.lmsConnect,
        OnboardingStep.timetable,
        OnboardingStep.fixedBlocks,
        OnboardingStep.aiConsent,
      ];
      for (final step in placeholders) {
        expect(find.text(step.title), findsOneWidget);
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
      }
      expect(find.text('아침 브리핑을 몇 시에 받을까요?'), findsOneWidget);
      await _tapInStep(tester, find.text('다음'));
      expect(find.text(OnboardingStep.firstBriefing.title), findsOneWidget);
      expect(preferences.getBool('onboarding_done'), isNull);

      await tester.tap(find.text('건너뛰기'));
      await tester.pumpAndSettle();

      expect(preferences.getBool('onboarding_done'), isTrue);
      expect(await skipped(), [
        for (final step in placeholders) step.number,
        OnboardingStep.firstBriefing.number,
      ]);
      // 오늘 브리핑을 아직 열지 않았으므로 시작 위치는 /briefing이다.
      expect(find.byType(BriefingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await db.close();
    });
  }
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
