// 드로어 '내 폰'(캘린더 켜고 끄기) 테스트. docs/architecture.md '화면 이동', '폰 DB'의
// `hiddenCalendars`.
//
// 폰 DB(메모리)에 수업·직접 넣은 일정·알림에서 추가한 일정·사캠 할 일을 넣고 지금을
// 2026-10-29(목) 10:00으로 고정해 띄운다. 캘린더를 끄면 그 항목이 월간 그리드와 패널에서
// 사라지고 `settings`에 적혀 다시 띄워도 유지되는지, 미배정 할 일은 숨긴 사캠 할 일도
// 그대로 보여 주는지 본다. 글자 배율 1.0과 2.0에서 돌린다. [withoutSources]의 단위 테스트도 둔다.

import 'dart:convert';

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('사이버캠퍼스를 끄면 그 할 일이 월간에서 사라지고, 다시 띄워도 꺼진 채이며 '
          '미배정 할 일에는 남는다', (tester) async {
        final db = await _seed();
        await _pumpApp(tester, db, textScale);
        expect(await _onMonth(tester, '사캠과제'), isTrue);

        await _openDrawer(tester);
        expect(await _toggle(tester, '충남대 사이버캠퍼스'), _shown(true));
        await _tapToggle(tester, '충남대 사이버캠퍼스');
        expect(await _toggle(tester, '충남대 사이버캠퍼스'), _shown(false));
        await _closeDrawer(tester);

        expect(await _onMonth(tester, '사캠과제'), isFalse);
        expect(await _onMonth(tester, '자구'), isTrue);
        final row = await (db.select(
          db.settings,
        )..where((t) => t.key.equals(SettingKeys.hiddenCalendars))).getSingle();
        expect(jsonDecode(row.value), ['lms']);

        // 앱을 다시 띄워도 꺼진 채다.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        await _pumpApp(tester, db, textScale);
        expect(await _onMonth(tester, '사캠과제'), isFalse);
        await _openDrawer(tester);
        expect(await _toggle(tester, '충남대 사이버캠퍼스'), _shown(false));

        await _tapDrawer(tester, find.text('미배정 할 일'));
        expect(find.text('사캠과제'), findsOneWidget);

        await _dispose(tester, db);
      });

      testWidgets('수업·내 일정·알림에서 추가를 끄면 각자의 항목만 사라지고, 켜면 돌아온다', (tester) async {
        final db = await _seed();
        await _pumpApp(tester, db, textScale);
        expect(await _onMonth(tester, '자구'), isTrue);
        expect(await _onMonth(tester, '헬스'), isTrue);
        expect(await _onMonth(tester, '택배 수령'), isTrue);

        await _openDrawer(tester);
        await _tapToggle(tester, '수업');
        await _closeDrawer(tester);
        expect(await _onMonth(tester, '자구'), isFalse);
        expect(await _onMonth(tester, '헬스'), isTrue);

        await _openDrawer(tester);
        await _tapToggle(tester, '내 일정');
        await _tapToggle(tester, '알림에서 추가');
        await _closeDrawer(tester);
        expect(await _onMonth(tester, '헬스'), isFalse);
        expect(await _onMonth(tester, '택배 수령'), isFalse);
        expect(await _onMonth(tester, '사캠과제'), isTrue);

        await _openDrawer(tester);
        await _tapToggle(tester, '수업');
        await _closeDrawer(tester);
        expect(await _onMonth(tester, '자구'), isTrue);
        expect(await _onMonth(tester, '헬스'), isFalse);

        await _dispose(tester, db);
      });
    });
  }

  group('withoutSources', () {
    final data = CalendarData(
      schedule: Schedule(
        classSlots: [
          ClassSlot(
            id: 1,
            courseId: 1,
            weekday: DateTime.thursday,
            startMin: 600,
            endMin: 675,
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.manual,
          ),
        ],
        fixedBlocks: [
          FixedBlock(
            id: 1,
            name: '알바',
            kind: FixedBlockKind.work,
            weekdays: const [DateTime.thursday],
            startMin: 1080,
            endMin: 1260,
            bufferMin: 0,
            source: EntrySource.manual,
          ),
        ],
        events: [
          _event(1, '헬스', EventSource.manual),
          _event(2, '팀플', EventSource.ai),
          _event(3, '택배 수령', EventSource.notification),
        ],
        planBlocks: [_block(1, taskId: 1), _block(2, taskId: 2)],
      ),
      tasks: const [
        Task(
          id: 1,
          title: '보고서',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
        Task(
          id: 2,
          title: '사캠과제',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          lmsKey: 'k1',
        ),
      ],
    );

    test('아무것도 숨기지 않으면 그대로다', () {
      expect(withoutSources(data, const {}), same(data));
    });

    test('내 일정을 숨기면 직접·말로 넣은 일정, 고정 일정, 사캠이 아닌 할 일과 그 블록을 뺀다', () {
      final result = withoutSources(data, {CalendarSource.mine});
      expect(result.schedule.classSlots, hasLength(1));
      expect(result.schedule.fixedBlocks, isEmpty);
      expect(result.schedule.events.map((e) => e.title), ['택배 수령']);
      expect(result.tasks.map((t) => t.title), ['사캠과제']);
      expect(result.schedule.planBlocks.map((b) => b.taskId), [2]);
    });

    test('사캠을 숨기면 lmsKey가 있는 할 일과 그 블록만 뺀다', () {
      final result = withoutSources(data, {CalendarSource.lms});
      expect(result.tasks.map((t) => t.title), ['보고서']);
      expect(result.schedule.planBlocks.map((b) => b.taskId), [1]);
      expect(result.schedule.events, hasLength(3));
      expect(result.schedule.fixedBlocks, hasLength(1));
    });

    test('수업과 알림에서 추가를 숨기면 시간표 칸과 알림 일정만 뺀다', () {
      final result = withoutSources(data, {
        CalendarSource.classes,
        CalendarSource.notification,
      });
      expect(result.schedule.classSlots, isEmpty);
      expect(result.schedule.events.map((e) => e.title), ['헬스', '팀플']);
      expect(result.tasks, hasLength(2));
    });

    test('settings의 이름을 읽을 때 모르는 이름은 버린다', () {
      expect(CalendarSource.parse(['lms', 'unknown', 'classes']), {
        CalendarSource.lms,
        CalendarSource.classes,
      });
    });
  });
}

