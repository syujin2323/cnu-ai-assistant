// 화면 테스트가 함께 쓰는 RootApp 띄우기 도우미. docs/architecture.md '확인과 CI'.
//
// Firebase 없이 RootApp만 띄운다. ProviderScope overrides로 폰 DB는 모드마다 메모리 DB, 모션 등급은
// off, SharedPreferences는 모의 값, 오늘 브리핑을 열었는지는 정해 둔 값으로 바꾼다. 시작 상태는
// [TestStart] 고정값 넷 가운데 하나로 정하고, 앱이 읽는 곳(SharedPreferences와 실제 모드 DB의
// settings)에 그대로 쓴다. 셸 테스트와 온보딩 테스트가 이 도우미를 함께 쓴다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 폰 화면 크기(세로, 390×844pt).
const phonePortrait = Size(390, 844);

/// Android 16이 방향 고정을 따르지 않는 큰 화면(태블릿 가로) 크기.
const tabletLandscape = Size(1280, 800);

/// 시작 상태 고정값. docs/architecture.md '화면 이동'의 시작 위치 규칙이 보는 값이다.
enum TestStart {
  /// 온보딩을 끝냈고 LMS에 로그인한 상태(`onboarding_done` + `lmsSessionState` active).
  loggedIn,

  /// 온보딩을 끝냈지만 로그아웃한 상태(`onboarding_done` + `lmsSessionState` disconnected).
  loggedOut,

  /// 처음 설치한 상태(아무 값 없음).
  fresh,

  /// 로그인 화면의 '로그인 없이 둘러보기'로 들어간 데모 모드(`app_mode` demo, `demo_entry` onboarding).
  demo,
}

/// 띄운 앱과 정리 함수.
class TestApp {
  TestApp(this.db, this.demoDb, this.preferences, this.container);

  /// 실제 모드의 폰 DB(메모리).
  final AppDatabase db;

  /// 데모 모드의 폰 DB(메모리).
  final AppDatabase demoDb;
  final SharedPreferences preferences;
  final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  /// 위젯 트리를 내려 provider를 정리한 뒤 DB를 닫는다(drift 스트림 타이머가 남지 않게).
  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await db.close();
    await demoDb.close();
  }
}

/// [size](기본은 폰 세로)에서 [start] 상태로 RootApp을 띄운다.
///
/// [preferences]·[settings]는 고정값 위에 덧쓴다. [briefingCheckFails]가 true면 오늘 브리핑을
/// 열었는지 확인하는 함수가 예외를 던진다. [now]를 주면 시계를 그 시각으로 고정한다.
Future<TestApp> pumpTestApp(
  WidgetTester tester, {
  TestStart start = TestStart.loggedIn,
  Map<String, Object> preferences = const {},
  Map<String, Object?> settings = const {},
  bool briefingOpenedToday = true,
  bool briefingCheckFails = false,
  String? launchPayload,
  DateTime? now,
  double textScale = 1.0,
  Size size = phonePortrait,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    if (start == TestStart.loggedIn || start == TestStart.loggedOut)
      PrefKeys.onboardingDone: true,
    if (start == TestStart.demo) ...{
      PrefKeys.appMode: AppMode.demo.name,
      PrefKeys.demoEntry: DemoEntry.onboarding.name,
    },
    ...preferences,
  });
  final sharedPreferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final demoDb = AppDatabase.memory();

  // LMS 상태는 앱 모드와 관계없이 실제 DB의 settings에 있다(docs/architecture.md '데모 모드').
  final settingsRepository = SettingsRepository(db);
  final startSettings = <String, Object?>{
    if (start == TestStart.loggedIn)
      SettingKeys.lmsSessionState: LmsSessionState.active,
    if (start == TestStart.loggedOut)
      SettingKeys.lmsSessionState: LmsSessionState.disconnected,
    ...settings,
  };
  for (final MapEntry(:key, :value) in startSettings.entries) {
    expect(
      await settingsRepository.write(key, value),
      isA<Ok<void>>(),
      reason: 'settings $key',
    );
  }

  Future<bool> briefingOpened() async {
    if (briefingCheckFails) throw StateError('브리핑 확인 실패(시험)');
    return briefingOpenedToday;
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // 실제 databaseProvider처럼 앱 모드를 보고 DB를 고르게 해, 데모 전환이 provider 사이
        // 의존 관계까지 그대로 돌게 한다. 파일 대신 모드마다 메모리 DB를 쓴다.
        databaseProvider.overrideWith(
          (ref) => switch (ref.watch(appModeProvider)) {
            AppMode.real => db,
            AppMode.demo => demoDb,
          },
        ),
        motionLevelProvider.overrideWithValue(MotionLevel.off),
        briefingOpenedTodayProvider.overrideWithValue(briefingOpened),
        launchPayloadProvider.overrideWithValue(launchPayload),
        if (now != null) clockProvider.overrideWithValue(FixedClock(now)),
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
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RootApp)),
  );
  return TestApp(db, demoDb, sharedPreferences, container);
}

/// 하단 탭 [label]. 지금 탭이 아니면 글자가 없으므로 접근성 이름으로 찾는다.
Finder tabButton(String label) => find.descendant(
  of: find.byType(AppTabBar),
  matching: find.bySemanticsLabel(label),
);

/// 하단 탭 옆 'AI 비서에게 말하기' 버튼.
Finder assistantButton() => find.descendant(
  of: find.byType(AppTabBar),
  matching: find.bySemanticsLabel(AppStrings.askAssistant),
);

/// 하단 탭 [label]을 누른다.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(tabButton(label));
  await tester.pumpAndSettle();
}

/// 글자 [text]를 누른다. 글자가 크면 버튼이 화면 밖에 있을 수 있으므로 먼저 보이게 스크롤한다.
Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// [target]이 화면에 보이게 스크롤한다. 글자가 크면 아래쪽 버튼은 스크롤해야 그려지므로,
/// 아직 없으면 세로로 스크롤되는 첫 영역을 내려 가며 찾는다.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
