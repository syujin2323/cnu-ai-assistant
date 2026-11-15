// 아이콘 테스트. docs/architecture.md '앱 코드 규약'(아이콘).
//
// 모든 아이콘이 캔버스와 같은 꼴(24 viewBox, 선은 currentColor, 둥근 끝)의 SVG 파일로 있고, AppIcon이 그 색으로
// 그리는지 본다.

import 'dart:io';

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('모든 아이콘은 같은 꼴의 SVG 파일이고, 파일 이름은 겹치지 않는다', () {
    final paths = <String>{};
    for (final name in AppIconName.values) {
      expect(paths.add(name.asset), isTrue, reason: name.name);
      final file = File(name.asset);
      expect(file.existsSync(), isTrue, reason: name.asset);
      final svg = file.readAsStringSync();
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox="0 0 24 24"'));
      expect(svg, contains('fill="none"'));
      expect(svg, contains('stroke="currentColor"'));
      expect(svg, contains('stroke-linecap="round"'));
    }
  });

  test('assets/icons의 SVG는 모두 아이콘 목록에 있다', () {
    final listed = {for (final name in AppIconName.values) name.asset};
    final files = {
      for (final file in Directory('assets/icons').listSync())
        if (file.path.endsWith('.svg')) file.path,
    };
    expect(files, listed);
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
  });
}
