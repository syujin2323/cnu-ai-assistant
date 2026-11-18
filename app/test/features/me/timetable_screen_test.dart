// 13 시간표·고정 일정 화면 테스트. docs/screens.md '13 시간표·고정 일정'. 과목·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/features/me/timetable_controller.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show tabletLandscape;
import '../../helpers/sheet_harness.dart';

/// 이번 학기 LMS 과목 하나의 불러온 수업(월·수 09:00–10:15, 합성관101).
Future<void> _seedClasses(AppDatabase db) async {
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

Future<void> _seedGym(AppDatabase db) => db
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

/// 보이게 끌어 올린 뒤 누른다. 목록이 게으르게 그려지므로 아직 없으면 먼저 스크롤해 찾는다.
Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('시간표 탭: 격자와 수업 목록을 보이고, 수업을 누르면 수업 시트를 연다', (tester) async {
    final app = await pumpProviderHarness(
      tester,
      const TimetableScreen(),
      seed: _seedClasses,
    );

    expect(find.text('LMS에 로그인하면 이번 학기 시간표를 불러와요'), findsOneWidget);
    expect(find.text('수업 1개'), findsOneWidget);
    expect(find.text('주 2회'), findsOneWidget);
    expect(find.text('월·수 09:00–10:15 · 합성관101'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '수업 추가'), findsOneWidget);

    await _tapIn(tester, find.text('월·수 09:00–10:15 · 합성관101'));
    expect(find.text('수업 고치기'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('새로 고침: 물을 바뀜이 없으면 토스트로 알린다', (tester) async {
    var calls = 0;
    final app = await pumpProviderHarness(
      tester,
      const TimetableScreen(),
      seed: _seedClasses,
      overrides: [
        timetableRefreshProvider.overrideWithValue(() async {
          calls++;
          return const SyncResult(SyncResultKind.normal, changedCount: 2);
        }),
      ],
    );

    await _tapIn(tester, find.text('새로 고침'));
    expect(calls, 1);
    expect(app.toast, '새 수업 2칸을 넣었어요');
    await app.dispose();
  });

  testWidgets('새로 고침: 바뀐 수업은 체크한 것만 반영하고 되돌리기 토스트를 띄운다', (tester) async {
    late ClassSlot monday;
    final app = await pumpProviderHarness(
      tester,
      const TimetableScreen(),
      seed: (db) async {
        await _seedClasses(db);
        monday = await (db.select(
          db.classSlots,
        )..where((t) => t.weekday.equals(1))).getSingle();
      },
      overrides: [
        timetableRefreshProvider.overrideWithValue(() async {
          const tuesday = ImportedClassSlot(
            weekday: 2,
            startMin: 540,
            endMin: 615,
            place: '합성관101',
          );
          return SyncResult(
            SyncResultKind.normal,
            changedCount: 1,
            timetableChanges: [
              TimetableSlotUpdate(
                monday,
                to: tuesday,
                imported: tuesday,
                reasons: const {TimetableUpdateReason.schoolTime},
              ),
            ],
          );
        }),
      ],
    );

    await _tapIn(tester, find.text('새로 고침'));
    expect(find.text('바뀐 수업이 1개 있어요'), findsOneWidget);
    expect(find.text('선형대수 수업 시간이 바뀌었어요'), findsOneWidget);
    expect(find.text('새 수업 1칸은 바로 넣었어요'), findsOneWidget);

    final apply = find.widgetWithText(FilledButton, '반영하기');
    await _tapIn(tester, find.byType(Checkbox));
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await _tapIn(tester, find.byType(Checkbox));
    await _tapIn(tester, apply);

    final moved = await (app.db.select(
      app.db.classSlots,
    )..where((t) => t.id.equals(monday.id))).getSingle();
    expect((moved.weekday, moved.importedWeekday), (2, 2));
    expect(app.toast, '바뀐 수업 1개를 반영했어요');
    await app.dispose();
  });

  testWidgets('새로 고침: 그대로 두기는 아무것도 바꾸지 않는다', (tester) async {
    late ClassSlot monday;
    final app = await pumpProviderHarness(
      tester,
      const TimetableScreen(),
      seed: (db) async {
        await _seedClasses(db);
        monday = await (db.select(
          db.classSlots,
        )..where((t) => t.weekday.equals(1))).getSingle();
      },
      overrides: [
        timetableRefreshProvider.overrideWithValue(
          () async => SyncResult(
            SyncResultKind.normal,
            timetableChanges: [TimetableSlotRemoval(monday)],
          ),
        ),
      ],
    );

    await _tapIn(tester, find.text('새로 고침'));
    expect(find.text('선형대수 수업이 학교 시간표에서 없어졌어요'), findsOneWidget);
    await _tapIn(tester, find.widgetWithText(OutlinedButton, '그대로 두기'));
    expect(
      (await app.db.select(app.db.classSlots).get()).map((r) => r.weekday),
      unorderedEquals([1, 3]),
    );
    expect(app.toast, '지금 시간표를 그대로 둘게요 · 새로 고침하면 다시 알려 드려요');
    await app.dispose();
  });

  testWidgets('고정 일정 탭: 카드를 누르면 고치고, 자주 넣는 일정과 아래 버튼은 새로 넣는다', (tester) async {
    final app = await pumpProviderHarness(
      tester,
      const TimetableScreen(initialTab: TimetableTab.fixed),
      seed: _seedGym,
    );

    expect(find.text('새로 고침'), findsNothing);
    expect(find.text('월·수 18:00–19:30 · 앞뒤 10분'), findsOneWidget);
    await _tapIn(tester, find.text('헬스'));
    expect(find.text('고정 일정 고치기'), findsOneWidget);
    // 시트가 화면을 거의 덮어 바깥을 누를 수 없으므로 뒤로 가기로 닫는다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _tapIn(tester, find.widgetWithText(ChoiceChipButton, '점심'));
    expect(find.text('점심 시간과 겹치는 날은 이 일정이 점심을 대신해요'), findsOneWidget);
    expect(find.text('월·화·수·목·금'), findsOneWidget);
    // 시트가 화면을 거의 덮어 바깥을 누를 수 없으므로 뒤로 가기로 닫는다.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await _tapIn(tester, find.widgetWithText(FilledButton, '고정 일정 추가'));
    expect(find.text('새 고정 일정'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('탭을 바꾸면 내용과 아래 버튼이 바뀐다', (tester) async {
    final app = await pumpProviderHarness(tester, const TimetableScreen());

    expect(find.text('아직 수업이 없어요'), findsOneWidget);
    await tester.tap(find.text('고정 일정'));
    await tester.pumpAndSettle();
    expect(find.text('고정 일정이 없어요'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '고정 일정 추가'), findsOneWidget);
    await app.dispose();
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    for (final tab in TimetableTab.values) {
      testWidgets('크기 $size, 글자 배율 $textScale, ${tab.name} 탭에서 넘치지 않는다', (
        tester,
      ) async {
        final app = await pumpProviderHarness(
          tester,
          TimetableScreen(initialTab: tab),
          seed: (db) async {
            await _seedClasses(db);
            await _seedGym(db);
          },
          textScale: textScale,
          size: size,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await app.dispose();
      });
    }
  }
}
