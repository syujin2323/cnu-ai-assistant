// 요청 상수 설정 파서 테스트. docs/lms.md '원격 스위치'·'응답 판별'.
//
// 합성 요청 상수(`example.invalid`)로 키 형식, `version`, 학교 도메인 https 검사, 로그인 주소 판단, JSON 표식을
// 본다. 실제 주소·표식은 쓰지 않는다.

import 'dart:convert';

import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  LmsRequestParamsParse parse(Object? json, {String? domain}) =>
      parseLmsRequestParams(
        json is String ? json : jsonEncode(json),
        schoolDomain: domain ?? syntheticSchoolDomain,
      );

  /// 합성 요청 상수에서 [path]의 값을 [value]로 바꾼 것. [value]가 [_remove]면 그 키를 뺀다. 목록은 번호로 지난다.
  Map<String, Object?> withValue(List<String> path, Object? value) {
    final copy = syntheticRequestParamsCopy();
    Object node = copy;
    for (final key in path.take(path.length - 1)) {
      node = node is List ? node[int.parse(key)]! : (node as Map)[key]!;
    }
    final map = node as Map<String, Object?>;
    if (identical(value, _remove)) {
      map.remove(path.last);
    } else {
      map[path.last] = value;
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
    // 합성 요청 상수의 모든 호스트를 학교 도메인의 하위 도메인으로 바꾸면 받는다.
    final school = syntheticRequestParamsJson.replaceAll(
      'example.invalid',
      'lms.$lmsSchoolDomain',
    );
    final params = parse(school, domain: lmsSchoolDomain).params!;
    expect(params.homeUrl.host, 'lms.$lmsSchoolDomain');
    expect(params.cookieDomains, ['lms.$lmsSchoolDomain']);
    // 로그인 요청의 주소도 학교 도메인 밖이면 domain이다.
    final outside = jsonDecode(school) as Map<String, Object?>;
    ((outside['login']! as Map)['request']! as Map)['url'] =
        'https://example.invalid/synthetic-login/submit';
    expectProblem(
      parse(outside, domain: lmsSchoolDomain),
      LmsConfigProblem.domain,
    );
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

  group('userAgent·ciphers·login', () {
    test('합성 로그인 요청 틀을 읽는다', () {
      final params = parse(syntheticRequestParamsJson).params!;
      expect(params.userAgent, 'SyntheticAgent/1.0');
      expect(params.ciphers, {'body': const LmsCipherSpec(keyVar: 'bodyKey')});
      final login = params.login;
      expect(login.steps, hasLength(2));
      expect(login.steps.first.method, LmsMethod.get);
      expect(
        login.steps.first.extract['formToken'],
        LmsPatternExtract(
          RegExp('name="synthetic-token" value="([^"]*)"'),
          optional: true,
        ),
      );
      expect(login.steps[1].url.isSingleVariable, isTrue);
      expect(login.request.method, LmsMethod.post);
      expect(login.request.headers.keys, ['X-Synthetic']);
      final body = login.request.body! as LmsEncryptedBody;
      expect(body.cipher, 'body');
      expect(body.field, 'payload');
      expect(body.names, {'studentId', 'password', 'formToken'});
      expect(
        login.request.extract['handoffUrl'],
        const LmsJsonExtract(['result', 'next'], optional: true),
      );
      expect(login.results, const [
        LmsLoginRule(
          when: [
            LmsJsonMarker(path: ['result', 'code'], anyOf: ['wrong']),
          ],
          result: LmsLoginResult.wrongCredentials,
        ),
        LmsLoginRule(
          when: [
            LmsJsonPresent(['result', 'next']),
          ],
          result: LmsLoginResult.success,
        ),
      ]);
      expect(login.handoff!.url.source, '{handoffUrl}');
    });

    test('준비 요청·세션 넘기기·헤더·뽑기·암호는 없어도 된다', () {
      final login = {
        'request': {
          'method': 'POST',
          'url': 'https://example.invalid/login',
          'body': {
            'form': {'id': '{studentId}', 'pw': '{password}'},
          },
        },
        'results': [
          {
            'when': [
              {'contains': 'welcome'},
            ],
            'result': 'success',
          },
        ],
      };
      final params = parse(withValue(['login'], login)..remove('ciphers'))
          .params!;
      expect(params.ciphers, isEmpty);
      expect(params.login.steps, isEmpty);
      expect(params.login.handoff, isNull);
      expect(params.login.request.extract, isEmpty);
      expect(params.login.request.body, isA<LmsFormBody>());
    });

    test('JSON 본문과 parseFailure 규칙, 여러 조건의 규칙을 읽는다', () {
      final login = {
        'request': {
          'method': 'POST',
          'url': 'https://example.invalid/login',
          'body': {
            'json': {
              'id': '{studentId}',
              'nested': [
                {'pw': '{password}'},
              ],
            },
          },
        },
        'results': [
          {
            'when': [
              {
                'path': 'code',
                'anyOf': ['-1', 0],
              },
              {'contains': 'x'},
            ],
            'result': 'parseFailure',
          },
          {
            'when': [
              {'path': 'ok', 'present': true},
            ],
            'result': 'success',
          },
        ],
      };
      final params = parse(withValue(['login'], login)).params!;
      expect(params.login.request.body, isA<LmsJsonBody>());
      expect(params.login.request.body!.names, {'studentId', 'password'});
      expect(params.login.results.first.when, const [
        LmsJsonMarker(path: ['code'], anyOf: ['-1', '0']),
        LmsBodyContains('x'),
      ]);
    });

    test('키가 빠졌거나 형이 다르면 field다', () {
      for (final (path, value) in <(List<String>, Object?)>[
        (['userAgent'], _remove),
        (['userAgent'], ''),
        (['userAgent'], '  '),
        (['userAgent'], 'Agent\r\nX-Other: 1'),
        (['userAgent'], 1),
        (['ciphers'], 'body'),
        (['ciphers', 'body'], _remove),
        (['ciphers', 'body', 'key'], _remove),
        (['ciphers', 'body', 'key'], {'var': '1key'}),
        (['ciphers', 'body', 'iv'], 'random'),
        (['ciphers', 'body', 'iv'], _remove),
        (['ciphers', 'body', 'key'], {'var': 'bodyKey', 'takeBytes': 20}),
        (['ciphers', 'body', 'key'], {'var': 'bodyKey', 'takeBytes': 16.0}),
        (['ciphers', 'body', 'key'], {'var': 'bodyKey', 'removeChars': 1}),
        (['login'], _remove),
        (['login'], 'login'),
        (['login', 'steps'], 'steps'),
        (['login', 'request'], _remove),
        (['login', 'request', 'method'], 'PUT'),
        (['login', 'request', 'method'], 'post'),
        (['login', 'request', 'url'], _remove),
        (['login', 'request', 'url'], 'https://example.invalid/{studentId}/x'),
        (['login', 'request', 'url'], '{studentId}x'),
        (['login', 'request', 'headers'], 'X: 1'),
        (['login', 'request', 'headers'], {'X Bad': 'yes'}),
        (['login', 'request', 'headers'], {'Cookie': 'x'}),
        (['login', 'request', 'headers'], {'user-agent': 'x'}),
        (['login', 'request', 'headers'], {'Host': 'x'}),
        (['login', 'request', 'headers'], {'Content-Length': '1'}),
        (['login', 'request', 'headers'], {'X-Ok': 'a\nb'}),
        (['login', 'request', 'headers'], {'X-Ok': 1}),
        (
          ['login', 'request', 'body'],
          {'form': <String, Object>{}, 'json': <String, Object>{}},
        ),
        (['login', 'request', 'body'], {'xml': '<x/>'}),
        (
          ['login', 'request', 'body'],
          {
            'form': {'id': 1},
          },
        ),
        (
          ['login', 'request', 'body'],
          {
            'form': {'': 'x'},
          },
        ),
        (['login', 'request', 'body', 'encrypted', 'cipher'], 'other'),
        (['login', 'request', 'body', 'encrypted', 'json'], _remove),
        (['login', 'request', 'body', 'encrypted', 'field'], ''),
        (
          ['login', 'request', 'extract'],
          {
            'a-b': {'path': 'x'},
          },
        ),
        (['login', 'request', 'extract', 'password'], {'path': 'x'}),
        (
          ['login', 'steps', '0', 'extract', 'studentId'],
          {'pattern': 'id=(.)'},
        ),
        (
          ['login', 'request', 'extract', 'handoffUrl'],
          {'path': 'x', 'pattern': 'x(.)'},
        ),
        (['login', 'request', 'extract', 'handoffUrl'], {'optional': true}),
        (['login', 'request', 'extract', 'handoffUrl'], {'pattern': ''}),
        (['login', 'request', 'extract', 'handoffUrl'], {'pattern': '('}),
        (['login', 'request', 'extract', 'handoffUrl'], {'path': 'a..b'}),
        (
          ['login', 'request', 'extract', 'handoffUrl'],
          {'path': 'a', 'optional': 'yes'},
        ),
        (['login', 'results'], _remove),
        (['login', 'results'], <Object>[]),
        (
          ['login', 'results'],
          [
            {
              'when': [
                {'contains': 'x'},
              ],
              'result': 'wrongCredentials',
            },
          ],
        ),
        (['login', 'results', '1', 'when'], <Object>[]),
        (['login', 'results', '1', 'result'], 'ok'),
        (
          ['login', 'results', '1', 'when'],
          [
            {'contains': 'x', 'path': 'a'},
          ],
        ),
        (
          ['login', 'results', '1', 'when'],
          [
            {'contains': ''},
          ],
        ),
        (
          ['login', 'results', '1', 'when'],
          [
            {'path': 'a', 'present': false},
          ],
        ),
        (
          ['login', 'results', '1', 'when'],
          [
            {
              'path': 'a',
              'present': true,
              'anyOf': ['x'],
            },
          ],
        ),
        (
          ['login', 'results', '1', 'when'],
          [
            {
              'path': 'a',
              'anyOf': ['x'],
              'extra': 1,
            },
          ],
        ),
        (['login', 'handoff'], 'handoff'),
      ]) {
        expectProblem(parse(withValue(path, value)), LmsConfigProblem.field);
      }
    });

    test('요청은 앞에서 뽑은 변수만 쓰고, 학번·비밀번호는 로그인 요청만 쓴다', () {
      for (final (path, value) in <(List<String>, Object?)>[
        // 준비 요청이 학번이나 뒤에서 뽑을 값을 쓴다.
        (['login', 'steps', '0', 'url'], '{studentId}'),
        (['login', 'steps', '0', 'url'], '{bodyKey}'),
        (['login', 'steps', '1', 'headers'], {'X-Id': '{password}'}),
        // 로그인 요청이 모르는 변수를 쓴다.
        (['login', 'request', 'headers'], {'X-Synthetic': '{unknown}'}),
        // 세션 넘기기가 비밀번호를 쓴다.
        (['login', 'handoff', 'url'], '{password}'),
        (['login', 'handoff', 'headers'], {'X-Id': '{studentId}'}),
        // 암호 키는 앞 요청에서 뽑은 값이어야 한다.
        (['ciphers', 'body', 'key'], {'var': 'studentId'}),
        (['ciphers', 'body', 'key'], {'var': 'handoffUrl'}),
      ]) {
        expectProblem(parse(withValue(path, value)), LmsConfigProblem.field);
      }
    });

    test('요청 주소가 학교 도메인 밖이거나 https가 아니면 domain이다', () {
      for (final path in [
        ['login', 'steps', '0', 'url'],
        ['login', 'request', 'url'],
        ['login', 'handoff', 'url'],
      ]) {
        for (final url in [
          'https://example.com/x',
          'http://example.invalid/x',
        ]) {
          expectProblem(parse(withValue(path, url)), LmsConfigProblem.domain);
        }
      }
    });
  });

  group('조건과 결과 규칙', () {
    test('LmsJsonPresent는 비어 있지 않은 글자·수·참거짓이 있을 때만 맞다', () {
      const present = LmsJsonPresent(['a', 'b']);
      for (final (json, expected) in <(Object?, bool)>[
        (
          {
            'a': {'b': 'x'},
          },
          true,
        ),
        (
          {
            'a': {'b': 0},
          },
          true,
        ),
        (
          {
            'a': {'b': false},
          },
          true,
        ),
        (
          {
            'a': {'b': ''},
          },
          false,
        ),
        (
          {
            'a': {'b': null},
          },
          false,
        ),
        (
          {
            'a': {
              'b': {'c': 1},
            },
          },
          false,
        ),
        (
          {
            'a': {'c': 'x'},
          },
          false,
        ),
        (null, false),
      ]) {
        expect(present.matches(json), expected, reason: '$json');
      }
    });

    test('LmsBodyContains는 본문 글자를 대소문자를 가려 본다', () {
      const contains = LmsBodyContains('Welcome');
      expect(contains.matches(null, '<p>Welcome</p>'), isTrue);
      expect(contains.matches(null, '<p>welcome</p>'), isFalse);
      expect(contains.matches({'Welcome': 1}), isFalse);
    });

    test('결과는 차례대로 처음 맞는 규칙이고, 한 규칙의 조건은 모두 맞아야 하며, 없으면 해석 실패다', () {
      final spec = LmsLoginSpec(
        request: LmsRequestSpec(method: LmsMethod.get, url: _dummyUrl),
        results: const [
          LmsLoginRule(
            when: [
              LmsJsonMarker(path: ['code'], anyOf: ['locked']),
            ],
            result: LmsLoginResult.parseFailure,
          ),
          LmsLoginRule(
            when: [
              LmsJsonPresent(['next']),
              LmsBodyContains('ok'),
            ],
            result: LmsLoginResult.success,
          ),
          LmsLoginRule(
            when: [
              LmsJsonPresent(['next']),
            ],
            result: LmsLoginResult.wrongCredentials,
          ),
        ],
      );
      expect(
        spec.resultOf({'code': 'locked', 'next': 'x'}, 'ok'),
        LmsLoginResult.parseFailure,
      );
      expect(spec.resultOf({'next': 'x'}, 'ok'), LmsLoginResult.success);
      expect(
        spec.resultOf({'next': 'x'}, 'no'),
        LmsLoginResult.wrongCredentials,
      );
      expect(spec.resultOf({'other': 1}, 'ok'), LmsLoginResult.parseFailure);
    });
  });

  test('로그인 요청 틀이 다르면 요청 상수도 다르다', () {
    final a = parse(syntheticRequestParamsJson).params!;
    final b = parse(syntheticRequestParamsJson).params!;
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    for (final (path, value) in <(List<String>, Object?)>[
      (['userAgent'], 'OtherAgent/1.0'),
      (['ciphers', 'body', 'iv'], 'key'),
      (['login', 'request', 'headers'], const <String, String>{}),
      (['login', 'handoff'], _remove),
      (['login', 'steps', '0', 'extract', 'formToken', 'optional'], false),
    ]) {
      expect(parse(withValue(path, value)).params, isNot(a), reason: '$path');
    }
  });
}

/// 결과 규칙 테스트에 쓰는 아무 주소.
final _dummyUrl = LmsTemplate('https://example.invalid/');

/// [withValue]에서 키를 빼라는 표시.
const Object _remove = Object();
