// 검색(`/search`). 뒤로가기만 있는 전체 화면이고, 색상·캘린더 필터와 하단 검색창은 검색 PR에서
// 만든다(docs/architecture.md '화면 이동').

import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 검색.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const SafeArea(child: ScreenPlaceholder(title: '검색')),
    );
  }
}
