// 08 월간 화면 테스트. docs/screens.md '08 월간'.
//
// 09 일간 테스트와 같은 샘플이다: 2026-11-16(월) 11:02. 오늘 일정 '상담' 15:00–15:30, 수요일(18일) 종일 일정 '학회'.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/event_info_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../today/day_screen_test.dart' show at, seed;

Future<TestApp> openMonth(
  WidgetTester tester, {
  double textScale = 1.0,
  Size size = phonePortrait,
}) async {
  final app = await pumpTestApp(
    tester,
    now: at(16, 11, 2),
    textScale: textScale,
    size: size,
  );
  await seed(app.db);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  app.router.go(Routes.calendarMonth);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 달력에 점을 두고, 오늘의 이벤트만 아래에 보인다', (
      tester,
    ) async {
      final app = await openMonth(tester, textScale: textScale);

      expect(find.byType(MonthScreen), findsOneWidget);
      expect(find.text('2026년 11월'), findsOneWidget);
      expect(find.bySemanticsLabel('11월 16일, 오늘, 일정 있음'), findsOneWidget);
      expect(find.bySemanticsLabel('11월 18일, 일정 있음'), findsOneWidget);
      expect(find.bySemanticsLabel('11월 17일'), findsOneWidget);
      await scrollTo(tester, find.text('상담'));
      expect(find.text('일정 · 15:00–15:30'), findsOneWidget);
      // 수업·할 일은 보이지 않는다.
      expect(find.text('자료구조'), findsNothing);
      expect(find.text('과제 1'), findsNothing);
      expect(tester.takeException(), isNull);
      await app.dispose(tester);
    });
  }

  testWidgets('날짜를 누르면 목록이 그날로 바뀌고, 카드는 일정 정보 시트를 연다', (tester) async {
    final app = await openMonth(tester);

    await tester.tap(find.bySemanticsLabel('11월 18일, 일정 있음'));
    await tester.pumpAndSettle();
    expect(find.text('11월 18일 (수)'), findsOneWidget);
    expect(find.text('상담'), findsNothing);
    await scrollTo(tester, find.text('학회'));
    expect(find.text('일정 · 종일'), findsOneWidget);

    await tester.tap(find.text('학회'));
    await tester.pumpAndSettle();
    expect(find.byType(EventInfoSheet), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('일정이 없는 날은 없다고 알리고, 이 날 일간 보기는 09 일간을 연다', (tester) async {
    final app = await openMonth(tester);

    await tester.tap(find.bySemanticsLabel('11월 17일'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('이 날은 일정이 없어요'));
    await tester.tap(find.text('이 날 일간 보기 ›'));
    await tester.pumpAndSettle();
    expect(tester.widget<DayScreen>(find.byType(DayScreen)).date, at(17, 0));
    await app.dispose(tester);
  });

  testWidgets('‹ ›로 달을 넘기면 공휴일 이름을 보이고, 오늘로 돌아온다. 주는 11 주간을 연다', (
    tester,
  ) async {
    final app = await openMonth(tester);

    await tester.tap(find.byTooltip('다음 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 12월'), findsOneWidget);
    expect(find.bySemanticsLabel('12월 25일, 성탄절'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '오늘'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 11월'), findsOneWidget);

    await tester.tap(find.byTooltip('지난달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);

    await tester.tap(find.text('주'));
    await tester.pumpAndSettle();
    expect(find.byType(WeekScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('태블릿 가로 폭에서도 넘치지 않는다', (tester) async {
    final app = await openMonth(tester, size: tabletLandscape, textScale: 2.0);
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
