// 고정 일정 폼·시트 테스트. docs/screens.md '13 시간표·고정 일정'의 고정 일정 시트, '14 온보딩' 3단계의 작은 폼.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/fixed_block_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show tabletLandscape;
import '../../helpers/sheet_harness.dart';

Finder _day(String label) =>
    find.descendant(of: find.byType(WeekdayPicker), matching: find.text(label));

/// 시트 안에서 보이게 끌어 올린 뒤 누른다.
Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<int> _seedGym(AppDatabase db) => db
    .into(db.fixedBlocks)
    .insert(
      FixedBlocksCompanion.insert(
        name: '헬스',
        weekdays: [1, 3],
        startMin: 1080,
        endMin: 1170,
        bufferMin: 10,
        kind: FixedBlockKind.exercise,
        source: EntrySource.manual,
      ),
    );

Future<FixedBlock> _gym(AppDatabase db) =>
    db.select(db.fixedBlocks).getSingle();

void main() {
  testWidgets('자주 넣는 일정(점심)의 처음 값으로 넣고 되돌리기 토스트를 띄운다', (tester) async {
    final app = await pumpSheetHarness(
      tester,
      (context, ref) =>
          showFixedBlockSheet(context, ref, template: FixedBlockKind.meal),
    );
    await app.open();

    expect(find.text('고정 일정 추가'), findsOneWidget);
    expect(find.text('월·화·수·목·금'), findsOneWidget);
    expect(find.text('점심 시간과 겹치는 날은 이 일정이 점심을 대신해요'), findsOneWidget);
    await _tapIn(tester, find.widgetWithText(FilledButton, '고정 일정 넣기'));
    await tester.pumpAndSettle();

    final row = await app.db.select(app.db.fixedBlocks).getSingle();
    expect(
      (row.name, row.kind, row.startMin, row.endMin, row.bufferMin),
      ('점심', FixedBlockKind.meal, 720, 780, 0),
    );
    expect(row.weekdays, [1, 2, 3, 4, 5]);
    expect(row.source, EntrySource.manual);
    expect(app.toast, '점심을 넣었어요');
    expect(app.result, isTrue);
    await app.dispose();
  });

  testWidgets('기타는 이름과 요일을 넣어야 저장할 수 있고, 수업과 겹치면 알리기만 한다', (tester) async {
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showFixedBlockSheet(context, ref),
      seed: (db) async {
        final course = await db
            .into(db.courses)
            .insert(CoursesCompanion.insert(name: '과목A'));
        await db
            .into(db.classSlots)
            .insert(
              ClassSlotsCompanion.insert(
                courseId: course,
                weekday: 2,
                startMin: 1050,
                endMin: 1110,
                online: false,
                source: SlotSource.manual,
              ),
            );
      },
    );
    await app.open();

    final save = find.widgetWithText(FilledButton, '고정 일정 넣기');
    FilledButton button() => tester.widget<FilledButton>(save);
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '동아리 연습');
    await tester.pump();
    expect(button().onPressed, isNull);
    await _tapIn(tester, _day('화'));
    expect(button().onPressed, isNotNull);
    expect(find.text('화요일 수업과 겹쳐요. 막지 않고 알려만 드려요'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('운동을 고르면 비어 있는 준비물에 운동복을 넣고, 앞뒤 여유는 5분씩 바꾼다', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showFixedBlockSheet(context, ref),
    );
    await app.open();

    await _tapIn(tester, find.text('운동'));
    expect(find.widgetWithText(TextField, '운동복'), findsOneWidget);
    await _tapIn(tester, find.bySemanticsLabel('앞뒤 여유 5분 늘리기'));
    expect(find.text('5분'), findsOneWidget);
    handle.dispose();
    await app.dispose();
  });

  testWidgets('고치면 값을 바꾸고, 지우기는 지운다', (tester) async {
    late FixedBlock gym;
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showFixedBlockSheet(context, ref, block: gym),
      seed: (db) async {
        await _seedGym(db);
        gym = await _gym(db);
      },
    );
    await app.open();

    expect(find.text('고정 일정 고치기'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '헬스'), '수영');
    await tester.pump();
    await _tapIn(tester, find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    final changed = await _gym(app.db);
    expect(
      (changed.name, changed.startMin, changed.bufferMin),
      ('수영', 1080, 10),
    );
    expect(app.toast, '수영을 고쳤어요');

    gym = changed;
    await app.open();
    await _tapIn(tester, find.widgetWithText(OutlinedButton, '지우기'));
    await tester.pumpAndSettle();
    expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);
    expect(app.toast, '수영을 지웠어요');
    await app.dispose();
  });

  testWidgets('14 온보딩의 작은 폼은 종류·앞뒤 여유·준비물 없이 이름·요일·시간이고 바뀌면 알린다', (
    tester,
  ) async {
    FixedBlockDraft? last;
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showAppSheet<void>(
        context: context,
        motion: MotionLevel.off,
        builder: (context) => SingleChildScrollView(
          child: FixedBlockForm(
            initial: fixedBlockTemplate(FixedBlockKind.work),
            mode: FixedBlockFormMode.quick,
            onChanged: (draft) => last = draft,
          ),
        ),
      ),
    );
    await app.open();

    for (final label in ['이름', '요일', '시간']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('준비물'), findsNothing);
    expect(find.text('종류'), findsNothing);
    expect(find.text('앞뒤 여유'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '알바'), '편의점 알바');
    await tester.pump();
    expect(
      (last?.name, last?.kind, last?.bufferMin),
      ('편의점 알바', FixedBlockKind.work, 20),
    );
    await app.dispose();
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    testWidgets('크기 $size, 글자 배율 $textScale에서 넘치지 않는다', (tester) async {
      late FixedBlock gym;
      final app = await pumpSheetHarness(
        tester,
        (context, ref) => showFixedBlockSheet(context, ref, block: gym),
        seed: (db) async {
          await _seedGym(db);
          gym = await _gym(db);
        },
        textScale: textScale,
        size: size,
      );
      await app.open();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await app.dispose();
    });
  }
}
