// 요청 틀 실행 테스트. docs/lms.md '로그인'.
//
// 요청 틀을 변수로 채워 만드는 요청(주소 풀기, 폼·JSON·암호 본문, Content-Type)과 응답에서 값 뽑기를 본다. 값은 모두
// 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/request_runner.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_lms_server.dart';

const _key = '0123456789abcdef0123456789abcdef';

void main() {
  const ciphers = {'body': LmsCipherSpec(keyVar: 'k')};

  ({LmsHttpRequest? request, String? problem}) build(
    LmsRequestSpec spec,
    Map<String, String> vars, {
    Uri? base,
  }) => buildLmsRequest(
    spec,
    vars,
    ciphers: ciphers,
    schoolDomain: 'example.invalid',
    base: base,
  );

  LmsRequestSpec get(
    String url, {
    Map<String, LmsExtract> extract = const {},
  }) => LmsRequestSpec(
    method: LmsMethod.get,
    url: LmsTemplate(url),
    extract: extract,
  );

  group('buildLmsRequest', () {
    test('주소: 그대로의 주소, 변수의 절대 주소, 기준 주소로 푼 상대 주소', () {
      expect(
        build(get('https://example.invalid/a?b=1'), const {}).request!.url,
        Uri.parse('https://example.invalid/a?b=1'),
      );
      expect(
        build(get('{u}'), {'u': 'https://lms.example.invalid/x'}).request!.url,
        Uri.parse('https://lms.example.invalid/x'),
      );
      expect(
        build(get('{u}'), {
          'u': '/js/key.js?v=2',
        }, base: Uri.parse('https://example.invalid/login/page')).request!.url,
        Uri.parse('https://example.invalid/js/key.js?v=2'),
      );
      expect(
        build(get('{u}'), {
          'u': 'key.js',
        }, base: Uri.parse('https://example.invalid/login/page')).request!.url,
        Uri.parse('https://example.invalid/login/key.js'),
      );
    });

    test('주소를 풀지 못하거나 학교 도메인의 https 주소가 아니면 url이다', () {
      for (final (value, base) in <(String, Uri?)>[
        ('/relative', null),
        ('https://example.com/x', null),
        ('http://example.invalid/x', null),
        ('//example.com/x', Uri.parse('https://example.invalid/')),
        ('', null),
        ('https://exa mple.invalid', null),
      ]) {
        final built = build(get('{u}'), {'u': value}, base: base);
        expect(built.request, isNull, reason: value);
        expect(built.problem, 'url', reason: value);
      }
    });

    test('헤더를 채우고 폼 본문은 키·값을 URL 인코딩한다', () {
      final request = build(
        LmsRequestSpec(
          method: LmsMethod.post,
          url: LmsTemplate('https://example.invalid/f'),
          headers: {'X-Id': LmsTemplate('id-{id}')},
          body: LmsFormBody({
            'a b': LmsTemplate('{v}'),
            'plain': LmsTemplate('x'),
          }),
        ),
        {'id': '7', 'v': '가+&=/ '},
      ).request!;
      expect(request.method, LmsMethod.post);
      expect(request.headers, {
        'X-Id': 'id-7',
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
      });
      expect(utf8.decode(request.body!), 'a+b=%EA%B0%80%2B%26%3D%2F+&plain=x');
    });

    test('JSON 본문은 틀의 키 순서대로 줄이지 않은 글자를 그대로 둔 짧은 JSON이다', () {
      final request = build(
        LmsRequestSpec(
          method: LmsMethod.post,
          url: LmsTemplate('https://example.invalid/j'),
          body: const LmsJsonBody({
            'b': '{x}',
            'a': [1, '합성'],
          }),
        ),
        {'x': 'X'},
      ).request!;
      expect(utf8.decode(request.body!), '{"b":"X","a":[1,"합성"]}');
      expect(
        request.headers['content-type'],
        'application/json; charset=utf-8',
      );
    });

    test('암호 본문은 채운 JSON을 암호화해 폼 필드 하나에 담는다', () {
      final request = build(
        LmsRequestSpec(
          method: LmsMethod.post,
          url: LmsTemplate('https://example.invalid/e'),
          body: const LmsEncryptedBody(
            cipher: 'body',
            field: 'payload',
            template: {'id': '{id}', 'note': '가'},
          ),
        ),
        {'k': _key, 'id': '7'},
      ).request!;
      final form = Uri.splitQueryString(utf8.decode(request.body!));
      expect(form.keys, ['payload']);
      expect(
        aesCbcDecryptBase64(
          form['payload']!,
          utf8.encode(_key),
          List.filled(16, 0),
        ),
        '{"id":"7","note":"가"}',
      );
      expect(
        request.headers['content-type'],
        'application/x-www-form-urlencoded; charset=UTF-8',
      );
    });

    test('요청 상수가 Content-Type을 정했으면(대소문자 무관) 그 값만 쓴다', () {
      final request = build(
        LmsRequestSpec(
          method: LmsMethod.post,
          url: LmsTemplate('https://example.invalid/j'),
          headers: {'Content-Type': LmsTemplate('text/plain')},
          body: const LmsJsonBody({'a': 1}),
        ),
        const {},
      ).request!;
      expect(request.headers, {'Content-Type': 'text/plain'});
    });

    test('변수가 없으면 variable, 암호 키를 만들지 못하면 cipher다', () {
      expect(
        build(
          LmsRequestSpec(
            method: LmsMethod.get,
            url: LmsTemplate('https://example.invalid/'),
            headers: {'X': LmsTemplate('{missing}')},
          ),
          const {},
        ).problem,
        'variable',
      );
      expect(
        build(
          LmsRequestSpec(
            method: LmsMethod.post,
            url: LmsTemplate('https://example.invalid/'),
            body: const LmsEncryptedBody(
              cipher: 'body',
              field: 'p',
              template: {'a': 1},
            ),
          ),
          {'k': 'short'},
        ).problem,
        'cipher',
      );
    });
  });

  group('LmsRequestRunner.run', () {
    LmsRequestRunner runner(FakeLmsServer server) => LmsRequestRunner(
      client: LmsClient(
        dio: createLmsDio(adapter: server),
        jar: LmsCookieJar(schoolDomain: 'example.invalid'),
        userAgent: 'SyntheticAgent/1.0',
        schoolDomain: 'example.invalid',
        clock: FixedClock(DateTime(2026, 11, 15, 10)),
        sleep: (_) async {},
      ),
      ciphers: ciphers,
      schoolDomain: 'example.invalid',
    );

    test('정규식의 첫 묶음과 JSON 자리 값을 뽑고, 못 찾은 선택 값은 빈 문자열이다', () async {
      final server = FakeLmsServer({
        'GET /p': (_) => const FakeLmsResponse(
          200,
          contentType: 'application/json',
          body: '{"a": {"n": 42}, "s": "token=t-9"}',
        ),
      });
      final result = await runner(server).run(
        get(
          'https://example.invalid/p',
          extract: {
            'n': const LmsJsonExtract(['a', 'n']),
            't': LmsPatternExtract(RegExp('token=([a-z0-9-]+)')),
            'opt': const LmsJsonExtract(['none'], optional: true),
          },
        ),
        const {},
      );
      final sent = result as LmsStepSent;
      expect(sent.isJson, isTrue);
      expect(sent.json, {
        'a': {'n': 42},
        's': 'token=t-9',
      });
      expect(sent.values, {'n': '42', 't': 't-9', 'opt': ''});
      expect(sent.missing, isNull);
      expect(sent.response.statusCode, 200);
    });

    test('꼭 뽑을 값을 못 찾으면 처음 못 찾은 이름을 알린다(빈 값과 묶음 없는 정규식 포함)', () async {
      final server = FakeLmsServer({
        'GET /p': (_) => const FakeLmsResponse(200, body: '<p>x=</p>'),
      });
      final sent = await runner(server).run(
        get(
          'https://example.invalid/p',
          extract: {
            'a': LmsPatternExtract(RegExp('x=([a-z]*)')),
            'b': LmsPatternExtract(RegExp('x=')),
            'c': const LmsJsonExtract(['a']),
          },
        ),
        const {},
      ) as LmsStepSent;
      expect(sent.isJson, isFalse);
      expect(sent.json, isNull);
      expect(sent.values, isEmpty);
      expect(sent.missing, 'a');
    });

    test('요청을 만들지 못하면 보내지 않는다', () async {
      final server = FakeLmsServer(const {});
      final result = await runner(server).run(get('{u}'), {'u': '/x'});
      expect(
        result,
        isA<LmsStepNotSent>().having((r) => r.field, 'field', 'url'),
      );
      expect(server.requests, isEmpty);
    });

    test('변수 주소의 상대 주소는 기준 주소로 푼다', () async {
      final server = FakeLmsServer({
        'GET /login/key.js': (_) => const FakeLmsResponse(200, body: 'ok'),
      });
      final sent = await runner(server).run(get('{u}'), {
        'u': 'key.js',
      }, base: Uri.parse('https://example.invalid/login/page')) as LmsStepSent;
      expect(sent.response.body, 'ok');
    });
  });
}
