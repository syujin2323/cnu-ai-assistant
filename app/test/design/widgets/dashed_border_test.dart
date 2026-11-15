// 점선 둥근 테두리 테스트.

import 'package:cnu_ai_assistant/design/widgets/dashed_border.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('점과 틈은 선 굵기의 3배·2배이고, 값이 바뀔 때만 다시 그린다', () {
    const painter = DashedBorderPainter(
      color: Color(0xFF6A58A8),
      radius: 16,
      width: 1.5,
    );
    expect(painter.dash, 4.5);
    expect(painter.gap, 3);
    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        const DashedBorderPainter(
          color: Color(0xFF6A58A8),
          radius: 16,
          width: 1,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('자식을 테두리 안에 그린다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: DashedBorder(
            color: Color(0xFFDCE0EC),
            radius: 14,
            background: Color(0xFFFFFFFF),
            child: SizedBox(width: 120, height: 40, child: Text('빈 시간')),
          ),
        ),
      ),
    );
    expect(find.text('빈 시간'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
