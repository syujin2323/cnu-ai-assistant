// 01 아침 브리핑 화면 테스트. docs/screens.md '01 아침 브리핑'.
//
// 2026-11-16(월) 08:00이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다.
// - 어제(일) 10:00–11:00에 '어제 일'(A)의 블록을 놓쳤다.
// - 오늘 '과제 B'의 제안 10:00–11:00, 전에 브리핑에서 확정한 '과제 C' 14:00–15:00이 있다.
// - 배치 엔진의 마지막 결과(덮어씀)는 급한 순서 [D, B, A]와 근거를 낸다.
// 02 홈에서 띄운 뒤 데이터를 넣고 /briefing으로 간다(브리핑이 처음 읽을 때 데이터가 있게).

import 'dart:async';

import 'package:cnu_ai_assistant/app/plan_controller.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/widgets/briefing_rows.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const sun = 15;
const mon = 16;

class _FixedPlan extends PlanController {
  _FixedPlan(this.result);

  final PlanResult result;

  @override
  PlanResult? build() => result;
}

/// 넣은 할 일과 블록의 id.
typedef Ids = ({int a, int b, int c, int d, int missed, int confirmed});

/// 할 일 D(마감 금요일)의 id를 미리 알 수 없으므로 순서대로 넣는다(1–4).
Future<Ids> seed(
  AppDatabase db, {
  bool fillDay = false,
  int? dailyCapMin,
  int lunchMin = 0,
}) async {
  final made = DateTime(2026, 11, 1);
  Future<void> rule(RuleKind kind, RuleParams params) => db
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
  await rule(
    RuleKind.workWindow,
    const RuleParams(startMin: 540, endMin: 1080),
  );
  await rule(RuleKind.classBuffer, const RuleParams(minutes: 10));
  await rule(
    RuleKind.meal,
    RuleParams(startMin: 690, endMin: 810, minutes: lunchMin),
  );
  if (dailyCapMin != null) {
    await rule(RuleKind.dailyCap, RuleParams(minutes: dailyCapMin));
  }
  Future<int> task(String title) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: title,
          kind: TaskKind.assignment,
          dueAt: Value(at(20, 18)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
  final a = await task('어제 일');
  final b = await task('과제 B');
  final c = await task('과제 C');
  final d = await task('과제 D');
  Future<int> block(
    int taskId,
    DateTime start,
    DateTime end,
    PlanBlockStatus status, {
    bool fromBriefing = false,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: end,
          status: status,
          source: BlockSource.auto,
          fromBriefing: Value(fromBriefing),
          reason: Value(
            BlockReason(
              slackMin: 600,
              dueAt: at(20, 18),
              gapMin: 60,
              rank: 2,
              factor: BlockFactor.fit,
            ),
          ),
        ),
      );
  final missed = await block(
    a,
    at(sun, 10),
    at(sun, 11),
    PlanBlockStatus.missed,
  );
  await block(b, at(mon, 10), at(mon, 11), PlanBlockStatus.suggested);
  final confirmed = await block(
    c,
    at(mon, 14),
    at(mon, 15),
    PlanBlockStatus.confirmed,
    fromBriefing: true,
  );
  if (fillDay) {
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            title: '하루 종일 실습',
            startAt: at(mon, 9),
            endAt: at(mon, 18),
            allDay: false,
            source: EventSource.manual,
          ),
        );
  }
  return (a: a, b: b, c: c, d: d, missed: missed, confirmed: confirmed);
}

final _plan = PlanResult(
  blocks: [
    BlockDraft(
      taskId: 4,
      startAt: at(17, 9),
      endAt: at(17, 10),
      reason: BlockReason(
        slackMin: 500,
        dueAt: at(20, 18),
        gapMin: 60,
        rank: 1,
        factor: BlockFactor.fit,
      ),
    ),
  ],
  shortages: const [],
  ranked: const [4, 2, 1],
);

/// 02 홈에서 띄우고, 데이터를 넣은 뒤 01 계획을 연다(시작 위치처럼 go로).
Future<(TestApp, Ids)> pumpBriefing(
  WidgetTester tester, {
  double textScale = 1.0,
  Size size = phonePortrait,
  bool fillDay = false,
  int? dailyCapMin,
  int lunchMin = 0,
  Map<String, Object?> settings = const {},
}) async {
  final app = await pumpTestApp(
    tester,
    now: at(mon, 8),
    textScale: textScale,
    size: size,
    settings: settings,
    overrides: [planControllerProvider.overrideWith(() => _FixedPlan(_plan))],
  );
  final ids = await seed(
    app.db,
    fillDay: fillDay,
    dailyCapMin: dailyCapMin,
    lunchMin: lunchMin,
  );
  await tester.pumpAndSettle();
  app.router.go(Routes.briefing);
  await tester.pumpAndSettle();
  expect(find.byType(BriefingScreen), findsOneWidget);
  return (app, ids);
}

