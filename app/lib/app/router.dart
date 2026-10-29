// 라우터. docs/architecture.md '화면 이동', '데모 모드'.
//
// 라우터는 이 파일 하나다. 경로 문자열은 [Routes] 상수로만 쓰고, 새 화면은 문서의 라우트 표에
// 먼저 더한다. 하단 탭은 `StatefulShellRoute.indexedStack`이고 가지 순서는 오늘 · 캘린더 · 과제 · 나다.
// 셸 밖 전체 화면 가운데 `/tasks/:id`와 `/me/timetable`은 그 탭 경로 아래에 두되 루트 Navigator에
// 띄운다. 그래서 알림 payload로 바로 열어도 뒤로 가면 그 탭으로 돌아간다.
//
// 시작 위치는 [_redirect] 한 곳에서만 정한다. 뒤로 가기 제어는 `PopScope`만 쓴다. 탭 전환에는
// 화면 전환 애니메이션을 쓰지 않는다(indexedStack).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/me/rules_screen.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_detail_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 경로. docs/architecture.md '화면 이동'의 라우트 표와 같다.
abstract final class Routes {
  /// 시작 위치를 정하는 자리. 화면은 없고 redirect가 곧바로 다른 경로로 보낸다.
  static const String root = '/';

  /// 온보딩(셸 밖).
  static const String onboarding = '/onboarding';

  /// 02 홈(오늘 탭).
  static const String today = '/today';

  /// 09 일간(오늘 탭). [date]는 `YYYY-MM-DD`(`domain/clock.dart`의 `isoDate`).
  static String day(String date) => '$today/$_daySegment/$date';

  /// 08 월간(캘린더 탭).
  static const String calendar = '/calendar';

  /// 주간(캘린더 탭, R1).
  static const String calendarWeek = '$calendar/$_weekSegment';

  /// 03 과제 목록(과제 탭).
  static const String tasks = '/tasks';

  /// 04 과제 상세(셸 밖 전체 화면).
  static String task(int id) => '$tasks/$id';

  /// 10 나(나 탭).
  static const String me = '/me';

  /// 내 규칙(나 탭).
  static const String meRules = '$me/$_rulesSegment';

  /// 시간표·고정 일정 편집(셸 밖 전체 화면).
  static const String meTimetable = '$me/$_timetableSegment';

  /// 01 아침 브리핑(셸 밖 전체 화면).
  static const String briefing = '/briefing';

  /// 06 AI 대화(셸 밖 전체 화면).
  static const String assistant = '/assistant';

  // 하위 경로 조각과 경로 매개변수 이름. 라우터 정의에만 쓴다.
  static const String _daySegment = 'day';
  static const String _weekSegment = 'week';
  static const String _rulesSegment = 'rules';
  static const String _timetableSegment = 'timetable';
  static const String _dateParam = 'date';
  static const String _idParam = 'id';
}

/// 앱을 켠 알림의 payload(go_router 경로 문자열). 알림으로 켜지지 않았으면 null이다.
///
/// 알림 PR에서 bootstrap이 `getNotificationAppLaunchDetails()`로 읽어 덮어쓴다.
final launchPayloadProvider = Provider<String?>((ref) => null);

