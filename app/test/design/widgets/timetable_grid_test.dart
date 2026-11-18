// 시간표 격자 테스트. docs/screens.md '13 시간표·고정 일정', '14 온보딩' 2단계. 과목·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/widgets/timetable_grid.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait, tabletLandscape;

ClassSlotEntry _entry(
  int id,
  String name, {
  int weekday = 1,
  int start = 540,
  int end = 615,
  String? place = '합성관101',
  bool online = false,
}) => ClassSlotEntry(
  slot: ClassSlot(
    id: id,
    courseId: id,
    weekday: weekday,
    startMin: start,
    endMin: end,
    place: place,
    online: online,
    source: SlotSource.auto,
  ),
  course: Course(id: id, name: name),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Size size = phonePortrait,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final entries = [
    _entry(1, '과목A', weekday: 1),
    _entry(2, '과목B', weekday: 3, start: 780, end: 870, online: true),
  ];

  testWidgets('요일 열에 과목과 장소를 그리고, 실시간 온라인은 온라인으로 쓴다', (tester) async {
    await _pump(tester, TimetableGrid(entries: entries, today: 3));

    expect(find.text('월'), findsOneWidget);
    expect(find.text('금'), findsOneWidget);
    expect(find.text('토'), findsNothing);
    expect(find.textContaining('과목A'), findsOneWidget);
    expect(find.textContaining('합성관101'), findsOneWidget);
    expect(find.textContaining('온라인'), findsOneWidget);
    expect(find.textContaining('09:00'), findsNothing);
  });

  testWidgets('토요일 수업이 있으면 월–일 열이고, 시각을 함께 쓸 수 있다', (tester) async {
    await _pump(
      tester,
      TimetableGrid(
        entries: [...entries, _entry(3, '과목C', weekday: 6)],
        today: 1,
        showTime: true,
      ),
    );

    expect(find.text('토'), findsOneWidget);
    expect(find.text('일'), findsOneWidget);
    expect(find.textContaining('09:00–10:15'), findsNWidgets(2));
  });

  testWidgets('칸을 누르면 그 칸을 받고, 화면 낭독기는 요일·과목·시각·장소를 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    ClassSlotEntry? tapped;
    await _pump(
      tester,
      TimetableGrid(entries: entries, today: 1, onTap: (e) => tapped = e),
    );

    await tester.tap(find.textContaining('과목B'));
    expect(tapped?.slot.id, 2);
    expect(
      find.bySemanticsLabel('월요일 과목A, 09:00–10:15, 합성관101'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('수요일 과목B, 13:00–14:30, 실시간 온라인'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('수업이 없으면 빈 격자 위에 안내를 둔다', (tester) async {
    await _pump(
      tester,
      const TimetableGrid(entries: [], today: 1, empty: Text('아직 수업이 없어요')),
    );
    expect(find.text('아직 수업이 없어요'), findsOneWidget);
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    testWidgets('크기 $size, 글자 배율 $textScale에서 넘치지 않는다', (tester) async {
      await _pump(
        tester,
        TimetableGrid(
          entries: [
            ...entries,
            _entry(4, '아주 긴 이름의 과목 실습과 토론', weekday: 2, end: 555),
          ],
          today: 2,
          showTime: true,
        ),
        textScale: textScale,
        size: size,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
