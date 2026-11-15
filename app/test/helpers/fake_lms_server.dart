// 가짜 LMS 서버. dio의 연결(`HttpClientAdapter`)을 바꿔 LMS에 요청하지 않고 합성 응답을 돌려준다. 받은 요청을
// 기록해 테스트가 주소·헤더·본문을 확인한다. 호스트는 `example.invalid`이고 응답은 모두 지어낸 값이다.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import 'lms_samples.dart';

/// 서버가 받은 요청.
class FakeLmsRequest {
  FakeLmsRequest(this.method, this.url, this.headers, this.body);

  final String method;

  final Uri url;

  final Map<String, Object?> headers;

  final List<int> body;

  /// 헤더 값(이름은 대소문자를 가리지 않는다). 없으면 null이다.
  String? header(String name) {
    for (final MapEntry(:key, :value) in headers.entries) {
      if (key.toLowerCase() == name.toLowerCase()) {
        return value is List ? value.join(', ') : '$value';
      }
    }
    return null;
  }

  /// 폼 본문의 필드.
  Map<String, String> get form => Uri.splitQueryString(utf8.decode(body));
}

/// 서버의 응답 하나.
class FakeLmsResponse {
  const FakeLmsResponse(
    this.status, {
    this.body = '',
    this.bodyBytes,
    this.contentType,
    this.setCookies = const [],
    this.location,
  }) : networkFailure = false;

  /// 연결 실패(응답 없음)를 흉내 낸다.
  const FakeLmsResponse.networkFailure()
    : status = 0,
      body = '',
      bodyBytes = null,
      contentType = null,
      setCookies = const [],
      location = null,
      networkFailure = true;

  final int status;

  final String body;

  /// 본문 바이트. 있으면 [body] 대신 쓴다(UTF-8이 아닌 본문을 흉내 낼 때).
  final List<int>? bodyBytes;

  final String? contentType;

  /// 응답 헤더의 쿠키 설정 값들.
  final List<String> setCookies;

  final String? location;

  final bool networkFailure;
}

/// 가짜 서버. 경로는 `'GET /path'`처럼 방법과 경로로 고르고, 없으면 404다.
class FakeLmsServer implements HttpClientAdapter {
  FakeLmsServer(this.routes);

  final Map<String, FakeLmsResponse Function(FakeLmsRequest request)> routes;

  /// 받은 요청(차례대로).
  final List<FakeLmsRequest> requests = [];

  /// 앞으로 이만큼의 요청을 연결 실패로 돌려준다.
  int failNext = 0;

  /// 닫혔는지.
  bool closed = false;

  /// [path]로 온 요청.
  List<FakeLmsRequest> to(String path) => [
    for (final r in requests)
      if (r.url.path == path) r,
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final request = FakeLmsRequest(
      options.method,
      options.uri,
      options.headers,
      bytes,
    );
    requests.add(request);
    final route = routes['${options.method} ${options.uri.path}'];
    final response = failNext > 0
        ? const FakeLmsResponse.networkFailure()
        : route == null
        ? const FakeLmsResponse(404)
        : route(request);
    if (failNext > 0) failNext--;
    if (response.networkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromBytes(
      response.bodyBytes ?? utf8.encode(response.body),
      response.status,
      headers: {
        'content-type': ?response.contentType == null
            ? null
            : [response.contentType!],
        if (response.setCookies.isNotEmpty) 'set-cookie': response.setCookies,
        'location': ?response.location == null ? null : [response.location!],
      },
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}

/// AES-CBC(PKCS#7)로 암호화한 base64를 푼다. 합성 서버가 받은 본문을 확인할 때 쓴다.
String aesCbcDecryptBase64(String cipherText, List<int> key, List<int> iv) {
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(
        false,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(key)),
            Uint8List.fromList(iv),
          ),
          null,
        ),
      );
  return utf8.decode(cipher.process(base64.decode(cipherText)));
}

/// 합성 로그인 서버의 경로. [syntheticRequestParams]의 로그인 요청 틀에 맞춘다.
///
/// - 로그인 페이지: 폼 토큰과 키 스크립트 주소를 담고, 쿠키 하나를 준다.
/// - 키 스크립트: [syntheticBodyKey]를 담는다.
/// - 로그인 요청: 암호문을 풀어 학번·비밀번호가 [syntheticStudentId]·[syntheticPassword]면 세션 넘기기 주소를, 아니면
///   틀림 코드를 돌려준다. [loginResult]로 응답을 바꿀 수 있다.
/// - 세션 넘기기: 홈으로 넘기며 세션 쿠키를 준다.
Map<String, FakeLmsResponse Function(FakeLmsRequest)> syntheticLoginRoutes({
  FakeLmsResponse Function(FakeLmsRequest request)? loginResult,
}) => {
  'GET /synthetic-login': (_) => const FakeLmsResponse(
    200,
    contentType: 'text/html; charset=utf-8',
    body:
        '<form data-synthetic-login-form>'
        '<input name="synthetic-token" value="tok-1">'
        '</form><script src="/assets/synthetic-key-3.js"></script>',
    setCookies: ['pre=p1; Path=/'],
  ),
  'GET /assets/synthetic-key-3.js': (_) => const FakeLmsResponse(
    200,
    contentType: 'application/javascript',
    body: "var syntheticKey = '$syntheticBodyKey';",
  ),
  'POST /synthetic-login/submit':
      loginResult ??
      (request) {
        final payload = jsonDecode(
          aesCbcDecryptBase64(
            request.form['payload']!,
            utf8.encode(syntheticBodyKey),
            List.filled(16, 0),
          ),
        ) as Map<String, Object?>;
        final ok =
            payload['id'] == syntheticStudentId &&
            payload['pw'] == syntheticPassword;
        return FakeLmsResponse(
          200,
          contentType: 'application/json',
          body: jsonEncode({
            'result': ok
                ? {'code': 'ok', 'next': 'https://example.invalid/handoff?t=1'}
                : {'code': 'wrong'},
          }),
          setCookies: ok
              ? ['auth=a1; Domain=example.invalid; Path=/; Secure']
              : const [],
        );
      },
  'GET /handoff': (_) => const FakeLmsResponse(
    302,
    location: '/home',
    setCookies: ['sess=s1; Path=/; HttpOnly'],
  ),
  'GET /home': (_) => const FakeLmsResponse(
    200,
    contentType: 'text/html; charset=utf-8',
    body: '<p>합성 홈</p>',
  ),
};
