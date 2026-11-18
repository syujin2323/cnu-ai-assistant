// 02 홈 화면 테스트. docs/screens.md '02 홈'·'되돌리기'.
//
// 2026-11-16(월) 11:02이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다. 자료구조 수업
// 13:00–14:00, 일정 '상담' 15:00–15:30, 할 일 '과제 1'의 확정 블록 09:00–10:00(끝남, 답 없음)과
// 16:00–17:00이 있다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 16, hour, minute);

final today = DateTime(2026, 11, 16);

/// 위 설명의 하루를 [db]에 넣고, 끝난 블록과 뒤 블록의 id를 돌려준다.
Future<({int past, int later})> seedDay(AppDatabase db) async {
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
          campus: Campus.daedeok,
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
  final taskId = await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제 1',
          kind: TaskKind.assignment,
          dueAt: Value(DateTime(2026, 11, 20, 18)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
  Future<int> confirmed(DateTime start, DateTime end) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: end,
          status: PlanBlockStatus.confirmed,
          source: BlockSource.manual,
        ),
      );
  return (
    past: await confirmed(at(9), at(10)),
    later: await confirmed(at(16), at(17)),
  );
}

/// 블록 [id]의 저장된 상태.
Future<PlanBlockStatus> statusOf(AppDatabase db, int id) async =>
    (await (db.select(
      db.planBlocks,
    )..where((block) => block.id.equals(id))).getSingle()).status;

