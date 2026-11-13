// 11 주간과 08 월간 머리의 '주 | 월'. docs/screens.md '11 주간'·'08 월간', docs/architecture.md '화면 이동'.
//
// 두 화면은 캘린더 탭 가지의 형제 경로라, '주 | 월'은 같은 자리에서 화면을 바꿔 끼운다(go). 그래서 08 월간에
// 뒤로 화살표가 없고, 캘린더 탭을 다시 누르면 11 주간으로 간다(docs/decisions.md 2026-11-13 '캘린더의
// '주 | 월'은 같은 자리에서 바꿔 끼운다'). 머리의 나머지(주 범위, '오늘', ‹ ›, '제안 일정')는 캘린더 PR에서
// 만든다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 탭의 보기.
enum CalendarView {
  /// 11 주간(캘린더 탭의 첫 화면).
  week,

  /// 08 월간.
  month;

  /// 이 보기의 경로.
  String get location => switch (this) {
    CalendarView.week => Routes.calendar,
    CalendarView.month => Routes.calendarMonth,
  };
}

/// '주 | 월'.
class CalendarViewSwitch extends StatelessWidget {
  const CalendarViewSwitch({super.key, required this.current});

  /// 지금 보는 보기.
  final CalendarView current;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CalendarView>(
      segments: const [
        ButtonSegment(value: CalendarView.week, label: Text('주')),
        ButtonSegment(value: CalendarView.month, label: Text('월')),
      ],
      selected: {current},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => context.go(selection.single.location),
    );
  }
}
