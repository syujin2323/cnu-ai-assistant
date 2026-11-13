// 08 월간(캘린더 탭 `/calendar/month`). docs/screens.md '08 월간'.
// 이벤트만 보인다: 약속·행사 같은 일정, 종일 일정, 시험인 수업, 학사일정 띠와 공휴일(R1). 수업·고정 일정·
// 할 일·마감은 11 주간과 09 일간에서 본다. '이 날 일간 보기'는 09 일간을 `Routes.day(날짜, from:
// DayViewFrom.month)`로 열고, '주'는 같은 자리에서 11 주간으로 바꿔 끼운다(뒤로 화살표 없음).
// 달력과 목록은 캘린더 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/calendar_view_switch.dart';
import 'package:material_ui/material_ui.dart';

/// 08 월간.
class MonthScreen extends StatelessWidget {
  const MonthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
          title: '월간',
          children: [CalendarViewSwitch(current: CalendarView.month)],
        ),
      ),
    );
  }
}
