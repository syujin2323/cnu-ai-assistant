// 온보딩 2단계(불러온 시간표 확인) 테스트. docs/screens.md '14 온보딩'의 2단계. 과목·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/timetable_step.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart' show tabletLandscape;
import '../../../helpers/sheet_harness.dart';

/// 이번 학기 LMS 과목 하나의 불러온 수업(월·수 09:00–10:15, 합성관101).
Future<void> _seed(AppDatabase db) async {
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

void main() {
  testWidgets('불러온 시간표를 격자로 보이고, 수업을 누르면 실시간 온라인·장소만 고치는 시트를 연다', (
    tester,
  ) async {
    var confirmed = 0;
    final app = await pumpProviderHarness(
      tester,
      TimetableStep(onConfirm: () => confirmed++),
      seed: _seed,
    );

    expect(find.text('이번 학기 시간표를 불러왔어요'), findsOneWidget);
    expect(find.text('수업 1개 · 주 2회'), findsOneWidget);
    expect(find.text('통합정보시스템에서 불러옴'), findsOneWidget);
    expect(find.textContaining('선형대수'), findsNWidgets(2));

    await tester.tap(find.textContaining('선형대수').first);
    await tester.pumpAndSettle();
    expect(find.text('월·수 09:00–10:15 · 불러온 시간표'), findsOneWidget);
    expect(find.text('과목'), findsNothing);
    // 녹화 강의로 표시하면 격자에서 빠지고 아래 줄로 남는다.
    final recorded = find.descendant(
      of: find.widgetWithText(FormSwitchRow, '녹화 강의'),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(recorded);
    await tester.pumpAndSettle();
    await tester.tap(recorded);
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('수업 1개 · 주 0회'), findsOneWidget);
    expect(find.bySemanticsLabel('선형대수, 녹화 강의'), findsOneWidget);
    expect(find.text('아직 수업이 없어요'), findsNothing);

    // 아래 버튼은 내용이 길면 스크롤해야 만들어진다.
    await tester.dragUntilVisible(
      find.text('맞아요'),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞아요'));
    expect(confirmed, 1);
    await app.dispose();
  });

  testWidgets('불러온 수업이 없으면 빈 격자와 나중에 넣는 곳을 알린다', (tester) async {
    final app = await pumpProviderHarness(
      tester,
      TimetableStep(onConfirm: () {}),
    );

    expect(find.text('불러온 수업이 없어요'), findsOneWidget);
    expect(find.text('아직 수업이 없어요'), findsOneWidget);
    expect(find.textContaining('수업 0개'), findsNothing);
    await app.dispose();
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    testWidgets('크기 $size, 글자 배율 $textScale에서 넘치지 않는다', (tester) async {
      final app = await pumpProviderHarness(
        tester,
        TimetableStep(onConfirm: () {}),
        seed: _seed,
        textScale: textScale,
        size: size,
      );
      expect(tester.takeException(), isNull);
      await app.dispose();
    });
  }
}
