// layer 프리셋(전체 화면 덮개) 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/layer_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<void> pump(WidgetTester tester, MotionLevel level) =>
      tester.pumpWidget(
        MotionScope(
          level: level,
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('아래 화면')),
          ),
        ),
      );

  void open(MotionLevel level) => navigator.currentState!.push(
    layerRoute<void>(
      motion: level,
      builder: (context) => const Scaffold(body: Text('덮개')),
    ),
  );

  double coverLeft(WidgetTester tester) =>
      tester.getTopLeft(find.text('덮개')).dx;

  testWidgets('오른쪽에서 550ms에 들어오고, 닫으면 오른쪽으로 나간다', (tester) async {
    await pump(tester, MotionLevel.full);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    open(MotionLevel.full);
    // 첫 프레임은 Hero 계산을 위해 화면 밖에 그린다.
    await tester.pump();
    await tester.pump();
    expect(coverLeft(tester), closeTo(width, 0.5));

    await tester.pump(const Duration(milliseconds: 110));
    // ease.emphasized라 처음 5분의 1 시간에 절반 넘게 들어온다.
    expect(coverLeft(tester), lessThan(width / 2));
    expect(coverLeft(tester), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 440));
    expect(coverLeft(tester), 0);
    await tester.pumpAndSettle();

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    // 나갈 때도 빠르게 출발한다.
    expect(coverLeft(tester), greaterThan(width / 2));
    await tester.pump(const Duration(milliseconds: 440));
    expect(coverLeft(tester), closeTo(width, 0.5));
    await tester.pumpAndSettle();
    expect(find.text('덮개'), findsNothing);
  });

  testWidgets('off면 바로 열고 바로 닫는다', (tester) async {
    await pump(tester, MotionLevel.off);
    open(MotionLevel.off);
    await tester.pump();
    await tester.pump();
    expect(coverLeft(tester), 0);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump();
    expect(find.text('덮개'), findsNothing);
  });
}
