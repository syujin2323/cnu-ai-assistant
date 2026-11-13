// 06 AI 비서(셸 밖 전체 화면 `/assistant`). docs/screens.md '06 AI 비서'.
// screens.md '들어오는 길'의 곳에서 push로 열고, 닫으면 연 화면으로 돌아간다. 곳마다 다른 인자는
// [AssistantArgs](`assistant_args.dart`)로 `extra`에 담아 받는다. 말로 추가·말로 정하는 규칙과 직접 추가
// 폼, 받은 인자를 쓰는 동작은 AI 비서 PR에서 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:material_ui/material_ui.dart';

/// 06 AI 비서.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key, this.args = const AssistantArgs()});

  /// 연 곳이 넘긴 인자. 넘기지 않았으면 기본값(탭바 옆 버튼으로 연 것과 같음)이다.
  final AssistantArgs args;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 비서')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
