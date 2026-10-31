// 데일리 브리핑·중요 브리핑 테스트. docs/architecture.md '데일리 브리핑과 중요 브리핑'.
//
// 지금을 2026-10-29(목) 10:00, 마지막 접속을 어제 23:40으로 두고 폰 DB에 수업·할 일·중요 알림을
// 넣는다. 글자 배율 1.0과 2.0에서 돌린다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/workload.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_template.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 29, 10);
final _lastVisit = DateTime(2026, 10, 28, 23, 40);

void main() {
  group('템플릿 문장', () {
    Task task(String title, DateTime due) => Task(
      id: title.hashCode,
      title: title,
      kind: TaskKind.assignment,
      dueAt: due,
      dueTimeUnknown: false,
      status: TaskStatus.todo,
    );
    UnassignedTask unassigned(Task t) => UnassignedTask(
      task: t,
      workload: const Workload(
        remainingMin: 60,
        toPlaceMin: 60,
        source: EstimateSource.user,
      ),
      slackMin: 300,
      urgency: Urgency.medium,
    );
    const classItem = CalendarItem(
      kind: CalendarItemKind.classSession,
      title: '자구',
    );

    test('수업 수, 미배정 할 일, 가장 가까운 마감을 세 문장으로 쓴다', () {
      expect(
        dailyBriefingText(
          today: DateTime(2026, 10, 29),
          todayItems: const [classItem],
          unassigned: [unassigned(task('과제2', DateTime(2026, 10, 29, 23, 59)))],
          now: _now,
          dayBoundaryMin: 240,
        ),
        '수업 1개가 있는 목요일이에요. 과제2는 아직 시간을 정하지 않았어요. 과제2는 오늘 마감이에요.',
      );
      expect(
        dailyBriefingText(
          today: DateTime(2026, 10, 29),
          todayItems: const [],
          unassigned: [
            unassigned(task('보고서', DateTime(2026, 10, 30, 18))),
            unassigned(task('영상', DateTime(2026, 11, 2, 23, 59))),
          ],
          now: _now,
          dayBoundaryMin: 240,
        ),
        '오늘은 수업이 없어요. 보고서 등 2개는 아직 시간을 정하지 않았어요. 보고서는 내일 마감이에요.',
      );
    });

    test('할 일이 없으면 "오늘은 할 일이 없어요."다', () {
      expect(
        dailyBriefingText(
          today: DateTime(2026, 10, 29),
          todayItems: const [],
          unassigned: const [],
          now: _now,
          dayBoundaryMin: 240,
        ),
        '오늘은 수업이 없어요. 오늘은 할 일이 없어요.',
      );
    });
  });

  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('데일리 브리핑은 마지막 접속 이후 생긴 일만 보여 주고, 열면 기록하고 닫으면 알림을 본 것으로 둔다', (
        tester,
      ) async {
        final app = await _pump(tester, textScale, briefingOpened: false);

        expect(find.byType(BriefingScreen), findsOneWidget);
        expect(find.textContaining('어제 오후 11시 40분 마지막 접속 이후'), findsOneWidget);
        expect(
          find.text('수업 1개가 있는 목요일이에요. 과제2는 아직 시간을 정하지 않았어요. 과제2는 오늘 마감이에요.'),
          findsOneWidget,
        );
        await _scrollTo(tester, find.text('마지막 접속 이후 생긴 일'));
        expect(
          find.textContaining('자료구조 과제3', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('전날 저녁 공지', findRichText: true),
          findsNothing,
        );

        final briefing = await app.db.select(app.db.briefings).getSingle();
        expect(briefing.date, '2026-10-29');
        expect(briefing.openedAt, _now);
        expect(briefing.fromAt, _lastVisit);

        await _scrollTo(tester, find.text('캘린더로 가기'));
        await tester.tap(find.text('캘린더로 가기'));
        await tester.pumpAndSettle();
        expect(find.byType(MonthScreen), findsOneWidget);
        final alerts = await app.db.select(app.db.alerts).get();
        expect(alerts.every((a) => a.seenAt != null), isTrue);

        await app.dispose(tester);
      });

      testWidgets('안 본 알림이 있으면 원형 버튼에 레드닷이 있고, 중요 브리핑을 열면 NEW로 보인 뒤 사라진다', (
        tester,
      ) async {
        final app = await _pump(tester, textScale, briefingOpened: true);

        expect(find.byTooltip('중요 브리핑, 새 알림 있음'), findsOneWidget);
        await tester.tap(find.byTooltip('중요 브리핑, 새 알림 있음'));
        await tester.pumpAndSettle();

        expect(find.text('중요 브리핑'), findsOneWidget);
        expect(find.text('긴급'), findsOneWidget);
        expect(find.text('NEW'), findsNWidgets(2));
        await tester.ensureVisible(find.text('지금까지 요약'));
        expect(find.textContaining('지금(오전 10시)까지 상황이에요.'), findsOneWidget);

        // 열린 동안 원형 버튼은 같은 자리의 닫기 X이고, 누르면 닫힌다.
        expect(find.byTooltip('중요 브리핑 닫기'), findsOneWidget);
        await tester.tap(find.byTooltip('중요 브리핑 닫기'));
        await tester.pumpAndSettle();
        expect(find.text('긴급'), findsNothing);
        expect(find.byTooltip('중요 브리핑'), findsOneWidget);
        expect(find.byTooltip('중요 브리핑, 새 알림 있음'), findsNothing);

        // 바깥(위쪽 어둡게 한 곳)을 눌러도 닫힌다.
        await tester.tap(find.byTooltip('중요 브리핑'));
        await tester.pumpAndSettle();
        expect(find.text('긴급'), findsOneWidget);
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();
        expect(find.text('긴급'), findsNothing);

        // 손잡이를 아래로 끌어도 닫힌다.
        await tester.tap(find.byTooltip('중요 브리핑'));
        await tester.pumpAndSettle();
        final sheetTop = tester.getTopLeft(find.text('중요 브리핑')).dy;
        await tester.dragFrom(Offset(200, sheetTop - 16), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(find.text('긴급'), findsNothing);
        expect(find.byTooltip('중요 브리핑'), findsOneWidget);

        await app.dispose(tester);
      });
    });
  }
}

