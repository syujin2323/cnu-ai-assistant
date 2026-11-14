// pop 프리셋 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/pop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    MotionLevel level = MotionLevel.full,
    Object? trigger,
  }) => tester.pumpWidget(
    MotionScope(
      level: level,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Pop(
            trigger: trigger,
            child: const SizedBox.square(dimension: 24),
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(of: find.byType(Pop), matching: find.byType(Opacity)),
      )
      .opacity;

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(of: find.byType(Pop), matching: find.byType(Transform)),
      )
      .transform
      .entry(0, 0);

  testWidgets('투명하고 .6배에서 550ms에 튀어나오고, 중간에 잠깐 1배를 넘는다', (tester) async {
    await pump(tester);
    expect(opacity(tester), 0);
    expect(scale(tester), closeTo(AppMotion.popScaleFrom, 1e-9));
    var largest = 0.0;
    for (var ms = 0; ms < 550; ms += 25) {
      await tester.pump(const Duration(milliseconds: 25));
      largest = scale(tester) > largest ? scale(tester) : largest;
      expect(opacity(tester), lessThanOrEqualTo(1));
    }
    expect(largest, greaterThan(1));
    await tester.pump(const Duration(milliseconds: 25));
    expect(scale(tester), 1);
    expect(opacity(tester), 1);
  });

  testWidgets('trigger가 바뀌면 처음부터 다시 튀고, 같으면 그대로다', (tester) async {
    await pump(tester, trigger: false);
    await tester.pumpAndSettle();
    await pump(tester, trigger: false);
    expect(opacity(tester), 1);
    await pump(tester, trigger: true);
    await tester.pump();
    expect(opacity(tester), closeTo(0, 0.05));
    await tester.pumpAndSettle();
    expect(scale(tester), 1);
  });

  testWidgets('off면 처음부터 원래대로다', (tester) async {
    await pump(tester, level: MotionLevel.off);
    expect(opacity(tester), 1);
    expect(scale(tester), 1);
  });
}
