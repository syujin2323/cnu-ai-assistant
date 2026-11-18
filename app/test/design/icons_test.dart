// 아이콘 테스트. docs/architecture.md '앱 코드 규약'(아이콘).
//
// 모든 아이콘이 캔버스와 같은 꼴(24 viewBox, 선은 currentColor, 둥근 끝)의 SVG 문자열로 있고, AppIcon이 그 색으로
// 그리는지 본다. 아이콘은 에셋이 아니라 Dart 문자열이다(docs/decisions.md 2026-11-19 '아이콘 SVG는 Dart 문자열로
// 둔다').

import 'dart:io';

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('모든 아이콘은 같은 꼴의 SVG 문자열이다', () {
    for (final name in AppIconName.values) {
      final svg = name.svg;
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, endsWith('</svg>'));
      expect(svg, contains('viewBox="0 0 24 24"'));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('stroke="currentColor"'));
      expect(svg, contains('stroke-linecap="round"'));
    }
  });

  test('아이콘을 에셋으로 두지 않는다(패치로 새 아이콘을 내려고)', () {
    expect(Directory('assets/icons').existsSync(), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('icons')));
  });

  testWidgets('AppIcon은 모든 아이콘을 주어진 색으로 그린다', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [
            for (final name in AppIconName.values)
              AppIcon(name, size: 20, color: const Color(0xFF123456)),
          ],
        ),
      ),
    );
    final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    expect(pictures, hasLength(AppIconName.values.length));
    for (final picture in pictures) {
      expect(
        picture.colorFilter,
        const ColorFilter.mode(Color(0xFF123456), BlendMode.srcIn),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
