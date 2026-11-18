// 문서의 코드 규약 가운데 글자로 찾을 수 있는 금지 규칙을 확인한다(docs/decisions.md 2026-11-14 '문서의 코드
// 금지 규칙을 테스트로 확인한다'). 어긴 파일과 줄을 알려 주고, 규칙마다 허용한 파일만 예외다. 주석(`//` 뒤)은 보지
// 않는다. 이 파일은 `lib/`의 원본이 없어 '원본과 같은 경로' 규칙의 예외다.
//
// 규칙을 더하거나 예외 파일을 바꾸면 docs/architecture.md '확인과 CI'의 목록도 함께 고친다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libFiles = _dartFiles('lib');
  final testFiles = _dartFiles('test');

  test('DateTime.now()는 domain/clock.dart에서만 부른다', () {
    // docs/architecture.md '앱 코드 규약'의 시각 규칙. 다른 코드는 Clock을 받는다.
    expect(
      _violations(
        libFiles,
        RegExp(r'DateTime\.now\('),
        allowed: {'lib/domain/clock.dart'},
      ),
      isEmpty,
    );
  });

  test('플랫폼 채널(MethodChannel)은 platform/과 lms/ 밖에서 쓰지 않는다', () {
    expect(
      _violations(
        libFiles,
        RegExp(r'\bMethodChannel\b'),
        allowedPrefixes: {'lib/platform/', 'lib/lms/'},
      ),
      isEmpty,
    );
  });

  test('아이콘은 AppIcon만 쓴다(Icons.*와 SvgPicture는 design/icons.dart만, SVG 문자열은 design/icon_svgs.dart만)', () {
    expect(_violations(libFiles, RegExp(r'\bIcons\.')), isEmpty);
    expect(
      _violations(
        libFiles,
        RegExp(r'SvgPicture\.(asset|string|file|network|memory)\('),
        allowed: {'lib/design/icons.dart'},
      ),
      isEmpty,
    );
    expect(
      _violations(
        libFiles,
        RegExp(r'<svg\b'),
        allowed: {'lib/design/icon_svgs.dart'},
      ),
      isEmpty,
    );
  });

  test('Flutter SDK의 material·cupertino 라이브러리를 import하지 않는다(material_ui·cupertino_ui)', () {
    final sdkImport = RegExp(
      r'''import\s+['"]package:flutter/(material|cupertino)\.dart['"]''',
    );
    expect(_violations([...libFiles, ...testFiles], sdkImport), isEmpty);
  });

  test('print·debugPrint 대신 app/logging.dart의 함수만 쓴다', () {
    expect(
      _violations(
        libFiles,
        RegExp(r'(^|[^\w.])(print|debugPrint)\('),
        allowed: {'lib/app/logging.dart'},
      ),
      isEmpty,
    );
  });

  test('시트는 showAppSheet로만 연다(showModalBottomSheet는 design/widgets/app_sheet.dart만)', () {
    expect(
      _violations(
        libFiles,
        RegExp(r'\bshowModalBottomSheet\b'),
        allowed: {'lib/design/widgets/app_sheet.dart'},
      ),
      isEmpty,
    );
  });

  test('domain/은 Flutter·drift·Firebase와 lms/를 import하지 않는다', () {
    final forbidden = RegExp(
      r'''import\s+['"]package:(flutter|drift|firebase_\w+|cnu_ai_assistant/(lms|data|features|app|platform|design)/)''',
    );
    expect(
      _violations([
        for (final file in libFiles)
          if (_path(file).startsWith('lib/domain/')) file,
      ], forbidden),
      isEmpty,
    );
  });
}

/// [root](app/ 기준) 아래의 손으로 쓴 Dart 파일. 생성 파일(*.g.dart)은 뺀다.
List<File> _dartFiles(String root) => [
  for (final entity in Directory(root).listSync(recursive: true))
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.endsWith('.g.dart'))
      entity,
]..sort((a, b) => a.path.compareTo(b.path));

/// `lib/domain/clock.dart`처럼 app/ 기준 경로(구분자 `/`).
String _path(File file) =>
    file.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^\./'), '');

/// [pattern]이 주석 밖에 나오는 줄을 '경로:줄 번호' 목록으로 돌려준다. [allowed]의 파일과 [allowedPrefixes]로
/// 시작하는 파일은 보지 않는다.
List<String> _violations(
  List<File> files,
  RegExp pattern, {
  Set<String> allowed = const {},
  Set<String> allowedPrefixes = const {},
}) => [
  for (final file in files)
    if (!allowed.contains(_path(file)) &&
        !allowedPrefixes.any(_path(file).startsWith))
      for (final (index, line) in file.readAsLinesSync().indexed)
        if (pattern.hasMatch(_withoutComment(line)))
          '${_path(file)}:${index + 1}',
];

/// 줄에서 `//` 주석을 뗀다. 문자열 안의 `//`(주소 등)까지 떼므로 그 뒤의 금지 패턴은 놓칠 수 있다(받아들인 점).
String _withoutComment(String line) {
  final index = line.indexOf('//');
  return index < 0 ? line : line.substring(0, index);
}
