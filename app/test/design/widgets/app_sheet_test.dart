// showAppSheet 테스트. docs/architecture.md '화면 이동'(시트), '디자인 토큰'(sheet·scrim·모서리 32).
//
// 탭 화면은 탭 가지 Navigator 안에 있으므로, 시트를 루트 Navigator에 열어야 떠 있는 하단 탭바를
// 덮고 시트를 연 채 탭을 바꿀 수 없다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 탭 화면에서 연 시트는 루트에 떠서 탭바를 덮고, 연 채로는 탭을 '
        '바꿀 수 없다', (tester) async {
      final app = await pumpTestApp(tester, textScale: textScale);
      expect(find.byType(TodayScreen), findsOneWidget);

      unawaited(
        showAppSheet<void>(
          context: tester.element(find.byType(TodayScreen)),
          motion: MotionLevel.off,
          builder: (context) => const Padding(
            padding: EdgeInsets.all(AppSpace.s24),
            child: Text('시트 내용'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('시트 내용'), findsOneWidget);

      // 탭 가지가 아니라 루트 Navigator에 있다.
      expect(
        Navigator.of(tester.element(find.text('시트 내용'))),
        same(app.router.routerDelegate.navigatorKey.currentState),
      );
      // 모양은 테마의 sheet 배경, 위 모서리 32, 뒤 scrim이다.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.light.sheet);
      expect(
        material.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      );
      expect(
        tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
        AppColors.light.scrim,
      );

      // 막은 탭바까지 화면 전체를 덮는다.
      final barrier = tester.getRect(find.byType(ModalBarrier).last);
      final tabBar = tester.getRect(find.byType(AppTabBar));
      expect(barrier.contains(tabBar.topLeft), isTrue);
      expect(barrier.contains(tabBar.bottomRight - const Offset(1, 1)), isTrue);

      // 탭바의 '캘린더'를 눌러도 막이나 시트가 받아 탭은 그대로다(글자가 크면 시트가 그 자리를 덮는다).
      await tester.tap(tabButton('캘린더'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(app.router.state.uri.path, Routes.today);

      await app.dispose(tester);
    });
  }
}
