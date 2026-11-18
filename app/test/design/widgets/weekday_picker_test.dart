// 요일 고르기 테스트. docs/screens.md '13 시간표·고정 일정'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait;

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
          body: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('누르면 그 요일을 더하거나 빼고, 바꿀 수 없으면 누르지 못한다', (tester) async {
    var selected = <int>{1};
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => WeekdayPicker(
          selected: selected,
          onChanged: (days) => setState(() => selected = days),
        ),
      ),
    );

    await tester.tap(find.text('수'));
    await tester.pump();
    expect(selected, {1, 3});
    await tester.tap(find.text('월'));
    await tester.pump();
    expect(selected, {3});

    await _pump(tester, const WeekdayPicker(selected: {2}, onChanged: null));
    await tester.tap(find.text('화'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('요일마다 켜짐을 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, WeekdayPicker(selected: const {5}, onChanged: (_) {}));

    expect(
      tester.getSemantics(find.bySemanticsLabel('금요일')),
      matchesSemantics(
        label: '금요일',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('좁은 화면과 글자 200%에서도 넘치지 않는다(다음 줄로 넘김)', (tester) async {
    await _pump(
      tester,
      WeekdayPicker(selected: const {1, 7}, onChanged: (_) {}),
      textScale: 2,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('일'), findsOneWidget);
  });
}