/// 오늘 할 일 줄의 제목들(위에서부터). 줄이 그려지게 목록 아래까지 스크롤한다.
Future<List<String>> taskRowTitles(WidgetTester tester) async {
  await scrollTo(tester, find.textContaining('할 일 전체 보기'));
  final titles = ['과제 B', '과제 C', '과제 D'];
  final found = [
    for (final title in titles)
      if (row(title).evaluate().isNotEmpty)
        (title, tester.getTopLeft(row(title)).dy),
  ]..sort((x, y) => x.$2.compareTo(y.$2));
  return [for (final (title, _) in found) title];
}

/// 오늘 할 일 줄의 제목(시간표의 할 일 블록에도 같은 제목이 보임).
Finder row(String title) => find.descendant(
  of: find.byType(BriefingTaskRow),
  matching: find.text(title),
);

Future<void> tapFinder(WidgetTester tester, Finder target) async {
  await scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('날짜·오늘 일정·어제 못 한 일·오늘 할 일을 보이고, 전 확정은 체크된 채 오늘 시작하기다', (
        tester,
      ) async {
        final (app, _) = await pumpBriefing(tester, textScale: textScale);

        expect(find.text('계획'), findsOneWidget);
        expect(find.textContaining('11월 16일'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('^오늘 일정\\. 수업 0개')),
          findsOneWidget,
        );
        await scrollTo(tester, find.textContaining('어제 10:00–11:00'));
        expect(find.text('어제 못 한 일'), findsOneWidget);
        expect(find.text('어제 일'), findsOneWidget);
        expect(find.textContaining('어제 10:00–11:00'), findsOneWidget);
        expect(await taskRowTitles(tester), ['과제 C', '과제 B', '과제 D']);
        expect(find.text('확정'), findsOneWidget);
        expect(find.text('추천'), findsOneWidget);
        expect(find.textContaining('오늘 확정한 할 일 1개'), findsOneWidget);
        await scrollTo(tester, find.text('오늘 시작하기'));
        expect(find.text('오늘 시작하기'), findsOneWidget);
        expect(find.textContaining('할 일 전체 보기 · 4개'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('체크를 바꾸면 N개 확정하기가 되고, 확정하면 블록을 바꿔 끼우고 오늘 시작하기로 돌아온다', (
        tester,
      ) async {
        final (app, ids) = await pumpBriefing(tester, textScale: textScale);

        await tapFinder(tester, row('과제 B'));
        expect(find.textContaining('고른 할 일 2개'), findsOneWidget);
        await tapFinder(tester, find.text('2개 확정하기'));

        expect(find.text('오늘 할 일 2개를 확정했어요'), findsOneWidget);
        expect(find.text('오늘 시작하기'), findsOneWidget);
        final blocks = await app.db.select(app.db.planBlocks).get();
        final briefed = blocks.where((block) => block.fromBriefing).toList()
          ..sort((x, y) => x.startAt.compareTo(y.startAt));
        expect(
          [for (final b in briefed) (b.taskId, b.startAt, b.status)],
          [
            (ids.b, at(mon, 10), PlanBlockStatus.confirmed),
            (ids.c, at(mon, 14), PlanBlockStatus.confirmed),
          ],
        );
        expect(blocks.where((b) => b.id == ids.confirmed), isEmpty);

        await app.dispose(tester);
      });

      testWidgets('전 확정을 모두 풀면 확정한 할 일 빼기다', (tester) async {
        final (app, ids) = await pumpBriefing(tester, textScale: textScale);

        await tapFinder(tester, row('과제 C'));
        await tapFinder(tester, find.text('확정한 할 일 빼기'));

        expect(find.text('확정한 할 일을 오늘 일정에서 뺐어요'), findsOneWidget);
        expect(
          (await app.db.select(app.db.planBlocks).get()).where(
            (b) => b.id == ids.confirmed,
          ),
          isEmpty,
        );

        await app.dispose(tester);
      });

      testWidgets('어제 못 한 일을 체크하면 오늘 빈 자리에 넣고, [했어요]는 어제 한 것으로 적는다', (
        tester,
      ) async {
        final (app, ids) = await pumpBriefing(tester, textScale: textScale);

        await tapFinder(
          tester,
          find.descendant(
            of: find.byType(BriefingMissedRow),
            matching: find.text('어제 일'),
          ),
        );
        expect(find.textContaining('오늘 09:00–10:00'), findsOneWidget);

        await tapFinder(tester, find.text('했어요'));
        expect(find.text('어제 일을 어제 한 것으로 기록했어요'), findsOneWidget);
        final stored = (await app.db.select(app.db.planBlocks).get())
            .singleWhere((b) => b.id == ids.missed);
        expect(stored.status, PlanBlockStatus.done);
        expect(find.text('어제 못 한 일'), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('마감이 지난 어제 일은 오늘에 넣을 수 없고 [했어요]만 된다', (tester) async {
        final (app, ids) = await pumpBriefing(tester, textScale: textScale);
        await (app.db.update(app.db.tasks)
              ..where((task) => task.id.equals(ids.a)))
            .write(TasksCompanion(dueAt: Value(at(sun, 23, 59))));
        await tester.pumpAndSettle();

        final title = find.descendant(
          of: find.byType(BriefingMissedRow),
          matching: find.text('어제 일'),
        );
        await scrollTo(tester, title);
        await tester.tap(title, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.textContaining('어제 10:00–11:00'), findsOneWidget);
        expect(find.text('오늘은 빈 시간이 없어요'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('마감이 지나 오늘 일정에 넣을 수 없음')),
          findsOneWidget,
        );

        await tapFinder(tester, find.text('했어요'));
        expect(find.text('어제 일을 어제 한 것으로 기록했어요'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('시간순은 시각 순서이고 시각이 없는 줄은 뒤다', (tester) async {
        final (app, _) = await pumpBriefing(tester, textScale: textScale);

        await tapFinder(tester, find.text('시간순'));

        expect(await taskRowTitles(tester), ['과제 B', '과제 C', '과제 D']);

        await app.dispose(tester);
      });

      testWidgets('놓을 빈 자리가 없으면 체크하지 않고 알린다', (tester) async {
        final (app, _) = await pumpBriefing(
          tester,
          textScale: textScale,
          fillDay: true,
        );

        await tapFinder(tester, row('과제 D'));

        expect(find.text('오늘은 빈 시간이 없어요'), findsOneWidget);
        expect(find.text('오늘 시작하기'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('하루 최대 공부량을 넘으면 합계를 알린다', (tester) async {
        final (app, _) = await pumpBriefing(
          tester,
          textScale: textScale,
          dailyCapMin: 60,
        );
        expect(find.textContaining('(내 규칙)을 넘어요'), findsNothing);

        await tapFinder(tester, row('과제 B'));

        expect(find.text('하루 공부 1시간(내 규칙)을 넘어요'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('다른 화면에서 push로 열었으면 닫기·오늘 시작하기가 연 화면으로 돌아간다', (tester) async {
        // 02 홈의 [계획]처럼 push로 열면 닫을 때 연 곳으로 돌아간다(go로 02 홈에 가지 않음). 연 곳이
        // 02 홈이 아니어도 돌아가는지 09 일간에서 본다.
        final (app, _) = await pumpBriefing(tester, textScale: textScale);
        final day = Routes.day(DateTime(2026, 11, 16));
        for (final leave in [
          () => tapFinder(tester, find.byTooltip('계획 닫기')),
          () => tapFinder(tester, find.text('오늘 시작하기')),
        ]) {
          app.router.go(day);
          await tester.pumpAndSettle();
          unawaited(app.router.push(Routes.briefing));
          await tester.pumpAndSettle();
          expect(find.byType(BriefingScreen), findsOneWidget);

          await leave();
          expect(find.byType(BriefingScreen), findsNothing);
          expect(app.router.state.uri.path, day);
        }

        await app.dispose(tester);
      });

      testWidgets('닫기·오늘 시작하기는 02 홈, 할 일 전체 보기는 03 전체 할 일로 간다', (tester) async {
        final (app, _) = await pumpBriefing(tester, textScale: textScale);

        await tapFinder(tester, find.byTooltip('계획 닫기'));
        expect(find.byType(TodayScreen), findsOneWidget);

        app.router.go(Routes.briefing);
        await tester.pumpAndSettle();
        await tapFinder(tester, find.text('오늘 시작하기'));
        expect(app.router.state.uri.path, Routes.today);

        app.router.go(Routes.briefing);
        await tester.pumpAndSettle();
        await tapFinder(tester, find.textContaining('할 일 전체 보기'));
        expect(app.router.state.uri.toString(), '/tasks?tab=all');

        await app.dispose(tester);
      });

      testWidgets('이동·점심 시간 표시를 끄면 오늘 일정에 이동·점심 카드를 그리지 않는다', (tester) async {
        for (final shown in [true, false]) {
          final (app, _) = await pumpBriefing(
            tester,
            textScale: textScale,
            lunchMin: 30,
            settings: {SettingKeys.showTravelMeal: shown},
          );
          // 오늘(월) 16:00–17:00 대면 수업과 매 수업 앞뒤 20분 이동.
          final courseId = await app.db
              .into(app.db.courses)
              .insert(CoursesCompanion.insert(name: '자료구조'));
          await app.db
              .into(app.db.classSlots)
              .insert(
                ClassSlotsCompanion.insert(
                  courseId: courseId,
                  weekday: DateTime.monday,
                  startMin: 960,
                  endMin: 1020,
                  campus: Campus.daedeok,
                  online: false,
                  source: SlotSource.manual,
                ),
              );
          final made = DateTime(2026, 11, 2);
          await app.db
              .into(app.db.rules)
              .insert(
                RulesCompanion.insert(
                  kind: RuleKind.travel,
                  params: const RuleParams(
                    minutes: 20,
                    position: TravelPosition.everyClass,
                  ),
                  active: true,
                  source: EntrySource.manual,
                  createdAt: made,
                  updatedAt: made,
                ),
              );
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();

          final reason = 'showTravelMeal: $shown';
          expect(
            find.text('점심'),
            shown ? findsOneWidget : findsNothing,
            reason: reason,
          );
          expect(
            find.text('이동 20분'),
            shown ? findsWidgets : findsNothing,
            reason: reason,
          );
          await app.dispose(tester);
        }
      });

      testWidgets('오늘 이미 확정한 잠긴 줄을 누르면 근거 시트를 연다', (tester) async {
        final (app, ids) = await pumpBriefing(tester, textScale: textScale);
        // 직접 놓은 오늘 16:00–17:00 '과제 D'는 브리핑이 바꾸지 않는 잠긴 줄이다.
        await app.db
            .into(app.db.planBlocks)
            .insert(
              PlanBlocksCompanion.insert(
                taskId: ids.d,
                startAt: at(mon, 16),
                endAt: at(mon, 17),
                status: PlanBlockStatus.confirmed,
                source: BlockSource.manual,
              ),
            );
        await tester.pumpAndSettle();

        final locked = find.descendant(
          of: find.byType(BriefingTaskRow),
          matching: find.text('직접 놓음'),
        );
        await scrollTo(tester, locked);
        await tester.tap(locked);
        await tester.pumpAndSettle();
        expect(find.text('직접 정한 시간이에요'), findsOneWidget);
        expect(find.textContaining('오늘 16:00–17:00'), findsWidgets);

        await app.dispose(tester);
      });

      testWidgets('말로 추가 칸에 쓰고 보내면 06 AI 비서를 연다', (tester) async {
        final (app, _) = await pumpBriefing(tester, textScale: textScale);

        final field = find.byType(TextField);
        await scrollTo(tester, field);
        await tester.enterText(field, '목요일 8시 팀플 회의');
        await tester.pumpAndSettle();
        await tapFinder(tester, find.byTooltip('06 AI 비서로 보내기'));

        expect(app.router.state.uri.path, Routes.assistant);

        await app.dispose(tester);
      });
    });
  }

  testWidgets('고를 할 일이 없으면 안내만 보이고, 태블릿 가로 폭에서도 넘치지 않는다', (tester) async {
    final app = await pumpTestApp(
      tester,
      now: at(mon, 8),
      textScale: 2.0,
      size: tabletLandscape,
      overrides: [
        planControllerProvider.overrideWith(() => _FixedPlan(PlanResult.empty)),
      ],
    );
    app.router.go(Routes.briefing);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('오늘 고를 할 일이 없어요'));
    expect(find.text('오늘 고를 할 일이 없어요'), findsOneWidget);
    expect(find.text('어제 못 한 일'), findsNothing);

    await app.dispose(tester);
  });
}
