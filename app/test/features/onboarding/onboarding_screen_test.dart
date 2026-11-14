// 온보딩 화면 테스트. docs/screens.md '14 온보딩', docs/architecture.md '온보딩'·'화면 이동'.
//
// 다섯 단계(1 LMS 로그인 · 2 불러온 시간표 확인 · 3 고정 일정 · 4 AI 사용 동의 · 5 아침 브리핑 시각)를
// 지나며 단계마다 뒤로·건너뛰기가 문서대로 있는지, 시스템 뒤로 가기, 건너뛴 단계 기록, 로그아웃 뒤 다시
// 들어온 경우, 저장 실패에도 계속되는지를 본다. 단계를 지나는 테스트는 debug 빌드의 개발용 '로그인 없이
// 다음으로'로 1단계를 넘어가고(테스트는 debug로 돈다), 1단계 로그인 폼으로 로그인한 뒤의 이동은 가짜 로그인
// 흐름으로 본다(폼 자체는 test/features/lms_connect/login_form_test.dart). 모든 단계를 지나가므로 글자
// 배율 2.0에서도 돌려 단계마다 넘침 예외가 없는지 함께 본다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/login_step.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_login_flow.dart';
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
        await _scrollToInStep(tester, find.text(AppStrings.unofficialShort));
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

        await _tapInStep(tester, find.text('동의하지 않고 계속'));
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
        // 동의하지 않았으므로 AI는 꺼져 있고, 브리핑 시각은 기본값으로 내 규칙에 저장했다.
        expect((await _settings(app)).aiEnabled, isFalse);
        expect((await _settings(app)).aiConsentAt, isNull);
        expect(await _briefingRules(app), [
          (briefingMin: Defaults.briefingMin, source: EntrySource.manual),
        ]);
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

      testWidgets('로그아웃 뒤 다시 들어와 1단계 로그인 폼으로 로그인하면 2–5단계 없이 시작 위치로 '
          '간다', (tester) async {
        final flow = FakeLoginFlow();
        final app = await pumpTestApp(
          tester,
          start: TestStart.loggedOut,
          textScale: textScale,
          overrides: [...lmsConfigOverrides(), loginFlowOverride(flow)],
        );
        // 실제 로그인 흐름은 성공하면 LMS 상태를 active로 쓴다.
        flow.beforeResult = () =>
            writeLmsSessionState(app, LmsSessionState.active);
        _expectStep(OnboardingStep.login);

        await _enterInStep(tester, '학번', '123456');
        await _enterInStep(tester, '비밀번호', 'pw-1234');
        await _tapInStep(tester, find.byType(Checkbox));
        await _tapInStep(tester, find.widgetWithText(FilledButton, '로그인'));
        expect(flow.calls, hasLength(1));
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(TodayScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('4단계에서 동의하면 AI를 켜고 동의 시각을 적는다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          now: _now,
          textScale: textScale,
        );
        await _goToStep(tester, OnboardingStep.aiConsent);
        expect(find.text('보내는 것'), findsOneWidget);

        await _tapInStep(tester, find.text('동의하고 계속'));
        _expectStep(OnboardingStep.briefingTime);
        final settings = await _settings(app);
        expect(settings.aiEnabled, isTrue);
        expect(settings.aiConsentAt, _now);

        await app.dispose(tester);
      });

      testWidgets('5단계는 오전 6:00–오후 12:00 칩 13개에서 기본 오전 8:00을 골라 두고, 고른 시각을 '
          '내 규칙 한 행에 저장한다(이미 있으면 그 행에 합친다)', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
        );
        // 이미 있는 브리핑 시각 규칙(하나만 두는 종류).
        final existing = await RulesRepository(app.db).save(
          kind: RuleKind.notify,
          params: const RuleParams(briefingMin: 420),
          source: EntrySource.manual,
          now: app.clock.current,
        );
        await _goToStep(tester, OnboardingStep.briefingTime);

        final chips = tester.widgetList<ChoiceChip>(
          find.byType(ChoiceChip, skipOffstage: false),
        );
        expect(chips, hasLength(13));
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, '오전 8:00', skipOffstage: false),
              )
              .selected,
          isTrue,
        );

        await _tapInStep(tester, find.widgetWithText(ChoiceChip, '오전 7:30'));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '오전 7:30'))
              .selected,
          isTrue,
        );
        await _tapInStep(tester, find.text('다음'));
        expect(find.byType(OnboardingScreen), findsNothing);

        final rules = (await RulesRepository(app.db).read() as Ok<List<Rule>>)
            .value
            .where((rule) => rule.kind == RuleKind.notify)
            .toList();
        expect(rules, hasLength(1));
        expect(rules.single.id, (existing as Ok<Rule>).value.id);
        expect(rules.single.params, const RuleParams(briefingMin: 450));

        await app.dispose(tester);
      });

      testWidgets('로그인한 뒤 온보딩을 끝내기 전에 앱이 꺼졌으면 2단계부터 다시 연다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          settings: {SettingKeys.lmsSessionState: LmsSessionState.active},
          textScale: textScale,
        );
        _expectStep(OnboardingStep.timetable);
        _expectHeader(
          tester,
          OnboardingStep.timetable,
          back: false,
          skip: false,
        );
        // 1단계로 돌아가 다시 로그인하지 않는다.
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        _expectStep(OnboardingStep.timetable);
        expect(app.router.state.uri.path, Routes.onboarding);

        await app.dispose(tester);
      });

      testWidgets(
        '처음 열 때 로그인하는 중(connecting)이면 1단계, 로그인한 적이 있으면(restoring·reconnectRequired) 2단계다',
        (tester) async {
          // docs/decisions.md 2026-11-14 '로그인하는 중은 로그인 전으로 본다'. 로그인에 실패해 connecting으로
          // 남은 채 둘러보기 → 끝내기로 돌아와도 로그인 없이 2단계로 가지 않는다.
          for (final (state, step) in [
            (LmsSessionState.connecting, OnboardingStep.login),
            (LmsSessionState.restoring, OnboardingStep.timetable),
            (LmsSessionState.reconnectRequired, OnboardingStep.timetable),
          ]) {
            final app = await pumpTestApp(
              tester,
              start: TestStart.fresh,
              settings: {SettingKeys.lmsSessionState: state},
              textScale: textScale,
            );
            _expectStep(step);
            await app.dispose(tester);
          }
        },
      );

      testWidgets('처음 열 때 settings를 읽지 못하면 1단계부터 연다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          settings: {SettingKeys.lmsSessionState: LmsSessionState.active},
          textScale: textScale,
          overrides: [
            settingsRepositoryProvider.overrideWith(
              (ref) => _ReadFails(ref.watch(databaseProvider)),
            ),
          ],
        );
        _expectStep(OnboardingStep.login);

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

        await _tapInStep(tester, find.text('동의하지 않고 계속'));
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
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LoginStep(
              onLoggedIn: () async {},
              onBrowse: () {},
              onSkipLoginForDev: () {},
              showDevSkip: showDevSkip,
            ),
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

