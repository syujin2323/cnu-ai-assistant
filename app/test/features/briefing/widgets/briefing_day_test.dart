// 01 아침 브리핑의 작은 시간표 테스트. docs/screens.md '01 아침 브리핑'.
//
// 논리적 하루는 2026-11-18(수)이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/features/briefing/widgets/briefing_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final day = DateTime(2026, 11, 18);

Future<void> pump(
  WidgetTester tester, {
  required DateTime now,
  List<BriefingDayTask> tasks = const [],
  int windowEndMin = 1380,
}) => tester.pumpWidget(
  MotionScope(
    level: MotionLevel.off,
    child: MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BriefingDay(
            day: day,
            now: now,
            items: const [],
            tasks: tasks,
            windowEndMin: windowEndMin,
            courseNames: const {},
            semanticsLabel: '오늘 일정',
          ),
        ),
      ),
    ),
  ),
);

/// 시간표의 높이.
double height(WidgetTester tester) =>
    tester.getSize(find.byType(BriefingDay)).height;

void main() {
  testWidgets('저녁에는 남은 일정이 없어도 23시까지 그린다', (tester) async {
    await pump(tester, now: DateTime(2026, 11, 18, 21, 30));

    expect(tester.takeException(), isNull);
    expect(find.text('21:30'), findsOneWidget);
    // 21시부터 23시까지 두 시간 + 아래 여백.
    expect(height(tester), 2 * BriefingDay.hourHeight + 8);
  });

  testWidgets('자정이 지나 하루 경계 전이면 지금 시각부터 한 시간을 그리고 넘치지 않는다', (tester) async {
    // 논리적 하루(11/18) 0시부터 1445분. 남은 일정이 없어 위가 24시가 된다.
    for (final now in [
      DateTime(2026, 11, 19, 0, 5),
      DateTime(2026, 11, 19, 3, 50),
    ]) {
      await pump(tester, now: now);

      expect(tester.takeException(), isNull, reason: '$now');
      expect(height(tester), BriefingDay.hourHeight + 8, reason: '$now');
      expect(
        find.text(
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}',
        ),
        findsOneWidget,
        reason: '$now',
      );
    }
  });

  testWidgets('자정 뒤에도 남은 할 일이 있으면 그 시각부터 그린다', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 11, 19, 0, 30),
      windowEndMin: 1500,
      tasks: [
        BriefingDayTask(
          title: '밤 과제',
          span: TimeSpan(
            DateTime(2026, 11, 19, 0, 40),
            DateTime(2026, 11, 19, 1, 10),
          ),
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('밤 과제'), findsOneWidget);
    expect(height(tester), BriefingDay.hourHeight + 8);
  });
}
