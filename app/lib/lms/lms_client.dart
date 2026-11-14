// LMS 네이티브 요청(dio). docs/lms.md '응답 판별'·'쿠키 금고'·'동기화'.
//
// - 학교 도메인의 https 주소에만 보낸다. 리다이렉트는 dio에 맡기지 않고 최대 5번까지 직접 따라가며, 그 사이 응답의
//   `Set-Cookie`도 쿠키 상자([LmsCookieJar])에 받는다(세션 넘기기 쿠키를 놓치지 않게). 학교 도메인 밖으로 넘기는
//   리다이렉트는 따라가지 않고 그 응답을 그대로 돌려준다.
// - 요청마다 상자의 쿠키(`Cookie` 헤더)와 금고의 User-Agent를 붙인다.
// - 모든 상태 코드를 판별기에 넘기고(`validateStatus`), 연결 실패·시간 초과(연결 10초, 수신 20초)는 3초 뒤 한 번만
//   다시 보낸다. 그래도 실패하면 응답 없음([LmsRawResponse.noResponse])이다.
// - 주소·헤더·본문·쿠키를 로그에 남기지 않고 dio `LogInterceptor`를 쓰지 않는다.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart' show isSchoolUrl;
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 따라가는 리다이렉트의 최대 횟수.
const lmsMaxRedirects = 5;

/// 연결 실패 뒤 다시 보내기까지 기다리는 시간.
const lmsRetryDelay = Duration(seconds: 3);

/// LMS 요청에 쓰는 dio. [adapter]가 있으면 그 연결을 쓴다(테스트).
Dio createLmsDio({HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.bytes,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  return dio;
}

/// LMS 요청의 연결. 앱은 null(dio 기본 연결)이고 테스트는 가짜 서버로 덮어쓴다.
final lmsHttpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// 다시 보내기 전에 기다리는 함수. 테스트는 기다리지 않게 덮어쓴다.
final lmsSleepProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

/// 보낼 요청 하나.
@immutable
final class LmsHttpRequest {
  const LmsHttpRequest({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
  });

  final LmsMethod method;

  final Uri url;

  final Map<String, String> headers;

  /// 본문 바이트. 본문의 `Content-Type`은 [headers]에 둔다. dio는 `Uint8List`만 바꾸지 않고 그대로 보내므로(다른
  /// `List<int>`는 글자로 바꿔 보냄) 형을 좁혀 둔다.
  final Uint8List? body;
}

/// LMS 요청을 보내는 클라이언트. 요청 흐름(로그인, 동기화) 하나에 하나씩 만든다.
class LmsClient {
  LmsClient({
    required this._dio,
    required this.jar,
    required this.userAgent,
    required this.schoolDomain,
    required this._clock,
    this._sleep = Future<void>.delayed,
  });

  final Dio _dio;

  final Clock _clock;

  final Future<void> Function(Duration) _sleep;

  /// 이 흐름의 쿠키 상자.
  final LmsCookieJar jar;

  final String userAgent;

  final String schoolDomain;

  /// [request]를 보내고 리다이렉트를 따라간 응답. 연결에 두 번 실패하면 [LmsRawResponse.noResponse]다. 주소가 학교
  /// 도메인의 https 주소가 아니면 프로그래밍 오류다(요청 틀을 채울 때 막는다).
  Future<LmsRawResponse> send(LmsHttpRequest request) async {
    if (!isSchoolUrl(request.url, domain: schoolDomain)) {
      throw ArgumentError.value(request.url.host, 'request.url', 'not school');
    }
    final first = await _follow(request);
    if (first != null) return first;
    await _sleep(lmsRetryDelay);
    return await _follow(request) ?? const LmsRawResponse.noResponse();
  }

  /// 리다이렉트를 따라간다. 연결에 실패하면 null이다.
  Future<LmsRawResponse?> _follow(LmsHttpRequest request) async {
    var method = request.method;
    var url = request.url;
    var headers = request.headers;
    var body = request.body;
    for (var hop = 0; ; hop++) {
      final response = await _once(method, url, headers, body);
      if (response == null) return null;
      final status = response.statusCode ?? 0;
      jar.storeFrom(
        url,
        response.headers['set-cookie'] ?? const [],
        kstToUtc(_clock.now()),
      );
      final location = response.headers['location']?.firstOrNull;
      if (_isRedirect(status) && location != null && hop < lmsMaxRedirects) {
        final next = url.resolve(location);
        if (isSchoolUrl(next, domain: schoolDomain)) {
          if (status == 303 ||
              ((status == 301 || status == 302) && method == LmsMethod.post)) {
            method = LmsMethod.get;
            body = null;
            headers = {
              for (final MapEntry(:key, :value) in headers.entries)
                if (key.toLowerCase() != 'content-type') key: value,
            };
          }
          url = next;
          continue;
        }
      }
      return LmsRawResponse(
        statusCode: status,
        finalUrl: url,
        contentType: response.headers['content-type']?.firstOrNull,
        body: utf8.decode(response.data ?? const [], allowMalformed: true),
      );
    }
  }

  Future<Response<List<int>>?> _once(
    LmsMethod method,
    Uri url,
    Map<String, String> headers,
    Uint8List? body,
  ) async {
    final cookieHeader = jar.headerFor(url, kstToUtc(_clock.now()));
    try {
      return await _dio.requestUri<List<int>>(
        url,
        data: body,
        options: Options(
          method: method == LmsMethod.get ? 'GET' : 'POST',
          headers: {
            ...headers,
            'user-agent': userAgent,
            'cookie': ?cookieHeader,
          },
        ),
      );
    } on DioException {
      return null;
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;
}
