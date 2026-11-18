// 수업 시트 테스트. docs/screens.md '13 시간표·고정 일정'의 수업 시트, '14 온보딩' 2단계. 과목·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/class_slot_repository.dart';
import 'package:cnu_ai_assistant/design/widgets/class_slot_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show tabletLandscape;
import '../../helpers/sheet_harness.dart';

/// 이번 학기 LMS 과목 하나와 그 과목의 불러온 수업(월·수 09:00–10:15, 합성관101).
Future<void> _seedImported(AppDatabase db) async {
  final course = await db
      .into(db.courses)
      .insert(
        CoursesCompanion.insert(
          name: '선형대수',
          remoteId: const Value('c1'),
          semester: const Value('2026-2'),
        ),
      );
  for (final weekday in [1, 3]) {
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: course,
            weekday: weekday,
            startMin: 540,
            endMin: 615,
            place: const Value('합성관101'),
            online: false,
            source: SlotSource.auto,
            importedWeekday: Value(weekday),
            importedStartMin: const Value(540),
            importedEndMin: const Value(615),
            importedPlace: const Value('합성관101'),
          ),
        );
  }
}

Future<ClassGroup> _onlyGroup(AppDatabase db) async {
  final entries = switch (await ClassSlotRepository(db).read()) {
    Ok(:final value) => value,
    Err(:final error) => fail('$error'),
  };
  return groupClassSlots(entries).single;
}

Future<List<ClassSlot>> _rows(AppDatabase db) => (db.select(
  db.classSlots,
)..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

Finder _day(String label) =>
    find.descendant(of: find.byType(WeekdayPicker), matching: find.text(label));

/// 시트 안에서 보이게 끌어 올린 뒤 누른다.
Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('새 수업: 과목 칩과 요일을 고르면 넣고 되돌리기 토스트를 띄운 뒤 닫는다', (tester) async {
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(context, ref),
      seed: (db) => db
          .into(db.courses)
          .insert(
            CoursesCompanion.insert(
              name: '자료구조',
              remoteId: const Value('c2'),
              semester: const Value('2026-2'),
            ),
          ),
    );
    await app.open();

    expect(find.text('수업 추가'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, '수업 넣기');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await _tapIn(tester, find.text('자료구조'));
    await _tapIn(tester, _day('화'));
    await _tapIn(tester, _day('목'));
    await tester.pump();
    expect(find.text('화·목'), findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final rows = await _rows(app.db);
    expect(rows.map((r) => (r.weekday, r.startMin, r.endMin, r.source)), [
      (2, 540, 615, SlotSource.manual),
      (4, 540, 615, SlotSource.manual),
    ]);
    expect(app.toast, '자료구조를 넣었어요');
    expect(app.result, isTrue);
    await app.dispose();
  });

  testWidgets('고를 과목이 없으면 직접 입력이고, 그 이름으로 과목을 만든다', (tester) async {
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(context, ref),
    );
    await app.open();

    expect(find.textContaining('LMS에 로그인하면 과목 목록에서 골라요'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '스터디');
    await tester.pump();
    await _tapIn(tester, _day('금'));
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '수업 넣기');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final courses = await app.db.select(app.db.courses).get();
    expect(courses.map((c) => c.name), ['스터디']);
    expect((await _rows(app.db)).single.weekday, 5);
    await app.dispose();
  });

  testWidgets('겹치는 수업은 알리기만 한다', (tester) async {
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(context, ref),
      seed: _seedImported,
    );
    await app.open();

    expect(find.textContaining('수업과 겹쳐요'), findsNothing);
    await _tapIn(tester, _day('수'));
    await tester.pump();
    expect(find.text('수요일 선형대수 수업과 겹쳐요. 막지 않고 알려만 드려요'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('불러온 수업을 고치면 묶음 전체를 바꾸고, 고친 장소 표시를 켠다', (tester) async {
    late ClassGroup group;
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(context, ref, group: group),
      seed: (db) async {
        await _seedImported(db);
        group = await _onlyGroup(db);
      },
    );
    await app.open();

    expect(find.text('수업 고치기'), findsOneWidget);
    expect(find.text('월·수'), findsOneWidget);
    expect(find.textContaining('통합정보시스템에서 불러온 값이에요'), findsOneWidget);
    expect(find.text('캠퍼스'), findsNothing);

    final place = find.widgetWithText(TextField, '합성관101');
    await tester.ensureVisible(place);
    await tester.enterText(place, '합성관202');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final rows = await _rows(app.db);
    expect(rows.map((r) => (r.weekday, r.place, r.placeEdited)), [
      (1, '합성관202', true),
      (3, '합성관202', true),
    ]);
    expect(app.toast, '선형대수를 고쳤어요');
    await app.dispose();
  });

  testWidgets('빼기는 불러온 수업을 숨긴다', (tester) async {
    late ClassGroup group;
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(context, ref, group: group),
      seed: (db) async {
        await _seedImported(db);
        group = await _onlyGroup(db);
      },
    );
    await app.open();

    final remove = find.widgetWithText(OutlinedButton, '빼기');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect((await _rows(app.db)).every((r) => r.hidden), isTrue);
    expect(app.toast, '선형대수를 시간표에서 뺐어요');
    expect(app.result, isTrue);
    await app.dispose();
  });

  testWidgets('14 온보딩 2단계: 실시간 온라인과 장소만 고치고, 바뀐 것이 없으면 저장하지 않는다', (
    tester,
  ) async {
    late ClassGroup group;
    final app = await pumpSheetHarness(
      tester,
      (context, ref) => showClassSlotSheet(
        context,
        ref,
        group: group,
        mode: ClassSheetMode.placeOnly,
      ),
      seed: (db) async {
        await _seedImported(db);
        group = await _onlyGroup(db);
      },
    );
    await app.open();

    expect(find.text('과목'), findsNothing);
    expect(find.byType(WeekdayPicker), findsNothing);
    expect(find.text('월·수 09:00–10:15 · 불러온 시간표'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(app.result, isFalse);
    expect(app.toast, isNull);

    await app.open();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    final rows = await _rows(app.db);
    expect(rows.map((r) => (r.online, r.onlineEdited, r.place)), [
      (true, true, '합성관101'),
      (true, true, '합성관101'),
    ]);
    expect(app.toast, '선형대수를 실시간 온라인으로 표시했어요');
    await app.dispose();
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    testWidgets('크기 $size, 글자 배율 $textScale에서 넘치지 않는다', (tester) async {
      late ClassGroup group;
      final app = await pumpSheetHarness(
        tester,
        (context, ref) => showClassSlotSheet(context, ref, group: group),
        seed: (db) async {
          await _seedImported(db);
          group = await _onlyGroup(db);
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
