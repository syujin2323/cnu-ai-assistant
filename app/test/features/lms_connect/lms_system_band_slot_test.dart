// 01 계획·02 홈·03 할 일 맨 위의 점검·오프라인 띠. docs/screens.md '20 시스템'.
//
// 마지막 동기화 시도를 `sync_runs`에 넣어 상태를 만든다(로그인한 실제 모드, 원격 스위치 켜짐).

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_screen.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 16, 11, 2);

/// 마지막 동기화 시도를 [kind]로 남긴다.
Future<void> lastAttempt(
  TestApp app,
  WidgetTester tester,
  SyncResultKind kind, {
  String? detail,
}) async {
  await app.db
      .into(app.db.syncRuns)
      .insert(
        SyncRunsCompanion.insert(
          startedAt: app.clock.now(),
          trigger: SyncTrigger.periodic,
          scope: SyncScope.list,
          result: kind,
          changedCount: 0,
          elapsedMs: 10,
          detail: Value(detail),
        ),
      );
  await tester.pumpAndSettle();
}

AssistantArgs assistantArgs(WidgetTester tester) =>
    tester.widget<AssistantScreen>(find.byType(AssistantScreen)).args;

void main() {
  testWidgets('오프라인이면 02 홈 위에 띠를 두고, [직접 입력하기]는 06 AI 비서를 일정 폼으로 연다', (
    tester,
  ) async {
    final app = await pumpTestApp(tester, now: _now);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('인터넷에 연결되지 않았어요'), findsNothing);

    await lastAttempt(
      app,
      tester,
      SyncResultKind.networkFailure,
      detail: SyncRunDetail.offline,
    );
    expect(find.text('인터넷에 연결되지 않았어요'), findsOneWidget);
    await tapText(tester, '직접 입력하기');
    expect(
      assistantArgs(tester),
      const AssistantArgs(form: DirectAddKind.event),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);

    // 연결 실패는 오프라인과 다른 띠이고 [직접 입력하기]가 없다.
    await lastAttempt(app, tester, SyncResultKind.networkFailure);
    expect(find.text('인터넷에 연결되지 않았어요'), findsNothing);
    expect(find.text('LMS에 연결할 수 없어요'), findsOneWidget);
    expect(find.text('직접 입력하기'), findsNothing);

    // 다시 받는 데 성공하면 띠가 사라진다.
    await lastAttempt(app, tester, SyncResultKind.normal);
    expect(find.text('LMS에 연결할 수 없어요'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('03 할 일 위에도 띠를 두고, [직접 입력하기]는 할 일 폼으로 연다', (tester) async {
    final app = await pumpTestApp(tester, now: _now);
    await tapTab(tester, '할 일');
    await lastAttempt(
      app,
      tester,
      SyncResultKind.networkFailure,
      detail: SyncRunDetail.offline,
    );
    expect(find.text('인터넷에 연결되지 않았어요'), findsOneWidget);
    await tapText(tester, '직접 입력하기');
    expect(
      assistantArgs(tester),
      const AssistantArgs(form: DirectAddKind.task),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await app.dispose(tester);
  });

  testWidgets('01 계획 위에도 점검 띠를 둔다', (tester) async {
    final app = await pumpTestApp(
      tester,
      now: _now,
      briefingOpenedToday: false,
    );
    expect(find.byType(BriefingScreen), findsOneWidget);
    await lastAttempt(app, tester, SyncResultKind.serverError);
    expect(find.text('LMS가 점검 중이에요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('[다시 확인]은 지금 다시 받고 결과를 토스트로 알린다', (tester) async {
    var calls = 0;
    var next = SyncResultKind.serverError;
    final app = await pumpTestApp(
      tester,
      now: _now,
      overrides: [
        lmsListRefreshProvider.overrideWithValue(() async {
          calls++;
          return SyncResult(next);
        }),
      ],
    );
    await lastAttempt(app, tester, SyncResultKind.serverError);
    await tapText(tester, '다시 확인');
    expect(calls, 1);
    expect(find.text('아직 점검 중이에요 · 받아 둔 정보는 그대로예요'), findsOneWidget);

    next = SyncResultKind.normal;
    await tapText(tester, '다시 확인');
    expect(calls, 2);
    expect(find.text('LMS 정보를 새로 받았어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('데모 모드에서는 띠가 없다', (tester) async {
    final app = await pumpTestApp(tester, now: _now, start: TestStart.demo);
    await lastAttempt(app, tester, SyncResultKind.serverError);
    expect(find.text('LMS가 점검 중이에요'), findsNothing);
    await app.dispose(tester);
  });
}
