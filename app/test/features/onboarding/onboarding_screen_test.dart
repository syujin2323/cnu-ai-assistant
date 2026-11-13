// 온보딩 화면 테스트. docs/screens.md '14 온보딩', docs/architecture.md '온보딩'·'화면 이동'.
//
// 다섯 단계(1 LMS 로그인 · 2 불러온 시간표 확인 · 3 고정 일정 · 4 AI 사용 동의 · 5 아침 브리핑 시각)를
// 지나며 단계마다 뒤로·건너뛰기가 문서대로 있는지, 시스템 뒤로 가기, 건너뛴 단계 기록, 로그아웃 뒤 다시
// 들어온 경우, 저장 실패에도 계속되는지를 본다. 1단계 로그인 폼은 아직 없어 debug 빌드의 개발용
// '로그인 없이 다음으로'로 넘어간다(테스트는 debug로 돈다). 모든 단계를 지나가므로 글자 배율 2.0에서도
// 돌려 단계마다 넘침 예외가 없는지 함께 본다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/login_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// 개발용 버튼 문구.
const _devSkip = '로그인 없이 다음으로';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('다섯 단계를 지나며 뒤로·건너뛰기가 문서대로 있고, 5단계를 마치면 '
          'onboarding_done을 켜고 /briefing으로 간다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          briefingOpenedToday: false,
          textScale: textScale,
        );

        // 1단계: 머리가 없다(뒤로·건너뛰기 없음). 아래에 둘러보기와 비공식 표시가 있다.
        _expectStep(OnboardingStep.login);
        _expectHeader(tester, OnboardingStep.login, back: false, skip: false);
        expect(find.text('로그인 없이 둘러보기 · 샘플 학생의 하루'), findsOneWidget);
        expect(find.text(AppStrings.unofficialShort), findsOneWidget);

        // 시스템 뒤로 가기는 1단계에서는 화면을 닫는다(받지 않고 넘기므로 앱을 나간다).
        expect(await tester.binding.handlePopRoute(), isFalse);
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.login);

        // 개발용 '로그인 없이 다음으로'는 LMS 상태를 active로 쓰고 2단계로 간다.
        await _tapInStep(tester, find.text(_devSkip));
        _expectStep(OnboardingStep.timetable);
        expect(await readLmsSessionState(app), LmsSessionState.active);

        // 2단계: 뒤로·건너뛰기가 없고 시스템 뒤로 가기도 받지 않는다(앱을 나가지도 않는다).
        _expectHeader(
          tester,
          OnboardingStep.timetable,
          back: false,
          skip: false,
        );
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.timetable);
        expect(app.router.state.uri.path, Routes.onboarding);

        // 3단계만 건너뛸 수 있고, 3단계부터 뒤로 갈 수 있다.
        await _tapInStep(tester, find.text('맞아요'));
        _expectStep(OnboardingStep.fixedBlocks);
        _expectHeader(
          tester,
          OnboardingStep.fixedBlocks,
          back: true,
          skip: true,
        );

        await _tapInStep(tester, find.text('다음'));
        _expectStep(OnboardingStep.aiConsent);
        _expectHeader(
          tester,
          OnboardingStep.aiConsent,
          back: true,
          skip: false,
        );

        await _tapInStep(tester, find.text('다음'));
        _expectStep(OnboardingStep.briefingTime);
        _expectHeader(
          tester,
          OnboardingStep.briefingTime,
          back: true,
          skip: false,
        );
        expect(app.preferences.getBool(PrefKeys.onboardingDone), isNull);

        await _tapInStep(tester, find.text('다음'));
        expect(app.preferences.getBool(PrefKeys.onboardingDone), isTrue);
        expect(await _skipped(app), isEmpty);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(BriefingScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.briefing);

        await app.dispose(tester);
      });

      testWidgets('3단계를 건너뛰면 [3]이 남고, 뒤로 돌아와 마치면 빠진다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
        );
        await _tapInStep(tester, find.text(_devSkip));
        await _tapInStep(tester, find.text('맞아요'));

        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.aiConsent);
        expect(await _skipped(app), [OnboardingStep.fixedBlocks.number]);

        // 시스템 뒤로 가기는 3–5단계에서 앞 단계로 간다.
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.fixedBlocks);

        await _tapInStep(tester, find.text('다음'));
        _expectStep(OnboardingStep.aiConsent);
        expect(await _skipped(app), isEmpty);

        // 앞 단계 버튼도 같다.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.fixedBlocks);

        await app.dispose(tester);
      });

      testWidgets('로그아웃 뒤 다시 들어와 1단계에서 로그인하면 2–5단계 없이 시작 위치로 간다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.loggedOut,
          textScale: textScale,
        );
        _expectStep(OnboardingStep.login);

        await _tapInStep(tester, find.text(_devSkip));
        expect(await readLmsSessionState(app), LmsSessionState.active);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(TodayScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('건너뛴 단계를 저장하지 못해도 온보딩은 계속된다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          briefingOpenedToday: false,
          textScale: textScale,
          overrides: [
            settingsRepositoryProvider.overrideWith(
              (ref) => _SkippedWriteFails(ref.watch(databaseProvider)),
            ),
          ],
        );
        await _tapInStep(tester, find.text(_devSkip));
        await _tapInStep(tester, find.text('맞아요'));
        await tester.tap(find.text('건너뛰기'));
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.aiConsent);
        expect(await _skipped(app), isEmpty);

        await _tapInStep(tester, find.text('다음'));
        await _tapInStep(tester, find.text('다음'));
        expect(find.byType(BriefingScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('저장이 끝나기 전에는 다음·뒤로를 다시 받지 않는다', (tester) async {
        final gate = _Gate();
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
          overrides: [
            settingsRepositoryProvider.overrideWith(
              (ref) => _GatedSettings(ref.watch(databaseProvider), gate),
            ),
          ],
        );
        await _tapInStep(tester, find.text(_devSkip));

        // 2단계: 저장이 끝나기 전에 '맞아요'를 한 번 더 눌러도 한 단계만 간다.
        await _scrollToInStep(tester, find.text('맞아요'));
        gate.close();
        await tester.tap(find.text('맞아요'));
        await tester.pump();
        await tester.tap(find.text('맞아요'));
        await tester.pump();
        gate.open();
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.fixedBlocks);

        // 3단계: 저장이 끝나기 전에 앞 단계를 눌러도 받지 않는다.
        await _scrollToInStep(tester, find.text('다음'));
        gate.close();
        await tester.tap(find.text('다음'));
        await tester.pump();
        await tester.tap(find.byType(BackButton));
        await tester.pump();
        gate.open();
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.aiConsent);

        await app.dispose(tester);
      });
    });
  }

  testWidgets("개발용 '$_devSkip'는 끄면 보이지 않는다(release·profile 빌드와 같음)", (
    tester,
  ) async {
    Future<void> pumpStep({required bool showDevSkip}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginStep(
            onBrowse: () {},
            onSkipLoginForDev: () {},
            showDevSkip: showDevSkip,
          ),
        ),
      ),
    );

    // 테스트는 debug 빌드로 돌므로 기본값이면 보인다.
    await pumpStep(showDevSkip: true);
    expect(find.text(_devSkip), findsOneWidget);

    await pumpStep(showDevSkip: false);
    expect(find.text(OnboardingStep.login.title), findsOneWidget);
    expect(find.text(_devSkip), findsNothing);
  });

  testWidgets('처음 그릴 때 컨트롤러의 지금 단계를 연다', (tester) async {
    final app = await pumpTestApp(
      tester,
      start: TestStart.fresh,
      overrides: [
        onboardingControllerProvider.overrideWith(_StartsAtAiConsent.new),
      ],
    );
    _expectStep(OnboardingStep.aiConsent);
    _expectHeader(tester, OnboardingStep.aiConsent, back: true, skip: false);

    await app.dispose(tester);
  });

  test('단계 번호는 1–5이고, 건너뛴 단계 목록에 모두 쓸 수 있다', () {
    expect(OnboardingStep.values.map((step) => step.number), [1, 2, 3, 4, 5]);
    expect(
      AppSettings.encodeValue(SettingKeys.onboardingSkipped, [
        for (final step in OnboardingStep.values) step.number,
      ]),
      [1, 2, 3, 4, 5],
    );
    expect(
      [
        for (final step in OnboardingStep.values)
          if (step.skippable) step,
      ],
      [OnboardingStep.fixedBlocks],
    );
  });
}

