// 06 AI 비서(셸 밖 전체 화면 `/assistant`). docs/screens.md '06 AI 비서'.
// 하단 탭 옆 'AI 비서에게 말하기' 버튼, 03 할 일의 '할 일 추가'(06 직접 추가 폼을 할 일로) 등
// screens.md '들어오는 길'의 곳에서 연다. 말로 추가·말로 정하는 규칙과 직접 추가 폼은 AI 비서 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 06 AI 비서.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 비서')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
