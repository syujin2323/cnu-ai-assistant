// pulse 프리셋 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/pulse.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, MotionLevel level) =>
      tester.pumpWidget(
        MotionScope(
          level: level,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: Pulse(child: SizedBox.square(dimension: 12))),
          ),
        ),
      );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(of: find.byType(Pulse), matching: find.byType(Opacity)),
      )
      .opacity;

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(Pulse),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .entry(0, 0);

  testWidgets('.6배·투명도 .9에서 1.9배·투명으로 퍼지기를 1.8초마다 되풀이한다', (tester) async {
    await pump(tester, MotionLevel.full);
    expect(scale(tester), closeTo(AppMotion.pulseScaleFrom, 1e-9));
    expect(opacity(tester), closeTo(AppMotion.pulseOpacityFrom, 1e-9));

    await tester.pump(const Duration(milliseconds: 900));
    expect(scale(tester), greaterThan(1.25));
    expect(opacity(tester), lessThan(0.45));

    await tester.pump(const Duration(milliseconds: 899));
    expect(scale(tester), closeTo(AppMotion.pulseScaleTo, 0.01));
    expect(opacity(tester), closeTo(0, 0.01));

    // 다시 처음부터.
    await tester.pump(const Duration(milliseconds: 1));
    expect(scale(tester), closeTo(AppMotion.pulseScaleFrom, 1e-9));
    await pump(tester, MotionLevel.off);
  });

  testWidgets('off면 움직이지 않고 고리를 그리지 않는다', (tester) async {
    await pump(tester, MotionLevel.off);
    await tester.pumpAndSettle();
    expect(opacity(tester), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('등급이 off로 바뀌면 멈춘다', (tester) async {
    await pump(tester, MotionLevel.full);
    await tester.pump(const Duration(milliseconds: 300));
    await pump(tester, MotionLevel.off);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