/// 4단계에서 시작하는 컨트롤러(온보딩 도중 다시 열 때처럼).
class _StartsAtAiConsent extends OnboardingController {
  @override
  OnboardingState build() =>
      const OnboardingState(step: OnboardingStep.aiConsent);
}

/// 건너뛴 단계 목록만 쓰지 못하는 저장소(폰 DB 쓰기 실패 흉내).
class _SkippedWriteFails extends SettingsRepository {
  _SkippedWriteFails(super.db);

  @override
  Future<Result<void>> write(String key, Object? value) async {
    if (key == SettingKeys.onboardingSkipped) {
      return const Err(StorageError('settings.write'));
    }
    return super.write(key, value);
  }
}

/// 저장소 읽기를 붙잡아 두는 문. 닫혀 있는 동안 읽기가 끝나지 않는다(저장 중 흉내).
class _Gate {
  Completer<void>? _closed;

  void close() => _closed = Completer<void>();

  void open() {
    _closed?.complete();
    _closed = null;
  }

  Future<void> wait() => _closed?.future ?? Future<void>.value();
}

/// 문이 닫혀 있으면 읽기를 기다리게 하는 저장소.
class _GatedSettings extends SettingsRepository {
  _GatedSettings(super.db, this.gate);

  final _Gate gate;

