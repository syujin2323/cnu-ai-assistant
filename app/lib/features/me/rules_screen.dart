// 내 규칙(나 탭 `/me/rules`). 규칙 목록과 폼(켜기·끄기·고치기·지우기)은 내 규칙 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 내 규칙.
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
