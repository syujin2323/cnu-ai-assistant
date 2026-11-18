// 시각 단계 버튼 테스트. docs/screens.md '13 시간표·고정 일정'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/widgets/time_range_fields.dart';
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

/// 상태를 들고 [TimeRangeFields]를 그린다.
class _Holder extends StatefulWidget {
  const _Holder({required this.start, required this.end, this.endHigh = 1440});

  final int start;
  final int end;
  final int endHigh;

  @override
  State<_Holder> createState() => _HolderState();
}

class _HolderState extends State<_Holder> {
  late int start = widget.start;
  late int end = widget.end;

  @override
  Widget build(BuildContext context) => TimeRangeFields(
    startMin: start,
    endMin: end,
    endHigh: widget.endHigh,
    onChanged: (s, e) => setState(() {
      start = s;
      end = e;
    }),
  );
}

Finder _button(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('15분씩 옮기고, 시작이 끝에 닿으면 끝도 함께 옮긴다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Holder(start: 540, end: 570));
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);

    await tester.tap(_button('끝 15분 늦추기'));
    await tester.pump();
    expect(find.text('09:45'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(_button('시작 15분 늦추기'));
      await tester.pump();
    }
    // 시작 09:45가 끝에 닿아 끝이 10:00으로 밀린다.
    expect(find.text('09:45'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('끝 범위를 넘기면 다음 날로 쓰고, 끝에 닿으면 버튼을 막는다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Holder(start: 1380, end: 1425, endHigh: 1455));

    await tester.tap(_button('끝 15분 늦추기'));
    await tester.pump();
    expect(find.text('24:00'), findsOneWidget);
    await tester.tap(_button('끝 15분 늦추기'));
    await tester.pump();
    expect(find.text('다음 날 00:15'), findsOneWidget);
    expect(
      tester.getSemantics(_button('끝 15분 늦추기')),
      matchesSemantics(
        label: '끝 15분 늦추기',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('끝은 시작보다 늦어야 해서 끝이 시작 바로 뒤면 앞당기지 못한다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const _Holder(start: 540, end: 555));
    expect(
      tester.getSemantics(_button('끝 15분 앞당기기')),
      matchesSemantics(
        label: '끝 15분 앞당기기',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('좁은 화면과 글자 200%에서도 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      const _Holder(start: 1380, end: 1500, endHigh: 1800),
      textScale: 2,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('다음 날 01:00'), findsOneWidget);
  });

  test('endText는 자정까지 HH:MM, 그 뒤는 다음 날이다', () {
    expect(TimeRangeFields.endText(615), '10:15');
    expect(TimeRangeFields.endText(1440), '24:00');
    expect(TimeRangeFields.endText(1560), '다음 날 02:00');
  });
}
