// 시간표·고정 일정 편집(셸 밖 전체 화면 `/me/timetable`). 온보딩 4·5단계와 10 나의 설정에서 연다.
// 과목 고르기와 통합정보시스템 자동 채움, 확인·수정은 시간표 PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 시간표·고정 일정 편집.
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.timetableAndFixed)),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
