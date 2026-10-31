// 일간(`/calendar/day/:date`). 월간에서 선택한 날을 한 번 더 누르거나 드로어의 '일'로 연다.
// 시간축의 수업·고정 일정·일정·블록은 일간 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_placeholder_view.dart';
import 'package:material_ui/material_ui.dart';

/// 일간.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.date});

  /// 보여 줄 날짜(`YYYY-MM-DD`). 읽을 때는 `domain/clock.dart`의 [tryParseIsoDate]를 쓴다.
  final String date;

  @override
  Widget build(BuildContext context) {
    final day = tryParseIsoDate(date);
    return CalendarPlaceholderView(
      view: CalendarView.day,
      title: day == null ? '일간' : '${day.month}월 ${day.day}일',
    );
  }
}
