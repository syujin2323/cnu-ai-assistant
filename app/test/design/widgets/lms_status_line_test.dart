// LMS 상태 줄과 '다시 로그인' 칩 테스트. docs/screens.md 'LMS 상태 줄과 다시 로그인'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait, tabletLandscape;

LmsStatus _status(LmsStatusKind kind, String text) =>
    LmsStatus(kind: kind, text: text);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Size size = phonePortrait,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

/// 그려진 아이콘 이름과 색.
(AppIconName, Color?) _icon(WidgetTester tester) {
  final icon = tester.widget<AppIcon>(find.byType(AppIcon));
  return (icon.name, icon.color);
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  final colors = AppColors.light;

  testWidgets('상태마다 아이콘과 색이 다르다', (tester) async {
    for (final (kind, icon, color) in [
      (LmsStatusKind.synced, AppIconName.refresh, colors.muted),
      (LmsStatusKind.demo, AppIconName.refresh, colors.muted),
      (LmsStatusKind.connectionFailed, AppIconName.warning, colors.alert),
      (LmsStatusKind.reloginNeeded, AppIconName.refresh, colors.accent),
      (LmsStatusKind.maintenance, AppIconName.info, colors.muted),
      (LmsStatusKind.paused, AppIconName.info, colors.muted),
      (LmsStatusKind.beforeLogin, AppIconName.info, colors.muted),
    ]) {
      await _pump(tester, LmsStatusLine(status: _status(kind, '문구')));
      expect(_icon(tester), (icon, color), reason: '$kind');
      expect(_textColor(tester, '문구'), color, reason: '$kind');
    }
  });

  testWidgets('누를 수 있으면 버튼으로 읽고(할 수 있는 일을 덧붙임) 누르면 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      LmsStatusLine(
        status: _status(LmsStatusKind.synced, 'LMS 정보 12분 전'),
        onTap: () => taps++,
        tapHint: '눌러서 새로 고침',
      ),
    );
    expect(
      tester.getSemantics(find.byType(LmsStatusLine)),
      isSemantics(
        label: 'LMS 정보 12분 전, 눌러서 새로 고침',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('LMS 정보 12분 전'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(LmsStatusLine)).height,
      greaterThanOrEqualTo(AppSize.minTouch),
    );

    // 누를 수 없으면 문구만 읽는다.
    await _pump(
      tester,
      LmsStatusLine(
        status: _status(LmsStatusKind.paused, lmsPausedText),
        tapHint: '자세히 보기',
      ),
    );
    expect(
      tester.getSemantics(find.byType(LmsStatusLine)),
      isSemantics(label: lmsPausedText, isButton: false, hasTapAction: false),
    );
    handle.dispose();
  });

  testWidgets('새로 고치는 중이면 불러오는 중이고 누를 수 없다', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      LmsStatusLine(
        status: _status(LmsStatusKind.synced, 'LMS 정보 12분 전'),
        onTap: () => taps++,
        busy: true,
      ),
    );
    expect(find.text(LmsStatusLine.busyText), findsOneWidget);
    expect(find.text('LMS 정보 12분 전'), findsNothing);
    await tester.tap(find.text(LmsStatusLine.busyText));
    expect(taps, 0);
  });

  testWidgets('다시 로그인 칩은 강조색 글자와 새로 고침 아이콘이고 누르면 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    const text = 'LMS 정보 3시간 전 · 다시 로그인';
    await _pump(
      tester,
      LmsReloginChip(
        status: _status(LmsStatusKind.reloginNeeded, text),
        onTap: () => taps++,
      ),
    );
    expect(_icon(tester), (AppIconName.refresh, colors.accent));
    expect(_textColor(tester, text), colors.accent);
    expect(
      tester.getSemantics(find.byType(LmsReloginChip)),
      isSemantics(label: text, isButton: true, hasTapAction: true),
    );
    await tester.tap(find.text(text));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(LmsReloginChip)).height,
      greaterThanOrEqualTo(AppSize.minTouch),
    );
    handle.dispose();
  });

  for (final (name, size) in [
    ('폰', phonePortrait),
    ('태블릿 가로', tabletLandscape),
  ]) {
    testWidgets('$name 폭, 글자 200%에서 긴 문구는 줄을 바꾸고 넘치지 않는다', (tester) async {
      const long = 'LMS 정보 25시간 전 · 연결할 수 없어요';
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LmsStatusLine(
              status: _status(LmsStatusKind.connectionFailed, long),
              onTap: () {},
            ),
            LmsReloginChip(
              status: _status(
                LmsStatusKind.reloginNeeded,
                'LMS 정보 25시간 전 · 다시 로그인',
              ),
              onTap: () {},
            ),
          ],
        ),
        textScale: 2,
        size: size,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
