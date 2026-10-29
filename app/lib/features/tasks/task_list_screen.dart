// 03 과제 목록(과제 탭 `/tasks`). 내용과 '과제 추가' 버튼(06 AI 대화로 감)은 과제 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 03 과제 목록.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: ScreenPlaceholder(title: AppStrings.tabTasks)),
    );
  }
}
