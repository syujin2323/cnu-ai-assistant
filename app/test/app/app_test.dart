// 앱이 뜨고 캘린더 첫 화면과 드로어가 도는지 보는 화면 테스트와 시작 위치·라우트 표·데모 전환 테스트.
// docs/architecture.md '확인과 CI', '화면 이동', '데모 모드'.
//
// Firebase 없이 RootApp만 띄운다. ProviderScope overrides로 폰 DB는 메모리 DB, 모션 등급은 off,
// SharedPreferences는 모의 값, 오늘 브리핑을 열었는지는 정해 둔 값으로 바꾼다.
// 모든 검사를 글자 배율 1.0과 2.0에서 돌려 넘침(RenderFlex overflow) 예외가 없어야 한다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/agenda_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/day_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/year_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/me/rules_screen.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/search/search_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_detail_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 모드마다 다른 메모리 DB 두 개를 함께 열어 둔다. drift의 '같은 DB 클래스를 여러 번 만듦' 경고는
  // 두 인스턴스가 같은 연결을 쓸 때를 알리는 것이라 여기에는 해당하지 않으므로 끈다.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('온보딩을 끝냈고 오늘 브리핑을 열었으면 /calendar 월간이 뜨고 '
          '드로어로 보기와 화면을 오간다', (tester) async {
        final app = await _pumpApp(
          tester,
          preferences: {'onboarding_done': true},
          textScale: textScale,
        );

        expect(find.byType(MonthScreen), findsOneWidget);
        expect(find.byType(CalendarBottomBar), findsOneWidget);
        // 글자 배율이 앱 안 화면까지 그대로 닿는지(앱이 textScaler를 덮어쓰지 않는지) 본다.
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(MonthScreen)))
              .scale(10),
          10 * textScale,
        );

        // 보기끼리는 바꾸고(go), 나머지는 위에 쌓는다(push).
        for (final (label, screen) in <(String, Type)>[
          ('년', YearScreen),
          ('주', WeekScreen),
          ('일', DayScreen),
          ('일정', AgendaScreen),
          ('월', MonthScreen),
        ]) {
          await _openDrawerItem(tester, label);
          expect(find.byType(screen), findsOneWidget, reason: label);
        }

        await _openDrawerItem(tester, '미배정 할 일');
        expect(find.byType(TaskListScreen), findsOneWidget);
        app.router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(MonthScreen), findsOneWidget);

        await tester.tap(find.byTooltip('검색'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);
        app.router.pop();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('나'));
        await tester.pumpAndSettle();
        expect(find.byType(MeScreen), findsOneWidget);

        await app.dispose(tester);
      });

      group('시작 위치', () {
        testWidgets('온보딩을 끝내지 않았으면 /onboarding으로 간다', (tester) async {
          final app = await _pumpApp(
            tester,
            preferences: {},
            textScale: textScale,
          );

          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.byType(CalendarBottomBar), findsNothing);
          // 첫 화면 맨 아래의 표시까지 내려 본다(글자가 크면 처음에는 그려지지 않는다).
          await _scrollTo(tester, find.text('충남대 비공식 앱 · 학교와 관계없는 학생 프로젝트'));
          expect(find.text('시작하기'), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('온보딩을 끝냈고 오늘 브리핑을 아직 열지 않았으면 /briefing으로 간다', (
          tester,
        ) async {
          final app = await _pumpApp(
            tester,
            preferences: {'onboarding_done': true},
            briefingOpenedToday: false,
            textScale: textScale,
          );

          expect(find.byType(BriefingScreen), findsOneWidget);
          expect(find.byType(CalendarBottomBar), findsNothing);

          await _tapText(tester, '캘린더로 가기');
          expect(find.byType(MonthScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('알림 payload가 온보딩보다 먼저다', (tester) async {
          final app = await _pumpApp(
            tester,
            preferences: {},
            launchPayload: Routes.task(3),
            textScale: textScale,
          );

          expect(find.byType(TaskDetailScreen), findsOneWidget);
          expect(
            tester
                .widget<TaskDetailScreen>(find.byType(TaskDetailScreen))
                .taskId,
            3,
          );
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(app.router.state.uri.path, Routes.task(3));

          await app.dispose(tester);
        });

        testWidgets('온보딩 중에도 /me/timetable을 열 수 있고 닫으면 온보딩으로 돌아온다', (
          tester,
        ) async {
          final app = await _pumpApp(
            tester,
            preferences: {},
            textScale: textScale,
          );
          expect(find.byType(OnboardingScreen), findsOneWidget);

          // 온보딩 4·5단계가 시간표·고정 일정 편집을 여는 방식(push).
          app.router.push(Routes.meTimetable);
          await tester.pumpAndSettle();
          expect(find.byType(TimetableScreen), findsOneWidget);

          app.router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(TimetableScreen), findsNothing);
          expect(find.byType(OnboardingScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('온보딩을 끝냈으면 /onboarding으로 가는 이동은 캘린더로 돌린다', (tester) async {
          final app = await _pumpApp(
            tester,
            preferences: {'onboarding_done': true},
            textScale: textScale,
          );

          app.router.go(Routes.onboarding);
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(find.byType(MonthScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('데모 모드면 payload와 onboarding_done을 보지 않고 브리핑 규칙만 따른다', (
          tester,
        ) async {
          final app = await _pumpApp(
            tester,
            preferences: {'app_mode': 'demo', 'demo_entry': 'onboarding'},
            briefingOpenedToday: false,
            launchPayload: Routes.task(3),
            textScale: textScale,
          );

          expect(find.byType(DemoBand), findsOneWidget);
          expect(find.byType(BriefingScreen), findsOneWidget);
          expect(find.byType(TaskDetailScreen), findsNothing);
          expect(find.byType(OnboardingScreen), findsNothing);

          await app.dispose(tester);
        });
      });

      testWidgets('라우트 표의 경로마다 그 화면이 뜨고, 캘린더 보기에만 하단 바가 있다', (tester) async {
        final app = await _pumpApp(
          tester,
          preferences: {'onboarding_done': true},
          textScale: textScale,
        );

        // (경로, 화면, 하단 바(추가 알약·중요 브리핑)가 보이는지)
        final table = <(String, Type, bool)>[
          (Routes.calendarYear, YearScreen, true),
          (Routes.calendarWeek, WeekScreen, true),
          (Routes.calendarDay('2026-10-29'), DayScreen, true),
          (Routes.calendarAgenda, AgendaScreen, true),
          (Routes.calendar, MonthScreen, true),
          (Routes.search, SearchScreen, false),
          (Routes.tasks, TaskListScreen, false),
          (Routes.task(1), TaskDetailScreen, false),
          (Routes.me, MeScreen, false),
          (Routes.meRules, RulesScreen, false),
          (Routes.meTimetable, TimetableScreen, false),
          (Routes.briefing, BriefingScreen, false),
          (Routes.assistant, AssistantScreen, false),
        ];
        for (final (path, screen, calendarFrame) in table) {
          app.router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(screen), findsOneWidget, reason: path);
          expect(
            find.byType(CalendarBottomBar),
            calendarFrame ? findsOneWidget : findsNothing,
            reason: path,
          );
        }

        await app.dispose(tester);
      });

      testWidgets('나에서 데모 모드에 들어가면 데모 띠가 보이고 끝내기로 /me에 돌아온다', (tester) async {
        final app = await _pumpApp(
          tester,
          preferences: {'onboarding_done': true},
          textScale: textScale,
        );

        app.router.push(Routes.me);
        await tester.pumpAndSettle();
        await _tapText(tester, '데모 모드 들어가기');

        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(MonthScreen), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'demo');
        expect(app.preferences.getString('demo_entry'), 'me');
        expect(app.container.read(databaseProvider), same(app.demoDb));

        await _tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(MeScreen), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'real');
        expect(app.preferences.containsKey('demo_entry'), isFalse);
        expect(app.container.read(databaseProvider), same(app.db));

        // go로 온 /me에는 돌아갈 곳이 없으므로 캘린더로 가는 버튼이 있다.
        await tester.tap(find.byTooltip('캘린더로 가기'));
        await tester.pumpAndSettle();
        expect(find.byType(MonthScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('온보딩 첫 화면의 둘러보기로 데모에 들어가면 끝내기로 온보딩 첫 화면에 돌아온다', (
        tester,
      ) async {
        final app = await _pumpApp(
          tester,
          preferences: {},
          textScale: textScale,
        );

        await _tapText(tester, '둘러보기 · 샘플 학생의 하루');

        // 데모 모드는 onboarding_done을 보지 않는다.
        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(MonthScreen), findsOneWidget);
        expect(app.preferences.getString('demo_entry'), 'onboarding');

        await _tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        await _scrollTo(tester, find.text('시작하기'));
        expect(find.text('시작하기'), findsOneWidget);

        await app.dispose(tester);
      });
    });
  }
}

/// 띄운 앱과 정리 함수.
class _TestApp {
  _TestApp(this.db, this.demoDb, this.preferences, this.container);

  final AppDatabase db;
  final AppDatabase demoDb;
  final SharedPreferences preferences;
  final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  /// 위젯 트리를 내려 provider를 정리한 뒤 DB를 닫는다(drift 스트림 타이머가 남지 않게).
  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // drift는 스트림 쿼리 구독이 끝난 뒤 짧은 타이머로 정리한다. 가짜 시계를 넘겨 주지 않으면
    // 그 타이머가 돌지 않아 close가 끝나지 않는다(캘린더·설정 스트림을 보는 화면이 있을 때).
    await tester.pump(const Duration(seconds: 1));
    await db.close();
    await demoDb.close();
  }
}

/// 폰 화면 크기(390×844pt)에서 RootApp을 띄운다.
Future<_TestApp> _pumpApp(
  WidgetTester tester, {
  required Map<String, Object> preferences,
  bool briefingOpenedToday = true,
  String? launchPayload,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(preferences);
  final sharedPreferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final demoDb = AppDatabase.memory();

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
        briefingOpenedTodayProvider.overrideWithValue(
          () async => briefingOpenedToday,
        ),
        launchPayloadProvider.overrideWithValue(launchPayload),
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
  return _TestApp(db, demoDb, sharedPreferences, container);
}

/// 상단바 메뉴로 드로어를 열고 [label] 항목을 누른다.
Future<void> _openDrawerItem(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('메뉴'));
  await tester.pumpAndSettle();
  final item = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(label),
  );
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

/// 글자 [text]를 누른다. 글자가 크면 버튼이 화면 밖에 있을 수 있으므로 먼저 보이게 스크롤한다.
Future<void> _tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await _scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// [target]이 화면에 보이게 스크롤한다. 글자가 크면 아래쪽 버튼은 스크롤해야 그려지므로,
/// 아직 없으면 세로로 스크롤되는 첫 영역을 내려 가며 찾는다.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
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
