// 세로 하루 시간표 위젯 테스트. docs/screens.md '02 홈'·'09 일간'·'할 일 블록'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline_layout.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait, tabletLandscape;

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 16, hour, minute);

final day = DateTime(2026, 11, 16);

final lesson = ClassItem(
  TimeSpan(at(10, 30), at(11, 45)),
  slot: const ClassSlot(
    id: 1,
    courseId: 7,
    weekday: 1,
    startMin: 630,
    endMin: 705,
    place: '자연과학관 105',
    campus: Campus.daedeok,
    online: false,
    source: SlotSource.auto,
  ),
  place: '자연과학관 105',
);

BlockItem block(
  int id,
  DateTime start,
  DateTime end,
  PlanBlockStatus status, {
  String title = '연결 리스트 구현',
}) => BlockItem(
  TimeSpan(start, end),
  block: PlanBlock(
    id: id,
    taskId: id,
    startAt: start,
    endAt: end,
    status: status,
    source: BlockSource.manual,
  ),
  entry: TaskEntry(
    task: Task(
      id: id,
      title: title,
      kind: TaskKind.assignment,
      dueAt: DateTime(2026, 11, 18, 23, 59),
      dueTimeUnknown: false,
      status: TaskStatus.todo,
    ),
  ),
);

final items = <DayItem>[
  lesson,
  MealItem(TimeSpan(at(11, 55), at(12, 35))),
  block(1, at(13), at(13, 30), PlanBlockStatus.confirmed, title: '퀴즈'),
  block(2, at(14), at(15, 30), PlanBlockStatus.done),
  block(3, at(16), at(17), PlanBlockStatus.suggested, title: '영상'),
  EventItem(
    TimeSpan(at(19), at(20, 30)),
    event: Event(
      id: 1,
      title: '동아리 회의',
      startAt: at(19),
      endAt: at(20, 30),
      allDay: false,
      place: '학생회관',
      source: EventSource.manual,
    ),
  ),
];
final free = [TimeSpan(at(17, 15), at(18, 45))];

Future<void> pump(
  WidgetTester tester, {
  DateTime? now,
  double textScale = 1,
  Size size = phonePortrait,
  ValueChanged<DayItem>? onItemTap,
  ValueChanged<BlockItem>? onBlockCheck,
  ValueChanged<TimeSpan>? onFreeTap,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  final when = now ?? at(9);
  await tester.pumpWidget(
    MotionScope(
      level: MotionLevel.off,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: DayTimeline(
                layout: layoutDayTimeline(
                  day: day,
                  items: items,
                  free: free,
                  now: when,
                  today: true,
                  windowEndMin: 1380,
                ),
                day: day,
                now: when,
                dayBoundaryMin: Defaults.dayBoundaryMin,
                courseNames: const {7: '선형대수'},
                onItemTap: onItemTap,
                onBlockCheck: onBlockCheck,
                onFreeTap: onFreeTap,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('수업·일정·할 일 블록·점심·빈 시간을 그리고 시 글자를 단다', (tester) async {
    await pump(tester);
    expect(find.text('선형대수'), findsOneWidget);
    expect(find.text('퀴즈'), findsOneWidget);
    expect(find.text('연결 리스트 구현'), findsOneWidget);
    expect(find.text('영상'), findsOneWidget);
    expect(find.text('동아리 회의'), findsOneWidget);
    expect(find.text('점심 · 40분 비워 뒀어요'), findsOneWidget);
    expect(find.text('빈 시간 1시간 30분'), findsOneWidget);
    expect(find.text('놓기'), findsOneWidget);
    // 수업은 '수업 · 장소 · 시각', 제안은 '제안 · 종류 · 마감'을 덧붙인다.
    expect(find.text('수업 · 자연과학관 105 · 10:30–11:45'), findsOneWidget);
    // 1시간 카드는 짧은 모양이라 오른쪽에 '종류 · 시각'만 보인다.
    expect(find.text('제안 · 16:00–17:00'), findsOneWidget);
    // 1시간 30분 카드는 중간 모양이라 '종류 · 할 일 종류 · 마감 · 시각'을 덧붙인다.
    expect(find.text('완료 · 과제 · 모레 23:59 마감 · 14:00–15:30'), findsOneWidget);
    expect(find.textContaining('9'), findsWidgets);
  });

  testWidgets('카드·체크·빈 시간을 누르면 그 항목을 넘긴다', (tester) async {
    final tapped = <Object>[];
    await pump(
      tester,
      onItemTap: tapped.add,
      onBlockCheck: tapped.add,
      onFreeTap: tapped.add,
    );
    await tester.tap(find.text('선형대수'));
    await tester.tap(find.text('퀴즈'));
    await tester.tap(find.bySemanticsLabel('퀴즈 완료로 표시'));
    await tester.tap(find.text('빈 시간 1시간 30분'));
    await tester.pumpAndSettle();
    expect(tapped, [lesson, items[2], items[2], free.single]);
  });

  testWidgets('확정·완료 블록에만 체크가 있고, 제안·놓침에는 없다', (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel('퀴즈 완료로 표시'), findsOneWidget);
    expect(find.bySemanticsLabel('연결 리스트 구현 완료 취소'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('영상 완료')), findsNothing);
  });

  testWidgets('읽기 도구는 카드마다 제목·시각·종류와 할 수 있는 일을 한 번에 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, onItemTap: (_) {}, onFreeTap: (_) {});
    expect(
      find.bySemanticsLabel('선형대수, 10:30부터 11:45, 수업, 정보 보기'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('영상, 16:00부터 17:00, 제안, 근거 보기'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('17:15부터 1시간 30분 빈 시간, 할 일 놓기'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('지금 하는 카드는 진행 중과 남은 분을 보이고 지금 선을 그린다', (tester) async {
    await pump(tester, now: at(10, 50));
    expect(find.text('진행 중 · 55분 남음 · 자연과학관 105'), findsOneWidget);
    expect(find.text('10:50'), findsOneWidget);
  });

  for (final (name, size) in [
    ('폰', phonePortrait),
    ('태블릿 가로', tabletLandscape),
  ]) {
    testWidgets('$name 폭, 글자 200%에서도 넘치지 않는다', (tester) async {
      await pump(tester, textScale: 2, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
