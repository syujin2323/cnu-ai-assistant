// 앱에 넣어 둔 처리방침·이용약관 글 테스트. docs/decisions.md 2026-11-18 '처리방침·이용약관은 별도 공개 레포의
// GitHub Pages에 두고 앱 안에서도 보인다'.
//
// 글은 `make legal-sync`가 공개 레포에서 받는다. 받은 글에 채우지 않은 빈칸이 남지 않았는지, 시행일이 있는지,
// 앱 화면이 그리는 꼴(제목·표)로 읽히는지 본다.

import 'package:cnu_ai_assistant/design/legal_texts.dart';
import 'package:cnu_ai_assistant/domain/text/markdown_lite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, markdown) in [
    ('처리방침', privacyPolicyMarkdown),
    ('이용약관', termsMarkdown),
  ]) {
    test('$name: 빈칸이 채워져 있고 시행일이 있다', () {
      for (final placeholder in [
        '[YYYY-MM-DD]',
        '[이름]',
        '[운영자 이름]',
        '[팀 공용 메일]',
      ]) {
        expect(markdown, isNot(contains(placeholder)), reason: placeholder);
      }
      expect(
        RegExp(r'^시행일: \d{4}-\d{2}-\d{2}$', multiLine: true).hasMatch(markdown),
        isTrue,
      );
      expect(markdown, contains('충남대 비공식 앱'));
    });
  }

  test('처리방침은 열 항과 표 네 개로 읽힌다', () {
    final blocks = parseMarkdownLite(privacyPolicyMarkdown);
    final sections = blocks
        .whereType<MdHeading>()
        .where((heading) => heading.level == 2)
        .map((heading) => plainText(heading.spans))
        .toList();
    expect(sections, hasLength(10));
    expect(sections.first, startsWith('1. '));
    expect(sections.last, startsWith('10. '));
    final tables = blocks.whereType<MdTable>().toList();
    expect(tables, hasLength(4));
    for (final table in tables) {
      expect(table.rows, isNotEmpty);
    }
  });

  test('이용약관은 제1조부터 제12조까지 읽히고, 처리방침으로 가는 링크가 있다', () {
    final blocks = parseMarkdownLite(termsMarkdown);
    final articles = blocks
        .whereType<MdHeading>()
        .where((heading) => heading.level == 2)
        .map((heading) => plainText(heading.spans))
        .toList();
    expect(articles, hasLength(12));
    expect(articles.first, startsWith('제1조'));
    expect(articles.last, startsWith('제12조'));
    final links = [
      for (final block in blocks)
        if (block is MdParagraph)
          for (final span in block.spans) ?span.link,
    ];
    expect(links, contains('privacy'));
  });
}