/// 위 하루를 넣은 02 홈을 띄운다.
Future<(TestApp, ({int past, int later}))> pumpHome(
  WidgetTester tester, {
  double textScale = 1.0,
  Size size = phonePortrait,
  Map<String, Object?> settings = const {},
}) async {
  final app = await pumpTestApp(
    tester,
    now: at(11, 2),
    textScale: textScale,
    size: size,
    settings: settings,
  );
  final ids = await seedDay(app.db);
  // 표가 바뀌고 300ms 뒤 재계산이 돌아, 끝나고 30분 지난 09:00 블록을 놓침으로 바꾼다.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return (app, ids);
}

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('머리에 날짜와 지금·남은 일정·할 일 수를 보이고, 끝난 블록을 묻는다', (tester) async {
        final (app, _) = await pumpHome(tester, textScale: textScale);

        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.text('11월 16일 (월)'), findsOneWidget);
        expect(find.text('11:02 · 남은 일정 2개 · 할 일 1개'), findsOneWidget);
        expect(find.text('과제 1, 하셨나요?'), findsOneWidget);
        expect(find.text('09:00–10:00 · 끝난 지 1시간 2분'), findsOneWidget);
        // 시간표에는 수업·일정·뒤 블록이 있고, 끝난 블록은 접혀 있다.
        expect(find.textContaining('자료구조'), findsWidgets);
        expect(find.textContaining('상담'), findsWidgets);
        expect(find.bySemanticsLabel('과제 1 완료로 표시'), findsOneWidget);
        expect(find.text('지난 일정 1개 보기'), findsOneWidget);
        // LMS에 로그인해 있으면 다시 로그인 칩이 없다.
        expect(find.byType(LmsReloginChip), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('했어요는 블록을 끝내고 카드 안 되돌리기로 돌린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '했어요');
        expect(find.text('기록했어요'), findsOneWidget);
        expect(find.text('과제 1을 끝냈어요'), findsOneWidget);
        expect(find.text('오늘 남은 할 일 1개 · 다음은 16:00 과제 1'), findsOneWidget);
        expect(await statusOf(app.db, ids.past), PlanBlockStatus.done);

        // 되돌리면 답하기 전 상태(재계산이 바꿔 둔 놓침)로 돌아가 다시 묻는다.
        await tapText(tester, '되돌리기');
        expect(find.text('과제 1, 하셨나요?'), findsOneWidget);
        expect(await statusOf(app.db, ids.past), PlanBlockStatus.missed);

        await app.dispose(tester);
      });

      testWidgets('못 했어요는 다시 놓을지 묻고, 다시 놓기는 확정 블록을 만들고 알린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '못 했어요');
        expect(find.text('못 했어도 괜찮아요'), findsOneWidget);
        expect(find.text('11:05에 다시 놓을까요?'), findsOneWidget);
        expect(await statusOf(app.db, ids.past), PlanBlockStatus.missed);

        await tapText(tester, '다시 놓기');
        expect(find.text('과제 1을 11:05에 다시 놓았어요'), findsOneWidget);
        final blocks = await app.db.select(app.db.planBlocks).get();
        final placed = blocks.singleWhere(
          (block) => block.id != ids.past && block.id != ids.later,
        );
        expect(
          (placed.startAt, placed.endAt, placed.status, placed.source),
          (at(11, 5), at(12, 5), PlanBlockStatus.confirmed, BlockSource.manual),
        );
        // 답이 끝나 카드는 다음 할 일로 돌아간다.
        expect(find.text('다음 할 일'), findsOneWidget);
        expect(find.text('11:05 과제 1'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('오늘은 괜찮아요는 다시 놓지 않고 알린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '못 했어요');
        await tapText(tester, '오늘은 괜찮아요');

        expect(find.text('오늘은 다시 놓지 않을게요'), findsOneWidget);
        expect(find.text('16:00 과제 1'), findsOneWidget);
        final blocks = await app.db.select(app.db.planBlocks).get();
        expect(blocks.map((block) => block.id), [ids.past, ids.later]);
        expect(await statusOf(app.db, ids.past), PlanBlockStatus.missed);

        await app.dispose(tester);
      });

      testWidgets('시간표 블록의 체크는 완료를 켜고 끄며 알린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        await scrollTo(tester, find.bySemanticsLabel('과제 1 완료로 표시'));
        await tester.tap(find.bySemanticsLabel('과제 1 완료로 표시'));
        await tester.pumpAndSettle();
        expect(find.text('과제 1 · 1시간 끝냈어요'), findsOneWidget);
        expect(await statusOf(app.db, ids.later), PlanBlockStatus.done);

        await tester.tap(find.bySemanticsLabel('과제 1 완료 취소'));
        await tester.pumpAndSettle();
        expect(find.text('과제 1을 다시 할 일로 돌렸어요'), findsOneWidget);
        expect(await statusOf(app.db, ids.later), PlanBlockStatus.confirmed);

        await app.dispose(tester);
      });

      testWidgets('시간표의 할 일 블록을 누르면 근거 시트가 열리고, 완료는 되돌리기로 돌린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        // 16:00–17:00 '과제 1'(직접 놓은 확정 블록).
        await scrollTo(tester, find.text('과제 1'));
        await tester.tap(find.text('과제 1'));
        await tester.pumpAndSettle();
        expect(find.text('확정'), findsOneWidget);
        expect(find.text('직접 정한 시간이에요'), findsOneWidget);
        expect(find.textContaining('오늘 16:00–17:00 · 1시간'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, '완료'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, '지우기'), findsOneWidget);
        // 옮기기 시트가 붙기 전에는 [옮기기]를 두지 않는다.
        expect(find.text('옮기기'), findsNothing);

        await tester.tap(find.widgetWithText(FilledButton, '완료'));
        await tester.pumpAndSettle();
        expect(find.text('직접 정한 시간이에요'), findsNothing);
        expect(await statusOf(app.db, ids.later), PlanBlockStatus.done);
        expect(find.text('과제 1 · 1시간 끝냈어요'), findsOneWidget);

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await statusOf(app.db, ids.later), PlanBlockStatus.confirmed);

        // 지우기는 블록을 지운 것으로 둔다.
        await scrollTo(tester, find.text('과제 1'));
        await tester.tap(find.text('과제 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, '지우기'));
        await tester.pumpAndSettle();
        expect(await statusOf(app.db, ids.later), PlanBlockStatus.dismissed);
        expect(find.textContaining('과제 1을 지웠어요'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('지난 일정을 펼치고 접는다', (tester) async {
        final (app, _) = await pumpHome(tester, textScale: textScale);

        // 놓친 블록은 흐리게 '놓침'으로 그리고 체크가 없다(근거 시트는 W5 PR에서 붙어 아직 누를 수 없음).
        final pastBlock = find.bySemanticsLabel(
          '과제 1, 09:00부터 10:00, 놓침, 근거 보기',
        );
        expect(pastBlock, findsNothing);

        await tapText(tester, '지난 일정 1개 보기');
        expect(find.text('지난 일정 접기'), findsOneWidget);
        expect(pastBlock, findsOneWidget);

        await tapText(tester, '지난 일정 접기');
        expect(find.text('지난 일정 1개 보기'), findsOneWidget);
        expect(pastBlock, findsNothing);

        await app.dispose(tester);
      });

      testWidgets('머리의 [계획]은 01 계획을 열고, 닫으면 02 홈으로 돌아온다', (tester) async {
        // docs/decisions.md 2026-11-19 ''아침 브리핑'을 '계획'으로 부르고 02 홈에서도 연다'.
        final (app, _) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '계획');
        expect(find.byType(BriefingScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.briefing);
        // push로 열어 02 홈이 아래에 남는다(go로 열면 하단 탭 셸이 내려감).
        expect(find.byType(TodayScreen, skipOffstage: false), findsOneWidget);

        await tester.tap(find.byTooltip('계획 닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(BriefingScreen), findsNothing);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.today);

        await app.dispose(tester);
      });

      testWidgets('일간 보기는 오늘의 09 일간을 연다', (tester) async {
        final (app, _) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '일간 보기');

        expect(app.router.state.uri.path, Routes.day(today));

        await app.dispose(tester);
      });

      testWidgets('다른 탭으로 떠나면 방금 한 답과 그 되돌리기 기록을 버린다', (tester) async {
        final (app, ids) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '했어요');
        expect(find.text('기록했어요'), findsOneWidget);

        await tapTab(tester, '나');
        await tapTab(tester, '오늘');

        expect(find.text('기록했어요'), findsNothing);
        expect(find.text('다음 할 일'), findsOneWidget);
        expect(await statusOf(app.db, ids.past), PlanBlockStatus.done);
        expect(await app.db.select(app.db.undoLog).get(), isEmpty);

        await app.dispose(tester);
      });

      testWidgets('하단 탭 밖 화면으로 갔다가 새로 연 02 홈에는 방금 한 답이 남지 않는다', (tester) async {
        final (app, _) = await pumpHome(tester, textScale: textScale);

        await tapText(tester, '했어요');
        expect(find.text('기록했어요'), findsOneWidget);

        app.router.go(Routes.briefing);
        await tester.pumpAndSettle();
        app.router.go(Routes.today);
        await tester.pumpAndSettle();

        expect(find.text('기록했어요'), findsNothing);
        expect(find.text('다음 할 일'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('LMS에 다시 로그인해야 하면 칩을 보이고, 누르면 다시 로그인 화면을 연다', (tester) async {
        final (app, _) = await pumpHome(
          tester,
          textScale: textScale,
          settings: {
            SettingKeys.lmsSessionState: LmsSessionState.reconnectRequired,
          },
        );

        final chip = find.textContaining('다시 로그인');
        await scrollTo(tester, chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(find.byType(ReloginScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.login);

        await app.dispose(tester);
      });

      testWidgets('할 일을 놓지 않은 날은 남은 빈 시간과 가장 가까운 빈 시간을 보인다', (tester) async {
        final app = await pumpTestApp(
          tester,
          now: at(11, 2),
          textScale: textScale,
        );
        await tester.pumpAndSettle();

        expect(find.text('오늘 놓은 할 일이 없어요'), findsOneWidget);
        expect(find.textContaining('가장 가까운 빈 시간은 11:05'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('이동·점심 시간 표시를 끄면 이동·점심 카드를 그리지 않는다', (tester) async {
        Future<void> addRules(TestApp app) async {
          final made = DateTime(2026, 11, 2);
          for (final (kind, params) in [
            (
              RuleKind.travel,
              const RuleParams(
                minutes: 20,
                position: TravelPosition.everyClass,
              ),
            ),
            // seedDay의 0분 점심보다 나중에 저장한 점심(점심 자리는 나중 것만 씀).
            (
              RuleKind.meal,
              const RuleParams(startMin: 690, endMin: 780, minutes: 30),
            ),
          ]) {
            await app.db
                .into(app.db.rules)
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
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }

        final (shown, _) = await pumpHome(tester, textScale: textScale);
        await addRules(shown);
        expect(find.text('이동 20분'), findsWidgets);
        expect(find.textContaining('점심 · 30분'), findsOneWidget);
        await shown.dispose(tester);

        final (hidden, _) = await pumpHome(
          tester,
          textScale: textScale,
          settings: {SettingKeys.showTravelMeal: false},
        );
        await addRules(hidden);
        expect(find.text('이동 20분'), findsNothing);
        expect(find.textContaining('점심 · 30분'), findsNothing);
        // 이동·점심 카드만 숨기고 수업은 그대로 그린다.
        expect(find.text('자료구조'), findsOneWidget);
        await hidden.dispose(tester);
      });

      testWidgets('오늘 일정을 읽지 못하면 안내만 보인다', (tester) async {
        final app = await pumpTestApp(
          tester,
          now: at(11, 2),
          textScale: textScale,
          overrides: [
            todayHomeProvider.overrideWithValue(
              AsyncError(StateError('읽기 실패(시험)'), StackTrace.empty),
            ),
          ],
        );

        expect(find.text('오늘 일정을 불러오지 못했어요'), findsOneWidget);

        await app.dispose(tester);
      });
    });
  }

  testWidgets('태블릿 가로 폭과 글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    final (app, _) = await pumpHome(
      tester,
      textScale: 2.0,
      size: tabletLandscape,
    );

    expect(find.text('과제 1, 하셨나요?'), findsOneWidget);
    await tapText(tester, '못 했어요');
    expect(find.text('11:05에 다시 놓을까요?'), findsOneWidget);

    await app.dispose(tester);
  });
}
