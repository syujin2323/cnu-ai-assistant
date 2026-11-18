// 03 할 일 화면 테스트. docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// 2026-11-16(월) 10:00.
final _now = DateTime(2026, 11, 16, 10);

DateTime _at(int day, [int hour = 23, int minute = 59]) =>
    DateTime(2026, 11, day, hour, minute);

/// LMS 할 일 하나를 넣는다(원본과 할 일).
Future<int> _lmsTask(
  AppDatabase db,
  String title, {
  required int course,
  required String courseName,
  DateTime? due,
  TaskKind kind = TaskKind.assignment,
}) async {
  final key = 'k:$title';
  await db
      .into(db.lmsItems)
      .insert(
        LmsItemsCompanion.insert(
          remoteKey: key,
          courseId: course,
          courseName: courseName,
          title: title,
          kind: LmsItemKind.values.byName(kind.name),
          dueAt: Value(due),
          dueTimeUnknown: false,
          firstSeenAt: _now,
          lastSeenAt: _now,
          missCount: 0,
          contentHash: key,
        ),
      );
  return db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: title,
          kind: kind,
          dueAt: Value(due),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          lmsKey: Value(key),
        ),
      );
}

/// 개인 할 일 하나를 넣는다.
Future<int> _personalTask(AppDatabase db, String title, {DateTime? due}) => db
    .into(db.tasks)
    .insert(
      TasksCompanion.insert(
        title: title,
        kind: TaskKind.personal,
        dueAt: Value(due),
        dueTimeUnknown: false,
        status: TaskStatus.todo,
        source: const Value(EntrySource.manual),
      ),
    );

Future<int> _course(AppDatabase db, String name) =>
    db.into(db.courses).insert(CoursesCompanion.insert(name: name));

/// 과목 둘의 LMS 할 일 셋(내일, 모레, 열흘 뒤 마감)과 개인 할 일 둘(목요일 마감, 마감 없음).
Future<void> _seed(AppDatabase db) async {
  final ds = await _course(db, '자료구조');
  final la = await _course(db, '선형대수');
  await _lmsTask(db, '연결 리스트 과제', course: ds, courseName: '자료구조', due: _at(17));
  await _lmsTask(
    db,
    '고윳값 퀴즈',
    course: la,
    courseName: '선형대수',
    due: _at(18),
    kind: TaskKind.quiz,
  );
  await _lmsTask(db, '트리 과제', course: ds, courseName: '자료구조', due: _at(26));
  await _personalTask(db, '장학금 서류', due: _at(19));
  await _personalTask(db, '책 반납');
}

Future<TestApp> _open(
  WidgetTester tester, {
  bool seed = true,
  TestStart start = TestStart.loggedIn,
  double textScale = 1.0,
  Size size = phonePortrait,
}) async {
  final app = await pumpTestApp(
    tester,
    start: start,
    now: _now,
    textScale: textScale,
    size: size,
  );
  if (seed) await _seed(app.db);
  await tapTab(tester, AppStrings.tabTasks);
  return app;
}

