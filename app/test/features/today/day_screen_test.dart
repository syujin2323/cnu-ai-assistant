// 09 일간 화면 테스트. docs/screens.md '09 일간'.
//
// 2026-11-16(월) 11:02이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다. 월요일 자료구조 수업
// 13:00–14:00, 오늘 일정 '상담' 15:00–15:30, 수요일 종일 일정 '학회'가 있다. 할 일은 '과제 1'(오늘 23:59 마감,
// 확정 블록 16:00–17:00)과 '과제 2'(목요일 18:00 마감, 엔진이 제안을 놓음)다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/free_slot_sheet.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/task_sheet.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

Future<void> seed(AppDatabase db) async {
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
  final course = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '자료구조'));
  await db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: course,
          weekday: DateTime.monday,
          startMin: 780,
          endMin: 840,
          online: false,
          source: SlotSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '상담',
          startAt: at(16, 15),
          endAt: at(16, 15, 30),
          allDay: false,
          source: EventSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '학회',
          startAt: at(18, 0),
          endAt: at(19, 0),
          allDay: true,
          source: EventSource.manual,
        ),
      );
  final first = await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제 1',
          kind: TaskKind.assignment,
          dueAt: Value(at(16, 23, 59)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
  await db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: first,
          startAt: at(16, 16),
          endAt: at(16, 17),
          status: PlanBlockStatus.confirmed,
          source: BlockSource.manual,
        ),
      );
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제 2',
          kind: TaskKind.assignment,
          dueAt: Value(at(19, 18)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
}

