// 월간(`/calendar`) 화면 테스트. docs/architecture.md '화면 이동'.
//
// 폰 DB(메모리)에 수업·일정·할 일을 넣고 지금을 2026-10-29(목) 10:00으로 고정해 띄운다.
// 그리드가 날짜마다 색 막대(제목은 전체 달에서만)를, 패널이 선택한 날의 일정을 보여 주는지, 좌우 달 넘기기·위아래 모양
// 바꾸기(전체 달·데일리 스케줄, 손잡이·패널 본문·머리줄·맨 위 칸 어디서 끌어도)·To-Do 체크·오늘 버튼·두 번 눌러 일간 열기·마감 행에서 할 일 상세
// 열기가 도는지 본다. 글자 배율 1.0과 2.0에서 돌린다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/day_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/month_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/week_screen.dart';
import 'package:cnu_ai_assistant/features/search/search_screen.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/live_day.dart';
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
      testWidgets('오늘의 수업·일정·마감이 패널에 보이고, 다른 날을 고르면 패널이 바뀐다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        expect(find.text('10월'), findsOneWidget);
        expect(find.text('10월 29일에 추가'), findsOneWidget);
        // 그리드 칸에는 제목이 없으므로 제목은 패널 행에만 있다.
        expect(find.text('자구'), findsOneWidget);
        await _scrollPanelTo(tester, find.text('마감 · 아직 시간을 정하지 않음'));
        expect(find.text('과제2'), findsOneWidget);
        expect(
          find.text('10:00 - 11:15 · 공대5호관 412', skipOffstage: false),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel(RegExp(r'^10월 30일 금요일')));
        await tester.pumpAndSettle();
        expect(find.text('10월 30일에 추가'), findsOneWidget);
        await _scrollPanelTo(tester, find.text('택배 수령'));
        expect(find.text('택배 수령'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('기본 칸에는 제목 없이 색 막대만 있고, 전체 달 칸에는 제목이 있다', (tester) async {
        final app = await _pumpMonth(tester, textScale);
        final today = find.bySemanticsLabel(RegExp(r'^10월 29일 목요일'));
        final tomorrow = find.bySemanticsLabel(RegExp(r'^10월 30일 금요일'));
        Finder inCell(Finder cell, String title) =>
            find.descendant(of: cell, matching: find.text(title));

        // 기본: 칸 이름은 일정 수를 알리고, 칸 안에는 제목이 없다.
        expect(find.bySemanticsLabel('10월 29일 목요일, 오늘, 일정 2개'), findsOneWidget);
        expect(inCell(today, '자구'), findsNothing);
        expect(inCell(today, '과제2'), findsNothing);
        expect(inCell(tomorrow, '택배 수령'), findsNothing);
        expect(find.text('택배 수령'), findsNothing);

        // 전체 달: 같은 칸에 제목이 보인다.
        await tester.fling(
          find.bySemanticsLabel(RegExp(r'^10월 15일')),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();
        expect(inCell(today, '자구'), findsOneWidget);
        expect(inCell(today, '과제2'), findsOneWidget);
        expect(inCell(tomorrow, '택배 수령'), findsOneWidget);

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

      testWidgets('그리드를 왼쪽으로 넘기면 다음 달, 오른쪽은 이전 달이고 휠·오늘 버튼으로도 바뀐다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);
        final grid = find.bySemanticsLabel(RegExp(r'^10월 15일'));

        await tester.fling(grid, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('11월'), findsOneWidget);

        await tester.fling(
          find.bySemanticsLabel(RegExp(r'^11월 15일')),
          const Offset(300, 0),
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

        await tester.fling(grid, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('오늘로 이동'));
        await tester.pumpAndSettle();
        expect(find.text('10월'), findsOneWidget);
        expect(find.text('10월 29일에 추가'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('그리드를 아래로 넘기면 전체 달, 위로 넘기면 기본, 한 번 더 위로 넘기면 데일리 스케줄이다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);
        final grid = find.bySemanticsLabel(RegExp(r'^10월 15일'));

        await tester.fling(grid, const Offset(0, 300), 1000);
        await tester.pumpAndSettle();
        // 패널이 사라지고, 칸마다 일정 제목이 보이며 하단 바는 그대로다.
        expect(find.bySemanticsLabel('하루 시간표 펼치기'), findsNothing);
        expect(find.text('10:00 - 11:15 · 공대5호관 412'), findsNothing);
        expect(find.text('자구'), findsWidgets);
        expect(find.text('과제2'), findsWidgets);
        expect(find.byType(CalendarBottomBar), findsOneWidget);
        expect(find.text('10월'), findsOneWidget);

        // 전체 달에서도 좌우로 달이 바뀐다.
        await tester.fling(grid, const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('11월'), findsOneWidget);
        await tester.fling(
          find.bySemanticsLabel(RegExp(r'^11월 15일')),
          const Offset(300, 0),
          1000,
        );
        await tester.pumpAndSettle();

        await tester.fling(grid, const Offset(0, -300), 1000);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('하루 시간표 펼치기'), findsOneWidget);
        expect(find.text('10월'), findsOneWidget);

        await tester.fling(grid, const Offset(0, -300), 1000);
        await tester.pumpAndSettle();
        expect(find.text('29일 목요일 데일리 스케줄'), findsOneWidget);
        expect(find.byType(CalendarBottomBar), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('패널 머리에 음력이, 전체 달의 일요일 칸에만 짧은 음력이 보인다', (tester) async {
        final app = await _pumpMonth(tester, textScale);
        final grid = find.bySemanticsLabel(RegExp(r'^10월 15일'));

        // 기본: 선택한 날(10월 29일 목) 머리에 음력. 그리드 칸에는 음력이 없다.
        expect(find.text('음력 9월 19일'), findsOneWidget);
        expect(find.text('9.15'), findsNothing);
        await tester.tap(find.bySemanticsLabel(RegExp(r'^10월 30일 금요일')));
        await tester.pumpAndSettle();
        expect(find.text('음력 9월 20일'), findsOneWidget);
        expect(find.text('음력 9월 19일'), findsNothing);

        // 전체 달: 일요일 칸(달 밖 9월 27일과 10월 18일·25일)에만 '월.일'.
        await tester.fling(grid, const Offset(0, 300), 1000);
        await tester.pumpAndSettle();
        expect(find.text('8.17'), findsOneWidget);
        expect(find.text('9.15'), findsOneWidget);
        expect(find.text('9.8'), findsOneWidget);
        // 일요일이 아닌 날(10월 29일 목, 음력 9월 19일)에는 적지 않는다.
        expect(find.text('9.19'), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('손잡이를 누르면 데일리 스케줄로 펼쳐져 시간표·To-Do·오늘 미배정 할 일이 보이고 '
          '하단 바가 숨으며, X로 접으면 돌아온다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();

        // 그리드와 하단 바는 숨고 패널이 상단바 아래를 채운다.
        expect(find.bySemanticsLabel(RegExp(r'^10월 15일')), findsNothing);
        expect(find.byType(CalendarBottomBar), findsNothing);
        expect(find.text('10월'), findsOneWidget);
        expect(find.text('29일 목요일 데일리 스케줄'), findsOneWidget);
        expect(find.byType(LiveDay), findsOneWidget);
        expect(
          find.textContaining('자구 · 1시간 15분 남음', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('To-Do'), findsOneWidget);
        expect(_checkbox('과제2'), findsOneWidget);
        final todoHeader = find.text('오늘 해야 할 미배정 할 일 1개');
        await tester.ensureVisible(todoHeader);
        expect(todoHeader, findsOneWidget);
        await tester.ensureVisible(find.text('오늘 마감 · 남은 2시간'));
        expect(find.text('오늘 마감 · 남은 2시간'), findsOneWidget);

        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp(r'^10월 15일')), findsOneWidget);
        expect(find.byType(CalendarBottomBar), findsOneWidget);
        expect(find.text('29일 목요일 데일리 스케줄'), findsNothing);

        // 손잡이를 다시 누르면 펼치고, 한 번 더 누르면 접힌다.
        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('하루 시간표 접기'));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarBottomBar), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('To-Do에서 블록과 마감을 체크하면 완료로 저장되고, 풀거나 되돌리면 원래대로다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);
        final blockId = await app.db
            .into(app.db.planBlocks)
            .insert(
              PlanBlocksCompanion.insert(
                taskId: app.taskId,
                startAt: DateTime(2026, 10, 29, 14),
                endAt: DateTime(2026, 10, 29, 16),
                status: PlanBlockStatus.confirmed,
                source: BlockSource.manual,
              ),
            );
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();
        // 블록(14:00)이 먼저, 그날 마감(23:59)이 다음이다.
        expect(_checkbox('과제2'), findsNWidgets(2));
        Future<void> tapBox(int index) async {
          await tester.ensureVisible(_checkbox('과제2').at(index));
          await tester.pumpAndSettle();
          await tester.tap(_checkbox('과제2').at(index));
          await tester.pumpAndSettle();
        }

        Future<PlanBlockStatus> blockStatus() async => (await (app.db.select(
          app.db.planBlocks,
        )..where((b) => b.id.equals(blockId))).getSingle()).status;
        Future<TaskStatus> taskStatus() async =>
            (await app.db.select(app.db.tasks).getSingle()).status;

        await tapBox(0);
        expect(await blockStatus(), PlanBlockStatus.done);
        final undo = await app.db.select(app.db.undoLog).getSingle();
        expect(undo.action, UndoAction.update);
        expect(undo.beforeJson, '{"status":"confirmed"}');
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data == '과제2' &&
                w.style?.decoration == TextDecoration.lineThrough,
          ),
          findsOneWidget,
        );
        await tapBox(0);
        expect(await blockStatus(), PlanBlockStatus.confirmed);

        await tapBox(1);
        expect(await taskStatus(), TaskStatus.done);
        await tapBox(1);
        expect(await taskStatus(), TaskStatus.todo);

        // 체크한 뒤 스낵바의 되돌리기로도 돌아간다.
        await tapBox(1);
        expect(await taskStatus(), TaskStatus.done);
        expect(find.text('과제2 완료로 표시했어요'), findsOneWidget);
        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await taskStatus(), TaskStatus.todo);

        await app.dispose(tester);
      });

      testWidgets('드로어의 미배정 할 일에 시간을 덜 정한 할 일이 급한 순서로 보인다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.byTooltip('메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('미배정 할 일'));
        await tester.pumpAndSettle();

        expect(find.text('과제2'), findsOneWidget);
        expect(find.text('오늘 마감 · 남은 2시간'), findsOneWidget);
        expect(find.text('배치'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('시간을 정하지 않은 마감 행을 누르면 배치 시트가 열리고, 말로 정해 저장하면 '
          '확정 블록이 생기며 되돌리기로 지운다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        final row = find.text('마감 · 아직 시간을 정하지 않음');
        await _scrollPanelTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('할 일 배치'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, '오늘 오후 2시부터 2시간');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await _tapInSheet(tester, find.text('저장'));

        final blocks = await app.db.select(app.db.planBlocks).get();
        expect(blocks.single.taskId, app.taskId);
        expect(blocks.single.startAt, DateTime(2026, 10, 29, 14));
        expect(blocks.single.endAt, DateTime(2026, 10, 29, 16));
        expect(blocks.single.source, BlockSource.ai);
        expect(find.text('10월 29일 목요일 오후 2시에 시간을 정했어요'), findsOneWidget);
        await _scrollPanelTo(tester, find.text('마감 · 시간 정함'));
        expect(find.text('마감 · 시간 정함'), findsOneWidget);

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(await app.db.select(app.db.planBlocks).get(), isEmpty);

        await app.dispose(tester);
      });

      testWidgets('마감 뒤로 정하면 저장할 수 없고, 겹치는 일정은 경고한다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        final row = find.text('마감 · 아직 시간을 정하지 않음');
        await _scrollPanelTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '오전 10시부터 1시간');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.textContaining('겹치는 일정: 자구 10:00–11:15'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, '내일 오후 3시');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.textContaining('마감 전으로 정해 주세요'), findsOneWidget);
        await tester.ensureVisible(find.text('저장'));
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('저장'),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );

        await app.dispose(tester);
      });

      testWidgets('추가 알약(직접 입력)으로 일정을 더하면 패널에 보인다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.text('10월 29일에 추가'));
        await tester.pumpAndSettle();
        expect(find.text('일정 추가'), findsOneWidget);

        await tester.enterText(find.widgetWithText(TextField, '제목'), '헬스');
        await tester.pumpAndSettle();
        await _tapInSheet(tester, find.text('저장'));

        final events = await app.db.select(app.db.events).get();
        expect(events.map((e) => e.title), contains('헬스'));
        final added = events.firstWhere((e) => e.title == '헬스');
        expect(added.startAt, DateTime(2026, 10, 29, 11));
        expect(added.source, EventSource.manual);
        await _scrollPanelTo(tester, find.text('헬스'));
        expect(find.text('헬스'), findsWidgets);

        await app.dispose(tester);
      });

      testWidgets('+(말로 입력)로 문장을 해석하면 제목·시각·장소가 채워진다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.byTooltip('말로 일정 추가'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          '내일 저녁 7시 공대5호관에서 팀플 2시간',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('10월 30일 금요일'), findsOneWidget);
        expect(find.text('오후 7시 시작'), findsOneWidget);
        expect(find.text('오후 9시 끝'), findsOneWidget);
        await _tapInSheet(tester, find.text('저장'));

        final event = (await app.db.select(app.db.events).get()).firstWhere(
          (e) => e.title == '팀플',
        );
        expect(event.place, '공대5호관');
        expect(event.source, EventSource.ai);
        expect(event.endAt, DateTime(2026, 10, 30, 21));

        await app.dispose(tester);
      });
      testWidgets('주간·일간은 시간표에 일정을 그리고, 요일을 누르거나 넘기면 그날로 간다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        app.router.go(Routes.calendarWeek);
        await tester.pumpAndSettle();
        expect(find.byType(WeekScreen), findsOneWidget);
        expect(
          find.bySemanticsLabel('택배 수령, 14:00부터 16:00까지', skipOffstage: false),
          findsOneWidget,
        );
        await tester.tap(find.bySemanticsLabel(RegExp(r'^10월 30일 금요일')));
        await tester.pumpAndSettle();
        expect(app.router.state.uri.path, Routes.calendarDay('2026-10-30'));
        expect(find.byType(DayScreen), findsOneWidget);

        app.router.go(Routes.calendarDay('2026-10-29'));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('자구, 10:00부터 11:15까지', skipOffstage: false),
          findsOneWidget,
        );
        await tester.fling(find.byType(DayScreen), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(app.router.state.uri.path, Routes.calendarDay('2026-10-30'));
        expect(find.text('10월 30일에 추가'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('연간에서 달을 누르면 그 달 월간이고, 일정 목록은 날짜별로 모은다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        app.router.go(Routes.calendarYear);
        await tester.pumpAndSettle();
        expect(find.text('2026년'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('2026년 11월'));
        await tester.pumpAndSettle();
        expect(find.byType(MonthScreen), findsOneWidget);
        expect(find.text('11월'), findsOneWidget);

        app.router.go(Routes.calendarAgenda);
        await tester.pumpAndSettle();
        expect(find.text('10월 29일 목요일 · 오늘'), findsOneWidget);
        expect(find.text('택배 수령', skipOffstage: false), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('검색은 제목으로 찾고 종류로 거르며, 결과를 누르면 월간에서 그날을 고른다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.byTooltip('검색'));
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);

        await tester.tap(find.widgetWithText(FilterChip, '마감'));
        await tester.pumpAndSettle();
        expect(find.text('1건'), findsOneWidget);
        expect(find.text('과제2'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilterChip, '마감'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '택배');
        await tester.pumpAndSettle();
        expect(find.text('1건'), findsOneWidget);
        await tester.tap(find.text('택배 수령'));
        await tester.pumpAndSettle();
        expect(find.byType(MonthScreen), findsOneWidget);
        expect(find.text('10월 30일에 추가'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('모션이 켜져 있으면 달이 옆으로 밀리며 바뀌고, 데일리 스케줄도 펼쳐진다', (tester) async {
        final app = await _pumpMonth(
          tester,
          textScale,
          motion: MotionLevel.full,
        );

        await tester.fling(
          find.bySemanticsLabel(RegExp(r'^10월 15일')),
          const Offset(-300, 0),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // 밀리는 동안은 두 달이 함께 있다.
        expect(find.bySemanticsLabel(RegExp(r'^10월 15일')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^11월 15일')), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('11월'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^10월 15일')), findsNothing);

        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();
        expect(find.text('29일 목요일 데일리 스케줄'), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('손잡이가 아니어도 패널 본문을 위로 끌면 데일리 스케줄, 아래로 끌면 전체 달이다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.dragFrom(_panelBody(tester), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text('29일 목요일 데일리 스케줄'), findsOneWidget);
        expect(find.byType(CalendarBottomBar), findsNothing);

        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('하루 시간표 펼치기'), findsOneWidget);

        // 목록이 맨 위이므로 아래로 당기면 패널이 사라지고 칸마다 제목이 보인다.
        await tester.dragFrom(_panelBody(tester), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('하루 시간표 펼치기'), findsNothing);
        expect(
          find.descendant(
            of: find.bySemanticsLabel(RegExp(r'^10월 30일 금요일')),
            matching: find.text('택배 수령'),
          ),
          findsOneWidget,
        );
        expect(find.byType(CalendarBottomBar), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('데일리 스케줄에서 머리줄이나 맨 위의 To-Do 칸을 아래로 끌면 기본으로 접힌다', (
        tester,
      ) async {
        final app = await _pumpMonth(tester, textScale);

        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();
        await tester.drag(find.text('29일 목요일 데일리 스케줄'), const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsNothing);
        expect(find.byType(CalendarBottomBar), findsOneWidget);
        expect(find.bySemanticsLabel('하루 시간표 펼치기'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('하루 시간표 펼치기'));
        await tester.pumpAndSettle();
        // 위로 끌면 칸 안에서 굴러갈 뿐 접히지 않는다. 글자가 크면 머리가 밀려 나가므로 처음 자리를 잡는다.
        final todo = tester.getCenter(find.text('To-Do'));
        await tester.dragFrom(todo, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsOneWidget);
        // 아래로 끌면 칸을 맨 위로 되감고, 맨 위에서 더 당긴 만큼 패널이 내려와 접힌다.
        await tester.dragFrom(todo, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsNothing);
        expect(find.byType(CalendarBottomBar), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('천천히 끌어도 손잡이는 놓은 위치로, 그리드는 끈 거리로 달을 넘긴다', (tester) async {
        final app = await _pumpMonth(tester, textScale);

        final handle = find.bySemanticsLabel('하루 시간표 펼치기');
        await tester.timedDrag(
          handle,
          const Offset(0, -400),
          const Duration(seconds: 2),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsOneWidget);

        await tester.timedDrag(
          find.bySemanticsLabel('하루 시간표 접기'),
          const Offset(0, 500),
          const Duration(seconds: 2),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsNothing);

        // 절반을 넘지 않게 조금만 올리면 다시 접힌 채로 돌아온다.
        await tester.timedDrag(
          find.bySemanticsLabel('하루 시간표 펼치기'),
          const Offset(0, -60),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LiveDay), findsNothing);

        await tester.timedDrag(
          find.bySemanticsLabel(RegExp(r'^10월 15일')),
          const Offset(-120, 0),
          const Duration(seconds: 2),
        );
        await tester.pumpAndSettle();
        expect(find.text('11월'), findsOneWidget);

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
Future<_MonthApp> _pumpMonth(
  WidgetTester tester,
  double textScale, {
  MotionLevel motion = MotionLevel.off,
}) async {
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
        motionLevelProvider.overrideWithValue(motion),
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

/// 이름이 [label]인 To-Do 체크 칸.
Finder _checkbox(String label) => find.byWidgetPredicate(
  (widget) => widget is Checkbox && widget.semanticLabel == label,
);

/// 시트 안의 [target]이 보이게 한 뒤 누른다(글자가 크면 아래 버튼은 스크롤해야 보인다).
Future<void> _tapInSheet(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 선택일 패널을 [target]이 보이게 내린다. 기본 모양 목록은 끌면 패널이 움직이므로, 화면 읽기
/// 초점이 옮겨 갈 때처럼 [Scrollable.ensureVisible]로 내린다(목록은 한 번에 모두 그린다).
Future<void> _scrollPanelTo(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

/// 기본 모양 패널 본문(손잡이가 아닌 곳)에서 끌 위치: 패널 머리의 날짜 숫자('29'). 그리드 칸의
/// 숫자보다 뒤에 그려진다.
Offset _panelBody(WidgetTester tester) =>
    tester.getCenter(find.text('29').last);