/// [text]가 보이고 누를 수 있는지(접히지 않음).
bool _shown(String text) => find.text(text).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets('주간 할 일이 먼저 열리고 탭 숫자·요약·줄을 보인다', (tester) async {
    final app = await _open(tester);
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.bySemanticsLabel('주간 할 일 3개'), findsOneWidget);
    expect(find.bySemanticsLabel('전체 할 일 5개'), findsOneWidget);
    expect(find.text('11월 23일 (월)까지 · 남은 일 약 3시간'), findsOneWidget);
    expect(find.text('자료구조 · 과제'), findsOneWidget);
    expect(find.text('연결 리스트 과제'), findsOneWidget);
    expect(find.text('내일 23:59 마감'), findsOneWidget);
    expect(find.text('선형대수 · 퀴즈'), findsOneWidget);
    expect(find.text('개인'), findsOneWidget);
    // 7일 뒤가 넘는 마감과 마감 없는 일은 주간에 없다.
    expect(find.text('트리 과제'), findsNothing);
    expect(find.text('책 반납'), findsNothing);
    // 시간표가 없으면 제안을 만들지 않는다.
    expect(find.text('시간표를 받으면 빈 시간에 놓아요'), findsNWidgets(3));
    await app.dispose(tester);
  });

  testWidgets('전체 할 일은 마감 없음 묶음을 맨 아래에 두고, 주소의 탭도 바꾼다', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.bySemanticsLabel('전체 할 일 5개'));
    await tester.pumpAndSettle();
    expect(find.text('트리 과제'), findsOneWidget);
    // 묶음 머리와 그 줄의 마감 문구.
    expect(find.text('마감 없음'), findsNWidgets(2));
    expect(find.text('7일 안 마감 3개 · 남은 일 약 3시간'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('책 반납')).dy,
      greaterThan(tester.getTopLeft(find.text('트리 과제')).dy),
    );
    expect(
      app.router.routeInformationProvider.value.uri.toString(),
      Routes.tasksTab(TaskListTab.all),
    );

    // 화면에서 주간으로 바꾼 뒤 다시 전체 탭으로 열면(01 계획의 '할 일 전체 보기') 전체 탭이다.
    await tester.tap(find.bySemanticsLabel('주간 할 일 3개'));
    await tester.pumpAndSettle();
    expect(find.text('트리 과제'), findsNothing);
    app.router.go(Routes.tasksTab(TaskListTab.all));
    await tester.pumpAndSettle();
    expect(find.text('트리 과제'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets("'LMS만'은 개인 할 일을 접고 숫자를 LMS로 센다", (tester) async {
    final app = await _open(tester);
    expect(_shown('장학금 서류'), isTrue);
    await tester.tap(find.bySemanticsLabel('LMS 할 일만 보기'));
    await tester.pumpAndSettle();
    expect(_shown('장학금 서류'), isFalse);
    expect(find.bySemanticsLabel('주간 할 일 2개'), findsOneWidget);
    expect(find.bySemanticsLabel('전체 할 일 3개'), findsOneWidget);
    expect(
      find.text('LMS 할 일 2개 · 11월 23일 (월)까지 · 남은 일 약 2시간'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('LMS 할 일만 보기'));
    await tester.pumpAndSettle();
    expect(_shown('장학금 서류'), isTrue);
    await app.dispose(tester);
  });

  testWidgets("로그인 전에는 'LMS만' 칩이 없다", (tester) async {
    final app = await pumpTestApp(tester, now: _now);
    await writeLmsSessionState(app, LmsSessionState.disconnected);
    await _seed(app.db);
    app.router.go(Routes.tasks);
    await tester.pumpAndSettle();
    expect(find.text('LMS 로그인 전'), findsOneWidget);
    expect(find.bySemanticsLabel('LMS 할 일만 보기'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('과목별은 급한 과목부터 묶고 개인은 마지막이며 줄 머리에서 과목을 뺀다', (tester) async {
    // 모든 줄을 한 화면에 그리도록 키 큰 화면에서 본다(목록은 보이는 줄만 만든다).
    final app = await _open(tester, size: const Size(390, 1800));
    await tester.tap(find.bySemanticsLabel('전체 할 일 5개'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('과목별'));
    await tester.pumpAndSettle();
    final heads = ['자료구조', '선형대수', '개인'];
    final tops = [
      for (final head in heads) tester.getTopLeft(find.text(head)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('2개'), findsNWidgets(2));
    expect(find.text('과제'), findsNWidgets(2));
    expect(find.text('직접 추가'), findsNWidgets(2));
    expect(find.text('자료구조 · 과제'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('동그라미를 누르면 줄을 접고 완료로 저장하며 되돌릴 수 있다', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.bySemanticsLabel('연결 리스트 과제 공부 완료로 표시'));
    await tester.pumpAndSettle();
    expect(find.text('연결 리스트 과제 · 공부 완료로 옮겼어요'), findsOneWidget);
    expect(find.text('연결 리스트 과제'), findsNothing);
    expect(find.bySemanticsLabel('주간 할 일 2개'), findsOneWidget);
    final tasks = await TaskRepository(app.db).read();
    final done = switch (tasks) {
      Ok(:final value) => value.firstWhere(
        (entry) => entry.task.title == '연결 리스트 과제',
      ),
      Err(:final error) => fail('할 일을 읽지 못했다: $error'),
    };
    expect(done.task.status, TaskStatus.done);
    expect(done.task.completedAt, _now);

    await tapText(tester, '되돌리기');
    expect(find.text('연결 리스트 과제'), findsOneWidget);
    expect(_shown('연결 리스트 과제'), isTrue);
    expect(find.bySemanticsLabel('주간 할 일 3개'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('개인 할 일을 끝내면 완료로 옮겼다고 알린다', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.bySemanticsLabel('장학금 서류 완료로 표시'));
    await tester.pumpAndSettle();
    expect(find.text('장학금 서류 · 완료로 옮겼어요'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('남은 할 일이 없으면 빈 화면과 할 일 추가를 보인다', (tester) async {
    final app = await _open(tester, seed: false);
    expect(find.text('남은 할 일이 없어요'), findsOneWidget);
    expect(find.text('LMS 정보를 아직 받지 않았어요'), findsOneWidget);
    expect(find.text('새 할 일이 올라오면 정해진 시간에 가져와요'), findsOneWidget);
    // 머리의 [할 일 추가]와 빈 화면의 [할 일 추가]가 같은 폼을 연다.
    expect(find.text('할 일 추가'), findsNWidgets(2));
    await tester.tap(find.text('할 일 추가').last);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('주간이 비었으면 전체 할 일 보기로 옮긴다', (tester) async {
    final app = await _open(tester, seed: false);
    await _personalTask(app.db, '책 반납');
    await tester.pumpAndSettle();
    expect(find.text('7일 안에 마감인 할 일이 없어요'), findsOneWidget);
    expect(find.text('11월 23일 (월)까지는 비어 있어요'), findsOneWidget);
    expect(find.text('나머지 할 일 1개는 전체 할 일에 있어요'), findsOneWidget);
    await tapText(tester, '전체 할 일 보기');
    expect(find.text('책 반납'), findsOneWidget);
    expect(find.text('7일 안에 마감인 할 일이 없어요'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets("'LMS만'인데 개인 할 일만 있으면 개인 할 일도 보기로 끈다", (tester) async {
    final app = await _open(tester, seed: false);
    await _personalTask(app.db, '장학금 서류', due: _at(19));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('LMS 할 일만 보기'));
    await tester.pumpAndSettle();
    expect(find.text('남은 LMS 할 일이 없어요'), findsOneWidget);
    expect(find.text('개인 할 일 1개는 LMS만을 끄면 보여요'), findsOneWidget);
    await tapText(tester, '개인 할 일도 보기');
    expect(_shown('장학금 서류'), isTrue);
    expect(find.text('남은 LMS 할 일이 없어요'), findsNothing);
    await app.dispose(tester);
  });

  testWidgets('LMS 상태 줄을 누르면 LMS 정보 시트를 연다', (tester) async {
    final app = await _open(tester);
    await tester.tap(find.text('LMS 정보 받기 전'));
    await tester.pumpAndSettle();
    expect(find.text('LMS와 연동돼 있어요'), findsOneWidget);
    expect(find.text('새로 고침'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('데모 모드는 샘플 할 일을 보이고 넘치지 않는다', (tester) async {
    final app = await _open(tester, seed: false, start: TestStart.demo);
    expect(find.text('샘플 데이터 · 데모'), findsOneWidget);
    expect(find.byType(TaskListScreen), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^전체 할 일 ')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('과목별'));
    await tester.pumpAndSettle();
    await app.dispose(tester);
  });

  for (final (name, scale, size) in [
    ('글자 2.0', 2.0, phonePortrait),
    ('태블릿 가로', 1.0, tabletLandscape),
  ]) {
    testWidgets('$name에서도 넘치지 않는다', (tester) async {
      final app = await _open(tester, textScale: scale, size: size);
      await tester.tap(find.bySemanticsLabel('LMS 할 일만 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^전체 할 일 ')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('과목별'));
      await tester.pumpAndSettle();
      await app.dispose(tester);
    });
  }
}
