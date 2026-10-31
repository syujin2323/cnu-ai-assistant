// 라우터. docs/architecture.md '화면 이동', '데모 모드'.
//
// 라우터는 이 파일 하나다. 경로 문자열은 [Routes] 상수로만 쓰고, 새 화면은 문서의 라우트 표에
// 먼저 더한다. 하단 탭은 없다(2026-10-31 결정). 캘린더 보기(년·월·주·일·일정)가 첫 화면이고
// 드로어에서 서로 바꾼다(go, 전환 애니메이션 없음). 검색·브리핑·미배정 할 일·나는 그 위에
// 쌓아(push) 뒤로 가면 보던 캘린더로 돌아온다.
//
// 시작 위치는 [_redirect] 한 곳에서만 정한다. 뒤로 가기 제어는 `PopScope`만 쓴다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 경로. docs/architecture.md '화면 이동'의 라우트 표와 같다.
abstract final class Routes {
  /// 시작 위치를 정하는 자리. 화면은 없고 redirect가 곧바로 다른 경로로 보낸다.
  static const String root = '/';

  /// 온보딩.
  static const String onboarding = '/onboarding';

  /// 월간 + 선택일 패널. 첫 화면.
  static const String calendar = '/calendar';

  /// 연간.
  static const String calendarYear = '$calendar/$_yearSegment';

  /// 주간.
  static const String calendarWeek = '$calendar/$_weekSegment';

  /// 일간. [date]는 `YYYY-MM-DD`(`domain/clock.dart`의 `isoDate`).
  static String calendarDay(String date) => '$calendar/$_daySegment/$date';

  /// 일정 목록.
  static const String calendarAgenda = '$calendar/$_agendaSegment';

  /// 검색.
  static const String search = '/search';

  /// 미배정 할 일.
  static const String tasks = '/tasks';

  /// 할 일 상세.
  static String task(int id) => '$tasks/$id';

  /// 나·설정.
  static const String me = '/me';

  /// 내 규칙.
  static const String meRules = '$me/$_rulesSegment';

  /// 시간표·고정 일정 편집.
  static const String meTimetable = '$me/$_timetableSegment';

  /// 데일리 브리핑(전체 화면).
  static const String briefing = '/briefing';

  /// AI 대화(내 규칙을 말로 정할 때).
  static const String assistant = '/assistant';

  // 하위 경로 조각과 경로 매개변수 이름. 라우터 정의에만 쓴다.
  static const String _yearSegment = 'year';
  static const String _weekSegment = 'week';
  static const String _daySegment = 'day';
  static const String _agendaSegment = 'agenda';
  static const String _rulesSegment = 'rules';
  static const String _timetableSegment = 'timetable';
  static const String _dateParam = 'date';
  static const String _idParam = 'id';
}

/// 앱을 켠 알림의 payload(go_router 경로 문자열). 알림으로 켜지지 않았으면 null이다.
///
/// bootstrap이 `getNotificationAppLaunchDetails()`로 읽어 덮어쓴다.
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
      GoRoute(
        path: Routes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      // 캘린더 보기끼리는 드로어에서 go로 바꾸므로 화면 전환 애니메이션을 쓰지 않는다.
      GoRoute(
        path: Routes.calendar,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: MonthScreen()),
        routes: [
          GoRoute(
            path: Routes._yearSegment,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: YearScreen()),
          ),
          GoRoute(
            path: Routes._weekSegment,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: WeekScreen()),
          ),
          GoRoute(
            path: '${Routes._daySegment}/:${Routes._dateParam}',
            pageBuilder: (context, state) => NoTransitionPage(
              child: DayScreen(date: state.pathParameters[Routes._dateParam]!),
            ),
          ),
          GoRoute(
            path: Routes._agendaSegment,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AgendaScreen()),
          ),
        ],
      ),
      GoRoute(
        path: Routes.tasks,
        builder: (context, state) => const TaskListScreen(),
        routes: [
          GoRoute(
            path: ':${Routes._idParam}',
            builder: (context, state) => TaskDetailScreen(
              taskId: int.tryParse(state.pathParameters[Routes._idParam]!),
            ),
          ),
        ],
      ),
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
            builder: (context, state) => const TimetableScreen(),
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
/// `/calendar`다. 데모 모드면 `onboarding_done`과 payload를 보지 않고 브리핑 규칙만 따른다.
///
/// 다른 경로는 막지 않는다. 온보딩 4·5단계가 `/me/timetable`을 열고, payload로 연 화면이
/// 온보딩에 덮이지 않게 하기 위해서다. 다만 온보딩을 끝냈거나 데모 모드면 `/onboarding`으로
/// 가는 이동은 브리핑이나 캘린더로 돌린다.
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
    return openedToday ? Routes.calendar : Routes.briefing;
  } catch (error) {
    // 폰 DB를 읽지 못하면 브리핑도 보여 줄 수 없으므로 캘린더로 간다. 여기서 던지면
    // onException이 다시 시작 위치로 보내 같은 실패를 되풀이한다.
    appLog(
      'start_briefing_check_failed',
      area: 'router',
      data: {'error': errorKind(error)},
    );
    return Routes.calendar;
  }
}
