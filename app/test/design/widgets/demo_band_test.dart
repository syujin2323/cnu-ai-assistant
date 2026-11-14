// 데모 띠 테스트. docs/architecture.md '데모 모드'.
//
// 띠는 ink 알약에 bg 글자다. 데모를 끝내는 동안 막은 '끝내기'의 글자도 알약과 구별되어야 한다(정하지 않으면
// Material 기본 비활성색인 ink 38%가 되어 알약에 묻힌다).

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<Color?> labelColor(
    WidgetTester tester, {
    required bool exiting,
    bool failed = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: DemoBand(onExit: () {}, exiting: exiting, failed: failed),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = failed ? '다시 시도' : '끝내기';
    return DefaultTextStyle.of(tester.element(find.text(label))).style.color;
  }

  testWidgets('버튼 글자는 평소 bg이고, 끝내는 동안 막으면 알약(ink)과 구별되는 faint다', (
    tester,
  ) async {
    final colors = AppColors.light;
    expect(await labelColor(tester, exiting: false), colors.bg);

    final disabled = await labelColor(tester, exiting: true);
    expect(disabled, colors.faint);
    expect(disabled, isNot(colors.ink));

    // 끝내지 못한 뒤 '다시 시도'를 눌러 다시 끝내는 동안도 같다.
    expect(await labelColor(tester, exiting: true, failed: true), colors.faint);
  });
}
