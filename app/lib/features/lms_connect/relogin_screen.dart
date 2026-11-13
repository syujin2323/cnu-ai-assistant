// 14 다시 로그인(셸 밖 전체 화면 `/login`). docs/screens.md '다시 로그인'.
//
// 01 아침 브리핑·02 홈·03 할 일의 '다시 로그인' 칩, 03 할 일 LMS 정보 시트, 10 나 › LMS 계정이
// `context.push(Routes.login)`으로 열고, 로그인이 끝나면 pop해 연 화면으로 돌아간다(go로 열면 돌아갈
// 곳이 없다). 데모 모드에서는 이 화면을 열지 않고 '데모에서는 LMS에 연결하지 않아요'를 띄운다.
// 폼은 14 온보딩 1단계와 함께 쓰는 로그인 폼의 다시 로그인 모드(학번 고정, 비밀번호만)이고,
// LMS 로그인 PR에서 이 폴더에 만든다.

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 14 다시 로그인.
class ReloginScreen extends StatelessWidget {
  const ReloginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('다시 로그인')),
      body: const SafeArea(child: ScreenPlaceholder()),
    );
  }
}
