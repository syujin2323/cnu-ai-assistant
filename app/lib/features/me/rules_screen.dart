// 12 내 규칙(`/me/rules`, 셸 밖 전체 화면). docs/screens.md '12 내 규칙'.
// 10 나에서 push로 열고 뒤로 가면 10 나로 돌아온다. 규칙 목록과 폼(켜기·끄기·고치기·지우기)은
// 내 규칙 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 12 내 규칙.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myRules)),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
