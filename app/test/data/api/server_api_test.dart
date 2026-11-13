// 앱 서버 클라이언트 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'.
//
// 네트워크 없이 dio의 HttpClientAdapter를 가짜로 바꿔, 응답을 Result로 바꾸는지(성공은 본문, 실패는
// 상태 코드와 오류 본문의 code)와 데모 모드에서 요청을 보내지 않는지 본다.

import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:dio/dio.dart';
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
}

/// 요청을 기록하고 [_respond]가 만든 응답을 돌려주는 어댑터.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
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
