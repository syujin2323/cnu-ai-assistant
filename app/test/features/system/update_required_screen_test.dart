import 'package:cnu_ai_assistant/app/config.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/features/system/update_required_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<List<Uri>> pumpScreen(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: UpdateRequiredScreen(
            launcher: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    return opened;
  }

  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 이유와 그대로인 것, 업데이트 버튼을 보인다', (tester) async {
      await pumpScreen(tester, textScale: textScale);

      expect(find.text('새 버전으로 업데이트해 주세요'), findsOneWidget);
      expect(find.textContaining('LMS 로그인은 그대로'), findsOneWidget);
      expect(find.text('업데이트하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Android는 Play 스토어, iOS는 테스터 페이지를 연다', (tester) async {
    for (final (platform, url) in [
      (TargetPlatform.android, AppConfig.androidUpdateUrl),
      (TargetPlatform.iOS, AppConfig.iosUpdateUrl),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final opened = await pumpScreen(tester);

      await tester.tap(find.text('업데이트하기'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse(url)], reason: '$platform');
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