/// 4단계에서 시작하는 컨트롤러.
class _StartsAtAiConsent extends OnboardingController {
  @override
  Future<OnboardingState> build() async =>
      const OnboardingState(step: OnboardingStep.aiConsent);
}

/// settings를 읽지 못하는 저장소(폰 DB 읽기 실패 흉내).
class _ReadFails extends SettingsRepository {
  _ReadFails(super.db);

  @override
  Future<Result<AppSettings>> read() async =>
      const Err(StorageError('settings.read'));
}

/// 고정 시각(동의 시각을 견주려고 초 단위로 둠).
final _now = DateTime(2026, 11, 13, 9, 30);

/// 실제 모드 DB의 settings.
Future<AppSettings> _settings(TestApp app) async =>
    switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value,
      Err(:final error) => fail('settings를 읽지 못했다: $error'),
    };

/// 실제 모드 DB의 브리핑 시각 규칙(`notify`).
Future<List<({int? briefingMin, EntrySource source})>> _briefingRules(
  TestApp app,
) async => switch (await RulesRepository(app.db).read()) {
  Ok(:final value) => [
    for (final rule in value)
      if (rule.kind == RuleKind.notify)
        (briefingMin: rule.params.briefingMin, source: rule.source),
  ],
  Err(:final error) => fail('rules를 읽지 못했다: $error'),
};

/// 개발용 넘어가기로 1단계를 지나 [step]까지 간다(3단계는 '다음', 4단계는 동의하지 않음).
Future<void> _goToStep(WidgetTester tester, OnboardingStep step) async {
  await _tapInStep(tester, find.text(_devSkip));
  if (step == OnboardingStep.timetable) return;
  await _tapInStep(tester, find.text('맞아요'));
  if (step == OnboardingStep.fixedBlocks) return;
  await _tapInStep(tester, find.text('다음'));
  if (step == OnboardingStep.aiConsent) return;
  await _tapInStep(tester, find.text('동의하지 않고 계속'));
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

/// 지금 단계가 [step]인지(그 단계 이름이 있는지). 글자가 크면 아래 버튼을 보려고 스크롤해 이름이 화면
/// 위로 밀려 있을 수 있으므로 화면 밖도 찾는다.
void _expectStep(OnboardingStep step) {
  expect(
    find.text(step.title, skipOffstage: false),
    findsOneWidget,
    reason: step.name,
  );
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

/// 지금 단계의 버튼이 보이게 스크롤한다. 글자가 크면 버튼이 화면 아래로 밀려 있어, 그려질 때까지 내린 뒤
/// 화면 안으로 끝까지 맞춘다.
Future<void> _scrollToInStep(WidgetTester tester, Finder button) async {
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
  await tester.ensureVisible(button);
  await tester.pump();
}

/// 지금 단계의 입력 칸 [label]에 [text]를 넣는다.
Future<void> _enterInStep(
  WidgetTester tester,
  String label,
  String text,
) async {
  final field = find.widgetWithText(TextField, label);
  await _scrollToInStep(tester, field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// 지금 단계의 버튼을 누른다.
Future<void> _tapInStep(WidgetTester tester, Finder button) async {
  await _scrollToInStep(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
