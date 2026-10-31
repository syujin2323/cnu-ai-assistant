// 미배정 할 일(`/tasks`). 여유도 순 목록과 '배치' 버튼은 미배정 할 일 PR에서 만든다
// (docs/architecture.md '도메인 기본값, 빈 시간과 여유도').

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 미배정 할 일.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.unassignedTasks)),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