/// 앱의 라우터. 한 번 만들고 다시 만들지 않는다(안에서는 `ref.read`만 쓴다).
final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  // payload는 앱을 켤 때 한 번만 쓴다.
  var launchPayload = ref.read(launchPayloadProvider);
  String? takeLaunchPayload() {
    final payload = launchPayload;
    launchPayload = null;
    return payload;
  }

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.root,
    redirect: (context, state) => _redirect(ref, state, takeLaunchPayload),
    // 없는 경로(잘못된 payload 등)는 시작 위치로 보낸다.
    onException: (context, state, router) => router.go(Routes.root),
    routes: [
      GoRoute(
        path: Routes.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.briefing,
        builder: (context, state) => const BriefingScreen(),
      ),
      GoRoute(
        path: Routes.assistant,
        builder: (context, state) => const AssistantScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: '${Routes._daySegment}/:${Routes._dateParam}',
                    builder: (context, state) => DayScreen(
                      date: state.pathParameters[Routes._dateParam]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (context, state) => const MonthScreen(),
                routes: [
                  GoRoute(
                    path: Routes._weekSegment,
                    builder: (context, state) => const WeekScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                builder: (context, state) => const TaskListScreen(),
                routes: [
                  GoRoute(
                    path: ':${Routes._idParam}',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => TaskDetailScreen(
                      taskId: int.tryParse(
                        state.pathParameters[Routes._idParam]!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.me,
                builder: (context, state) => const MeScreen(),
                routes: [
                  GoRoute(
                    path: Routes._rulesSegment,
                    builder: (context, state) => const RulesScreen(),
                  ),
                  GoRoute(
                    path: Routes._timetableSegment,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const TimetableScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// 시작 위치를 정하는 한 곳(docs/architecture.md '화면 이동', '데모 모드').
///
/// 시작 위치(`/`)에서만 순서대로 정한다. 알림 payload 경로 → 온보딩을 끝내지 않았으면
/// `/onboarding` → 오늘(논리적 하루)의 브리핑을 아직 열지 않았으면 `/briefing` → 그 밖에는
/// `/today`다. 데모 모드면 `onboarding_done`과 payload를 보지 않고 브리핑 규칙만 따른다.
///
/// 다른 경로는 막지 않는다. 온보딩 4·5단계가 `/me/timetable`을 열고, payload로 연 화면이
/// 온보딩에 덮이지 않게 하기 위해서다. 다만 온보딩을 끝냈거나 데모 모드면 `/onboarding`으로
/// 가는 이동은 브리핑이나 오늘로 돌린다.
Future<String?> _redirect(
  Ref ref,
  GoRouterState state,
  String? Function() takeLaunchPayload,
) async {
  final location = state.uri.path;
  final demo = ref.read(appModeProvider) == AppMode.demo;
  final onboardingDone =
      ref.read(sharedPreferencesProvider).getBool(PrefKeys.onboardingDone) ??
      false;

  if (location == Routes.root) {
    // payload는 앱을 켤 때 한 번만 쓴다. 데모 모드에서는 보지 않고 버린다.
    final payload = takeLaunchPayload();
    if (!demo) {
      if (payload != null) return payload;
      if (!onboardingDone) return Routes.onboarding;
    }
  } else if (location != Routes.onboarding || (!demo && !onboardingDone)) {
    return null;
  }
  try {
    final openedToday = await ref.read(briefingOpenedTodayProvider)();
    return openedToday ? Routes.today : Routes.briefing;
  } catch (error) {
    // 폰 DB를 읽지 못하면 브리핑도 보여 줄 수 없으므로 오늘로 간다. 여기서 던지면
    // onException이 다시 시작 위치로 보내 같은 실패를 되풀이한다.
    appLog(
      'start_briefing_check_failed',
      area: 'router',
      data: {'error': errorKind(error)},
    );
    return Routes.today;
  }
}

/// 하단 탭 셸. 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
class _TabShell extends ConsumerWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  static const List<AppTabItem> _tabs = [
    AppTabItem(label: AppStrings.tabToday, icon: AppIconName.today),
    AppTabItem(label: AppStrings.tabCalendar, icon: AppIconName.calendar),
    AppTabItem(label: AppStrings.tabTasks, icon: AppIconName.tasks),
    AppTabItem(label: AppStrings.tabMe, icon: AppIconName.me),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OS '투명도 줄이기'에서도 흰 배경으로 그린다(설정 읽기는 R1 플랫폼 코드).
    final glass = ref.watch(motionLevelProvider) == MotionLevel.full;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: AppTabBar(
        items: _tabs,
        currentIndex: shell.currentIndex,
        glass: glass,
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
