// 하단 탭바 테스트. docs/architecture.md '디자인 토큰'(유리), docs/screens.md '하단 탭과 AI 비서 버튼'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, {required bool glass}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            bottomNavigationBar: AppTabBar(
              items: const [
                AppTabItem(label: '오늘', icon: AppIconName.today),
                AppTabItem(label: '나', icon: AppIconName.me),
              ],
              currentIndex: 0,
              onSelected: (_) {},
              onAssistant: () {},
              glass: glass,
            ),
          ),
        ),
      );

  testWidgets('유리면 탭 알약과 AI 비서 버튼이 같은 유리 필터(blur 뒤 saturate)를 쓴다', (
    tester,
  ) async {
    await pumpBar(tester, glass: true);
    final filters = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .map((widget) => widget.filter)
        .toList();
    expect(filters, hasLength(2));
    expect(filters, everyElement(AppGlass.filter));
  });

  testWidgets('유리가 아니면(모션 light·off) 흐리게 하지 않는다', (tester) async {
    await pumpBar(tester, glass: false);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
