// 08 월간(캘린더 탭 `/calendar`). 날짜마다 마감과 블록을 표시하고 날짜를 누르면 그날 일간으로 간다.
// 내용은 월간 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 08 월간.
class MonthScreen extends StatelessWidget {
  const MonthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: ScreenPlaceholder(title: AppStrings.tabCalendar)),
    );
  }
}
