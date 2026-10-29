// 01 아침 브리핑(셸 밖 전체 화면). 논리적 하루에 앱을 처음 열 때 먼저 보여 준다.
// 내용(AI 문단, 오늘 블록과 '모두 확정', 어제 못 한 일, 챙길 것)은 브리핑 PR에서 만든다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 01 아침 브리핑.
class BriefingScreen extends StatelessWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
          title: '아침 브리핑',
          children: [
            FilledButton(
              onPressed: () => context.go(Routes.today),
              child: const Text('오늘로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
