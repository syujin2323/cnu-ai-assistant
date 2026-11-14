// 요청 틀 테스트. docs/lms.md '로그인'.
//
// 문자열 틀의 변수 자리, JSON 틀 채우기, JSON 자리 읽기와 값의 글자를 본다. 값은 모두 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LmsTemplate', () {
    test('{이름} 자리만 변수이고, 꼴이 다른 중괄호는 그대로 둔다', () {
      final template = LmsTemplate('a={first}&b={second_2}&c={3x}&d={ }&e={}');
      expect(template.names, {'first', 'second_2'});
      expect(
        template.render({'first': '1', 'second_2': '둘'}),
        'a=1&b=둘&c={3x}&d={ }&e={}',
      );
    });

    test('틀 전체가 변수 하나인지 가린다', () {
      expect(LmsTemplate('{url}').isSingleVariable, isTrue);
      expect(LmsTemplate('{url}/x').isSingleVariable, isFalse);
      expect(LmsTemplate('{a}{b}').isSingleVariable, isFalse);
      expect(LmsTemplate('https://example.invalid/').isSingleVariable, isFalse);
    });

    test('같은 변수를 여러 번 쓸 수 있고, 값의 중괄호는 다시 바꾸지 않는다', () {
      expect(LmsTemplate('{a}-{a}').render({'a': '{a}'}), '{a}-{a}');
    });

    test('없는 변수는 LmsMissingVariable을 던진다', () {
      expect(
        () => LmsTemplate('x{missing}').render(const {}),
        throwsA(
          isA<LmsMissingVariable>().having((e) => e.name, 'name', 'missing'),
        ),
      );
    });

    test('같은 글자의 틀은 같다', () {
      expect(LmsTemplate('{a}'), LmsTemplate('{a}'));
      expect(LmsTemplate('{a}').hashCode, LmsTemplate('{a}').hashCode);
      expect(LmsTemplate('{a}'), isNot(LmsTemplate('{b}')));
    });
  });

  group('JSON 틀', () {
    const template = {
      'id': '{studentId}',
      'list': [
        '{a}',
        {'deep': 'x{b}y'},
        3,
        true,
        null,
      ],
      'fixed': '합성',
    };

    test('문자열 값의 변수를 모두 모은다', () {
      expect(jsonTemplateNames(template), {'studentId', 'a', 'b'});
      expect(jsonTemplateNames(7), isEmpty);
    });

    test('문자열 값만 채우고 키 순서와 다른 값은 그대로 둔다', () {
      final rendered = renderJsonTemplate(template, {
        'studentId': '123456',
        'a': 'A',
        'b': 'B',
      });
      expect(
        jsonEncode(rendered),
        '{"id":"123456","list":["A",{"deep":"xBy"},3,true,null],"fixed":"합성"}',
      );
    });
  });

  group('jsonAt', () {
    final json = {
      'a': {
        'b': [
          {'c': 'x'},
          'y',
        ],
      },
    };

    test('키와 0부터 세는 번호로 지난다', () {
      expect(jsonAt(json, ['a', 'b', '0', 'c']), 'x');
      expect(jsonAt(json, ['a', 'b', '1']), 'y');
      expect(jsonAt(json, const []), json);
    });

    test('없는 자리는 null이다', () {
      for (final path in [
        ['z'],
        ['a', 'b', '2'],
        ['a', 'b', '-1'],
        ['a', 'b', 'first'],
        ['a', 'b', '1', 'c'],
      ]) {
        expect(jsonAt(json, path), isNull, reason: '$path');
      }
    });
  });

  test('jsonScalarText는 글자·정수·소수점 아래가 없는 수·참거짓만 글자로 바꾼다', () {
    expect(jsonScalarText('x'), 'x');
    expect(jsonScalarText(''), '');
    expect(jsonScalarText(42), '42');
    expect(jsonScalarText(-1), '-1');
    expect(jsonScalarText(42.0), '42');
    expect(jsonScalarText(1.5), '1.5');
    expect(jsonScalarText(true), 'true');
    expect(jsonScalarText(null), isNull);
    expect(jsonScalarText(const {'a': 1}), isNull);
    expect(jsonScalarText(const [1]), isNull);
  });

  test('본문·뽑기·요청·암호 틀은 값이 같으면 같다', () {
    LmsRequestSpec spec(String header) => LmsRequestSpec(
      method: LmsMethod.post,
      url: LmsTemplate('https://example.invalid/x'),
      headers: {'X': LmsTemplate(header)},
      body: const LmsEncryptedBody(
        cipher: 'c',
        field: 'f',
        template: {
          'a': ['{b}'],
        },
      ),
      extract: {'v': LmsPatternExtract(RegExp('v=(.)'))},
    );
    expect(spec('1'), spec('1'));
    expect(spec('1').hashCode, spec('1').hashCode);
    expect(spec('1'), isNot(spec('2')));
    expect(
      LmsFormBody({'a': LmsTemplate('{x}')}),
      LmsFormBody({'a': LmsTemplate('{x}')}),
    );
    expect(const LmsJsonBody({'a': 1}), isNot(const LmsJsonBody({'a': 2})));
    expect(
      const LmsJsonExtract(['a'], optional: true),
      isNot(const LmsJsonExtract(['a'])),
    );
    expect(
      const LmsCipherSpec(keyVar: 'k', takeBytes: 16),
      isNot(const LmsCipherSpec(keyVar: 'k')),
    );
  });
}
