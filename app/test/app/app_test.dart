// 앱이 뜨고 네 탭과 AI 비서 버튼이 보이는지 보는 화면 테스트와 시작 위치(앱으로 돌아올 때 포함)·라우트
// 표·데모 전환 테스트. docs/architecture.md '확인과 CI', '화면 이동', '데모 모드',
// docs/screens.md '하단 탭과 AI 비서 버튼', '01 아침 브리핑'.
//
// RootApp은 test/helpers/pump_app.dart로 띄운다(Firebase 없이 메모리 DB와 모의 SharedPreferences).
// 모든 검사를 글자 배율 1.0과 2.0에서 돌려 넘침(RenderFlex overflow) 예외가 없어야 한다.

import 'dart:async';
import 'dart:io';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/briefing_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/me/rules_screen.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_detail_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';

/// 14 온보딩 1단계 아래의 데모 들어가기 문구(docs/screens.md '1단계 · LMS 로그인').
const _browseDemo = '로그인 없이 둘러보기 · 샘플 학생의 하루';

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
        expect(find.byType(WeekScreen), findsOneWidget);
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

      testWidgets('하단 탭바와 AI 비서 버튼은 모션을 끈 화면 테스트에서도 늘 유리로 그린다', (tester) async {
        // docs/decisions.md 2026-11-13 '모션은 모든 사람에게 같게 보인다'. 유리는 모션 등급과 관계없고
        // (R1) OS 투명도 줄이기만 끈다.
        final app = await pumpTestApp(tester, textScale: textScale);
        expect(tester.widget<AppTabBar>(find.byType(AppTabBar)).glass, isTrue);
        final filters = tester
            .widgetList<BackdropFilter>(
              find.descendant(
                of: find.byType(AppTabBar),
                matching: find.byType(BackdropFilter),
              ),
            )
            .map((widget) => widget.filter)
            .toList();
        expect(filters, hasLength(2));
        expect(filters, everyElement(AppGlass.filter));

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

        app.router.go(Routes.day(DateTime(2026, 10, 29)));
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
          expect(find.text(OnboardingStep.login.title), findsOneWidget);
          // 첫 화면 맨 아래의 표시까지 내려 본다(글자가 크면 처음에는 그려지지 않는다).
          await scrollTo(tester, find.text(AppStrings.unofficialShort));
          expect(find.text(_browseDemo), findsOneWidget);

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

      group('앱으로 돌아올 때(resumed)', () {
        // 2026-11-13 21:00(논리적 하루 11월 13일)에 켠다. 하루 경계는 04:00(임시값)으로 적어 둔다.
        final evening = DateTime(2026, 11, 13, 21);
        final nextMorning = DateTime(2026, 11, 14, 8);
        const boundary = {SettingKeys.dayBoundaryMin: 240};

        testWidgets('하루가 바뀌었고 그날 브리핑을 아직 보지 않았으면 /briefing으로 간다', (
          tester,
        ) async {
          final app = await pumpTestApp(
            tester,
            now: evening,
            settings: boundary,
            textScale: textScale,
          );
          await tapTab(tester, '캘린더');
          expect(find.byType(WeekScreen), findsOneWidget);

          app.clock.current = nextMorning;
          app.briefingOpenedToday = false;
          await sendAppToBackgroundAndBack(tester);

          expect(find.byType(BriefingScreen), findsOneWidget);
          expect(find.byType(AppTabBar), findsNothing);
          expect(app.router.state.uri.path, Routes.briefing);

          // 브리핑으로 가며 탭 셸이 내려가므로, 닫으면 보던 캘린더 탭이 아니라 오늘부터 다시 연다.
          await tapText(tester, '오늘로 가기');
          expect(find.byType(TodayScreen), findsOneWidget);
          _expectTabs(tester, selected: '오늘');

          await app.dispose(tester);
        });

        testWidgets('같은 논리적 하루 안이면 브리핑을 보지 않았어도 보던 화면을 그대로 둔다', (tester) async {
          final app = await pumpTestApp(
            tester,
            now: evening,
            settings: boundary,
            textScale: textScale,
          );
          await tapTab(tester, '캘린더');

          // 다음 날 03:30은 하루 경계 04:00 전이라 아직 11월 13일이다.
          app.clock.current = DateTime(2026, 11, 14, 3, 30);
          app.briefingOpenedToday = false;
          await sendAppToBackgroundAndBack(tester);

          expect(find.byType(WeekScreen), findsOneWidget);
          expect(find.byType(BriefingScreen), findsNothing);
          _expectTabs(tester, selected: '캘린더');

          await app.dispose(tester);
        });

        testWidgets('하루가 바뀌었어도 그날 브리핑을 이미 봤으면 보던 화면을 그대로 둔다', (tester) async {
          final app = await pumpTestApp(
            tester,
            now: evening,
            settings: boundary,
            textScale: textScale,
          );
          await tapTab(tester, '캘린더');

          app.clock.current = nextMorning;
          await sendAppToBackgroundAndBack(tester);

          expect(find.byType(WeekScreen), findsOneWidget);
          expect(find.byType(BriefingScreen), findsNothing);

          await app.dispose(tester);
        });

        testWidgets('06 AI 비서·다시 로그인에 있으면 미루고, 닫은 뒤 다시 돌아오면 /briefing으로 간다', (
          tester,
        ) async {
          // (미루는 화면의 경로, 화면)
          final rows = <(String, Type)>[
            (Routes.assistant, AssistantScreen),
            (Routes.login, ReloginScreen),
          ];
          for (final (path, screen) in rows) {
            final app = await pumpTestApp(
              tester,
              now: evening,
              settings: boundary,
              textScale: textScale,
            );
            app.router.push(path);
            await tester.pumpAndSettle();

            app.clock.current = nextMorning;
            app.briefingOpenedToday = false;
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(screen), findsOneWidget, reason: path);
            expect(app.router.state.uri.path, path, reason: path);

            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            expect(find.byType(TodayScreen), findsOneWidget, reason: path);

            // 미룬 확인은 다음에 돌아올 때 다시 본다.
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(BriefingScreen), findsOneWidget, reason: path);

            await app.dispose(tester);
          }
        });

        testWidgets('온보딩 중이면 하루가 바뀌어도 그대로 둔다', (tester) async {
          final app = await pumpTestApp(
            tester,
            start: TestStart.loggedOut,
            now: evening,
            settings: boundary,
            textScale: textScale,
          );
          expect(find.text(OnboardingStep.login.title), findsOneWidget);
          // 로그아웃 뒤 1단계에서 로그인해 진행 줄이 도는 중이라 LMS 상태가 이미 active다. 미루지 않으면
          // 시작 위치 규칙이 온보딩을 끝낸 사람으로 보고 /briefing으로 보낸다.
          await writeLmsSessionState(app, LmsSessionState.active);

          app.clock.current = nextMorning;
          app.briefingOpenedToday = false;
          await sendAppToBackgroundAndBack(tester);

          expect(find.byType(OnboardingScreen), findsOneWidget);
          expect(find.text(OnboardingStep.login.title), findsOneWidget);
          expect(app.router.state.uri.path, Routes.onboarding);

          await app.dispose(tester);
        });

        testWidgets(
          '01을 띄운 채 하루가 바뀌어 돌아오면 01이 그날을 본 것으로 적고, 같은 날 다시 돌아와도 브리핑을 다시 띄우지 않는다',
          (tester) async {
            final app = await pumpTestApp(
              tester,
              now: evening,
              settings: boundary,
              textScale: textScale,
              realBriefingCheck: true,
            );
            expect(find.byType(BriefingScreen), findsOneWidget);
            final briefings = BriefingRepository(app.db);
            expect(
              await briefings.isSeen(DateTime(2026, 11, 13)),
              const Ok(true),
            );

            // 01에서 아무것도 누르지 않고 떠났다가 다음 날 아침 돌아온다. 01은 미루는 화면이라 그대로 두되,
            // 01이 새 날을 본 것으로 적는다.
            app.clock.current = nextMorning;
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(BriefingScreen), findsOneWidget);
            expect(app.router.state.uri.path, Routes.briefing);
            expect(
              await briefings.isSeen(DateTime(2026, 11, 14)),
              const Ok(true),
            );

            await tapText(tester, '오늘로 가기');
            await tapTab(tester, '캘린더');
            app.clock.current = DateTime(2026, 11, 14, 12);
            await sendAppToBackgroundAndBack(tester);

            expect(find.byType(BriefingScreen), findsNothing);
            expect(find.byType(WeekScreen), findsOneWidget);
            _expectTabs(tester, selected: '캘린더');

            await app.dispose(tester);
          },
        );

        testWidgets(
          '10 나에서 들어간 데모가 새 날의 데모 브리핑을 띄운 뒤 끝내면, 다음에 돌아올 때 그날 실제 브리핑을 띄운다',
          (tester) async {
            final app = await pumpTestApp(
              tester,
              now: evening,
              settings: boundary,
              textScale: textScale,
              realBriefingCheck: true,
            );
            await tapText(tester, '오늘로 가기');
            await tapTab(tester, '나');
            await tapText(tester, '데모 모드 들어가기');
            expect(find.byType(BriefingScreen), findsOneWidget);
            await tapText(tester, '오늘로 가기');

            // 데모 모드 그대로 다음 날 돌아오면 데모의 그날 브리핑이 뜬다(데모 DB에 적힘).
            app.clock.current = nextMorning;
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(BriefingScreen), findsOneWidget);
            await tapText(tester, '오늘로 가기');
            await tapText(tester, '끝내기');
            expect(find.byType(MeScreen), findsOneWidget);
            final real = BriefingRepository(app.db);
            expect(await real.isSeen(DateTime(2026, 11, 14)), const Ok(false));

            // 데모에서 돌린 날은 실제 모드의 날로 치지 않는다.
            app.clock.current = DateTime(2026, 11, 14, 9);
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(BriefingScreen), findsOneWidget);
            expect(await real.isSeen(DateTime(2026, 11, 14)), const Ok(true));

            await app.dispose(tester);
          },
        );

        testWidgets(
          '돌아와 시작 위치를 다시 정하는 사이 다른 탭으로 가 브리핑으로 가지 못했으면, 그날 다음에 돌아올 때 다시 본다',
          (tester) async {
            final app = await pumpTestApp(
              tester,
              now: evening,
              settings: boundary,
              textScale: textScale,
            );

            app.clock.current = nextMorning;
            app.briefingOpenedToday = false;
            // 돌아와서 한 번 확인한 뒤(1번째), `/`의 시작 위치 규칙이 하는 확인(2번째)을 붙잡아 둔다.
            app.holdBriefingCheck(nth: 2);
            await sendAppToBackgroundAndBack(tester);
            for (var i = 0; i < 20 && !app.briefingCheckHeld; i++) {
              await tester.pump();
            }
            expect(app.briefingCheckHeld, isTrue);

            // 그사이 탭을 누르면 브리핑으로 가는 결과는 버려지고 누른 탭이 남는다.
            await tapTab(tester, '캘린더');
            app.releaseBriefingCheck();
            await tester.pumpAndSettle();
            expect(find.byType(WeekScreen), findsOneWidget);
            expect(find.byType(BriefingScreen), findsNothing);
            // 버려진 결과는 그 뒤 다른 곳에 도착해도 그날 돌린 것으로 적지 않는다.
            await tapTab(tester, '오늘');

            // 그날은 브리핑으로 가지 못했으므로 같은 날 다음에 돌아올 때 다시 본다.
            await sendAppToBackgroundAndBack(tester);
            expect(find.byType(BriefingScreen), findsOneWidget);
            expect(app.router.state.uri.path, Routes.briefing);

            await app.dispose(tester);
          },
        );
      });

      testWidgets('라우트 표의 경로마다 그 화면이 탭 안이나 셸 밖에 뜬다', (tester) async {
        final app = await pumpTestApp(tester, textScale: textScale);

        // (경로, 화면, 하단 탭이 보이는지). `/`는 시작 위치 규칙으로 /today에 간다.
        final table = <(String, Type, bool)>[
          (Routes.root, TodayScreen, true),
          (Routes.day(DateTime(2026, 10, 29)), DayScreen, true),
          (Routes.calendar, WeekScreen, true),
          (Routes.calendarMonth, MonthScreen, true),
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

      group('화면 진입 인자', () {
        testWidgets('06 AI 비서는 연 곳이 extra로 넘긴 인자를 받고, 문장은 경로에 들어가지 않으며, '
            '닫으면 연 화면으로 돌아온다', (tester) async {
          final app = await pumpTestApp(
            tester,
            briefingOpenedToday: false,
            textScale: textScale,
          );
          AssistantArgs args() =>
              tester.widget<AssistantScreen>(find.byType(AssistantScreen)).args;
          expect(find.byType(BriefingScreen), findsOneWidget);

          // 01 아침 브리핑의 말로 추가처럼, 쓴 문장을 바로 보내게 연다.
          const fromBriefing = AssistantArgs(
            prefill: '내일 3시 팀플 회의',
            sendNow: true,
          );
          app.router.push(Routes.assistant, extra: fromBriefing);
          await tester.pumpAndSettle();
          expect(args(), fromBriefing);
          expect(app.router.state.uri.toString(), Routes.assistant);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(AssistantScreen), findsNothing);
          expect(find.byType(BriefingScreen), findsOneWidget);

          // 03 할 일의 '할 일 추가'처럼, 직접 추가 폼을 할 일로 연다.
          await tapText(tester, '오늘로 가기');
          await tapTab(tester, '할 일');
          const fromTasks = AssistantArgs(form: DirectAddKind.task);
          app.router.push(Routes.assistant, extra: fromTasks);
          await tester.pumpAndSettle();
          expect(args(), fromTasks);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TaskListScreen), findsOneWidget);
          _expectTabs(tester, selected: '할 일');

          await app.dispose(tester);
        });

        testWidgets('06 AI 비서는 extra가 없거나 AssistantArgs가 아니면 기본 인자로 열린다', (
          tester,
        ) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          AssistantArgs args() =>
              tester.widget<AssistantScreen>(find.byType(AssistantScreen)).args;

          // 탭바 옆 'AI 비서에게 말하기'는 인자 없이 연다.
          await tester.tap(assistantButton());
          await tester.pumpAndSettle();
          expect(args(), const AssistantArgs());
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();

          app.router.push(Routes.assistant, extra: '내일 3시 회의');
          await tester.pumpAndSettle();
          expect(args(), const AssistantArgs());

          await app.dispose(tester);
        });

        testWidgets('03 할 일은 ?tab=으로 처음 탭을 받고, 모르는 값이면 주간 할 일이다', (
          tester,
        ) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          TaskListTab tab() => tester
              .widget<TaskListScreen>(find.byType(TaskListScreen))
              .initialTab;
          expect(Routes.tasksTab(TaskListTab.weekly), Routes.tasks);
          expect(Routes.tasksTab(TaskListTab.all), '/tasks?tab=all');

          // 01 아침 브리핑의 '할 일 전체 보기'처럼 다른 화면에서 전체 할 일로 연다.
          app.router.go(Routes.tasksTab(TaskListTab.all));
          await tester.pumpAndSettle();
          expect(tab(), TaskListTab.all);
          _expectTabs(tester, selected: '할 일');

          // 할 일 탭의 첫 화면은 남아 있으므로, 다른 탭에 갔다가 다른 인자로 다시 열면 그 화면이 새 값을 받는다.
          await tapTab(tester, '오늘');
          app.router.go(Routes.tasks);
          await tester.pumpAndSettle();
          expect(tab(), TaskListTab.weekly);

          for (final unknown in [
            '${Routes.tasks}?tab=done',
            '${Routes.tasks}?tab=',
          ]) {
            app.router.go(unknown);
            await tester.pumpAndSettle();
            expect(tab(), TaskListTab.weekly, reason: unknown);
          }

          await app.dispose(tester);
        });

        testWidgets('13 시간표·고정 일정은 ?tab=으로 처음 탭을 받고, 다른 탭에서 push로 열면 '
            '닫을 때 그 탭으로 돌아온다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          TimetableTab tab() => tester
              .widget<TimetableScreen>(find.byType(TimetableScreen))
              .initialTab;
          expect(
            Routes.meTimetableTab(TimetableTab.timetable),
            Routes.meTimetable,
          );
          expect(
            Routes.meTimetableTab(TimetableTab.fixed),
            '/me/timetable?tab=fixed',
          );

          // 일정 정보 시트의 [시간표·고정 일정에서 바꾸기]처럼 캘린더에서 고정 일정 탭으로 연다.
          await tapTab(tester, '캘린더');
          app.router.push(Routes.meTimetableTab(TimetableTab.fixed));
          await tester.pumpAndSettle();
          expect(tab(), TimetableTab.fixed);
          expect(find.byType(AppTabBar), findsNothing);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TimetableScreen), findsNothing);
          expect(find.byType(WeekScreen), findsOneWidget);
          _expectTabs(tester, selected: '캘린더');

          app.router.push('${Routes.meTimetable}?tab=week');
          await tester.pumpAndSettle();
          expect(tab(), TimetableTab.timetable);

          await app.dispose(tester);
        });
      });

      group('캘린더와 09 일간', () {
        final day = DateTime(2026, 11, 13);

        testWidgets('캘린더 탭은 11 주간부터 열고, 주·월은 같은 자리에서 바꿔 끼운다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          await tapTab(tester, '캘린더');
          expect(find.byType(WeekScreen), findsOneWidget);
          expect(app.router.state.uri.path, Routes.calendar);

          // '월'은 08 월간으로 바꿔 끼운다. 쌓지 않으므로 아래에 11이 남지 않고 돌아갈 화면도 없으며(뒤로 가기·
          // iOS 스와이프로 11에 가지 않음), 탭바는 그대로다.
          await tapText(tester, '월');
          expect(find.byType(MonthScreen), findsOneWidget);
          expect(find.byType(WeekScreen, skipOffstage: false), findsNothing);
          expect(app.router.canPop(), isFalse);
          expect(app.router.state.uri.path, Routes.calendarMonth);
          _expectTabs(tester, selected: '캘린더');

          // 캘린더 탭을 다시 누르면 첫 화면인 11 주간이다.
          await tapTab(tester, '캘린더');
          expect(find.byType(WeekScreen), findsOneWidget);

          // '월' 뒤 '주'도 바꿔 끼운다.
          await tapText(tester, '월');
          await tapText(tester, '주');
          expect(find.byType(WeekScreen), findsOneWidget);
          expect(find.byType(MonthScreen, skipOffstage: false), findsNothing);
          expect(app.router.canPop(), isFalse);

          await app.dispose(tester);
        });

        testWidgets('11 주간·08 월간에서 연 09 일간은 오늘 탭에 속하고, 뒤로 가면 연 화면으로 돌아온다', (
          tester,
        ) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          // (연 곳, 그 화면)
          final rows = <(DayViewFrom, Type)>[
            (DayViewFrom.week, WeekScreen),
            (DayViewFrom.month, MonthScreen),
          ];
          for (final (from, screen) in rows) {
            app.router.go(from.location);
            await tester.pumpAndSettle();
            expect(find.byType(screen), findsOneWidget, reason: from.name);

            app.router.go(Routes.day(day, from: from));
            await tester.pumpAndSettle();
            expect(find.byType(DayScreen), findsOneWidget, reason: from.name);
            _expectTabs(tester, selected: '오늘');

            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            expect(find.byType(DayScreen), findsNothing, reason: from.name);
            expect(find.byType(screen), findsOneWidget, reason: from.name);
            expect(app.router.state.uri.path, from.location, reason: from.name);
            _expectTabs(tester, selected: '캘린더');
          }

          // 시스템 뒤로 가기(Android)도 같다.
          app.router.go(Routes.day(day, from: DayViewFrom.week));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(DayScreen), findsNothing);
          expect(find.byType(WeekScreen), findsOneWidget);
          _expectTabs(tester, selected: '캘린더');

          await app.dispose(tester);
        });

        testWidgets('iOS에서 09 일간을 왼쪽 끝에서 밀어 닫아도 연 화면으로 돌아온다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          await tapTab(tester, '캘린더');
          app.router.go(Routes.day(day, from: DayViewFrom.week));
          await tester.pumpAndSettle();
          expect(find.byType(DayScreen), findsOneWidget);

          // 뒤로 가기를 막지 않으므로 스와이프 뒤로가 살아 있다.
          await tester.dragFrom(
            const Offset(5, 400),
            Offset(phonePortrait.width * 0.8, 0),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DayScreen), findsNothing);
          expect(find.byType(WeekScreen), findsOneWidget);
          _expectTabs(tester, selected: '캘린더');

          await app.dispose(tester);
        }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

        testWidgets('02 홈과 06 AI 비서에서 연 09 일간은 뒤로 가면 02 홈이다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);

          // 02 홈의 '일간 보기'.
          app.router.go(Routes.day(day));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(app.router.state.uri.path, Routes.today);

          // 06 AI 비서 답의 '일간에서 보기'. 다른 탭에서 06을 열었어도 09로 가면 06은 닫히고, 뒤로 가면 02 홈이다.
          await tapTab(tester, '할 일');
          await tester.tap(assistantButton());
          await tester.pumpAndSettle();
          app.router.go(Routes.day(day));
          await tester.pumpAndSettle();
          expect(find.byType(AssistantScreen), findsNothing);
          expect(find.byType(DayScreen), findsOneWidget);
          _expectTabs(tester, selected: '오늘');
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(TodayScreen), findsOneWidget);
          _expectTabs(tester, selected: '오늘');

          await app.dispose(tester);
        });

        testWidgets('09 일간에서 날짜를 넘겨도 뒤로 가면 지난 날을 거치지 않고 연 화면으로 간다', (
          tester,
        ) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          DateTime shown() =>
              tester.widget<DayScreen>(find.byType(DayScreen)).date;
          await tapTab(tester, '캘린더');
          app.router.go(Routes.day(day, from: DayViewFrom.week));
          await tester.pumpAndSettle();

          await tapText(tester, '다음 날');
          await tapText(tester, '다음 날');
          expect(shown(), DateTime(2026, 11, 15));
          await tapText(tester, '전날');
          expect(shown(), DateTime(2026, 11, 14));
          expect(app.router.state.uri.path, Routes.day(DateTime(2026, 11, 14)));

          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(DayScreen), findsNothing);
          expect(find.byType(WeekScreen), findsOneWidget);
          _expectTabs(tester, selected: '캘린더');

          await app.dispose(tester);
        });

        testWidgets('09 일간에서 오늘 탭을 다시 누르면 02 홈이고 연 화면으로 가지 않는다', (
          tester,
        ) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          await tapTab(tester, '캘린더');
          app.router.go(Routes.day(day, from: DayViewFrom.week));
          await tester.pumpAndSettle();

          // 지금 탭(오늘)을 다시 누르면 그 탭의 첫 화면으로 간다. 뒤로 가기가 아니므로 캘린더로 가지 않는다.
          await tapTab(tester, '오늘');
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(find.byType(DayScreen), findsNothing);
          _expectTabs(tester, selected: '오늘');

          await app.dispose(tester);
        });

        testWidgets('없는 날짜의 09 일간은 시작 위치로 보낸다', (tester) async {
          final app = await pumpTestApp(tester, textScale: textScale);
          for (final path in [
            '${Routes.today}/day/2026-02-30',
            '${Routes.today}/day/today',
          ]) {
            app.router.go(path);
            await tester.pumpAndSettle();
            expect(find.byType(DayScreen), findsNothing, reason: path);
            expect(app.router.state.uri.path, Routes.today, reason: path);
          }

          await app.dispose(tester);
        });
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

      testWidgets('01 아침 브리핑은 뜨기만 해도 그날을 본 것으로 기록해, 시작 위치를 다시 정하면 02 홈이다', (
        tester,
      ) async {
        // docs/decisions.md 2026-11-13 '아침 브리핑은 뜨는 순간 본 것으로 기록한다'.
        final app = await pumpTestApp(
          tester,
          textScale: textScale,
          realBriefingCheck: true,
          now: DateTime(2026, 11, 13, 9),
        );
        expect(find.byType(BriefingScreen), findsOneWidget);
        final today = app.clock.today(dayBoundaryMin: Defaults.dayBoundaryMin);
        expect(await BriefingRepository(app.db).isSeen(today), const Ok(true));

        // 아무것도 누르지 않고 떠났다가 다시 열어도 그날은 브리핑을 띄우지 않는다.
        app.router.go(Routes.root);
        await tester.pumpAndSettle();
        expect(find.byType(BriefingScreen), findsNothing);
        expect(find.byType(TodayScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('데모의 01 아침 브리핑은 데모 DB에 기록하고 실제 DB의 기록은 건드리지 않는다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.demo,
          textScale: textScale,
          realBriefingCheck: true,
          now: DateTime(2026, 11, 13, 9),
        );
        expect(find.byType(BriefingScreen), findsOneWidget);
        final today = app.clock.today(dayBoundaryMin: Defaults.dayBoundaryMin);

        expect(
          await BriefingRepository(app.demoDb).isSeen(today),
          const Ok(true),
        );
        expect(await BriefingRepository(app.db).isSeen(today), const Ok(false));

        await app.dispose(tester);
      });

      testWidgets('실제 01 아침 브리핑을 본 뒤 데모에 들어가면 데모 브리핑이 따로 뜨고, 끝내도 실제 기록은 그대로다', (
        tester,
      ) async {
        final now = DateTime(2026, 11, 13, 9);
        final app = await pumpTestApp(
          tester,
          textScale: textScale,
          realBriefingCheck: true,
          now: now,
        );
        expect(find.byType(BriefingScreen), findsOneWidget);
        final [real] = await app.db.select(app.db.briefings).get();
        expect(real.openedAt, now);

        await tapText(tester, '오늘로 가기');
        await tapTab(tester, '나');
        await tapText(tester, '데모 모드 들어가기');

        // 데모 DB에는 기록이 없으므로 데모의 01이 뜨고, 그 기록은 데모 DB에만 적는다.
        expect(find.byType(BriefingScreen), findsOneWidget);
        expect(
          await BriefingRepository(app.demoDb).isSeen(DateTime(2026, 11, 13)),
          const Ok(true),
        );

        await tapText(tester, '끝내기');
        app.router.go(Routes.root);
        await tester.pumpAndSettle();

        expect(find.byType(TodayScreen), findsOneWidget);
        final [after] = await app.db.select(app.db.briefings).get();
        expect(after.openedAt, now);

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

      testWidgets('온보딩 1단계의 둘러보기로 데모 01 아침 브리핑에 들어가면 끝내기로 1단계에 돌아온다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          briefingOpenedToday: false,
          textScale: textScale,
        );

        await tapText(tester, _browseDemo);

        // 데모 모드는 onboarding_done을 보지 않고, 그날 브리핑을 아직 보지 않았으면 01부터 연다.
        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.byType(BriefingScreen), findsOneWidget);
        expect(app.preferences.getString('demo_entry'), 'onboarding');

        await tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.text(OnboardingStep.login.title), findsOneWidget);
        await scrollTo(tester, find.text(_browseDemo));
        expect(find.text(_browseDemo), findsOneWidget);

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

        await tapText(tester, _browseDemo);
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

      testWidgets(
        '로그인에 실패해 connecting으로 남은 채 둘러보기 → 끝내기를 해도 로그인 없이 실제 모드로 가지 않고 1단계다',
        (tester) async {
          // docs/decisions.md 2026-11-14 '로그인하는 중은 로그인 전으로 본다'. 처음 사용자는 2단계로, 로그아웃했던
          // 사용자는 /briefing·/today로 가던 길이다.
          for (final start in [TestStart.fresh, TestStart.loggedOut]) {
            final app = await pumpTestApp(
              tester,
              start: start,
              textScale: textScale,
            );
            // '로그인'을 눌러 connecting이 됐는데 실패해 로그인 화면에 머문 상태(docs/lms.md '세션 상태' 1번).
            await writeLmsSessionState(app, LmsSessionState.connecting);

            await tapText(tester, _browseDemo);
            expect(find.byType(DemoBand), findsOneWidget, reason: start.name);
            await tapText(tester, '끝내기');

            expect(find.byType(DemoBand), findsNothing, reason: start.name);
            expect(
              find.byType(OnboardingScreen),
              findsOneWidget,
              reason: start.name,
            );
            expect(
              find.text(OnboardingStep.login.title),
              findsOneWidget,
              reason: start.name,
            );
            expect(app.router.state.uri.path, Routes.onboarding);

            await app.dispose(tester);
          }
        },
      );

      testWidgets('데모 모드의 10 나에는 데모 모드 끝내기가 있고 누르면 /me로 돌아온다', (tester) async {
        final app = await pumpTestApp(tester, textScale: textScale);
        await tapTab(tester, '나');
        await tapText(tester, '데모 모드 들어가기');

        await tapTab(tester, '나');
        expect(find.text('데모 모드 들어가기'), findsNothing);
        await tapText(tester, '데모 모드 끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(MeScreen), findsOneWidget);
        expect(find.text('데모 모드 끝내기'), findsNothing);
        expect(app.preferences.getString('app_mode'), 'real');

        await app.dispose(tester);
      });

      testWidgets('둘러보기로 들어간 데모를 10 나에서 끝내면 온보딩 1단계로 가고, 다시 둘러보기로 들어간다', (
        tester,
      ) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.fresh,
          textScale: textScale,
        );
        await tapText(tester, _browseDemo);
        expect(find.byType(DemoBand), findsOneWidget);

        await tapTab(tester, '나');
        await tapText(tester, '데모 모드 끝내기');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.onboarding);
        expect(app.preferences.getString('app_mode'), 'real');

        // 같은 앱 실행 안에서 다시 들어갈 수 있다(들어가기의 진행 중 표시가 남지 않는다).
        await tapText(tester, _browseDemo);
        expect(find.byType(DemoBand), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'demo');

        // 끝내기 상태도 대기로 돌아와 있어, 두 번째 데모도 끝낼 수 있다.
        expect(app.container.read(demoExitProvider), DemoExitState.idle);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '끝내기'))
              .onPressed,
          isNotNull,
        );
        await tapText(tester, '끝내기');
        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('데모 DB를 비우지 못하면 띠가 안내하고 데모에 남으며, 다시 시도로 끝낸다', (tester) async {
        final app = await pumpTestApp(
          tester,
          start: TestStart.demo,
          textScale: textScale,
        );
        final demoDb = app.demoDb;
        await demoDb.customStatement(
          "INSERT INTO courses (name) VALUES ('샘플 과목')",
        );
        await demoDb.customStatement(
          'CREATE TRIGGER keep_courses BEFORE DELETE ON courses '
          "BEGIN SELECT RAISE(ABORT, 'test'); END",
        );

        await tapText(tester, '끝내기');

        expect(find.byType(DemoBand), findsOneWidget);
        expect(find.text('데모를 끝내지 못했어요'), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'demo');
        expect(app.container.read(databaseProvider), same(demoDb));

        await demoDb.customStatement('DROP TRIGGER keep_courses');
        await tapText(tester, '다시 시도');

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(app.preferences.getString('app_mode'), 'real');
        // 다시 시도로 끝낸 뒤에도 끝내기 상태는 대기다(다음 데모에서 끝내기가 막히지 않게).
        expect(app.container.read(demoExitProvider), DemoExitState.idle);

        await app.dispose(tester);
      });

      testWidgets('데모를 끝내는 동안 띠와 10 나의 끝내기를 막고, 거듭 불러도 한 번만 끝낸다', (
        tester,
      ) async {
        final controller = _GatedAppMode();
        final app = await pumpTestApp(
          tester,
          start: TestStart.demo,
          textScale: textScale,
          overrides: [appModeProvider.overrideWith(() => controller)],
        );

        await tester.tap(find.text('끝내기'));
        await tester.pump();
        expect(controller.exits, 1);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, '끝내기'))
              .onPressed,
          isNull,
        );
        await tapTab(tester, '나');
        await scrollTo(tester, find.text('데모 모드 끝내기'));
        expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, '데모 모드 끝내기'))
              .enabled,
          isFalse,
        );
        // 끝내는 중에 다시 불러도 끝내기를 또 부르지 않는다(기다리지 않고 바로 센다).
        final again = app.container.read(demoExitProvider.notifier).exit();
        expect(controller.exits, 1);

        controller.gate.complete();
        await again;
        await tester.pumpAndSettle();

        expect(find.byType(DemoBand), findsNothing);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(controller.exits, 1);

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
          await scrollTo(tester, find.text(_browseDemo));
          expect(find.text(_browseDemo), findsOneWidget);

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

/// 데모 끝내기를 [gate]가 열릴 때까지 붙잡아 두고 부른 횟수를 세는 앱 모드.
class _GatedAppMode extends AppModeController {
  final gate = Completer<void>();
  var exits = 0;

  @override
  Future<Result<DemoEntry>> exitDemo(AppDatabase demoDatabase) async {
    exits++;
    await gate.future;
    return super.exitDemo(demoDatabase);
  }
}
