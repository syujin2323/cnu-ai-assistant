// 외부 링크 열기 테스트. docs/architecture.md '한눈에 보기'의 패키지 줄(`url_launcher`).
//
// `canLaunchUrl` 없이 바로 열고, 열지 못하면 주소를 보이고 복사하게 한다.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/widgets/external_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 합성 주소.
final _uri = Uri.parse('https://example.invalid/privacy');

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const Scaffold()),
    );
    return tester.element(find.byType(Scaffold));
  }

  /// 클립보드에 쓴 글자를 모은다.
  List<String> mockClipboard(WidgetTester tester) {
    final copied = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return copied;
  }

  testWidgets('열리면 아무것도 띄우지 않는다', (tester) async {
    final context = await pump(tester);
    final opened = <Uri>[];
    await openExternalLink(
      context,
      _uri,
      launcher: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(opened, [_uri]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("열지 못하면 주소를 보이고, '주소 복사'는 복사한 뒤 닫는다", (tester) async {
    final copied = mockClipboard(tester);
    final context = await pump(tester);
    final done = openExternalLink(context, _uri, launcher: (_) async => false);
    await tester.pumpAndSettle();
    expect(find.text('링크를 열지 못했어요'), findsOneWidget);
    expect(find.text(_uri.toString()), findsOneWidget);

    await tester.tap(find.text('주소 복사'));
    await tester.pumpAndSettle();
    expect(copied, [_uri.toString()]);
    expect(find.byType(AlertDialog), findsNothing);
    await done;
  });

  testWidgets("'닫기'는 복사하지 않고 닫는다", (tester) async {
    final copied = mockClipboard(tester);
    final context = await pump(tester);
    final done = openExternalLink(context, _uri, launcher: (_) async => false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    await done;
  });
}
