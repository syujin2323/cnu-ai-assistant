// 11 주간 화면 테스트. docs/screens.md '11 주간'.
//
// 09 일간 테스트와 같은 샘플이다: 2026-11-16(월) 11:02, 하루 창 09:00–18:00. 월요일 자료구조 수업 13:00–14:00, 오늘
// 일정 '상담' 15:00–15:30, 수요일 종일 일정 '학회', '과제 1'(오늘 23:59 마감, 확정 블록 16:00–17:00), '과제 2'
// (목요일 18:00 마감, 엔진이 제안을 놓음).

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/task_sheet.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../today/day_screen_test.dart' show at, seed;

Future<TestApp> openWeek(
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
  // 표가 바뀌고 300ms 뒤 재계산이 돌아 '과제 2'의 제안을 놓는다.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  app.router.go(Routes.calendar);
  await tester.pumpAndSettle();
  return app;
}

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 주 범위와 요약 세 칸, 날짜마다 날짜 줄·마감 줄·일정 줄을 보인다', (
      tester,
    ) async {
      final app = await openWeek(tester, textScale: textScale);

      expect(find.byType(WeekScreen), findsOneWidget);
      expect(find.text('11월 16일 – 22일'), findsOneWidget);
      // 이번 주라 '오늘' 버튼은 없다.
      expect(find.widgetWithText(TextButton, '오늘'), findsNothing);
      expect(find.text('마감'), findsOneWidget);
      expect(find.text('2개'), findsOneWidget);
      expect(find.text('할 일 예상 시간'), findsOneWidget);
      expect(find.text('빈 시간'), findsOneWidget);

      expect(find.textContaining('오늘 · 16일 (월)'), findsOneWidget);
      expect(find.text('자료구조'), findsOneWidget);
      expect(find.text('상담'), findsOneWidget);
      expect(find.text('과제 1'), findsOneWidget);
      expect(find.text('마감 · 과제 1'), findsOneWidget);
      // 제안 블록은 '제안 일정'을 켜기 전에는 보이지 않는다.
      expect(find.text('제안'), findsNothing);
      expect(tester.takeException(), isNull);

      await app.dispose(tester);
    });
  }

  testWidgets('제안 일정을 켜면 제안 블록을 목록에 꼬리표와 함께 보인다', (tester) async {
    final app = await openWeek(tester);
    expect(find.text('과제 2'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('과제 2'));
    expect(find.text('제안'), findsWidgets);
    await app.dispose(tester);
  });

  testWidgets('‹ ›로 주를 넘기고 오늘로 돌아온다. 지난주의 요약은 지킨 마감·놓친 블록이다', (tester) async {
    final app = await openWeek(tester);

    await tester.tap(find.byTooltip('지난주'));
    await tester.pumpAndSettle();
    expect(find.text('11월 9일 – 15일'), findsOneWidget);
    expect(find.text('지킨 마감'), findsOneWidget);
    expect(find.text('놓친 블록'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '오늘'));
    await tester.pumpAndSettle();
    expect(find.text('11월 16일 – 22일'), findsOneWidget);

    await tester.tap(find.byTooltip('다음 주'));
    await tester.pumpAndSettle();
    expect(find.text('11월 23일 – 29일'), findsOneWidget);
    // 매주 열리는 수업은 다음 주에도 있다.
    expect(find.text('자료구조'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('날짜 줄을 누르면 그날의 09 일간을, 마감 줄은 할 일 시트를, 월은 08 월간을 연다', (
    tester,
  ) async {
    final app = await openWeek(tester);

    await tester.tap(find.text('마감 · 과제 1'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskSheet), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('오늘 · 16일 (월)'));
    await tester.pumpAndSettle();
    expect(tester.widget<DayScreen>(find.byType(DayScreen)).date, at(16, 0));

    app.router.go(Routes.calendar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('태블릿 가로 폭에서도 넘치지 않는다', (tester) async {
    final app = await openWeek(tester, size: tabletLandscape, textScale: 2.0);
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
