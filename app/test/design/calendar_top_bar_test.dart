// 캘린더 상단바 제목 자리 테스트. docs/architecture.md '화면 이동'(삼성 캘린더 골자).
//
// 왼쪽 버튼은 하나(메뉴), 오른쪽은 둘(검색, 오늘로 이동)이어도 제목의 가운데가 화면 가운데와
// 1px 안으로 같은지, 긴 제목도 버튼과 겹치지 않고 넘치지 않는지 본다. 글자 배율 1.0과 2.0에서
// 돌린다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      for (final title in ['10월', '2026년']) {
        testWidgets('제목 \'$title\'이 화면 가운데에 있다', (tester) async {
          await _pump(tester, title, textScale);

          final screen = tester.getSize(find.byType(CalendarScaffold));
          final centre = tester.getCenter(find.text(title));
          expect(centre.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('긴 제목은 버튼과 겹치지 않고 말줄임된다', (tester) async {
        const title = '아주 긴 제목이 들어와도 버튼과 겹치지 않아야 한다';
        await _pump(tester, title, textScale);

        final text = tester.getRect(find.text(title));
        final menu = tester.getRect(find.byTooltip('메뉴'));
        final search = tester.getRect(find.byTooltip('검색'));
        expect(text.left, greaterThanOrEqualTo(menu.right));
        expect(text.right, lessThanOrEqualTo(search.left));
        expect(tester.takeException(), isNull);
      });

      testWidgets('제목은 머리말이고 버튼 이름표가 그대로다', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, '10월', textScale);

        expect(
          tester.getSemantics(find.text('10월')),
          isSemantics(label: '10월', isHeader: true),
        );
        expect(find.byTooltip('메뉴'), findsOneWidget);
        expect(find.byTooltip('검색'), findsOneWidget);
        expect(find.byTooltip('오늘로 이동'), findsOneWidget);
        handle.dispose();
      });
    });
  }
}

Future<void> _pump(WidgetTester tester, String title, double textScale) async {
  final day = DateTime(2026, 10, 29);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: CalendarScaffold(
          view: CalendarView.month,
          title: title,
          selected: day,
          today: day,
          onToday: () {},
          onAdd: (_) {},
          importantBriefing: (context, close) => const SizedBox.shrink(),
          hasUnseenAlerts: false,
          animate: false,
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
}
