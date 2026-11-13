// 디자인 토큰 테스트. docs/architecture.md '디자인 토큰'.
//
// 색 토큰은 문서의 표가 원본이다. 표를 읽어 이름마다 라이트·다크 값이 코드와 같은지 보고, 표에 있는
// 토큰이 코드에 모두 있는지도 본다. '(60%)'는 알파 60%(0x99), rgba는 `Color.fromRGBO`와 같다.

import 'dart:io';

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 표의 토큰 이름 → 코드의 값.
final Map<String, Color Function(AppColors)> _tokens = {
  'bg': (c) => c.bg,
  'surface': (c) => c.surface,
  'tint': (c) => c.tint,
  'edge': (c) => c.edge,
  'ink': (c) => c.ink,
  'ink2': (c) => c.ink2,
  'muted': (c) => c.muted,
  'icon': (c) => c.icon,
  'accent': (c) => c.accent,
  'strong': (c) => c.strong,
  'alert': (c) => c.alert,
  'alertSoft': (c) => c.alertSoft,
  'stripe': (c) => c.stripe,
  'classTint': (c) => c.classTint,
  'taskTint': (c) => c.taskTint,
  'personalTint': (c) => c.personalTint,
  'deadlineTint': (c) => c.deadlineTint,
  'tint2': (c) => c.tint2,
  'edge2': (c) => c.edge2,
  'onStrong': (c) => c.onStrong,
  'faint': (c) => c.faint,
  'alertLine': (c) => c.alertLine,
  'sheet': (c) => c.sheet,
  'scrim': (c) => c.scrim,
  'classLine': (c) => c.classLine,
  'classInk': (c) => c.classInk,
  'taskLine': (c) => c.taskLine,
  'taskInk': (c) => c.taskInk,
  'personalLine': (c) => c.personalLine,
  'personalInk': (c) => c.personalInk,
  'deadlineLine': (c) => c.deadlineLine,
  'deadlineInk': (c) => c.deadlineInk,
};

void main() {
  late Map<String, (Color, Color)> table;

  // `flutter test`는 app/에서 돈다.
  setUpAll(
    () => table = _readColorTable(
      File('../docs/architecture.md').readAsStringSync(),
    ),
  );

  test('문서 표의 색 토큰이 코드에 모두 있다', () {
    expect(table.keys, unorderedEquals(_tokens.keys));
  });

  test('라이트·다크 값이 문서 표와 같다', () {
    for (final MapEntry(key: name, value: (light, dark)) in table.entries) {
      final read = _tokens[name]!;
      expect(read(AppColors.light), light, reason: '$name 라이트');
      expect(read(AppColors.dark), dark, reason: '$name 다크');
    }
  });

  testWidgets('앱 테마 없이 띄운 위젯은 라이트 값을 읽는다', (tester) async {
    late AppColors read;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            read = AppColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(read, same(AppColors.light));
  });

  test('copyWith는 준 값만 바꾸고, lerp는 두 벌 사이를 잇는다', () {
    final changed = AppColors.light.copyWith(bg: AppColors.dark.bg);
    expect(changed.bg, AppColors.dark.bg);
    expect(changed.ink, AppColors.light.ink);
    expect(
      AppColors.light.lerp(AppColors.dark, 0).sheet,
      AppColors.light.sheet,
    );
    expect(AppColors.light.lerp(AppColors.dark, 1).sheet, AppColors.dark.sheet);
    expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
  });
}

/// '디자인 토큰' 절의 색 표를 읽는다. 이름 → (라이트, 다크).
Map<String, (Color, Color)> _readColorTable(String markdown) {
  final start = markdown.indexOf('## 디자인 토큰');
  final end = markdown.indexOf('### 모션 프리셋', start);
  final section = markdown.substring(start, end);
  final rows = <String, (Color, Color)>{};
  for (final line in section.split('\n')) {
    if (!line.startsWith('| `')) continue;
    final cells = line.split('|').map((cell) => cell.trim()).toList();
    final names = [
      for (final match in RegExp('`(\\w+)`').allMatches(cells[1])) match[1]!,
    ];
    final lights = cells[2].split('·');
    final darks = cells[3].split('·');
    expect(lights, hasLength(names.length), reason: line);
    expect(darks, hasLength(names.length), reason: line);
    for (var i = 0; i < names.length; i++) {
      rows[names[i]] = (_parseColor(lights[i]), _parseColor(darks[i]));
    }
  }
  return rows;
}

/// `#RRGGBB`, `#RRGGBB(60%)`, `rgba(r,g,b,.a)`를 읽는다.
Color _parseColor(String text) {
  final rgba = RegExp(r'^rgba\((\d+),(\d+),(\d+),([\d.]+)\)$').firstMatch(text);
  if (rgba != null) {
    return Color.fromRGBO(
      int.parse(rgba[1]!),
      int.parse(rgba[2]!),
      int.parse(rgba[3]!),
      double.parse(rgba[4]!),
    );
  }
  final hex = RegExp(r'^#([0-9A-F]{6})(?:\((\d+)%\))?$').firstMatch(text);
  if (hex == null) throw FormatException('색 표기를 읽지 못했다', text);
  final alpha = hex[2] == null ? 255 : (int.parse(hex[2]!) * 255 / 100).round();
  return Color((alpha << 24) | int.parse(hex[1]!, radix: 16));
}
