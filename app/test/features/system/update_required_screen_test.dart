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

  testWidgets('그 OS의 업데이트 주소를 연다', (tester) async {
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

  test('Play로 옮기기 전까지 두 OS 모두 App Distribution 테스터 페이지다', () {
    // 팀원 빌드는 Play 개발자 계정 전까지 App Distribution(Android APK, iPhone ad hoc)으로 낸다
    // (docs/decisions.md 2026-11-19). Play로 옮기면 Android 주소와 이 테스트를 함께 바꾼다.
    expect(
      AppConfig.androidUpdateUrl,
      'https://appdistribution.firebase.google.com/testerapps',
    );
    expect(AppConfig.iosUpdateUrl, AppConfig.androidUpdateUrl);
  });
}
