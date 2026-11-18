// 처리방침·이용약관용 작은 마크다운 테스트. 글은 모두 합성 글이다.

import 'package:cnu_ai_assistant/domain/text/markdown_lite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseInline', () {
    test('굵게와 링크를 조각으로 나누고 나머지는 그대로 둔다', () {
      expect(parseInline('앱은 **비공식 앱**이고 [처리방침](privacy)을 따라요.'), const [
        MdSpan('앱은 '),
        MdSpan('비공식 앱', bold: true),
        MdSpan('이고 '),
        MdSpan('처리방침', link: 'privacy'),
        MdSpan('을 따라요.'),
      ]);
    });

    test('굵게 안의 링크는 굵은 링크다', () {
      expect(parseInline('**[기록](https://example.invalid/a)**'), const [
        MdSpan('기록', bold: true, link: 'https://example.invalid/a'),
      ]);
    });

    test('짝이 없는 **는 그 뒤를 끝까지 굵게 본다', () {
      expect(parseInline('앞 **뒤'), const [
        MdSpan('앞 '),
        MdSpan('뒤', bold: true),
      ]);
    });

    test('링크 꼴이 아니면 글자 그대로다', () {
      expect(parseInline('[이름] (메모)'), const [MdSpan('[이름] (메모)')]);
      expect(parseInline(''), isEmpty);
    });
  });

  group('parseMarkdownLite', () {
    test('front matter를 건너뛰고 제목·문단·목록을 나눈다', () {
      final blocks = parseMarkdownLite('''---
title: 합성 문서
---

# 맨 위 제목

첫 문단은
두 줄이다.

## 1. 둘째 제목

- 하나
- **둘**

1. 첫째
2. 둘째
### 셋째 제목
''');
      expect(blocks, hasLength(6));
      expect(blocks[0], isA<MdHeading>().having((b) => b.level, 'level', 1));
      expect(
        blocks[1],
        isA<MdParagraph>().having(
          (b) => plainText(b.spans),
          'text',
          '첫 문단은 두 줄이다.',
        ),
      );
      expect(
        blocks[2],
        isA<MdHeading>()
            .having((b) => b.level, 'level', 2)
            .having((b) => plainText(b.spans), 'text', '1. 둘째 제목'),
      );
      expect(
        blocks[3],
        isA<MdList>().having((b) => b.ordered, 'ordered', isFalse).having(
          (b) => b.items,
          'items',
          const [
            [MdSpan('하나')],
            [MdSpan('둘', bold: true)],
          ],
        ),
      );
      expect(
        blocks[4],
        isA<MdList>()
            .having((b) => b.ordered, 'ordered', isTrue)
            .having((b) => b.items.length, 'items', 2),
      );
      expect(blocks[5], isA<MdHeading>().having((b) => b.level, 'level', 3));
    });

    test('표는 머리 줄과 몸 줄로 나누고, 칸 수를 머리에 맞춘다', () {
      final blocks = parseMarkdownLite('''
| 항목 | 목적 | 기간 |
|---|:---:|---|
| 학번 | **로그인** | 로그아웃 때까지 |
| 짧은 줄 | 하나 |
| 긴 줄 | 1 | 2 | 넘침 |
''');
      final table = blocks.single as MdTable;
      expect(table.header.map(plainText), ['항목', '목적', '기간']);
      expect(table.rows, hasLength(3));
      expect(table.rows[0][1], const [MdSpan('로그인', bold: true)]);
      expect(table.rows[1].map(plainText), ['짧은 줄', '하나', '']);
      expect(table.rows[2].map(plainText), ['긴 줄', '1', '2']);
    });

    test('구분 줄이 없으면 표가 아니라 문단이다', () {
      final blocks = parseMarkdownLite('| a | b |\n| c | d |');
      expect(blocks.single, isA<MdParagraph>());
    });

    test('닫는 --- 가 없으면 front matter로 보지 않는다', () {
      final blocks = parseMarkdownLite('---\n본문');
      expect(blocks.map((b) => b.runtimeType), [MdParagraph]);
    });
  });
}
