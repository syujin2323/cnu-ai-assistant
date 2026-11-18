// LMS 상태 줄·칩·정보 시트에서 하는 동작 테스트. docs/screens.md 'LMS 상태 줄과 다시 로그인', '03 할 일',
// docs/architecture.md '화면 이동'·'데모 모드'.

import 'dart:async';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// 앱 위의 provider를 읽는 ref(맨 위 Consumer 위젯).
WidgetRef _ref(WidgetTester tester) =>
    tester.element(find.byElementPredicate((e) => e is WidgetRef).first)
        as WidgetRef;

/// 02 홈 화면의 context.
BuildContext _home(WidgetTester tester) =>
    tester.element(find.byType(TodayScreen));

/// 남은 LMS 할 일 하나, 끝낸 LMS 할 일 하나, 개인 할 일 하나를 넣는다.
Future<void> _addTasks(AppDatabase db, DateTime now) async {
  final course = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '자료구조'));
  for (final (key, status) in [
    ('1:1:assignment:1', TaskStatus.todo),
    ('1:1:assignment:2', TaskStatus.done),
  ]) {
    await db
        .into(db.lmsItems)
        .insert(
          LmsItemsCompanion.insert(
            remoteKey: key,
            courseId: course,
            courseName: '자료구조',
            title: key,
            kind: LmsItemKind.assignment,
            dueTimeUnknown: false,
            firstSeenAt: now,
            lastSeenAt: now,
            missCount: 0,
            contentHash: 'h',
          ),
        );
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: key,
            kind: TaskKind.assignment,
            dueTimeUnknown: false,
            status: status,
            lmsKey: Value(key),
          ),
        );
  }
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '개인 일',
          kind: TaskKind.personal,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
}

void main() {
  testWidgets('다시 로그인은 /login을 쌓고 닫으면 연 화면으로 돌아온다', (tester) async {
    final app = await pumpTestApp(tester);
    openRelogin(_home(tester), _ref(tester));
    await tester.pumpAndSettle();
    expect(find.byType(ReloginScreen), findsOneWidget);

    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('데모 모드에서는 다시 로그인과 LMS 정보 시트를 열지 않고 알린다', (tester) async {
    final app = await pumpTestApp(tester, start: TestStart.demo);
    expect(find.byType(TodayScreen), findsOneWidget);

    openRelogin(_home(tester), _ref(tester));
    await tester.pumpAndSettle();
    expect(find.byType(ReloginScreen), findsNothing);
    expect(find.text(AppStrings.demoNoLms), findsOneWidget);

    await openLmsInfoSheet(_home(tester), _ref(tester));
    await tester.pumpAndSettle();
    expect(find.text('LMS와 연동돼 있어요'), findsNothing);
    expect(find.text(AppStrings.demoNoLms), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('LMS 정보 시트는 상태와 남은 LMS 할 일 수를 보이고, 상태가 바뀌면 다시 그린다', (
    tester,
  ) async {
    final app = await pumpTestApp(tester);
    await _addTasks(app.db, app.clock.now());
    await tester.pumpAndSettle();

    var refreshes = 0;
    // 새로 고침이 끝나기 전에는 시트가 그대로다(끝나지 않게 둠).
    final refreshing = Completer<void>();
    final opened = openLmsInfoSheet(
      _home(tester),
      _ref(tester),
      onRefresh: () {
        refreshes++;
        return refreshing.future;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('LMS와 연동돼 있어요'), findsOneWidget);
    // 끝낸 LMS 할 일과 개인 할 일은 세지 않는다.
    expect(find.text('1개'), findsOneWidget);
    expect(find.text('없음'), findsOneWidget);
    await tapText(tester, '새로 고침');
    expect(refreshes, 1);
    expect(find.text('LMS와 연동돼 있어요'), findsOneWidget);

    expect(
      await SettingsRepository(
        app.db,
      ).write(SettingKeys.lmsSessionState, LmsSessionState.reconnectRequired),
      isA<Ok<void>>(),
    );
    await tester.pumpAndSettle();
    expect(find.text('LMS 로그인이 풀렸어요'), findsOneWidget);

    // [다시 로그인]은 시트를 닫고 다시 로그인 화면을 연다.
    await tapText(tester, '다시 로그인');
    await opened;
    expect(find.byType(ReloginScreen), findsOneWidget);
    expect(find.text('LMS 로그인이 풀렸어요'), findsNothing);
    app.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('시트에서 누른 새로 고침이 끝나면 시트를 닫는다', (tester) async {
    final app = await pumpTestApp(tester);
    await tester.pumpAndSettle();
    final refreshing = Completer<void>();
    final opened = openLmsInfoSheet(
      _home(tester),
      _ref(tester),
      onRefresh: () => refreshing.future,
    );
    await tester.pumpAndSettle();
    await tapText(tester, '새로 고침');
    expect(find.text('LMS와 연동돼 있어요'), findsOneWidget);

    refreshing.complete();
    await tester.pumpAndSettle();
    await opened;
    expect(find.text('LMS와 연동돼 있어요'), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('새로 고칠 수 없으면 새로 고침이 없고, LMS 계정 보기는 시트를 닫고 10 나로 간다', (
    tester,
  ) async {
    final app = await pumpTestApp(tester);

    final opened = openLmsInfoSheet(_home(tester), _ref(tester));
    await tester.pumpAndSettle();
    expect(find.text('LMS와 연동돼 있어요'), findsOneWidget);
    expect(find.text('새로 고침'), findsNothing);

    // 원격 스위치 대신 로그인 전으로 바꿔 [LMS 로그인]을, 다시 연동됨으로 두고 넘어간다.
    expect(
      await SettingsRepository(app.db)
          .write(SettingKeys.lmsSessionState, LmsSessionState.disconnected),
      isA<Ok<void>>(),
    );
    await tester.pumpAndSettle();
    expect(find.text('LMS에 로그인하지 않았어요'), findsOneWidget);
    expect(find.text('LMS 로그인'), findsOneWidget);
    // 시트는 루트 Navigator에 열린다.
    Navigator.of(_home(tester), rootNavigator: true).pop();
    await opened;
    await tester.pumpAndSettle();

    // 연결 실패는 [LMS 계정 보기]다.
    expect(
      await SettingsRepository(app.db)
          .write(SettingKeys.lmsSessionState, LmsSessionState.active),
      isA<Ok<void>>(),
    );
    await app.db
        .into(app.db.syncRuns)
        .insert(
          SyncRunsCompanion.insert(
            startedAt: app.clock.now(),
            trigger: SyncTrigger.periodic,
            scope: SyncScope.list,
            result: SyncResultKind.networkFailure,
            changedCount: 0,
            elapsedMs: 10,
          ),
        );
    await tester.pumpAndSettle();
    final again = openLmsInfoSheet(_home(tester), _ref(tester));
    await tester.pumpAndSettle();
    expect(find.text('LMS에 연결할 수 없어요'), findsOneWidget);
    await tapText(tester, 'LMS 계정 보기');
    await again;
    expect(find.byType(MeScreen), findsOneWidget);
    expect(find.text('LMS에 연결할 수 없어요'), findsNothing);
    await app.dispose(tester);
  });
}
