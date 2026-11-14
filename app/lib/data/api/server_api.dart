import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:dio/dio.dart';

/// 토큰 하나를 구하는 함수. 구하지 못하면 null을 돌려준다.
typedef TokenSource = Future<String?> Function();

/// 앱 서버(Cloud Functions `api`) 클라이언트. docs/architecture.md '앱과 서버 사이 약속 (API)'.
///
/// 서버 요청은 모두 이 클래스의 dio 하나로 보낸다. 엔드포인트는 그 경로를 쓰는 PR에서 [postJson] 위에
/// 더하고, 응답이 성공이 아니면 예외 대신 `Result`의 `Err(ApiError(...))`를 돌려준다. 모든 요청에 App Check
/// 토큰(`X-Firebase-AppCheck`)과 설치 토큰(`X-Install-Token`)을 붙이고, `/v1/metrics`에는 설치 토큰을 붙이지
/// 않는다([ServerTokenInterceptor]). 요청 주소와 본문을 남기는 `LogInterceptor`는 쓰지 않는다. 데모
/// 모드에서는 요청을 보내지 않는다([demo]).
class ServerApi {
  ServerApi({
    required String baseUrl,
    this.demo = false,
    TokenSource? appCheckToken,
    TokenSource? installToken,
    HttpClientAdapter? adapter,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           // 연결 3초, 수신 5초. 콜드 스타트를 포함한 요청 하나의 전체 상한 5초는
           // 엔드포인트를 더할 때 요청마다 취소로 건다(넘으면 직접 추가 폼).
           connectTimeout: const Duration(seconds: 3),
           receiveTimeout: const Duration(seconds: 5),
           contentType: 'application/json; charset=utf-8',
           responseType: ResponseType.json,
         ),
       ) {
    _dio.interceptors.add(
      ServerTokenInterceptor(
        appCheckToken: appCheckToken,
        installToken: installToken,
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;

  /// 데모 모드인지. 그러면 요청을 보내지 않고 `ApiError(null, 'demo')`를 돌려준다(docs/architecture.md
  /// '데모 모드': 데모에서는 서버·AI를 부르지 않는다). 부르는 쪽마다 앱 모드를 따로 보지 않아도 되게 여기서
  /// 막는다.
  final bool demo;

  /// 서버 기본 주소(`app/config.dart`의 `apiBase` 또는 `--dart-define=API_BASE_URL`).
  String get baseUrl => _dio.options.baseUrl;

  /// [path]에 JSON [body]를 POST하고 성공 응답의 JSON 본문을 돌려준다. 성공이 아니면 상태 코드와 오류
  /// 본문의 `error.code`를 담은 [ApiError]이고, 응답을 받지 못했으면(연결 실패, 시간 초과) 상태 코드가
  /// null이다.
  Future<Result<Object?>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    if (demo) return const Err(ApiError(null, 'demo'));
    try {
      final response = await _dio.post<Object?>(path, data: body);
      return Ok(response.data);
    } on DioException catch (error) {
      final response = error.response;
      return Err(ApiError(response?.statusCode, _errorCode(response?.data)));
    }
  }

  /// 진행 중인 요청을 끝내고 연결을 닫는다. provider가 버려질 때 부른다.
  void close({bool force = false}) => _dio.close(force: force);

  /// 오류 본문 `{"error": {"code": ...}}`의 코드.
  static String? _errorCode(Object? data) => switch (data) {
    {'error': {'code': final String code}} => code,
    _ => null,
  };
}

/// 서버 요청에 App Check 토큰과 설치 토큰을 붙이는 인터셉터.
///
/// 토큰을 구하지 못하면(Firebase 오류, 보안 저장소 오류) 그 헤더 없이 보낸다. App Check를 강제하지 않는
/// 동안 서버는 기록만 하고, 설치 토큰이 없으면 401로 답한다. 토큰 값은 어디에도 남기지 않는다.
class ServerTokenInterceptor extends Interceptor {
  ServerTokenInterceptor({this._appCheckToken, this._installToken});

  /// App Check 토큰 헤더.
  static const String appCheckHeader = 'X-Firebase-AppCheck';

  /// 설치 토큰 헤더.
  static const String installTokenHeader = 'X-Install-Token';

  /// 설치 토큰을 붙이지 않는 경로(사용 지표, docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표).
  static const String metricsPath = '/v1/metrics';

  final TokenSource? _appCheckToken;
  final TokenSource? _installToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final appCheck = await _tokenOrNull(_appCheckToken, 'app_check');
    if (appCheck != null) options.headers[appCheckHeader] = appCheck;
    if (Uri.parse(options.path).path != metricsPath) {
      final install = await _tokenOrNull(_installToken, 'install');
      if (install != null) options.headers[installTokenHeader] = install;
    }
    handler.next(options);
  }

  static Future<String?> _tokenOrNull(TokenSource? source, String name) async {
    if (source == null) return null;
    try {
      final token = await source();
      return token == null || token.isEmpty ? null : token;
    } on Exception catch (error) {
      appLog(
        'server_token_failed',
        area: 'api',
        data: {'token': name, 'error': errorKind(error)},
      );
      return null;
    }
  }
}