  @override
  Future<Result<AppSettings>> read() async {
    await gate.wait();
    return super.read();
  }
}

/// 지금 단계가 [step]인지(그 단계 이름이 보이는지).
void _expectStep(OnboardingStep step) {
  expect(find.text(step.title), findsOneWidget, reason: step.name);
}

/// 화면 위 머리. 1단계에는 없고, 2단계부터 진행 막대와 앞 단계·건너뛰기 버튼(있는 단계만)이 있다.
void _expectHeader(
  WidgetTester tester,
  OnboardingStep step, {
  required bool back,
  required bool skip,
}) {
  expect(find.byType(BackButton), back ? findsOneWidget : findsNothing);
  expect(find.text('건너뛰기'), skip ? findsOneWidget : findsNothing);
  final progress = find.byType(LinearProgressIndicator);
  if (step == OnboardingStep.login) {
    expect(progress, findsNothing);
  } else {
    final bar = tester.widget<LinearProgressIndicator>(progress);
    expect(bar.semanticsLabel, '온보딩 5단계 중 ${step.number}단계');
    // 바탕은 진행 막대 바탕 토큰이다.
    expect(bar.backgroundColor, AppColors.light.tint2);
  }
}

/// 실제 모드 DB의 건너뛴 단계 목록.
Future<List<int>> _skipped(TestApp app) async =>
    switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value.onboardingSkipped,
      Err(:final error) => fail('settings를 읽지 못했다: $error'),
    };

/// 지금 단계의 버튼이 보이게 스크롤한다. 글자가 크면 버튼이 화면 아래로 밀려 있다.
Future<void> _scrollToInStep(WidgetTester tester, Finder button) =>
    tester.scrollUntilVisible(
      button,
      100,
      scrollable: find
          .descendant(
            of: find.byType(OnboardingStepLayout),
            matching: find.byType(Scrollable),
          )
          .first,
    );

/// 지금 단계의 버튼을 누른다.
Future<void> _tapInStep(WidgetTester tester, Finder button) async {
  await _scrollToInStep(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
