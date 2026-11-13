// 09 일간(오늘 탭 `/today/day/:date`). docs/screens.md '09 일간', docs/architecture.md '화면 이동'.
//
// 들어오는 길은 02 홈 '일간 보기', 11 주간 날짜 줄·일정 줄, 08 월간 '이 날 일간 보기', 06 AI 비서 답
// '일간에서 보기'이고, 어디서 열든 `context.go(Routes.day(날짜, from: …))`로 열어 늘 오늘 탭에 둔다.
// 11·08에서 열면 [DayViewFrom]을 넘기고, 뒤로 가면 오늘 탭에서 이 화면이 빠진 뒤 그 화면으로 간다
// (docs/decisions.md 2026-11-13 '다른 탭에서 연 09 일간은 오늘 탭에 두고 뒤로 가면 온 화면으로
// 돌아간다'). 02 홈과 06 AI 비서에서 열면 넘기지 않고, 뒤로 가면 02 홈이다. 날짜를 넘길 때는 `replace`로
// 이 화면만 바꿔 끼워 뒤로가 지난 날을 거치지 않게 한다. 시간표와 위 막대·날짜 줄은 일간 PR에서 만든다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 09 일간을 연 다른 탭의 화면. 뒤로 가면 이 화면으로 돌아간다.
enum DayViewFrom {
  /// 11 주간(캘린더 탭).
  week,

  /// 08 월간(캘린더 탭).
  month;

  /// 돌아갈 경로.
  String get location => switch (this) {
    DayViewFrom.week => Routes.calendar,
    DayViewFrom.month => Routes.calendarMonth,
  };
}

/// 09 일간.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.date, this.from});

  /// 보여 줄 날짜(그날 0시의 로컬 시각).
  final DateTime date;

  /// 다른 탭에서 열었으면 뒤로 가면 돌아갈 화면. null이면 02 홈으로 돌아간다.
  final DayViewFrom? from;

  @override
  Widget build(BuildContext context) {
    // 뒤로 간 뒤에는 이 화면의 context를 쓸 수 없으므로 라우터를 미리 잡아 둔다.
    final router = GoRouter.of(context);
    final from = this.from;
    return PopScope(
      // 뒤로 가기는 막지 않는다(iOS 왼쪽 끝 스와이프 뒤로를 살림). 오늘 탭에서 이 화면이 빠진 뒤 연
      // 화면으로 가며, 스와이프하는 동안 아래에 02 홈이 비치는 것은 받아들였다. 그 탭의 화면 상태는 남는다.
      // 이 콜백은 오늘 탭을 다시 누르거나 다른 곳으로 가서 이 화면이 빠질 때도 불리고, 어느 쪽이든 라우터는
      // 이미 새 위치에 있다. 뒤로 가기로 닫혔을 때만 연 화면으로 간다([Routes.isDayClosedByBack]).
      onPopInvokedWithResult: (didPop, result) {
        if (didPop &&
            from != null &&
            Routes.isDayClosedByBack(router.state.uri, from)) {
          router.go(from.location);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('일간')),
        body: SafeArea(
          child: ScreenPlaceholder(
            children: [
              Text(isoDate(date)),
              Wrap(
                spacing: AppSpace.s8,
                children: [
                  TextButton(
                    onPressed: () => _showDay(context, -1),
                    child: const Text('전날'),
                  ),
                  TextButton(
                    onPressed: () => _showDay(context, 1),
                    child: const Text('다음 날'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [days]만큼 옮긴 날로 바꿔 끼운다(쌓지 않음).
  void _showDay(BuildContext context, int days) => context.replace(
    Routes.day(DateTime(date.year, date.month, date.day + days), from: from),
  );
}