/// [day]의 09 일간을 연다.
Future<TestApp> openDay(
  WidgetTester tester,
  DateTime day, {
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
  app.router.go(Routes.day(day));
  await tester.pumpAndSettle();
  return app;
}

DateTime shown(WidgetTester tester) =>
    tester.widget<DayScreen>(find.byType(DayScreen)).date;

/// 저장된 블록.
Future<List<PlanBlock>> blocks(AppDatabase db) =>
    db.select(db.planBlocks).get();

void main() {
  testWidgets('위 막대·날짜 줄·머리와 마감 줄을 보이고, 마감 줄은 작은 할 일 시트를 연다', (tester) async {
    final app = await openDay(tester, DateTime(2026, 11, 16));

    expect(find.text('11월 16일 – 22일'), findsOneWidget);
    // 오늘을 보고 있으면 '오늘' 알약이 없다.
    expect(find.bySemanticsLabel('오늘로 가기'), findsNothing);
    expect(find.text('11월 16일 (월)'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^오늘 · 수업 1개 · 할 일 \d+개 · 일정 1개')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^11월 16일 \(월\), 오늘$')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel(RegExp('^23:59 마감, 과제 1')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskSheet), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('날짜 줄·‹ ›·오늘 알약·옆으로 밀기로 날을 바꿔 끼운다', (tester) async {
    final app = await openDay(tester, DateTime(2026, 11, 16));

    await tester.tap(find.bySemanticsLabel(RegExp('^11월 18일 ')));
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 18));
    expect(app.router.state.uri.path, Routes.day(DateTime(2026, 11, 18)));
    // 다른 날이면 주 범위 옆에 작은 '오늘' 알약이 생긴다(같은 줄, 글자 너비).
    final pill = tester.getRect(find.bySemanticsLabel('오늘로 가기'));
    final label = tester.getRect(find.text('11월 16일 – 22일'));
    expect(pill.width, lessThan(100));
    expect(pill.left, greaterThan(label.right - 1));

    await tester.tap(find.byTooltip('다음 주 같은 요일 보기'));
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 25));
    expect(find.text('11월 23일 – 29일'), findsOneWidget);

    await tester.tap(find.byTooltip('지난주 같은 요일 보기'));
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 18));

    // 왼쪽으로 밀면 다음 날, 오른쪽으로 밀면 전날이다.
    await tester.fling(find.text('11월 18일 (수)'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 19));
    await tester.fling(find.text('11월 19일 (목)'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 18));

    await tester.tap(find.bySemanticsLabel('오늘로 가기'));
    await tester.pumpAndSettle();
    expect(shown(tester), DateTime(2026, 11, 16));

    // 날을 바꿔 끼웠으므로 뒤로 가면 지난 날을 거치지 않고 02 홈이다.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(DayScreen), findsNothing);
    expect(app.router.state.uri.path, Routes.today);

    await app.dispose(tester);
  });

  testWidgets('제안이 있는 날은 모두 확정 띠를 두고, 누르면 확정한 뒤 되돌린다', (tester) async {
    final app = await openDay(tester, DateTime(2026, 11, 16));
    // '과제 2'의 제안이 놓인 날을 연다.
    final first = (await blocks(app.db))
        .firstWhere((block) => block.status == PlanBlockStatus.suggested);
    final day = DateTime(
      first.startAt.year,
      first.startAt.month,
      first.startAt.day,
    );
    final suggested = [
      for (final block in await blocks(app.db))
        if (block.status == PlanBlockStatus.suggested &&
            block.startAt.day == day.day &&
            block.endAt.isAfter(at(16, 11, 2)))
          block,
    ];
    app.router.go(Routes.day(day));
    await tester.pumpAndSettle();
    expect(find.text('제안 ${suggested.length}개가 확정 전이에요'), findsOneWidget);
    expect(find.textContaining('제안'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '모두 확정'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${day.day == 16 ? '오늘' : '내일'} 제안 ${suggested.length}개를 확정했어요',
      ),
      findsOneWidget,
    );
    final confirmed = {
      for (final block in await blocks(app.db)) block.id: block.status,
    };
    for (final block in suggested) {
      expect(confirmed[block.id], PlanBlockStatus.confirmed);
    }
    expect(find.widgetWithText(FilledButton, '모두 확정'), findsNothing);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    final undone = {
      for (final block in await blocks(app.db)) block.id: block.status,
    };
    for (final block in suggested) {
      expect(undone[block.id], PlanBlockStatus.suggested);
    }

    await app.dispose(tester);
  });

  testWidgets('공휴일은 날짜 줄에서 붉게 쓰고, 그날을 보면 머리 아래 공휴일 카드를 둔다', (tester) async {
    // 2026-12-25(금)은 성탄절이다. 그 전날을 열면 날짜 줄에만 보인다.
    final app = await openDay(tester, DateTime(2026, 12, 24));
    final colors = AppColors.light;
    Color? dateColor(String day) =>
        tester.widget<Text>(find.text(day)).style?.color;

    expect(find.bySemanticsLabel('12월 25일 (금), 성탄절'), findsOneWidget);
    expect(dateColor('25'), colors.alert);
    expect(dateColor('23'), colors.ink);
    expect(dateColor('27'), colors.alert, reason: '일요일');
    expect(find.bySemanticsLabel(RegExp('^성탄절, ')), findsNothing);

    await tester.tap(find.bySemanticsLabel('12월 25일 (금), 성탄절'));
    await tester.pumpAndSettle();
    expect(find.text('12월 25일 (금)'), findsOneWidget);
    expect(find.bySemanticsLabel('성탄절, 공휴일'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('종일 일정은 위에 따로 두고 누르면 일정 정보 시트를 연다', (tester) async {
    final app = await openDay(tester, DateTime(2026, 11, 18));

    expect(find.text('학회'), findsOneWidget);
    expect(find.text('하루 종일'), findsOneWidget);
    // 수업이 없어도 종일 일정이 있으면 빈 날 카드를 두지 않는다.
    expect(find.text('수업·일정이 없는 날이에요'), findsNothing);
    await tester.tap(find.bySemanticsLabel('학회, 종일 일정, 정보 보기'));
    await tester.pumpAndSettle();
    expect(find.text('종일'), findsWidgets);
    expect(find.text('말로 바꾸기'), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('수업·일정이 없는 날은 빈 날 카드를 두고, 빈 시간을 누르면 빈 시간에 놓기 시트를 연다', (
    tester,
  ) async {
    final app = await openDay(tester, DateTime(2026, 11, 21));

    expect(find.text('수업·일정이 없는 날이에요'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'빈 시간, 할 일 놓기$')).first);
    await tester.pumpAndSettle();
    expect(find.byType(FreeSlotSheet), findsOneWidget);

    await app.dispose(tester);
  });

  testWidgets('빈 시간 카드 아래 정시마다 놓기 칸을 두고, 시트의 말로 추가하기는 06에 날짜·시각을 넘긴다', (
    tester,
  ) async {
    final app = await openDay(tester, DateTime(2026, 11, 21));

    // 토요일은 09:00–18:00이 모두 비어 있다. 카드 아래 첫 정시는 12시다.
    expect(find.bySemanticsLabel('11:00부터 빈 시간, 할 일 놓기'), findsNothing);
    final slot = find.bySemanticsLabel('14:00부터 빈 시간, 할 일 놓기');
    await scrollTo(tester, slot);
    await tester.tap(slot);
    await tester.pumpAndSettle();
    expect(find.text('토요일 14:00–18:00 · 4시간 비어 있어요'), findsOneWidget);

    await tester.tap(find.text('일정은 말로 추가하기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AssistantScreen>(find.byType(AssistantScreen)).args.at,
      at(21, 14),
    );

    await app.dispose(tester);
  });

  testWidgets('지난 날은 빈 시간 카드를 그리지 않고 지난 날이라고 알린다', (tester) async {
    final app = await openDay(tester, DateTime(2026, 11, 14));

    expect(find.text('지난 날이에요. 할 일은 오늘부터 놓을 수 있어요'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'빈 시간')), findsNothing);
    expect(find.textContaining('빈 시간'), findsNothing);

    await app.dispose(tester);
  });

  for (final (name, size) in [
    ('폰', phonePortrait),
    ('태블릿 가로', const Size(1280, 800)),
  ]) {
    testWidgets('$name 폭, 글자 배율 2.0에서도 넘치지 않는다', (tester) async {
      final app = await openDay(
        tester,
        DateTime(2026, 11, 17),
        textScale: 2.0,
        size: size,
      );
      expect(find.byType(DayScreen), findsOneWidget);
      // 공휴일 카드도 넘치지 않는다.
      app.router.go(Routes.day(DateTime(2026, 12, 25)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('성탄절, 공휴일'), findsOneWidget);
      await app.dispose(tester);
    });
  }
}
