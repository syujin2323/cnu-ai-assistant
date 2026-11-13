// 03 할 일(할 일 탭 `/tasks`). docs/screens.md '03 할 일'.
// 탭 [주간 할 일 N | 전체 할 일 N], LMS 상태 줄, '할 일 추가'(06 직접 추가 폼을 할 일로)는 할 일 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 03 할 일.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: ScreenPlaceholder(title: AppStrings.tabTasks)),
    );
  }
}
