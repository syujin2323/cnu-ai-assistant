// 라우터. docs/architecture.md '화면 이동', '데모 모드'.
//
// 라우터는 이 파일 하나다. 경로 문자열은 [Routes] 상수로만 쓰고, 새 화면은 문서의 라우트 표에
// 먼저 더한다. 하단 탭은 `StatefulShellRoute.indexedStack`이고 가지 순서는 오늘 · 캘린더 · 할 일 · 나다.
// 탭바 옆 'AI 비서에게 말하기' 버튼은 06 AI 비서를 push로 열어, 닫으면 같은 탭으로 돌아온다.
// 셸 밖 전체 화면은 루트 Navigator에 띄우고, 여는 곳에서 push로 열어 닫으면 연 화면으로 돌아오게
// 한다(go로 열면 돌아갈 곳이 없다). 그 가운데 `/tasks/:id`, `/me/rules`, `/me/timetable`은 그 탭 경로
// 아래에 두어, 바로 열어도(go) 뒤로 가면 그 탭으로 돌아간다.
//
// 시작 위치는 [_redirect] 한 곳에서만 정한다. 앱으로 돌아올 때(resumed)는 RootApp이
// [StartRules.onResume]으로 그 규칙을 다시 돌릴지 본다. 플랫폼이 넘기는 경로(Android intent의
// `route` 값과 딥링크)는 받지 않는다(`overridePlatformDefaultLocation`과 AndroidManifest의
// `flutter_deeplinking_enabled` false). 뒤로 가기 제어는 `PopScope`만 쓴다. 탭 전환에는
// 화면 전환 애니메이션을 쓰지 않는다(indexedStack).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 경로. docs/architecture.md '화면 이동'의 라우트 표와 같다.
abstract final class Routes {
  /// 시작 위치를 정하는 자리. 화면은 없고 redirect가 곧바로 다른 경로로 보낸다.
  static const String root = '/';

  /// 온보딩(셸 밖).
  static const String onboarding = '/onboarding';

  /// 14 다시 로그인(셸 밖 전체 화면). 학번은 고정이고, 끝나면 연 화면으로 돌아간다(push로 연다).
  static const String login = '/login';

  /// 02 홈(오늘 탭).
  static const String today = '/today';

  /// 09 일간(오늘 탭). [date]는 `YYYY-MM-DD`(`domain/clock.dart`의 `isoDate`).
  static String day(String date) => '$today/$_daySegment/$date';

  /// 08 월간(캘린더 탭).
  static const String calendar = '/calendar';

  /// 주간(캘린더 탭, R1).
  static const String calendarWeek = '$calendar/$_weekSegment';

  /// 03 할 일(할 일 탭).
  static const String tasks = '/tasks';

  /// 04 할 일 상세(셸 밖 전체 화면, 재설계 예정).
  static String task(int id) => '$tasks/$id';

  /// 10 나(나 탭).
  static const String me = '/me';

  /// 12 내 규칙(셸 밖 전체 화면).
  static const String meRules = '$me/$_rulesSegment';

  /// 시간표·고정 일정 편집(셸 밖 전체 화면).
  static const String meTimetable = '$me/$_timetableSegment';

  /// 01 아침 브리핑(셸 밖 전체 화면).
  static const String briefing = '/briefing';

  /// 06 AI 비서(셸 밖 전체 화면).
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
/// (알림은 재설계 예정) 자리만 두고 재설계 때 다시 본다. 그전까지 여기에 알림 코드를 붙이지 않는다.
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

