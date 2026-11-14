// 앱 서버 클라이언트 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'.
//
// 네트워크 없이 dio의 HttpClientAdapter를 가짜로 바꿔, 응답을 Result로 바꾸는지(성공은 본문, 실패는
// 상태 코드와 오류 본문의 code), 데모 모드에서 요청을 보내지 않는지, App Check·설치 토큰 헤더를 붙이는지,
// 요청 전체 상한을 넘으면 취소하는지 본다. 토큰은 합성 값이다.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'https://api.example.invalid/api';

  ServerApi apiWith(_FakeAdapter adapter, {bool demo = false}) {
    final api = ServerApi(baseUrl: base, demo: demo, adapter: adapter);
    addTearDown(api.close);
    return api;
  }

  test('JSON 본문을 POST하고 성공 응답의 본문을 Ok로 돌려준다', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'intent': 'other'}));

    final result = await apiWith(adapter)
        .postJson('/v1/parse', {'text': '합성 문장'});

    expect(
      result,
      isA<Ok<Object?>>().having((ok) => ok.value, 'value', {'intent': 'other'}),
    );
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.toString(), '$base/v1/parse');
    expect(request.contentType, startsWith('application/json'));
    expect(jsonDecode(adapter.bodies.single), {'text': '합성 문장'});
  });

  test('성공이 아니면 상태 코드와 오류 본문의 code를 담은 ApiError다', () async {
    final adapter = _FakeAdapter(
      (_) => _json(429, {
        'error': {'code': 'install_limit', 'message': 'daily limit'},
      }),
    );

    expect(
      await apiWith(adapter).postJson('/v1/parse', {}),
      const Err<Object?>(ApiError(429, 'install_limit')),
    );
  });

  test('오류 본문이 약속과 다르면 code는 null이다', () async {
    for (final body in <Object>[
      <String, Object?>{},
      {'error': 'install_limit'},
      {
        'error': {'code': 429},
      },
      ['install_limit'],
    ]) {
      final adapter = _FakeAdapter((_) => _json(503, body));
      expect(
        await apiWith(adapter).postJson('/v1/parse', {}),
        const Err<Object?>(ApiError(503, null)),
        reason: '$body',
      );
    }
    final html = _FakeAdapter(
      (_) => ResponseBody.fromString(
        '<html>Bad Gateway</html>',
        502,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );
    expect(
      await apiWith(html).postJson('/v1/parse', {}),
      const Err<Object?>(ApiError(502, null)),
    );
  });

  test('응답을 받지 못하면(연결 실패) 상태 코드도 code도 null이다', () async {
    final adapter = _FakeAdapter(
      (_) => throw const SocketException('connection refused'),
    );

    expect(
      await apiWith(adapter).postJson('/v1/parse', {}),
      const Err<Object?>(ApiError(null, null)),
    );
  });

  test('데모 모드면 요청을 보내지 않고 ApiError(null, demo)다', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'intent': 'other'}));

    expect(
      await apiWith(adapter, demo: true).postJson('/v1/parse', {'text': 'x'}),
      const Err<Object?>(ApiError(null, 'demo')),
    );
    expect(adapter.requests, isEmpty);
  });

  group('토큰 헤더', () {
    const appCheckHeader = ServerTokenInterceptor.appCheckHeader;
    const installHeader = ServerTokenInterceptor.installTokenHeader;
    final installToken = 'I' * 43;

    ServerApi apiWithTokens(
      _FakeAdapter adapter, {
      TokenSource? appCheck,
      TokenSource? install,
    }) {
      final api = ServerApi(
        baseUrl: base,
        appCheckToken: appCheck,
        installToken: install,
        adapter: adapter,
      );
      addTearDown(api.close);
      return api;
    }

    test('App Check 토큰과 설치 토큰을 헤더에 붙인다', () async {
      final adapter = _FakeAdapter((_) => _json(200, {'intent': 'other'}));

      await apiWithTokens(
        adapter,
        appCheck: () async => 'app-check-synthetic',
        install: () async => installToken,
      ).postJson('/v1/parse', {'text': 'x'});

      final headers = adapter.requests.single.headers;
      expect(headers[appCheckHeader], 'app-check-synthetic');
      expect(headers[installHeader], installToken);
    });

    test('/v1/metrics에는 설치 토큰을 붙이지 않고 구하지도 않는다', () async {
      final adapter = _FakeAdapter((_) => _json(200, {}));
      var installCalls = 0;

      await apiWithTokens(
        adapter,
        appCheck: () async => 'app-check-synthetic',
        install: () async {
          installCalls++;
          return installToken;
        },
      ).postJson('/v1/metrics', {'date': '2026-10-12'});

      final headers = adapter.requests.single.headers;
      expect(headers[appCheckHeader], 'app-check-synthetic');
      expect(headers.containsKey(installHeader), isFalse);
      expect(installCalls, 0);
    });

    test('토큰을 구하지 못하면 그 헤더 없이 보낸다', () async {
      final sources = <TokenSource>[
        () async => throw PlatformException(code: 'unavailable'),
        () async => null,
        () async => '',
      ];
      for (final (index, source) in sources.indexed) {
        final adapter = _FakeAdapter((_) => _json(200, {}));

        final result = await apiWithTokens(
          adapter,
          appCheck: source,
          install: source,
        ).postJson('/v1/parse', {});

        expect(result, isA<Ok<Object?>>(), reason: '$index');
        final headers = adapter.requests.single.headers;
        expect(headers.containsKey(appCheckHeader), isFalse, reason: '$index');
        expect(headers.containsKey(installHeader), isFalse, reason: '$index');
      }
    });
  });

  group('요청 전체 상한', () {
    const limit = Duration(milliseconds: 50);

    ServerApi apiWithLimit(_FakeAdapter adapter, {TokenSource? appCheck}) {
      final api = ServerApi(
        baseUrl: base,
        appCheckToken: appCheck,
        totalTimeout: limit,
        adapter: adapter,
      );
      addTearDown(() => api.close(force: true));
      return api;
    }

    test('응답이 상한 안에 오지 않으면 취소하고 ApiError(null, timeout)다', () async {
      final adapter = _FakeAdapter((_) => Completer<ResponseBody>().future);
      final watch = Stopwatch()..start();

      final result = await apiWithLimit(adapter).postJson('/v1/parse', {});

      expect(result, const Err<Object?>(ApiError(null, 'timeout')));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('토큰을 구하다 멈춰도 상한에서 끝나고 요청을 보내지 않는다', () async {
      final adapter = _FakeAdapter((_) => _json(200, {}));

      final result = await apiWithLimit(
        adapter,
        appCheck: () => Completer<String?>().future,
      ).postJson('/v1/parse', {});

      expect(result, const Err<Object?>(ApiError(null, 'timeout')));
      expect(adapter.requests, isEmpty);
    });

    test('dio의 연결·수신 시간 초과도 timeout이다', () async {
      final adapter = _FakeAdapter(
        (options) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 5),
          requestOptions: options,
        ),
      );

      expect(
        await apiWithLimit(adapter).postJson('/v1/parse', {}),
        const Err<Object?>(ApiError(null, 'timeout')),
      );
    });

    test('상한 안에 온 응답은 그대로 받는다', () async {
      final adapter = _FakeAdapter((_) => _json(200, {'intent': 'other'}));

      final result = await apiWithLimit(adapter).postJson('/v1/parse', {});

      expect(
        result,
        isA<Ok<Object?>>().having((ok) => ok.value, 'value', {
          'intent': 'other',
        }),
      );
    });
  });
}

/// 요청을 기록하고 [_respond]가 만든 응답을 돌려주는 어댑터.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) _respond;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add(
        utf8.decode(await requestStream.expand((chunk) => chunk).toList()),
      );
    }
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