class _App {
  _App(this.db);

  final AppDatabase db;

  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    // drift는 스트림 쿼리 구독이 끝난 뒤 짧은 타이머로 정리한다.
    await tester.pump(const Duration(seconds: 1));
    await db.close();
  }
}

Future<_App> _pump(
  WidgetTester tester,
  double textScale, {
  required bool briefingOpened,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'onboarding_done': true});
  final preferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  await db
      .into(db.settings)
      .insert(
        SettingsCompanion.insert(
          key: SettingKeys.lastVisitAt,
          value: '"2026-10-28T23:40:00.000"',
        ),
      );
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
  await db
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
  await db
      .into(db.alerts)
      .insert(
        AlertsCompanion.insert(
          level: AlertLevel.schedule,
          source: AlertSource.lms,
          createdAt: DateTime(2026, 10, 28, 23, 50),
          body: '자료구조 과제3이 새로 올라왔어요.',
        ),
      );
  await db
      .into(db.alerts)
      .insert(
        AlertsCompanion.insert(
          level: AlertLevel.urgent,
          source: AlertSource.event,
          createdAt: DateTime(2026, 10, 28, 22),
          body: '전날 저녁 공지',
        ),
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        motionLevelProvider.overrideWithValue(MotionLevel.off),
        briefingOpenedTodayProvider.overrideWithValue(
          () async => briefingOpened,
        ),
        clockProvider.overrideWithValue(FixedClock(_now)),
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
  return _App(db);
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
