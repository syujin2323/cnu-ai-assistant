// rise 프리셋 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    MotionLevel level = MotionLevel.full,
    RiseStyle style = RiseStyle.card,
    Duration delay = Duration.zero,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MotionScope(
      level: level,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Rise(
            style: style,
            delay: delay,
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

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(of: find.byType(Rise), matching: find.byType(Opacity)),
      )
      .opacity;

  Matrix4 transform(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(Rise),
          matching: find.byType(Transform),
        ),
      )
      .transform;

  bool blurred(WidgetTester tester) => find
      .descendant(of: find.byType(Rise), matching: find.byType(ImageFiltered))
      .evaluate()
      .isNotEmpty;

  testWidgets('처음에는 투명하고 아래·작게·흐리게 있다가 800ms 뒤 원래대로 선다', (tester) async {
    await pump(tester);
    expect(opacity(tester), 0);
    expect(transform(tester).getTranslation().y, closeTo(18, 1e-9));
    expect(transform(tester).entry(0, 0), closeTo(0.985, 1e-9));
    expect(blurred(tester), isTrue);

    await tester.pump(const Duration(milliseconds: 160));
    // ease.emphasized라 처음 5분의 1 시간에 절반 넘게 떠오른다.
    expect(opacity(tester), greaterThan(0.5));
    expect(opacity(tester), lessThan(1));

    await tester.pump(const Duration(milliseconds: 640));
    expect(opacity(tester), 1);
    expect(transform(tester).getTranslation().y, 0);
    expect(transform(tester).entry(0, 0), 1);
    expect(blurred(tester), isFalse);
  });

  testWidgets('홈 시간표 카드는 12pt·.97에서 600ms, 브리핑은 900ms다', (tester) async {
    await pump(tester, style: RiseStyle.homeCard);
    expect(transform(tester).getTranslation().y, closeTo(12, 1e-9));
    expect(transform(tester).entry(0, 0), closeTo(0.97, 1e-9));
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(tester), 1);

    await pump(tester, style: RiseStyle.briefing);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, style: RiseStyle.briefing);
    await tester.pump(const Duration(milliseconds: 800));
    expect(opacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(tester), 1);
  });

  testWidgets('delay 동안은 처음 상태이고 그 뒤에 떠오른다', (tester) async {
    await pump(tester, delay: AppMotion.staggerList * 2);
    await tester.pump(const Duration(milliseconds: 110));
    expect(opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(AppMotion.rise);
    expect(opacity(tester), 1);
  });

  testWidgets('off면 처음부터 원래대로다', (tester) async {
    await pump(tester, level: MotionLevel.off, delay: AppMotion.staggerList);
    expect(opacity(tester), 1);
    expect(transform(tester).getTranslation().y, 0);
    expect(blurred(tester), isFalse);
  });

  testWidgets('떠오르는 동안에도 누를 수 있다', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    await tester.tap(find.byType(Rise), warnIfMissed: false);
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
}
