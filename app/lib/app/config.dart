// 비밀이 아닌 설정 상수. docs/architecture.md '한눈에 보기'(서버), '실행 방법',
// '앱과 서버 사이 약속 (API)'. 키나 토큰 같은 비밀값은 여기에 두지 않는다.

/// 앱 전역 설정 상수.
abstract final class AppConfig {
  /// 서버 API 기본 주소. 서울 리전(asia-northeast3)에 배포한 Functions의 `api` 함수다.
  ///
  /// 로컬 에뮬레이터나 다른 주소를 쓸 때는 `--dart-define=API_BASE_URL=...`로 덮어쓴다.
  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://asia-northeast3-cnu-ai-assistant.cloudfunctions.net/api',
  );
}
