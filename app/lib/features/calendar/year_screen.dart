// 연간(`/calendar/year`). 내용은 연간 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_placeholder_view.dart';
import 'package:material_ui/material_ui.dart';

/// 연간.
class YearScreen extends StatelessWidget {
  const YearScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CalendarPlaceholderView(view: CalendarView.year, title: '연간');
}
