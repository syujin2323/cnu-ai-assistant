// 04 할 일 상세(셸 밖 전체 화면 `/tasks/:id`, 재설계 예정. docs/screens.md '재설계 예정').
// 재설계 전까지 기능을 더하지 않고 다른 화면에서 이리로 오는 길도 만들지 않는다. 할 일을 누르면
// 무엇을 보일지는 재설계가 정한다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 04 할 일 상세(재설계 예정).
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  /// `tasks.id`. 경로의 `:id`가 정수가 아니면 null이다.
  final int? taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('할 일 상세')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
