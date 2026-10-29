// 06 AI 대화(셸 밖 전체 화면 `/assistant`). 모든 탭의 'AI 비서에게 말하기' 버튼과 03 과제 목록의
// '과제 추가' 버튼에서 연다. 말로 추가·말로 정하는 규칙은 AI PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 06 AI 대화.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 대화')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
