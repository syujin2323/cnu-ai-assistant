// 앱이 뜨고 네 탭과 AI 비서 버튼이 보이는지 보는 화면 테스트와 시작 위치·라우트 표·데모 전환 테스트.
// docs/architecture.md '확인과 CI', '화면 이동', '데모 모드', docs/screens.md '하단 탭과 AI 비서 버튼'.
//
// RootApp은 test/helpers/pump_app.dart로 띄운다(Firebase 없이 메모리 DB와 모의 SharedPreferences).
// 모든 검사를 글자 배율 1.0과 2.0에서 돌려 넘침(RenderFlex overflow) 예외가 없어야 한다.

import 'dart:io';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/me/rules_screen.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_detail_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';

/// 하단 탭 라벨(docs/screens.md '하단 탭과 AI 비서 버튼'의 순서).
const _tabLabels = ['오늘', '캘린더', '할 일', '나'];

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('로그인했고 오늘 브리핑을 열었으면 /today에 네 탭이 보이고 '
          '탭을 누르면 각 화면으로 간다', (tester) async {
        final app = await pumpTestApp(tester, textScale: textScale);

        expect(find.byType(TodayScreen), findsOneWidget);
        // 최근 앱 목록에 보이는 이름(MaterialApp.title)도 표시 이름과 같다.
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
          AppStrings.appName,
        );
        // 글자 배율이 앱 안 화면까지 그대로 닿는지(앱이 textScaler를 덮어쓰지 않는지) 본다.
        expect(
          MediaQuery.textScalerOf(tester.element(find.byType(TodayScreen)))
              .scale(10),
          10 * textScale,
        );
        _expectTabs(tester, selected: '오늘');

        await tapTab(tester, '캘린더');
        expect(find.byType(MonthScreen), findsOneWidget);
        expect(find.byType(TodayScreen), findsNothing);
        _expectTabs(tester, selected: '캘린더');

        await tapTab(tester, '할 일');
        expect(find.byType(TaskListScreen), findsOneWidget);
        _expectTabs(tester, selected: '할 일');

        await tapTab(tester, '나');
        expect(find.byType(MeScreen), findsOneWidget);
        // 10 나에는 맨 위 앱 이름 옆에만 비공식 표시를 둔다(docs/screens.md ''충남대 비공식 앱' 표시').
        expect(find.text(AppStrings.unofficialShort), findsOneWidget);
        expect(find.textContaining('학교와 관계없는'), findsNothing);

        await tapTab(tester, '오늘');
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.byType(MeScreen), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('탭바 옆 AI 비서 버튼은 06 AI 비서를 열고, 뒤로 가면 그 탭으로 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(tester, textScale: textScale);
        await tapTab(tester, '할 일');

        final button = assistantButton();
        expect(button, findsOneWidget);
        expect(
          tester.getSemantics(button),
          isSemantics(
            label: AppStrings.askAssistant,
            isButton: true,
            hasTapAction: true,
          ),
        );
        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(AppSize.minTouch));
        expect(size.height, greaterThanOrEqualTo(AppSize.minTouch));

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AssistantScreen), findsOneWidget);
        expect(find.text('AI 비서'), findsOneWidget);
        expect(find.byType(AppTabBar), findsNothing);
        expect(app.router.state.uri.path, Routes.assistant);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(AssistantScreen), findsNothing);
        expect(find.byType(TaskListScreen), findsOneWidget);
        _expectTabs(tester, selected: '할 일');

        await app.dispose(tester);
      });

      testWidgets('탭을 바꿔도 각 탭의 화면이 남고, 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다', (
        tester,
      ) async {
        final app = await pumpTestApp(tester, textScale: textScale);

        app.router.go(Routes.day('2026-10-29'));
        await tester.pumpAndSettle();
        expect(find.byType(DayScreen), findsOneWidget);

        await tapTab(tester, '나');
        expect(find.byType(MeScreen), findsOneWidget);
        expect(find.byType(DayScreen), findsNothing);

        // 다른 탭에서 돌아오면 그 탭에서 보던 화면이 그대로다.
        await tapTab(tester, '오늘');
        expect(find.byType(DayScreen), findsOneWidget);

        // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
        await tapTab(tester, '오늘');
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.byType(DayScreen), findsNothing);

        await app.dispose(tester);
      });

      group('시작 위치', () {
        testWidgets('처음 설치했으면 /onboarding으로 간다', (tester) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.fresh,
            textScale: textScale,
          );

          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.byType(AppTabBar), findsNothing);
          // 첫 화면 맨 아래의 표시까지 내려 본다(글자가 크면 처음에는 그려지지 않는다).
          await scrollTo(tester, find.text(AppStrings.unofficialShort));
          expect(find.text('시작하기'), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('온보딩을 끝냈어도 로그아웃했으면 브리핑보다 먼저 /onboarding으로 간다', (
          tester,
        ) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.loggedOut,
            briefingOpenedToday: false,
            textScale: textScale,
          );

          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.byType(BriefingScreen), findsNothing);
          expect(find.byType(AppTabBar), findsNothing);
          expect(app.router.state.uri.path, Routes.onboarding);

          await app.dispose(tester);
        });

        testWidgets('로그인했고 오늘 브리핑을 아직 열지 않았으면 /briefing으로 간다', (tester) async {
          final app = await pumpTestApp(
            tester,
            briefingOpenedToday: false,
            textScale: textScale,
          );

          expect(find.byType(BriefingScreen), findsOneWidget);
          expect(find.byType(AppTabBar), findsNothing);

          await tapText(tester, '오늘로 가기');
          expect(find.byType(TodayScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('오늘 브리핑을 열었는지 확인하지 못하면 /today로 간다', (tester) async {
          final app = await pumpTestApp(
            tester,
            briefingCheckFails: true,
            textScale: textScale,
          );

          // 시작 위치로 다시 보내 같은 실패를 되풀이하지 않고 오늘로 간다.
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(find.byType(BriefingScreen), findsNothing);
          expect(app.router.state.uri.path, Routes.today);

          await app.dispose(tester);
        });

        testWidgets('없는 경로로 가면 시작 위치로 돌아간다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);

          app.router.go('/no-such-path');
          await tester.pumpAndSettle();
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(app.router.state.uri.path, Routes.today);

          await app.dispose(tester);
        });

        testWidgets('알림 payload는 온보딩·로그아웃 확인 뒤에 본다', (tester) async {
          // (시작 상태, 뜨는 화면). 온보딩으로 보낼 때는 payload를 쓰지 않고 버린다.
          final cases = <(TestStart, Type)>[
            (TestStart.fresh, OnboardingScreen),
            (TestStart.loggedOut, OnboardingScreen),
            (TestStart.loggedIn, TaskDetailScreen),
          ];
          for (final (start, screen) in cases) {
            final app = await pumpTestApp(
              tester,
              start: start,
              launchPayload: Routes.task(3),
              textScale: textScale,
            );

            expect(find.byType(screen), findsOneWidget, reason: start.name);
            if (screen == TaskDetailScreen) {
              expect(
                tester
                    .widget<TaskDetailScreen>(find.byType(TaskDetailScreen))
                    .taskId,
                3,
              );
              expect(app.router.state.uri.path, Routes.task(3));
            } else {
              expect(find.byType(TaskDetailScreen), findsNothing);
              expect(app.router.state.uri.path, Routes.onboarding);
            }

            await app.dispose(tester);
          }
        });

        testWidgets('온보딩 중 /login을 열고 닫아도 온보딩으로 돌아온다', (tester) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.fresh,
            textScale: textScale,
          );
          expect(find.byType(OnboardingScreen), findsOneWidget);

          // /login처럼 시작 위치 밖의 경로는 시작 위치 규칙이 막지 않는다.
          app.router.push(Routes.login);
          await tester.pumpAndSettle();
          expect(find.byType(ReloginScreen), findsOneWidget);
          expect(find.byType(AppTabBar), findsNothing);
          expect(app.router.state.uri.path, Routes.login);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(ReloginScreen), findsNothing);
          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(app.router.state.uri.path, Routes.onboarding);

          await app.dispose(tester);
        });

        testWidgets('로그인했으면 /onboarding으로 가는 이동은 오늘로 돌린다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);

          app.router.go(Routes.onboarding);
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(find.byType(TodayScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets(
          '로그아웃하면(LMS 상태를 disconnected로 쓴 뒤) /onboarding으로 가는 이동은 돌리지 않는다',
          (tester) async {
            final app = await pumpTestApp(tester, textScale: textScale);
            await tapTab(tester, '나');

            // 10 나의 로그아웃이 하는 순서: LMS 상태를 먼저 쓰고(await) 그다음 /onboarding으로 간다.
            await writeLmsSessionState(app, LmsSessionState.disconnected);
            app.router.go(Routes.onboarding);
            await tester.pumpAndSettle();
            expect(find.byType(OnboardingScreen), findsOneWidget);
            expect(find.byType(AppTabBar), findsNothing);
            expect(app.router.state.uri.path, Routes.onboarding);

            // 시작 위치로 다시 가도(앱을 다시 켠 것과 같음) 로그인할 때까지 온보딩이다.
            app.router.go(Routes.root);
            await tester.pumpAndSettle();
            expect(find.byType(OnboardingScreen), findsOneWidget);
            expect(app.router.state.uri.path, Routes.onboarding);

            await app.dispose(tester);
          },
        );

        testWidgets('/onboarding에 있는 동안 LMS 상태가 connecting·active로 바뀌어도 머물고, '
            '로그인을 마치고 /로 가면 나간다', (tester) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.loggedOut,
            textScale: textScale,
          );
          expect(find.byType(OnboardingScreen), findsOneWidget);

          for (final state in [
            LmsSessionState.connecting,
            LmsSessionState.active,
          ]) {
            // 로그아웃 뒤 1단계에서 로그인하는 중이다. 라우터가 다시 정하거나 /onboarding으로 다시
            // 가도 이미 /onboarding에 있으므로 튕기지 않는다.
            await writeLmsSessionState(app, state);
            app.router.refresh();
            await tester.pumpAndSettle();
            app.router.go(Routes.onboarding);
            await tester.pumpAndSettle();
            expect(
              find.byType(OnboardingScreen),
              findsOneWidget,
              reason: state.name,
            );
            expect(
              app.router.state.uri.path,
              Routes.onboarding,
              reason: state.name,
            );
          }

          // 진행 줄이 끝나면 화면이 /로 가고, 시작 위치 규칙이 브리핑이나 오늘로 보낸다.
          app.router.go(Routes.root);
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsNothing);
          expect(find.byType(TodayScreen), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets(
          '데모 모드면 payload·onboarding_done·LMS 상태를 보지 않고 브리핑 규칙만 따른다',
          (tester) async {
            final app = await pumpTestApp(
              tester,
              start: TestStart.demo,
              briefingOpenedToday: false,
              launchPayload: Routes.task(3),
              textScale: textScale,
            );

            // 실제 DB의 LMS 상태는 로그인 전(disconnected)이지만 데모 모드는 보지 않는다.
            expect(
              await readLmsSessionState(app),
              LmsSessionState.disconnected,
            );
            expect(find.byType(DemoBand), findsOneWidget);
            expect(find.byType(BriefingScreen), findsOneWidget);
            expect(find.byType(TaskDetailScreen), findsNothing);
            expect(find.byType(OnboardingScreen), findsNothing);

            await app.dispose(tester);
          },
        );

        testWidgets('플랫폼이 넘긴 첫 경로(/today)를 보지 않고 /에서 시작한다', (tester) async {
          // Android intent의 route 값(`adb shell am start --es route /today`)이 이 값으로 들어온다.
          // 그대로 따르면 시작 위치 규칙을 거치지 않아 온보딩을 건너뛴다.
          tester.binding.platformDispatcher.defaultRouteNameTestValue =
              Routes.today;
          addTearDown(
            tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
          );
          final app = await pumpTestApp(
            tester,
            start: TestStart.fresh,
            textScale: textScale,
          );

          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.byType(TodayScreen), findsNothing);
          expect(app.router.state.uri.path, Routes.onboarding);

          await app.dispose(tester);
        });
      });

      testWidgets('라우트 표의 경로마다 그 화면이 탭 안이나 셸 밖에 뜬다', (tester) async {
        final app = await pumpTestApp(tester, textScale: textScale);

        // (경로, 화면, 하단 탭이 보이는지). `/`는 시작 위치 규칙으로 /today에 간다.
        final table = <(String, Type, bool)>[
          (Routes.root, TodayScreen, true),
          (Routes.day('2026-10-29'), DayScreen, true),
          (Routes.calendarWeek, WeekScreen, true),
          (Routes.login, ReloginScreen, false),
          (Routes.meRules, RulesScreen, false),
          (Routes.task(1), TaskDetailScreen, false),
          (Routes.meTimetable, TimetableScreen, false),
          (Routes.briefing, BriefingScreen, false),
          (Routes.assistant, AssistantScreen, false),
        ];
        for (final (path, screen, inShell) in table) {
          app.router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(screen), findsOneWidget, reason: path);
          expect(
            find.byType(AppTabBar),
            inShell ? findsOneWidget : findsNothing,
            reason: path,
          );
        }

        await app.dispose(tester);
      });

      testWidgets('10 나에서 연 셸 밖 화면은 탭바 없이 뜨고, 뒤로 가면 10 나로 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(tester, textScale: textScale);
        await tapTab(tester, '나');

        // (10 나의 항목, 열리는 화면, 경로)
        final rows = <(String, Type, String)>[
          (AppStrings.myRules, RulesScreen, Routes.meRules),
          (AppStrings.timetableAndFixed, TimetableScreen, Routes.meTimetable),
        ];
        for (final (item, screen, path) in rows) {
          await tapText(tester, item);
          expect(find.byType(screen), findsOneWidget, reason: path);
          expect(find.byType(AppTabBar), findsNothing, reason: path);
          expect(app.router.state.uri.path, path);

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(screen), findsNothing, reason: path);
          expect(find.byType(MeScreen), findsOneWidget, reason: path);
          _expectTabs(tester, selected: '나');
        }

        await app.dispose(tester);
      });

      testWidgets('/login(14 다시 로그인)은 셸 밖에 뜨고, 닫으면 연 화면으로 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(tester, textScale: textScale);
        await tapTab(tester, '할 일');

        // '다시 로그인' 칩·LMS 정보 시트·10 나 › LMS 계정이 여는 방식(push). 시작 위치 규칙이 막지 않는다.
        app.router.push(Routes.login);
        await tester.pumpAndSettle();
        expect(find.byType(ReloginScreen), findsOneWidget);
        expect(find.byType(AppTabBar), findsNothing);
        expect(app.router.state.uri.path, Routes.login);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(ReloginScreen), findsNothing);
        expect(find.byType(TaskListScreen), findsOneWidget);
        _expectTabs(tester, selected: '할 일');

        await app.dispose(tester);
      });

      testWidgets('처음 설치한 상태에서 /와 /onboarding은 셸 밖의 14 온보딩이다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
        );

        for (final path in [Routes.root, Routes.onboarding]) {
          app.router.go(path);
          await tester.pumpAndSettle();
          expect(find.byType(OnboardingScreen), findsOneWidget, reason: path);
          expect(find.byType(AppTabBar), findsNothing, reason: path);
          expect(app.router.state.uri.path, Routes.onboarding, reason: path);
        }

        await app.dispose(tester);
      });

      testWidgets('나 탭에서 데모 모드에 들어가면 데모 띠가 보이고 끝내기로 /me에 돌아온다', (tester) async {
        final app = await pumpTestApp(tester, textScale: textScale);

        await tapTab(tester, '나');
        await tapText(tester, '데모 모드 들어가기');

        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'demo');
        expect(app.preferences.getString('demo_entry'), 'me');
        expect(app.container.read(databaseProvider), same(app.demoDb));

        await tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(MeScreen), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'real');
        expect(app.preferences.containsKey('demo_entry'), isFalse);
        expect(app.container.read(databaseProvider), same(app.db));

        await app.dispose(tester);
      });

      testWidgets('온보딩 첫 화면의 둘러보기로 데모에 들어가면 끝내기로 온보딩 첫 화면에 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
        );

        await tapText(tester, '둘러보기 · 샘플 학생의 하루');

        // 데모 모드는 onboarding_done을 보지 않는다.
        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(app.preferences.getString('demo_entry'), 'onboarding');

        await tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        await scrollTo(tester, find.text('시작하기'));
        expect(find.text('시작하기'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('로그아웃한 뒤 둘러보기로 데모에 들어갔다가 끝내도 온보딩 첫 화면으로 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.loggedOut,
          textScale: textScale,
        );

        await tapText(tester, '둘러보기 · 샘플 학생의 하루');
        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(TodayScreen), findsOneWidget);

        // 온보딩을 끝냈어도 LMS 상태가 disconnected라 데모 밖에서는 로그인할 때까지 온보딩이다.
        await tapText(tester, '끝내기');
        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(TodayScreen), findsNothing);
        expect(app.router.state.uri.path, Routes.onboarding);

        await app.dispose(tester);
      });

      // 세로 폰만 지원하지만 targetSdk 36의 Android 16은 큰 화면에서 방향 고정을 따르지 않으므로,
      // 태블릿 가로 폭에서도 넘치지 않는지만 본다(docs/decisions.md 2026-11-06 '화면은 세로 폰만 지원한다').
      group('태블릿 가로 폭(1280×800pt)', () {
        testWidgets('/today와 네 탭 화면이 넘치지 않는다', (tester) async {
          final app = await pumpTestApp(
            tester,
            textScale: textScale,
            size: tabletLandscape,
          );

          expect(find.byType(TodayScreen), findsOneWidget);
          for (final label in ['캘린더', '할 일', '나', '오늘']) {
            await tapTab(tester, label);
          }
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(assistantButton(), findsOneWidget);

          await app.dispose(tester);
        });

        testWidgets('온보딩 첫 화면이 넘치지 않는다', (tester) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.fresh,
            textScale: textScale,
            size: tabletLandscape,
          );

          expect(find.byType(OnboardingScreen), findsOneWidget);
          await scrollTo(tester, find.text('시작하기'));
          expect(find.text('시작하기'), findsOneWidget);

          await app.dispose(tester);
        });
      });
    });
  }

  group('앱 표시 이름', () {
    // docs/decisions.md 2026-11-04 '앱 이름 CNU PLANNER'. 세 곳의 표시 이름이 같아야 한다.
    test('Android android:label이 AppStrings.appName과 같다', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:label="${AppStrings.appName}"'));
    });

    test('iOS CFBundleDisplayName이 AppStrings.appName과 같다', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final name = RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>([^<]*)</string>',
      ).firstMatch(plist)?.group(1);
      expect(name, AppStrings.appName);
    });
  });

  group('플랫폼 경로', () {
    // docs/architecture.md '화면 이동'. 실행 중에 들어오는 딥링크는 네이티브에서 막히므로 위젯
    // 테스트로는 볼 수 없어 설정만 본다(동작은 PR에서 adb로 확인).
    test(
      'Android MainActivity는 딥링크를 받지 않는다(flutter_deeplinking_enabled false)',
      () {
        final manifest = File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync();
        final activity = RegExp(
          r'<activity\b[^>]*android:name="\.MainActivity"[\s\S]*?</activity>',
        ).firstMatch(manifest)?.group(0);
        expect(activity, isNotNull);
        expect(
          activity,
          matches(
            RegExp(
              r'<meta-data\s+android:name="flutter_deeplinking_enabled"\s+'
              r'android:value="false"\s*/>',
            ),
          ),
        );
      },
    );
  });
}

/// 하단 탭 넷이 있고, 탭마다 따로 읽히는 버튼이며, [selected] 탭만 선택됨으로 읽히고 글자를 그린다.
void _expectTabs(WidgetTester tester, {required String selected}) {
  for (final label in _tabLabels) {
    final tab = tabButton(label);
    expect(tab, findsOneWidget, reason: '탭 $label');
    expect(
      tester.getSemantics(tab),
      isSemantics(
        label: label,
        isButton: true,
        hasSelectedState: true,
        isSelected: label == selected,
        hasTapAction: true,
      ),
      reason: '탭 접근성 $label',
    );
    expect(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label)),
      label == selected ? findsOneWidget : findsNothing,
      reason: '지금 탭만 글자를 그린다($label)',
    );
  }
}
