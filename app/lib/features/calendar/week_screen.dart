// 주간(`/calendar/week`). 2026-10-31 결정으로 R0다. 내용은 주간 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_placeholder_view.dart';
import 'package:material_ui/material_ui.dart';

/// 주간.
class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CalendarPlaceholderView(view: CalendarView.week, title: '주간');
}
