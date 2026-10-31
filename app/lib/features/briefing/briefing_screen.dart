// 데일리 브리핑(전체 화면 `/briefing`). 논리적 하루에 앱을 처음 열 때 먼저 보여 준다.
// 내용(글 브리핑, 오늘 일정, 미배정 할 일, 마지막 접속 이후 변경)은 브리핑 PR에서 만든다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 데일리 브리핑.
class BriefingScreen extends StatelessWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScreenPlaceholder(
          title: AppStrings.dailyBriefing,
          children: [
            FilledButton(
              onPressed: () => context.go(Routes.calendar),
              child: const Text('캘린더로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
