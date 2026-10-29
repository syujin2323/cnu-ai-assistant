import 'package:dio/dio.dart';

/// 앱 서버(Cloud Functions `api`) 클라이언트. docs/architecture.md '앱과 서버 사이 약속'.
///
/// 서버 요청은 모두 이 클래스의 dio 하나로 보낸다. 엔드포인트는 그 경로를 쓰는
/// PR에서 더하고, 응답이 성공이 아니면 예외 대신 `Result`의 `Err(ApiError(...))`를
/// 돌려준다. App Check 토큰과 설치 토큰을 붙이는 인터셉터도 첫 엔드포인트와 함께
/// 더한다. 요청 주소와 본문을 남기는 `LogInterceptor`는 쓰지 않는다.
class ServerApi {
  ServerApi({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          // 연결 3초, 수신 5초. 콜드 스타트를 포함한 요청 하나의 전체 상한 5초는
          // 엔드포인트를 더할 때 요청마다 취소로 건다(넘으면 템플릿·직접 입력).
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 5),
          contentType: 'application/json; charset=utf-8',
          responseType: ResponseType.json,
        ),
      );

  final Dio _dio;

  /// 서버 기본 주소(`app/config.dart`의 `apiBase` 또는 `--dart-define=API_BASE_URL`).
  String get baseUrl => _dio.options.baseUrl;

  /// 진행 중인 요청을 끝내고 연결을 닫는다. provider가 버려질 때 부른다.
  void close({bool force = false}) => _dio.close(force: force);
}
