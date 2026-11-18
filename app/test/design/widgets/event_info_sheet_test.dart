// 일정 정보 시트. docs/screens.md '일정 정보 시트'. 시트는 고른 동작만 돌려주고, 동작은 부르는 쪽이 한다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/event_info_sheet.dart';
import 'package:cnu_ai_assistant/domain/event_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/sheet_harness.dart';

final day = DateTime(2026, 11, 16);

EventInfoContent lesson({ClassDayChange? change, String? lockText}) =>
    EventInfoContent(
      kind: EventInfoKind.classItem,
      kicker: change?.label ?? '수업',
      title: '자료구조',
      time: '11월 16일 (월) · 13:00–14:15 · 공학관 1',
      dayWord: '오늘',
      date: day,
      change: change,
      changeLabel: lockText == null ? '오늘 수업만 바꾸기' : null,
      lockText: lockText,
    );

final event = EventInfoContent(
  kind: EventInfoKind.event,
  kicker: '개인 일정',
  title: '상담',
  time: '11월 16일 (월) · 15:00–15:30 · 학생회관',
  dayWord: '오늘',
  date: day,
);

final fixed = EventInfoContent(
  kind: EventInfoKind.fixed,
  kicker: '고정 일정',
  title: '알바',
  time: '11월 16일 (월) · 18:00–22:00 · 카페',
  dayWord: '오늘',
  date: day,
);

Future<SheetHarness> pumpSheet(
  WidgetTester tester,
  EventInfoContent content, {
  double textScale = 1,
}) async {
  final harness = await pumpSheetHarness(
    tester,
    (context, ref) => showEventInfoSheet(context, MotionLevel.off, content),
    textScale: textScale,
  );
  await harness.open();
  return harness;
}

/// 시트가 돌려준 수업 바꿈을 '바꿈 장소' 꼴로.
String changeOf(Object? result) => switch (result) {
  ChangeClassDay(:final change, :final place) => '${change?.name} $place',
  _ => '$result',
};

void main() {
  testWidgets('수업은 머리와 그날만 바꾸는 칩을 보이고, 고른 바꿈을 돌려준다', (tester) async {
    final harness = await pumpSheet(tester, lesson());
    expect(find.text('수업'), findsOneWidget);
    expect(find.text('자료구조'), findsOneWidget);
    expect(find.text('11월 16일 (월) · 13:00–14:15 · 공학관 1'), findsOneWidget);
    expect(find.text('오늘 수업만 바꾸기'), findsOneWidget);
    expect(
      find.text('그날만 바뀌고 시간표는 그대로예요. 빈 시간이 바뀌면 할 일을 다시 놓아요'),
      findsOneWidget,
    );
    expect(find.text('말로 바꾸기'), findsNothing);

    await tester.tap(find.text('휴강'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 수업만 바꾸기'), findsNothing);
    expect(changeOf(harness.result), 'cancelled null');

    await harness.open();
    await tester.tap(find.text('시험'));
    await tester.pumpAndSettle();
    expect(changeOf(harness.result), 'exam null');
    await harness.dispose();
  });

  testWidgets('지금 바뀐 칩을 다시 누르면 원래대로 돌린다', (tester) async {
    final harness = await pumpSheet(
      tester,
      lesson(change: ClassDayChange.exam),
    );
    expect(find.text('시험'), findsNWidgets(2)); // 머리 띠와 칩.
    await tester.tap(find.text('시험').last);
    await tester.pumpAndSettle();
    expect(changeOf(harness.result), 'null null');
    await harness.dispose();

    // 장소 변경도 다시 누르면 원래대로다(칸을 열지 않음).
    final moved = await pumpSheet(
      tester,
      lesson(change: ClassDayChange.placeChange),
    );
    await tester.tap(find.text('장소 변경').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(changeOf(moved.result), 'null null');
    await moved.dispose();
  });

  testWidgets('장소 변경은 바뀐 장소 칸을 열고, 쓴 장소가 있어야 저장한다', (tester) async {
    final harness = await pumpSheet(tester, lesson());
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

    await tester.tap(find.text('장소 변경'));
    await tester.pumpAndSettle();
    expect(find.text('바뀐 장소 (예: 공대 5호관 101)'), findsOneWidget);
    expect(save().onPressed, isNull);
    // 다시 누르면 칸을 닫는다.
    await tester.tap(find.text('장소 변경'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(harness.result, isNull);

    await tester.tap(find.text('장소 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField), ' 공대 5호관 101 ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(changeOf(harness.result), 'placeChange 공대 5호관 101');
    await harness.dispose();
  });

  testWidgets('바꿀 수 없는 수업은 안내만 보인다', (tester) async {
    final harness = await pumpSheet(
      tester,
      lesson(lockText: '지난 수업은 바꿀 수 없어요'),
    );
    expect(find.text('지난 수업은 바꿀 수 없어요'), findsOneWidget);
    expect(find.text('휴강'), findsNothing);
    expect(find.text('오늘 수업만 바꾸기'), findsNothing);
    await harness.dispose();
  });

  testWidgets('일정은 [말로 바꾸기]와 [지우기]를 두고, 고른 동작을 돌려준다', (tester) async {
    final harness = await pumpSheet(tester, event);
    expect(find.text('개인 일정'), findsOneWidget);
    expect(find.text('11월 16일 (월) · 15:00–15:30 · 학생회관'), findsOneWidget);
    expect(find.text('휴강'), findsNothing);

    await tester.tap(find.text('말로 바꾸기'));
    await tester.pumpAndSettle();
    expect(harness.result, isA<EditEventBySpeech>());

    await harness.open();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(harness.result, isA<DeleteEvent>());
    await harness.dispose();
  });

  testWidgets('고정 일정은 매주 반복한다고 알리고 13 시간표·고정 일정으로 보낸다', (tester) async {
    final harness = await pumpSheet(tester, fixed);
    expect(find.text('매주 반복하는 고정 일정이에요'), findsOneWidget);
    expect(find.text('말로 바꾸기'), findsNothing);
    await tester.tap(find.text('시간표·고정 일정에서 바꾸기'));
    await tester.pumpAndSettle();
    expect(harness.result, isA<OpenFixedBlocks>());
    await harness.dispose();
  });

  testWidgets('그냥 닫으면 아무 동작도 돌려주지 않는다', (tester) async {
    final harness = await pumpSheet(tester, lesson());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('오늘 수업만 바꾸기'), findsNothing);
    expect(harness.result, isNull);
    await harness.dispose();
  });

  testWidgets('글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    for (final content in [
      lesson(),
      lesson(lockText: '보강 수업이에요. 시간표에는 넣지 않았어요'),
      event,
      fixed,
    ]) {
      final harness = await pumpSheet(tester, content, textScale: 2);
      if (content.canChange) {
        await tester.tap(find.text('장소 변경'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
      }
      await harness.dispose();
    }
  });
}
