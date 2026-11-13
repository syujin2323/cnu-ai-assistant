// 11 주간(캘린더 탭의 첫 화면 `/calendar`). docs/screens.md '11 주간'.
// 날짜별 목록이고 머리는 주 범위, '오늘', ‹ ›, '제안 일정' 스위치, '주 | 월'이다. 날짜 줄·일정 줄을 누르면
// 09 일간을 `Routes.day(날짜, from: DayViewFrom.week)`로 열고(오늘 탭에 속하고 뒤로 가면 여기로 돌아옴),
// '월'은 같은 자리에서 08 월간으로 바꿔 끼운다. 요약 칸·날짜 줄·목록과 '제안 일정'은 캘린더 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/calendar_view_switch.dart';
import 'package:material_ui/material_ui.dart';

/// 11 주간.
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
          title: '주간',
          children: [CalendarViewSwitch(current: CalendarView.week)],
        ),
      ),
    );
  }
}
