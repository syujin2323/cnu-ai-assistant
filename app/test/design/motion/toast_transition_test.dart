// toast 프리셋(등장·퇴장) 테스트. docs/architecture.md '모션 프리셋'.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/toast_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const toastKey = Key('toast');

  Future<void> pump(
    WidgetTester tester, {
    required bool visible,
    MotionLevel level = MotionLevel.full,
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MotionScope(
      level: level,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ToastTransition(
            visible: visible,
            child: GestureDetector(
              key: toastKey,
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox(width: 200, height: 52),
            ),
          ),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(ToastTransition),
          matching: find.byType(Opacity),
          skipOffstage: false,
        ),
      )
      .opacity;

  double offsetY(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(ToastTransition),
          matching: find.byType(Transform),
          skipOffstage: false,
        ),
      )
      .transform
      .getTranslation()
      .y;

  testWidgets('숨겨 둔 토스트는 그리지 않는다', (tester) async {
    await pump(tester, visible: false);
    expect(find.byKey(toastKey), findsNothing);
  });

  testWidgets('보이면 16pt 아래에서 450ms에 올라오고 투명도는 300ms에 다 바뀐다', (tester) async {
    await pump(tester, visible: false);
    await pump(tester, visible: true);
    expect(find.byKey(toastKey), findsOneWidget);
    expect(offsetY(tester), closeTo(AppMotion.toastOffset, 1e-9));
    expect(opacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(tester), 1);
    expect(offsetY(tester), isNot(0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(offsetY(tester), 0);
  });

  testWidgets('올라오는 곡선은 살짝 튀어 위로 넘어갔다 돌아온다', (tester) async {
    await pump(tester, visible: false);
    await pump(tester, visible: true);
    var highest = 0.0;
    for (var ms = 0; ms < 450; ms += 15) {
      await tester.pump(const Duration(milliseconds: 15));
      highest = offsetY(tester) < highest ? offsetY(tester) : highest;
    }
    expect(highest, lessThan(0));
  });

  testWidgets('숨기면 거꾸로 가고, 다 내려간 뒤에는 그리지 않으며 그동안 누를 수 없다', (tester) async {
    var taps = 0;
    await pump(tester, visible: true, onTap: () => taps++);
    await tester.pumpAndSettle();
    // 보이는 동안은 누를 수 있다.
    await tester.tap(find.byKey(toastKey));
    expect(taps, 1);
    taps = 0;
    await pump(tester, visible: false, onTap: () => taps++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(toastKey), findsOneWidget);
    await tester.tap(find.byKey(toastKey), warnIfMissed: false);
    expect(taps, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(toastKey), findsNothing);
  });

  testWidgets('처음부터 보이게 그리면 올라오며 나타난다', (tester) async {
    await pump(tester, visible: true);
    expect(opacity(tester), 0);
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
  });

  testWidgets('off면 바로 나타나고 바로 사라진다', (tester) async {
    await pump(tester, visible: true, level: MotionLevel.off);
    expect(opacity(tester), 1);
    expect(offsetY(tester), 0);
    await pump(tester, visible: false, level: MotionLevel.off);
    await tester.pump();
    expect(find.byKey(toastKey), findsNothing);
  });
}
