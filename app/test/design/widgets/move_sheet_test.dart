// 옮기기 시트. docs/screens.md '옮기기 시트'. 시트는 고른 후보만 돌려주고, 옮기기는 부르는 쪽이 한다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/sheet_harness.dart';

MoveChoice choice(int hour, String why) {
  final start = DateTime(2026, 11, 16, hour);
  return MoveChoice(
    option: SlotOption(
      span: TimeSpan(start, start.add(const Duration(hours: 1))),
      gapMin: 120,
      factor: BlockFactor.unsplit,
    ),
    when: '오늘 $hour:00–${hour + 1}:00',
    why: why,
    cta: '$hour:00으로 옮기기',
  );
}

final content = MoveSheetContent(
  sub: '자료구조 과제 · 1시간 · 내일 23:59 마감',
  choices: [choice(14, '2시간 비어 있어 한 번에 끝낼 수 있어요'), choice(16, '평소 집중하는 시간이에요')],
  noneText: '마감 전에 옮길 수 있는 빈 시간이 없어요',
);

const none = MoveSheetContent(
  sub: '자료구조 과제 · 1시간 · 내일 23:59 마감',
  choices: [],
  noneText: '마감 전에 옮길 수 있는 빈 시간이 없어요',
);

Future<SheetHarness> pumpSheet(
  WidgetTester tester,
  MoveSheetContent content, {
  double textScale = 1,
}) async {
  final harness = await pumpSheetHarness(
    tester,
    (context, ref) => showMoveSheet(context, MotionLevel.off, content),
    textScale: textScale,
  );
  await harness.open();
  return harness;
}

void main() {
  testWidgets('후보를 보이고 처음에는 첫 후보를 골라 그 버튼으로 옮긴다', (tester) async {
    final harness = await pumpSheet(tester, content);
    expect(find.text('어디로 옮길까요?'), findsOneWidget);
    expect(find.text('자료구조 과제 · 1시간 · 내일 23:59 마감'), findsOneWidget);
    expect(find.text('오늘 14:00–15:00'), findsOneWidget);
    expect(find.text('평소 집중하는 시간이에요'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^오늘 14:00'))),
      isSemantics(
        label: '오늘 14:00–15:00, 2시간 비어 있어 한 번에 끝낼 수 있어요',
        isInMutuallyExclusiveGroup: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '14:00으로 옮기기'));
    await tester.pumpAndSettle();
    expect(find.text('어디로 옮길까요?'), findsNothing);
    expect((harness.result as MoveChoice?)?.when, '오늘 14:00–15:00');

    await harness.dispose();
  });

  testWidgets('다른 후보를 누르면 버튼이 바뀌고 그 후보를 돌려준다', (tester) async {
    final harness = await pumpSheet(tester, content);

    await tester.tap(find.text('평소 집중하는 시간이에요'));
    await tester.pumpAndSettle();
    expect(find.text('14:00으로 옮기기'), findsNothing);
    expect(find.text('어디로 옮길까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '16:00으로 옮기기'));
    await tester.pumpAndSettle();
    expect((harness.result as MoveChoice?)?.when, '오늘 16:00–17:00');

    await harness.dispose();
  });

  testWidgets('그냥 닫으면 옮기지 않는다', (tester) async {
    final harness = await pumpSheet(tester, content);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('어디로 옮길까요?'), findsNothing);
    expect(harness.result, isNull);

    await harness.dispose();
  });

  testWidgets('후보가 없으면 안내와 닫기만 보인다', (tester) async {
    final harness = await pumpSheet(tester, none);
    expect(find.text('마감 전에 옮길 수 있는 빈 시간이 없어요'), findsOneWidget);
    expect(find.byType(Radio<int>), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '닫기'));
    await tester.pumpAndSettle();
    expect(find.text('어디로 옮길까요?'), findsNothing);
    expect(harness.result, isNull);

    await harness.dispose();
  });

  testWidgets('글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    for (final value in [content, none]) {
      final harness = await pumpSheet(tester, value, textScale: 2);
      expect(find.text('어디로 옮길까요?'), findsOneWidget);
      await harness.dispose();
    }
  });
}