  late final GoRouter router;
  router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.root,
    // 플랫폼이 넘기는 첫 경로(Android intent의 `route` 값 등)를 보지 않고 늘 `/`에서 시작한다.
    // 그 경로로 열면 시작 위치 규칙을 거치지 않아 온보딩을 건너뛸 수 있다. 실행 중에 들어오는
    // 딥링크는 AndroidManifest의 `flutter_deeplinking_enabled` false가 막는다.
    overridePlatformDefaultLocation: true,
    redirect: (context, state) => _redirect(
      ref,
      state,
      takeLaunchPayload: takeLaunchPayload,
      // redirect가 도는 동안 routerDelegate는 아직 이동 전 위치를 갖고 있다. 첫 이동 전에는 빈 경로다.
      previousPath: () => router.routerDelegate.currentConfiguration.uri.path,
    ),
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
        path: Routes.login,
        builder: (context, state) => const ReloginScreen(),
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
                    parentNavigatorKey: rootNavigatorKey,
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
/// 시작 위치(`/`)에서 순서대로 정한다. (R1·R2) 업데이트 필요·앱 잠금 화면이 생기면 맨 앞에서 본다.
/// 실제 모드에서 온보딩을 끝내지 않았거나 LMS 상태가 `disconnected`(로그아웃 뒤처럼 로그인 정보가
/// 없음)면 `/onboarding` → 알림 payload 경로(알림은 재설계 예정. 순서는 재설계 때 다시 봄) →
/// 오늘(논리적 하루)의 브리핑을 아직 보지 않았으면 `/briefing` → 그 밖에는 `/today`다. 데모 모드면
/// `onboarding_done`·LMS 상태·payload를 보지 않고 브리핑 규칙만 따른다. settings는 한 번만 읽고,
/// 읽지 못하면 `/today`로 간다.
///
/// `/login`처럼 시작 위치 밖의 경로는 막지 않는다. `/onboarding`으로 가는 이동은 데모 모드이거나
/// 온보딩을 끝냈고 LMS 상태가 `disconnected`가 아닐 때만 브리핑이나 오늘로 돌린다. 다만 이미
/// `/onboarding`에 있으면 돌리지 않는다. 로그아웃 뒤 1단계에서 로그인하는 동안 LMS 상태가
/// `connecting`·`active`로 바뀌어도 튕기지 않게 하기 위해서이고, 로그인이 끝나면 화면이 `/`로 간다.
/// 같은 까닭으로 settings에 `refreshListenable`을 달지 않는다. 로그아웃은 LMS 상태를
/// `disconnected`로 먼저 쓰고(await) 그다음 `/onboarding`으로 간다.
///
/// settings를 읽으면 그 논리적 하루를 [StartRules]에 적는다. 앱으로 돌아왔을 때 다시 돌릴지 견주는 날이다.
Future<String?> _redirect(
  Ref ref,
  GoRouterState state, {
  required String? Function() takeLaunchPayload,
  required String Function() previousPath,
}) async {
  final location = state.uri.path;
  if (location != Routes.root && location != Routes.onboarding) return null;
  final toOnboarding = location == Routes.onboarding;
  // payload는 앱을 켤 때 `/`에서 한 번만 꺼낸다. 온보딩으로 보낼 때와 데모 모드에서는 쓰지 않고 버린다.
  final payload = toOnboarding ? null : takeLaunchPayload();
  // 온보딩으로 가야 하면 `/`는 `/onboarding`으로 보내고, `/onboarding`으로 가는 이동은 그대로 둔다.
  final onboarding = toOnboarding ? null : Routes.onboarding;
  final demo = ref.read(appModeProvider) == AppMode.demo;

  if (!demo) {
    if (toOnboarding && previousPath() == Routes.onboarding) return null;
    final onboardingDone =
        ref.read(sharedPreferencesProvider).getBool(PrefKeys.onboardingDone) ??
        false;
    if (!onboardingDone) return onboarding;
  }

  // 실제 모드의 settings는 실제 DB라 LMS 상태도 여기서 읽는다. 데모 모드에서는 LMS 상태를 보지 않는다.
  final AppSettings settings;
  switch (await ref.read(settingsRepositoryProvider).read()) {
    case Ok(:final value):
      settings = value;
    case Err(:final error):
      // LMS 상태도 브리핑도 알 수 없으므로 오늘로 간다(브리핑 확인 실패와 같음).
      appLog(
        'start_settings_read_failed',
        area: 'router',
        data: {'error': error.toString()},
      );
      return Routes.today;
  }
  ref
      .read(startRulesProvider)
      ._recordRun(
        ref.read(clockProvider).today(dayBoundaryMin: settings.dayBoundaryMin),
      );
  if (!demo) {
    if (settings.lmsSessionState == LmsSessionState.disconnected) {
      return onboarding;
    }
    if (payload != null) return payload;
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

/// 앱으로 돌아왔을 때 시작 위치 규칙을 다시 돌릴지 정하는 것. RootApp의 `AppLifecycleListener`가
/// [StartRules.onResume]을 부른다.
final startRulesProvider = Provider<StartRules>(StartRules.new);

/// 앱으로 돌아왔을 때(resumed) 시작 위치 규칙([_redirect])을 다시 돌릴지 정한다
/// (docs/architecture.md '화면 이동', docs/decisions.md 2026-11-06 '앱으로 돌아올 때는 하루가 바뀌었을
/// 때만 시작 위치를 다시 정한다').
///
/// 논리적 하루가 [_redirect]가 마지막으로 시작 규칙을 돌린 날과 다르고, 그날 브리핑을 아직 보지
/// 않았으며, 맨 위 화면이 미루는 화면이 아닐 때만 `/`로 가서 [_redirect]가 다시 정하게 한다. 같은 날
/// 안에서 돌아오면 보던 화면을 그대로 둔다. 시작 위치를 정하는 곳은 여전히 [_redirect] 하나다.
class StartRules {
  StartRules(this._ref);

  final Ref _ref;

  /// 돌아왔을 때 미루는 화면. 이미 시작 흐름에 있거나(14 온보딩, 다시 로그인, 01 아침 브리핑) 입력
  /// 중일 수 있는 화면(06 AI 비서와 그 위에 덮는 직접 추가 폼)이라 덮지 않는다. 미룬 확인은 다음에
  /// 돌아올 때 다시 본다.
  static const Set<String> _deferredPaths = {
    Routes.onboarding,
    Routes.login,
    Routes.briefing,
    Routes.assistant,
  };

  /// [_redirect]가 마지막으로 시작 규칙을 돌린 논리적 하루. 앱을 다시 켜면 처음부터 다시 돌므로
  /// 메모리에만 둔다. 아직 한 번도 돌리지 않았으면 null이다.
  DateTime? _lastRunDay;

  /// 진행 중인 확인. 돌아왔다는 신호가 겹쳐 와도 확인은 하나만 돈다.
  Future<void>? _resumeCheck;

  void _recordRun(DateTime day) => _lastRunDay = day;

  /// 앱으로 돌아왔을 때 부른다. 확인이 이미 돌고 있으면 그 확인을 돌려준다.
  Future<void> onResume() =>
      _resumeCheck ??= _checkOnResume().whenComplete(() => _resumeCheck = null);

  Future<void> _checkOnResume() async {
    final router = _ref.read(routerProvider);
    final lastRunDay = _lastRunDay;
    // 첫 시작 위치를 정하는 중이면 견줄 날이 없다.
    if (lastRunDay == null || _isDeferred(router)) return;
    final int dayBoundaryMin;
    switch (await _ref.read(settingsRepositoryProvider).read()) {
      case Ok(:final value):
        dayBoundaryMin = value.dayBoundaryMin;
      case Err(:final error):
        appLog(
          'resume_settings_read_failed',
          area: 'router',
          data: {'error': error.toString()},
        );
        return;
    }
    final today = _ref
        .read(clockProvider)
        .today(dayBoundaryMin: dayBoundaryMin);
    if (today == lastRunDay) return;
    final bool openedToday;
    try {
      openedToday = await _ref.read(briefingOpenedTodayProvider)();
    } catch (error) {
      // 확인하지 못하면 보던 화면을 그대로 둔다. 다음에 돌아올 때 다시 본다.
      appLog(
        'resume_briefing_check_failed',
        area: 'router',
        data: {'error': errorKind(error)},
      );
      return;
    }
    // 확인하는 동안 미루는 화면으로 옮겨 갔어도 그대로 둔다.
    if (openedToday || _isDeferred(router)) return;
    // `/`에서 [_redirect]가 시작 위치를 다시 정한다. 브리핑(셸 밖)으로 가면 하단 탭 셸이 내려가므로
    // 각 탭에서 보던 화면(탭 가지 상태)은 사라지고, 브리핑을 닫으면 탭은 첫 화면부터 다시 열린다.
    router.go(Routes.root);
  }

  /// 맨 위 화면이 미루는 화면인지. 첫 화면을 띄우기 전이면 미룬다.
  static bool _isDeferred(GoRouter router) {
    if (router.routerDelegate.currentConfiguration.isEmpty) return true;
    return _deferredPaths.contains(router.state.uri.path);
  }
}

/// 하단 탭 셸. 탭을 다시 누르면 그 탭의 첫 화면으로 돌아가고, 탭을 바꿔도 각 탭의 화면은 남는다.
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
    // 지금은 모션 등급만 본다. (R1) OS '투명도 줄이기'를 읽게 되면 그때도 여기서 유리를 끈다.
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
        // push라야 06을 닫을 때 지금 탭으로 돌아온다(go는 뒤로 갈 곳이 없다).
        onAssistant: () => context.push(Routes.assistant),
      ),
    );
  }
}
