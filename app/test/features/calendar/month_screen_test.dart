// 월간(`/calendar`) 화면 테스트. docs/architecture.md '화면 이동'.
//
// 폰 DB(메모리)에 수업·일정·할 일을 넣고 지금을 2026-10-29(목) 10:00으로 고정해 띄운다.
// 그리드가 날짜마다 칩을, 패널이 선택한 날의 일정을 보여 주는지, 달 넘기기·오늘 버튼·두 번 눌러
// 일간 열기·마감 행에서 할 일 상세 열기가 도는지 본다. 글자 배율 1.0과 2.0에서 돌린다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/day_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_detail_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('오늘의 수업·일정·마감이 칩과 패널에 보이고, 다른 날을 고르면 패널이 바뀐다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);

        expect(find.text('10월'), findsOneWidget);
        expect(find.text('10월 29일에 추가'), findsOneWidget);
        // 그리드 칩(제목)과 패널 행이 함께 있다.
        expect(find.text('자구'), findsWidgets);
        await _scrollPanelTo(tester, find.text('마감 · 아직 시간을 정하지 않음'));
        expect(find.text('과제2'), findsWidgets);
        expect(
          find.text('10:00 - 11:15 · 공대5호관 412', skipOffstage: false),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel(RegExp(r'^10월 30일 금요일')));
        await tester.pumpAndSettle();
        expect(find.text('10월 30일에 추가'), findsOneWidget);
        await _scrollPanelTo(tester, find.text('택배 수령'));
        expect(find.text('택배 수령'), findsWidgets);

        await app.dispose(tester);
      });

      testWidgets('선택한 날을 한 번 더 누르면 그날 일간으로 간다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        final cell = find.bySemanticsLabel(RegExp(r'^10월 30일 금요일'));
        await tester.tap(cell);
        await tester.pumpAndSettle();
        await tester.tap(cell);
        await tester.pumpAndSettle();

        expect(find.byType(DayScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.calendarDay('2026-10-30'));

        await app.dispose(tester);
      });

      testWidgets('그리드를 위로 넘기면 다음 달, 아래로 넘기면 이전 달이고 오늘 버튼으로 돌아온다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);
        final grid = find.bySemanticsLabel(RegExp(r'^10월 15일'));

        await tester.fling(grid, const Offset(0, -200), 1000);
        await tester.pumpAndSettle();
        expect(find.text('11월'), findsOneWidget);

        await tester.fling(
          find.bySemanticsLabel(RegExp(r'^11월 15일')),
          const Offset(0, 200),
          1000,
        );
        await tester.pumpAndSettle();
        await tester.fling(grid, const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('9월'), findsOneWidget);

        // 마우스 휠을 아래로 굴리면 다음 달.
        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        final center = tester.getCenter(
          find.bySemanticsLabel(RegExp(r'^9월 15일')),
        );
        await tester.sendEventToBinding(mouse.hover(center));
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
        await tester.pumpAndSettle();
        expect(find.text('10월'), findsOneWidget);

        await tester.fling(grid, const Offset(0, -200), 1000);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('오늘로 이동'));
        await tester.pumpAndSettle();
        expect(find.text('10월'), findsOneWidget);
        expect(find.text('10월 29일에 추가'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('마감 행을 누르면 그 할 일 상세가 열린다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        final row = find.text('마감 · 아직 시간을 정하지 않음');
        await _scrollPanelTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.byType(TaskDetailScreen), findsOneWidget);
        expect(
          tester.widget<TaskDetailScreen>(find.byType(TaskDetailScreen)).taskId,
          app.taskId,
        );

        await app.dispose(tester);
      });
    });
  }
}

class _MonthApp {
  _MonthApp(this.db, this.container, this.taskId);

  final AppDatabase db;
  final ProviderContainer container;
  final int taskId;

  GoRouter get router => container.read(routerProvider);

  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // drift는 스트림 쿼리 구독이 끝난 뒤 짧은 타이머로 정리한다(app_test.dart와 같다).
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }
}

/// 2026-10-29(목) 10:00, 온보딩·오늘 브리핑을 마친 상태로 앱을 띄운다(첫 화면 월간).
Future<_MonthApp> _pumpMonth(WidgetTester tester, double textScale) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final preferences = await SharedPreferences.getInstance();
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
          place: const Value('공대5호관 412'),
          campus: Campus.daedeok,
          online: false,
          source: SlotSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '택배 수령',
          startAt: DateTime(2026, 10, 30, 14),
          endAt: DateTime(2026, 10, 30, 16),
          allDay: false,
          source: EventSource.notification,
        ),
      );
  final taskId = await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제2',
          kind: TaskKind.assignment,
          dueAt: Value(DateTime(2026, 10, 29, 23, 59)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );

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
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RootApp)),
  );
  return _MonthApp(db, container, taskId);
}

/// 선택일 패널을 [target]이 보일 때까지 내린다(글자가 크면 아래 행은 아직 그려지지 않는다).
Future<void> _scrollPanelTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      80,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down &&
                widget.physics is! NeverScrollableScrollPhysics,
          )
          .last,
    );
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}
