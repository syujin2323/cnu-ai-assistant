// 요청 상수 설정 파서 테스트. docs/lms.md '원격 스위치'·'응답 판별'.
//
// 합성 요청 상수(`example.invalid`)로 키 형식, `version`, 학교 도메인 https 검사, 로그인 주소 판단, JSON 표식을
// 본다. 실제 주소·표식은 쓰지 않는다.

import 'dart:convert';

import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  LmsRequestParamsParse parse(Object? json, {String? domain}) =>
      parseLmsRequestParams(
        json is String ? json : jsonEncode(json),
        schoolDomain: domain ?? syntheticSchoolDomain,
      );

  /// 합성 요청 상수에서 [path]의 값을 [value]로 바꾼 것. [value]가 [_remove]면 그 키를 뺀다.
  Map<String, Object?> withValue(List<String> path, Object? value) {
    final copy = jsonDecode(syntheticRequestParamsJson) as Map<String, Object?>;
    var node = copy;
    for (final key in path.take(path.length - 1)) {
      node = node[key]! as Map<String, Object?>;
    }
    if (identical(value, _remove)) {
      node.remove(path.last);
    } else {
      node[path.last] = value;
    }
    return copy;
  }

  void expectProblem(LmsRequestParamsParse result, LmsConfigProblem problem) {
    expect(result.params, isNull);
    expect(result.problem, problem);
  }

  test('합성 요청 상수를 읽고, 쿠키 도메인은 소문자로 바꾸고 앞의 점을 뗀다', () {
    final result = parse(
      withValue(['cookieDomains'], ['.Example.Invalid', 'lms.example.invalid']),
    );
    expect(result.problem, isNull);
    final params = result.params!;
    expect(params.version, 1);
    expect(params.homeUrl, Uri.parse('https://example.invalid/home'));
    expect(
      params.loginUrl,
      Uri.parse('https://example.invalid/synthetic-login?next=home'),
    );
    expect(params.cookieDomains, ['example.invalid', 'lms.example.invalid']);
    expect(
      params.markers,
      const LmsMarkers(
        loginPage: ['data-synthetic-login-form'],
        maintenance: ['data-synthetic-maintenance'],
        authError: [
          LmsJsonMarker(path: ['header', 'code'], anyOf: ['9001', '9002']),
        ],
      ),
    );
  });

  test('모르는 키는 무시하고, 표식 목록은 비어 있어도 된다', () {
    final json = withValue(
      ['markers'],
      {
        'loginPage': <String>[],
        'maintenance': <String>[],
        'authError': <Object>[],
        'later': 'ignored',
      },
    )..['requests'] = {'any': 'thing'};
    final params = parse(json).params!;
    expect(params.markers, const LmsMarkers());
  });

  test('비어 있으면 empty, JSON 객체가 아니면 notJson이다', () {
    expectProblem(parse(''), LmsConfigProblem.empty);
    expectProblem(parse('  \n'), LmsConfigProblem.empty);
    expectProblem(parse('{'), LmsConfigProblem.notJson);
    expectProblem(parse('[1]'), LmsConfigProblem.notJson);
    expectProblem(parse('"text"'), LmsConfigProblem.notJson);
    expectProblem(parse('null'), LmsConfigProblem.notJson);
  });

  test('version이 없거나 정수가 아니거나 이 앱이 모르는 값이면 version이다', () {
    for (final version in [_remove, '1', 1.5, 0, 2, null]) {
      expectProblem(
        parse(withValue(['version'], version)),
        LmsConfigProblem.version,
      );
    }
  });

  test('필요한 키가 없거나 형이 다르면 field다', () {
    for (final (path, value) in <(List<String>, Object?)>[
      (['homeUrl'], _remove),
      (['homeUrl'], 1),
      (['loginUrl'], _remove),
      (['loginUrl'], 'not a url'),
      (['loginUrl'], '/relative/path'),
      (['cookieDomains'], _remove),
      (['cookieDomains'], <String>[]),
      (['cookieDomains'], 'example.invalid'),
      (['cookieDomains'], ['']),
      (['markers'], _remove),
      (['markers'], <Object>[]),
      (['markers', 'loginPage'], _remove),
      (['markers', 'loginPage'], 'marker'),
      (['markers', 'maintenance'], ['ok', '']),
      (['markers', 'maintenance'], [1]),
      (['markers', 'authError'], _remove),
      (['markers', 'authError'], ['header.code']),
      (
        ['markers', 'authError'],
        [
          {
            'path': 'header..code',
            'anyOf': ['1'],
          },
        ],
      ),
      (
        ['markers', 'authError'],
        [
          {
            'path': '',
            'anyOf': ['1'],
          },
        ],
      ),
      (
        ['markers', 'authError'],
        [
          {'path': 'header.code', 'anyOf': <String>[]},
        ],
      ),
      (
        ['markers', 'authError'],
        [
          {
            'path': 'header.code',
            'anyOf': [true],
          },
        ],
      ),
      (
        ['markers', 'authError'],
        [
          {
            'path': 'header.code',
            'anyOf': [''],
          },
        ],
      ),
      (
        ['markers', 'authError'],
        [
          {
            'anyOf': ['1'],
          },
        ],
      ),
    ]) {
      expectProblem(parse(withValue(path, value)), LmsConfigProblem.field);
    }
  });

  test('주소가 https가 아니거나 학교 도메인 밖이면 domain이다', () {
    for (final url in [
      'http://example.invalid/home',
      'http://example.invalid:443/home',
      'https://example.com/home',
      'https://example.invalid.attacker.example/home',
      'https://notexample.invalid/home',
      'https://user@example.invalid/home',
      'https://example.invalid:8443/home',
      'wss://example.invalid/home',
    ]) {
      expectProblem(
        parse(withValue(['homeUrl'], url)),
        LmsConfigProblem.domain,
      );
      expectProblem(
        parse(withValue(['loginUrl'], url)),
        LmsConfigProblem.domain,
      );
    }
    for (final domains in [
      ['example.com'],
      ['example.invalid', 'notexample.invalid'],
      ['invalid'],
    ]) {
      expectProblem(
        parse(withValue(['cookieDomains'], domains)),
        LmsConfigProblem.domain,
      );
    }
  });

  test('하위 도메인, 대문자 호스트, 443 포트를 적은 주소는 받는다', () {
    final params = parse(
      withValue(['homeUrl'], 'https://LMS.Example.Invalid:443/home'),
    ).params!;
    expect(params.homeUrl.host, 'lms.example.invalid');
  });

  test('앱의 학교 도메인은 그 하위 도메인 주소만 받는다(합성 호스트는 domain)', () {
    expectProblem(
      parse(syntheticRequestParamsJson, domain: lmsSchoolDomain),
      LmsConfigProblem.domain,
    );
    final school = withValue(['homeUrl'], 'https://lms.$lmsSchoolDomain/')
      ..['loginUrl'] = 'https://sso.$lmsSchoolDomain/login'
      ..['cookieDomains'] = ['lms.$lmsSchoolDomain', '.sso.$lmsSchoolDomain'];
    expect(parse(school, domain: lmsSchoolDomain).problem, isNull);
  });

  group('isSchoolUrl·isSchoolHost', () {
    test('학교 도메인과 그 하위 도메인의 https 주소만 맞다', () {
      expect(
        isSchoolUrl(
          Uri.parse('https://a.b.example.invalid/x?y=1#z'),
          domain: 'example.invalid',
        ),
        isTrue,
      );
      expect(
        isSchoolUrl(
          Uri.parse('https://example.invalid'),
          domain: 'EXAMPLE.invalid',
        ),
        isTrue,
      );
      for (final url in [
        'http://example.invalid/',
        'https://evilexample.invalid/',
        'https://example.invalid.evil/',
        'https:///path',
        'https://u:p@example.invalid/',
        'https://example.invalid:80/',
      ]) {
        expect(
          isSchoolUrl(Uri.parse(url), domain: 'example.invalid'),
          isFalse,
          reason: url,
        );
      }
    });

    test('호스트와 도메인의 대소문자는 가리지 않는다', () {
      expect(
        isSchoolHost('LMS.EXAMPLE.INVALID', domain: 'example.invalid'),
        isTrue,
      );
      expect(
        isSchoolHost('EXAMPLE.INVALID', domain: 'Example.Invalid'),
        isTrue,
      );
      expect(
        isSchoolHost('lms.example.invalid', domain: 'EXAMPLE.INVALID'),
        isTrue,
      );
    });

    test('도메인이 비어 있으면 어떤 호스트도 맞지 않는다', () {
      expect(isSchoolHost('example.invalid', domain: ''), isFalse);
      expect(isSchoolHost('', domain: ''), isFalse);
    });
  });

  group('isLoginUrl', () {
    final params = parse(syntheticRequestParamsJson).params!;

    test('같은 호스트에서 로그인 주소의 경로와 같거나 그 아래면 맞고, 쿼리는 보지 않는다', () {
      for (final url in [
        'https://example.invalid/synthetic-login',
        'https://example.invalid/synthetic-login?next=other',
        'https://EXAMPLE.invalid/synthetic-login/step2',
      ]) {
        expect(params.isLoginUrl(Uri.parse(url)), isTrue, reason: url);
      }
    });

    test('경로가 글자로만 겹치거나 호스트가 다르면 아니다', () {
      for (final url in [
        'https://example.invalid/synthetic-login-help',
        'https://example.invalid/home?next=synthetic-login',
        'https://lms.example.invalid/synthetic-login',
        'https://example.invalid/',
      ]) {
        expect(params.isLoginUrl(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('로그인 주소의 경로가 루트면 같은 호스트의 모든 주소가 맞다', () {
      for (final login in [
        'https://sso.example.invalid',
        'https://sso.example.invalid/',
      ]) {
        final root = parse(withValue(['loginUrl'], login)).params!;
        for (final (url, expected) in [
          ('https://sso.example.invalid/any/path', true),
          ('https://sso.example.invalid', true),
          ('https://sso.example.invalid/', true),
          ('https://example.invalid/any/path', false),
        ]) {
          expect(
            root.isLoginUrl(Uri.parse(url)),
            expected,
            reason: '$login → $url',
          );
        }
      }
    });
  });

  group('LmsJsonMarker.matches', () {
    const marker = LmsJsonMarker(
      path: ['header', 'code'],
      anyOf: ['9001', 'AUTH'],
    );

    test('그 자리의 문자열·정수 값이 목록에 있으면 맞다', () {
      expect(
        marker.matches({
          'header': {'code': 9001},
        }),
        isTrue,
      );
      expect(
        marker.matches({
          'header': {'code': '9001'},
        }),
        isTrue,
      );
      expect(
        marker.matches({
          'header': {'code': 'AUTH'},
        }),
        isTrue,
      );
      expect(
        marker.matches({
          'header': {'code': 9001.0},
        }),
        isTrue,
      );
    });

    test('값이 다르거나, 자리가 없거나, 객체·목록·null이면 아니다', () {
      for (final json in <Object?>[
        {
          'header': {'code': 200},
        },
        {
          'header': {'code': 'auth'},
        },
        {
          'header': {'code': 9001.5},
        },
        {'header': <String, Object>{}},
        {'header': 'text'},
        {
          'header': {
            'code': {'value': 9001},
          },
        },
        {
          'header': {
            'code': [9001],
          },
        },
        {
          'header': {'code': null},
        },
        null,
        'header',
        [9001],
      ]) {
        expect(marker.matches(json), isFalse, reason: '$json');
      }
    });

    test('목록은 0부터 세는 번호로 지난다', () {
      const listMarker = LmsJsonMarker(
        path: ['errors', '1', 'kind'],
        anyOf: ['x'],
      );
      expect(
        listMarker.matches({
          'errors': [
            {'kind': 'y'},
            {'kind': 'x'},
          ],
        }),
        isTrue,
      );
      expect(
        listMarker.matches({
          'errors': [
            {'kind': 'x'},
          ],
        }),
        isFalse,
      );
      const badIndex = LmsJsonMarker(path: ['errors', 'first'], anyOf: ['x']);
      expect(
        badIndex.matches({
          'errors': ['x'],
        }),
        isFalse,
      );
      const negative = LmsJsonMarker(path: ['errors', '-1'], anyOf: ['x']);
      expect(
        negative.matches({
          'errors': ['x'],
        }),
        isFalse,
      );
    });

    test('참거짓 값은 true·false 문자열로 견준다', () {
      const flag = LmsJsonMarker(path: ['expired'], anyOf: ['true']);
      expect(flag.matches({'expired': true}), isTrue);
      expect(flag.matches({'expired': false}), isFalse);
    });
  });

  test('같은 값으로 해석한 요청 상수는 같다', () {
    final a = parse(syntheticRequestParamsJson).params!;
    final b = parse(syntheticRequestParamsJson).params!;
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    final other = parse(withValue(['markers', 'loginPage'], ['data-other']))
        .params!;
    expect(a, isNot(other));
    final otherDomains = parse(
      withValue(['cookieDomains'], ['lms.example.invalid']),
    ).params!;
    expect(a, isNot(otherDomains));
  });
}

/// [withValue]에서 키를 빼라는 표시.
const Object _remove = Object();
