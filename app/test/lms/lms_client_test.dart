// LMS 네이티브 요청 테스트. docs/lms.md '응답 판별'·'쿠키 금고'·'동기화'.
//
// 가짜 서버로 User-Agent·쿠키 붙이기, 리다이렉트를 직접 따라가며 그 사이 쿠키 받기, 방법 바꾸기, 학교 도메인 밖
// 리다이렉트, 다시 보내기를 본다. 주소는 `example.invalid`이고 쿠키 값은 짧은 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_lms_server.dart';

Uri _url(String path) => Uri.parse('https://example.invalid$path');

void main() {
  late List<Duration> sleeps;

  setUp(() => sleeps = []);

  LmsClient client(FakeLmsServer server) => LmsClient(
    dio: createLmsDio(adapter: server),
    jar: LmsCookieJar(schoolDomain: 'example.invalid'),
    userAgent: 'SyntheticAgent/1.0',
    schoolDomain: 'example.invalid',
    clock: FixedClock(DateTime(2026, 11, 15, 10)),
    sleep: (duration) async => sleeps.add(duration),
  );

  test('User-Agent를 붙이고 응답의 상태·최종 주소·Content-Type·본문을 돌려준다', () async {
    final server = FakeLmsServer({
      'GET /a': (_) => const FakeLmsResponse(
        404,
        contentType: 'application/json',
        body: '{"합성": 1}',
      ),
    });
    final response = await client(server)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a?x=1')));
    expect(response.statusCode, 404);
    expect(response.finalUrl, _url('/a?x=1'));
    expect(response.contentType, 'application/json');
    expect(response.body, '{"합성": 1}');
    final request = server.requests.single;
    expect(request.header('user-agent'), 'SyntheticAgent/1.0');
    expect(request.header('cookie'), isNull);
    expect(request.url.query, 'x=1');
  });

  test('POST 본문과 헤더를 그대로 보낸다', () async {
    final server = FakeLmsServer({
      'POST /form': (_) => const FakeLmsResponse(200),
    });
    await client(server).send(
      LmsHttpRequest(
        method: LmsMethod.post,
        url: _url('/form'),
        headers: const {
          'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Synthetic': 'yes',
        },
        body: utf8.encode('a=1&b=%EA%B0%80'),
      ),
    );
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.form, {'a': '1', 'b': '가'});
    expect(request.header('x-synthetic'), 'yes');
  });

  test('리다이렉트를 직접 따라가며 그 사이 받은 쿠키를 다음 요청에 붙인다', () async {
    final server = FakeLmsServer({
      'GET /a': (_) => const FakeLmsResponse(
        302,
        location: '/b',
        setCookies: ['x=v1; Path=/'],
      ),
      'GET /b': (_) => const FakeLmsResponse(
        301,
        location: 'https://example.invalid/dir/c',
        setCookies: ['y=v2; Path=/'],
      ),
      'GET /dir/c': (_) => const FakeLmsResponse(302, location: 'd'),
      'GET /dir/d': (_) => const FakeLmsResponse(200, body: 'done'),
    });
    final lms = client(server);
    final response = await lms.send(
      LmsHttpRequest(method: LmsMethod.get, url: _url('/a')),
    );
    expect(response.statusCode, 200);
    expect(response.finalUrl, _url('/dir/d'));
    expect(response.body, 'done');
    expect(
      [for (final r in server.requests) r.url.path],
      ['/a', '/b', '/dir/c', '/dir/d'],
    );
    expect(server.to('/b').single.header('cookie'), 'x=v1');
    expect(server.to('/dir/d').single.header('cookie'), 'x=v1; y=v2');
    expect([for (final c in lms.jar.cookies) c.name], ['x', 'y']);
  });

  test('POST 뒤 303·302·301은 본문 없는 GET으로, 307·308은 같은 POST로 따라간다', () async {
    for (final (status, method, keepsBody) in [
      (303, 'GET', false),
      (302, 'GET', false),
      (301, 'GET', false),
      (307, 'POST', true),
      (308, 'POST', true),
    ]) {
      final server = FakeLmsServer({
        'POST /submit': (_) => FakeLmsResponse(status, location: '/next'),
        'GET /next': (_) => const FakeLmsResponse(200),
        'POST /next': (_) => const FakeLmsResponse(200),
      });
      await client(server).send(
        LmsHttpRequest(
          method: LmsMethod.post,
          url: _url('/submit'),
          headers: const {'content-type': 'application/json'},
          body: utf8.encode('{"a":1}'),
        ),
      );
      final next = server.to('/next').single;
      expect(next.method, method, reason: '$status');
      expect(next.body.isNotEmpty, keepsBody, reason: '$status');
      expect(next.header('content-type') != null, keepsBody, reason: '$status');
    }
  });

  test('리다이렉트는 5번까지만 따라가고 그다음 응답을 그대로 돌려준다', () async {
    final server = FakeLmsServer({
      for (var i = 0; i < 10; i++)
        'GET /r$i': (_) => FakeLmsResponse(302, location: '/r${i + 1}'),
    });
    final response = await client(server)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/r0')));
    expect(response.statusCode, 302);
    expect(response.finalUrl, _url('/r5'));
    expect(server.requests, hasLength(6));
  });

  test('학교 도메인 밖이나 http로 넘기는 리다이렉트는 따라가지 않는다', () async {
    for (final location in [
      'https://example.com/x',
      'http://example.invalid/x',
      'https://user@example.invalid/x',
    ]) {
      final server = FakeLmsServer({
        'GET /a': (_) => FakeLmsResponse(302, location: location),
      });
      final response = await client(server)
          .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a')));
      expect(response.statusCode, 302, reason: location);
      expect(response.finalUrl, _url('/a'), reason: location);
      expect(server.requests, hasLength(1), reason: location);
    }
  });

  test('연결에 실패하면 3초 뒤 한 번만 다시 보내고, 또 실패하면 응답 없음이다', () async {
    final routes = {'GET /a': (_) => const FakeLmsResponse(200, body: 'ok')};
    final once = FakeLmsServer(routes)..failNext = 1;
    final recovered = await client(once)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a')));
    expect(recovered.statusCode, 200);
    expect(sleeps, [lmsRetryDelay]);
    expect(lmsRetryDelay, const Duration(seconds: 3));

    sleeps.clear();
    final twice = FakeLmsServer(routes)..failNext = 2;
    final failed = await client(twice)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a')));
    expect(failed.statusCode, isNull);
    expect(failed.body, isEmpty);
    expect(sleeps, [lmsRetryDelay]);
    expect(twice.requests, hasLength(2));
  });

  test('리다이렉트 중간에 연결이 끊기면 처음부터 다시 보낸다', () async {
    var hops = 0;
    final server = FakeLmsServer({
      'GET /a': (_) => const FakeLmsResponse(302, location: '/b'),
      'GET /b': (_) => ++hops == 1
          ? const FakeLmsResponse.networkFailure()
          : const FakeLmsResponse(200, body: 'ok'),
    });
    final response = await client(server)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a')));
    expect(response.body, 'ok');
    expect(
      [for (final r in server.requests) r.url.path],
      ['/a', '/b', '/a', '/b'],
    );
  });

  test('UTF-8이 아닌 본문도 던지지 않고 대체 글자로 푼다', () async {
    final server = FakeLmsServer({
      'GET /a': (_) =>
          const FakeLmsResponse(200, bodyBytes: [0x61, 0xff, 0x62]),
    });
    final response = await client(server)
        .send(LmsHttpRequest(method: LmsMethod.get, url: _url('/a')));
    expect(response.body, 'a�b');
  });

  test('학교 도메인의 https 주소가 아니면 보내지 않는다(프로그래밍 오류)', () async {
    final server = FakeLmsServer(const {});
    for (final url in ['https://example.com/', 'http://example.invalid/']) {
      expect(
        () => client(server)
            .send(LmsHttpRequest(method: LmsMethod.get, url: Uri.parse(url))),
        throwsArgumentError,
      );
    }
    expect(server.requests, isEmpty);
  });

  test('createLmsDio는 리다이렉트를 따라가지 않고 모든 상태 코드를 받으며 시간 제한을 둔다', () {
    final options = createLmsDio().options;
    expect(options.followRedirects, isFalse);
    expect(options.validateStatus(500), isTrue);
    expect(options.validateStatus(302), isTrue);
    expect(options.connectTimeout, const Duration(seconds: 10));
    expect(options.receiveTimeout, const Duration(seconds: 20));
    expect(options.sendTimeout, const Duration(seconds: 20));
  });
}
