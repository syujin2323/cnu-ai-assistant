// 04 과제 상세(셸 밖 전체 화면 `/tasks/:id`). R0에서는 영상 길이·인정 시간·시청 시간도 보여 준다
// (05 강의 상세는 R1에 `/lectures/:id`). 내용은 과제 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 04 과제 상세.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  /// `tasks.id`. 경로의 `:id`가 정수가 아니면 null이다.
  final int? taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('과제 상세')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