Event _event(int id, String title, EventSource source) => Event(
  id: id,
  title: title,
  startAt: DateTime(2026, 10, 29, 14),
  endAt: DateTime(2026, 10, 29, 15),
  allDay: false,
  source: source,
);

PlanBlock _block(int id, {required int taskId}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: DateTime(2026, 10, 29, 20),
  endAt: DateTime(2026, 10, 29, 21),
  status: PlanBlockStatus.confirmed,
  source: BlockSource.manual,
);

/// 수업(자구, 목 10:00), 직접 넣은 일정(헬스), 알림에서 추가한 일정(택배 수령), 사캠 할 일(사캠과제)을
/// 모두 2026-10-29(목)에 넣은 폰 DB.
Future<AppDatabase> _seed() async {
  final db = AppDatabase.memory();
  final courseId = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '자료구조', alias: const Value('자구')));
  await db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: DateTime.thursday,
          startMin: 600,
          endMin: 675,
          campus: Campus.daedeok,
          online: false,
          source: SlotSource.manual,
        ),
      );
  for (final (title, hour, source) in [
    ('헬스', 18, EventSource.manual),
    ('택배 수령', 14, EventSource.notification),
  ]) {
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            title: title,
            startAt: DateTime(2026, 10, 29, hour),
            endAt: DateTime(2026, 10, 29, hour + 1),
            allDay: false,
            source: source,
          ),
        );
  }
  final due = DateTime(2026, 10, 29, 23, 59);
  await db
      .into(db.lmsItems)
      .insert(
        LmsItemsCompanion.insert(
          remoteKey: 'synthetic-1',
          courseId: courseId,
          courseName: '자료구조',
          title: '사캠과제',
          kind: LmsItemKind.assignment,
          dueAt: Value(due),
          dueTimeUnknown: false,
          firstSeenAt: DateTime(2026, 10, 20),
          lastSeenAt: DateTime(2026, 10, 29),
          missCount: 0,
          contentHash: 'synthetic',
        ),
      );
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '사캠과제',
          kind: TaskKind.assignment,
          dueAt: Value(due),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          lmsKey: const Value('synthetic-1'),
        ),
      );
  return db;
}

/// 2026-10-29(목) 10:00, 온보딩·오늘 브리핑을 마친 상태로 [db]를 쓰는 앱을 띄운다(첫 화면 월간).
Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase db,
  double textScale,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        motionLevelProvider.overrideWithValue(MotionLevel.off),
        briefingOpenedTodayProvider.overrideWithValue(() async => true),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 10, 29, 10))),
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: const RootApp(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(MonthScreen), findsOneWidget);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  // drift는 스트림 쿼리 구독이 끝난 뒤 짧은 타이머로 정리한다(app_test.dart와 같다).
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

/// 월간 그리드나 선택일 패널에 [title]이 있는지. 패널 목록은 화면 밖 행까지 한 번에 그리므로
/// 내리지 않고 찾는다.
Future<bool> _onMonth(WidgetTester tester, String title) async {
  await tester.pump();
  return find.text(title).evaluate().isNotEmpty;
}

/// [scrollable]을 맨 위부터 내리며 [target]을 찾는다. 찾으면 그 자리에서 멈춘다.
Future<bool> _scrollTo(
  WidgetTester tester,
  Finder scrollable,
  Finder target,
) async {
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(0);
  await tester.pump();
  while (target.evaluate().isEmpty &&
      position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      (position.pixels + 80).clamp(0, position.maxScrollExtent).toDouble(),
    );
    await tester.pump();
  }
  return target.evaluate().isNotEmpty;
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('메뉴'));
  await tester.pumpAndSettle();
}

Future<void> _closeDrawer(WidgetTester tester) async {
  await _tapDrawer(tester, find.byTooltip('메뉴 닫기'));
}

/// 드로어 안의 [target]이 보이게 내린 뒤 누른다(글자가 크면 아래 줄은 아직 그려지지 않는다).
Future<void> _tapDrawer(WidgetTester tester, Finder target) async {
  await _showInDrawer(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _showInDrawer(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
      .first;
  expect(await _scrollTo(tester, scrollable, target), isTrue);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Finder _toggleFinder(String label) => find.descendant(
  of: find.byType(Drawer),
  matching: find.bySemanticsLabel(label),
);

/// 드로어의 [label] 캘린더 줄의 접근성 노드.
Future<SemanticsNode> _toggle(WidgetTester tester, String label) async {
  await _showInDrawer(tester, _toggleFinder(label));
  return tester.getSemantics(_toggleFinder(label));
}

Future<void> _tapToggle(WidgetTester tester, String label) =>
    _tapDrawer(tester, _toggleFinder(label));

Matcher _shown(bool shown) =>
    isSemantics(isButton: true, hasCheckedState: true, isChecked: shown);
