// 공개 레포 syujin2323/cnu-planner-docs의 처리방침·이용약관을 받아 lib/design/legal_texts.dart를 만든다.
// 레포 루트에서 `make legal-sync`로 돌린다(docs/architecture.md '테스트 배포'). 앱은 이 글을 앱 안 화면으로
// 보인다(docs/decisions.md 2026-11-18 '처리방침·이용약관은 별도 공개 레포의 GitHub Pages에 두고 앱 안에서도
// 보인다').

import 'dart:convert';
import 'dart:io';

const _base =
    'https://raw.githubusercontent.com/syujin2323/cnu-planner-docs/main';
const _output = 'lib/design/legal_texts.dart';
const _quotes = "'''";

Future<void> main() async {
  final client = HttpClient();
  try {
    final privacy = await _fetch(client, 'privacy.md');
    final terms = await _fetch(client, 'terms.md');
    File(_output).writeAsStringSync(_render(privacy, terms));
    stdout.writeln('$_output: 처리방침 ${privacy.length}자, 이용약관 ${terms.length}자');
  } finally {
    client.close();
  }
}

Future<String> _fetch(HttpClient client, String name) async {
  final request = await client.getUrl(Uri.parse('$_base/$name'));
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('$name: HTTP ${response.statusCode}');
  }
  final text = await response.transform(utf8.decoder).join();
  if (text.contains(_quotes)) {
    throw FormatException('$name에 $_quotes가 있어 Dart 문자열에 넣을 수 없어요');
  }
  return text.endsWith('\n') ? text : '$text\n';
}

String _render(String privacy, String terms) => [
  '// 생성 파일: 레포 루트에서 `make legal-sync`로 공개 레포 syujin2323/cnu-planner-docs의 main에서 받는다.',
  '// 손으로 고치지 않는다. 처리방침·이용약관을 바꾸려면 그 레포에 PR로 올려 병합한 뒤 다시 받는다',
  "// (docs/architecture.md '테스트 배포'). 에셋이 아니라 Dart 코드에 두어 Shorebird 패치로도 바꿀 수 있다.",
  '',
  '/// 개인정보 처리방침(privacy.md).',
  'const String privacyPolicyMarkdown = r$_quotes',
  '$privacy$_quotes;',
  '',
  '/// 이용약관(terms.md).',
  'const String termsMarkdown = r$_quotes',
  '$terms$_quotes;',
  '',
].join('\n');
