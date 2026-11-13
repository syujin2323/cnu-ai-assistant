// 13 시간표·고정 일정(`/me/timetable`, 셸 밖 전체 화면). docs/screens.md '13 시간표·고정 일정'.
// 10 나와 일정 정보 시트의 '시간표·고정 일정에서 바꾸기'(고정 일정 탭)에서 push로 열고, 닫으면 연
// 화면으로 돌아온다. 위에 [시간표 | 고정 일정] 두 탭을 둔다. 시간표 탭은 14 온보딩 1단계에서 로그인할
// 때 통합정보시스템에서 불러온 이번 학기 시간표를 보이고, [새로 고침]을 누를 때만 다시 불러와 바뀐
// 수업을 반영할지 묻는다. 고정 일정 탭은 카드와 '자주 넣는 일정' 칩, 시트로 넣는다. 화면은 시간표
// PR에서 만든다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 13 시간표·고정 일정.
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
