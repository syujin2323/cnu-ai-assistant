// press 프리셋 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    MotionLevel level = MotionLevel.full,
    bool enabled = true,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MotionScope(
      level: level,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Press(
            enabled: enabled,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox.square(dimension: 100),
            ),
          ),
        ),
      ),
    ),
  );

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(Press),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .entry(0, 0);

  testWidgets('누르는 동안 180ms에 걸쳐 .97로 줄고, 떼면 180ms에 돌아온다', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Press)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // ease.emphasized라 처음에 빠르게 줄어 30ms에 이미 절반을 넘는다.
    expect(scale(tester), lessThan(0.985));
    expect(scale(tester), greaterThan(AppMotion.pressScale));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester), closeTo(AppMotion.pressScale, 1e-9));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    // 돌아올 때도 빠르게 출발한다.
    expect(scale(tester), greaterThan(0.985));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester), 1);
  });

  testWidgets('다 줄기 전에 떼도 그때 크기에서 빠르게 돌아온다', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Press)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final pressed = scale(tester);
    expect(pressed, lessThan(0.98));
    await gesture.up();
    await tester.pump();
    expect(scale(tester), closeTo(pressed, 1e-9));
    await tester.pump(const Duration(milliseconds: 30));
    expect(scale(tester) - pressed, greaterThan((1 - pressed) / 2));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester), 1);
  });

  testWidgets('막힌 버튼은 줄지 않는다', (tester) async {
    await pump(tester, enabled: false);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Press)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(tester), 1);
    await gesture.up();
  });

  testWidgets('off면 누르자마자 줄고 떼자마자 돌아온다', (tester) async {
    await pump(tester, level: MotionLevel.off);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Press)),
    );
    await tester.pump();
    expect(scale(tester), AppMotion.pressScale);
    await gesture.up();
    await tester.pump();
    expect(scale(tester), 1);
  });

  testWidgets('안쪽 버튼의 탭은 그대로 받는다', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    await tester.tap(find.byType(Press));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
