// 일정 목록(`/calendar/agenda`). 내용은 일정 목록 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_placeholder_view.dart';
import 'package:material_ui/material_ui.dart';

/// 일정 목록.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CalendarPlaceholderView(view: CalendarView.agenda, title: '일정');
}
