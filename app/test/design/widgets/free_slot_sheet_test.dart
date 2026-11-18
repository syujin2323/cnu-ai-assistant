// 빈 시간에 놓기 시트. docs/screens.md '빈 시간에 놓기 시트'. 시트는 고른 것만 돌려주고, 놓기와 06 AI 비서
// 열기는 부르는 쪽이 한다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/free_slot_sheet.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sheet_harness.dart';

final gap = TimeSpan(
  DateTime(2026, 11, 16, 15),
  DateTime(2026, 11, 16, 16, 30),
);

FreeSlotChoice choice(int id, String title, String sub, int minutes) =>
    FreeSlotChoice(
      entry: TaskEntry(
        task: Task(
          id: id,
          title: title,
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      ),
      sub: sub,
      minutes: minutes,
    );

final content = FreeSlotContent(
  span: gap,
  title: '15:00–16:30 · 1시간 30분 비어 있어요',
  choices: [
    choice(1, '자료구조 과제', '과제 · 내일 23:59 마감', 60),
    choice(2, '아주 긴 이름의 운영체제 프로젝트 중간 보고서 초안 쓰기', '팀플 · 금요일 18:00 마감', 90),
  ],
);

final empty = FreeSlotContent(
  span: gap,
  title: '15:00–16:30 · 1시간 30분 비어 있어요',
  choices: const [],
);

Future<SheetHarness> pumpSheet(
  WidgetTester tester,
  FreeSlotContent content, {
  double textScale = 1,
}) async {
  final harness = await pumpSheetHarness(
    tester,
    (context, ref) => showFreeSlotSheet(context, MotionLevel.off, content),
    textScale: textScale,
  );
  await harness.open();
  return harness;
}

void main() {
  testWidgets('빈 시간과 놓을 할 일을 보이고, 고른 할 일을 돌려준다', (tester) async {
    final harness = await pumpSheet(tester, content);
    expect(find.text('15:00–16:30 · 1시간 30분 비어 있어요'), findsOneWidget);
    expect(find.text('무엇을 놓을까요? 직접 놓은 시간은 확정으로 저장해요'), findsOneWidget);
    expect(find.text('과제 · 내일 23:59 마감'), findsOneWidget);
    expect(find.text('1시간'), findsOneWidget);
    expect(find.text('1시간 30분'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('^자료구조 과제'))),
      isSemantics(
        label: '자료구조 과제, 과제 · 내일 23:59 마감, 1시간 놓기',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('자료구조 과제'));
    await tester.pumpAndSettle();
    expect(find.text('무엇을 놓을까요? 직접 놓은 시간은 확정으로 저장해요'), findsNothing);
    final pick = harness.result as FreeSlotPlace?;
    expect(pick?.choice.taskId, 1);
    expect(pick?.choice.minutes, 60);

    await harness.dispose();
  });

  testWidgets('일정은 말로 추가하기를 고를 수 있다', (tester) async {
    final harness = await pumpSheet(tester, content);

    await tester.tap(find.text('일정은 말로 추가하기'));
    await tester.pumpAndSettle();
    expect(harness.result, isA<FreeSlotSpeak>());

    await harness.dispose();
  });

  testWidgets('놓을 할 일이 없으면 안내와 말로 추가하기만 보인다', (tester) async {
    final harness = await pumpSheet(tester, empty);
    expect(find.text('이 시간에 놓을 남은 할 일이 없어요'), findsOneWidget);
    expect(find.text('일정은 말로 추가하기'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(harness.result, isNull);

    await harness.dispose();
  });

  testWidgets('글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    for (final value in [content, empty]) {
      final harness = await pumpSheet(tester, value, textScale: 2);
      expect(find.text('일정은 말로 추가하기'), findsOneWidget);
      await harness.dispose();
    }
  });
}
