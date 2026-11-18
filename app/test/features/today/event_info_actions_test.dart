// 02 홈에서 여는 일정 정보 시트의 동작. docs/screens.md '일정 정보 시트'.
//
// 2026-11-16(월) 11:02이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다. 자료구조 수업
// 13:00–14:00(공학관 1), 일정 '상담' 15:00–15:30, 고정 일정 '알바' 16:30–17:30이 있다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 16, hour, minute);

Future<void> seedDay(AppDatabase db) async {
  final made = DateTime(2026, 11, 1);
  for (final (kind, params) in [
    (RuleKind.workWindow, const RuleParams(startMin: 540, endMin: 1080)),
    (RuleKind.classBuffer, const RuleParams(minutes: 10)),
    (RuleKind.meal, const RuleParams(startMin: 690, endMin: 810, minutes: 0)),
  ]) {
    await db
        .into(db.rules)
        .insert(
          RulesCompanion.insert(
            kind: kind,
            params: params,
            active: true,
            source: EntrySource.manual,
            createdAt: made,
            updatedAt: made,
          ),
        );
  }
  final courseId = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '자료구조'));
  await db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: DateTime.monday,
          startMin: 780,
          endMin: 840,
          place: const Value('공학관 1'),
          online: false,
          source: SlotSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '상담',
          startAt: at(15),
          endAt: at(15, 30),
          allDay: false,
          source: EventSource.manual,
        ),
      );
  await db
      .into(db.fixedBlocks)
      .insert(
        FixedBlocksCompanion.insert(
          name: '알바',
          weekdays: const [DateTime.monday],
          startMin: 990,
          endMin: 1050,
          bufferMin: 0,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
        ),
      );
}

/// 위 하루를 넣은 02 홈을 띄운다.
Future<TestApp> pumpHome(WidgetTester tester, {double textScale = 1}) async {
  final app = await pumpTestApp(tester, now: at(11, 2), textScale: textScale);
  await seedDay(app.db);
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  expect(find.byType(TodayScreen), findsOneWidget);
  return app;
}

/// 시간표의 [title] 카드를 눌러 일정 정보 시트를 연다.
Future<void> openCard(WidgetTester tester, String title) async {
  await scrollTo(tester, find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// 저장된 수업 예외를 '종류 날짜 장소' 꼴로.
Future<List<String>> exceptionsOf(AppDatabase db) async => [
  for (final row in await db.select(db.classExceptions).get())
    '${row.kind.name} ${row.date} ${row.place}',
];

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets(
      '글자 배율 $textScale: 수업을 누르면 그날만 휴강·장소 변경으로 바꾸고, 되돌리거나 원래대로 돌린다',
      (tester) async {
        final app = await pumpHome(tester, textScale: textScale);

        await openCard(tester, '자료구조');
        expect(find.text('11월 16일 (월) · 13:00–14:00 · 공학관 1'), findsOneWidget);
        await tapText(tester, '휴강');
        expect(find.text('오늘 자료구조 수업을 휴강으로 표시했어요'), findsOneWidget);
        expect(await exceptionsOf(app.db), ['cancelled 2026-11-16 null']);

        await tapText(tester, '되돌리기');
        expect(await exceptionsOf(app.db), isEmpty);

        await openCard(tester, '자료구조');
        await tapText(tester, '장소 변경');
        await tester.enterText(find.byType(TextField), '공대 5호관 101');
        await tester.pump();
        await tapText(tester, '저장');
        expect(find.text('오늘 자료구조 수업 장소를 공대 5호관 101로 바꿨어요'), findsOneWidget);
        expect(await exceptionsOf(app.db), [
          'placeChange 2026-11-16 공대 5호관 101',
        ]);

        // 다시 열면 바뀐 장소를 보이고, 바뀐 칩을 다시 누르면 원래대로 돌린다.
        await openCard(tester, '자료구조');
        expect(
          find.text('11월 16일 (월) · 13:00–14:00 · 공대 5호관 101'),
          findsOneWidget,
        );
        await tester.tap(find.text('장소 변경').last);
        await tester.pumpAndSettle();
        expect(find.text('오늘 자료구조 수업을 원래대로 돌렸어요'), findsOneWidget);
        expect(await exceptionsOf(app.db), isEmpty);

        await app.dispose(tester);
      },
    );
  }

  testWidgets('일정을 누르면 [말로 바꾸기]는 06 AI 비서에 문장을 채워 열고, [지우기]는 되돌릴 수 있게 지운다', (
    tester,
  ) async {
    final app = await pumpHome(tester);
    Future<List<String>> titles() async => [
      for (final row in await app.db.select(app.db.events).get()) row.title,
    ];

    await openCard(tester, '상담');
    expect(find.text('개인 일정'), findsOneWidget);
    await tapText(tester, '말로 바꾸기');
    expect(
      tester.widget<AssistantScreen>(find.byType(AssistantScreen)).args,
      const AssistantArgs(prefill: '11월 16일 상담 '),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);

    await openCard(tester, '상담');
    await tapText(tester, '지우기');
    expect(find.text('상담을 지웠어요'), findsOneWidget);
    expect(await titles(), isEmpty);
    await tapText(tester, '되돌리기');
    expect(await titles(), ['상담']);
    await app.dispose(tester);
  });

  testWidgets('고정 일정을 누르면 13 시간표·고정 일정의 고정 일정 탭을 연다', (tester) async {
    final app = await pumpHome(tester);

    await openCard(tester, '알바');
    expect(find.text('고정 일정'), findsOneWidget);
    expect(find.text('매주 반복하는 고정 일정이에요'), findsOneWidget);
    await tapText(tester, '시간표·고정 일정에서 바꾸기');
    expect(
      tester.widget<TimetableScreen>(find.byType(TimetableScreen)).initialTab,
      TimetableTab.fixed,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    await app.dispose(tester);
  });
}
