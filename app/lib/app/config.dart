// 비밀이 아닌 설정 상수. docs/architecture.md '한눈에 보기'(서버), '실행 방법',
// '앱과 서버 사이 약속 (API)'. 키나 토큰 같은 비밀값은 여기에 두지 않는다.

/// 앱 전역 설정 상수.
abstract final class AppConfig {
  /// 서버 API 기본 주소. 서울 리전(asia-northeast3)에 배포한 Functions의 `api` 함수다.
  ///
  /// 로컬 에뮬레이터나 다른 주소를 쓸 때는 `--dart-define=API_BASE_URL=...`로 덮어쓴다.
  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://asia-northeast3-cnu-planner.cloudfunctions.net/api',
  );

  /// Firebase App Distribution의 테스터 페이지. 초대받은 팀원이 받은 앱의 새 빌드를 받는 곳이다.
  static const String appDistributionTesterUrl =
      'https://appdistribution.firebase.google.com/testerapps';

  /// 업데이트 필요 화면의 Android 업데이트 버튼(docs/screens.md '20 시스템'). Play 개발자 계정 전에는 팀원
  /// 빌드를 App Distribution의 APK로 내므로 그 테스터 페이지다(docs/decisions.md 2026-11-19 '팀원 빌드는 Play
  /// 계정 전까지 App Distribution으로 내고 실사용자는 조건이 차면 시작한다'). Play로 옮기면 Play 스토어의 앱
  /// 페이지(`https://play.google.com/store/apps/details?id=io.github.syujin2323.cnuaiassistant`)로 되돌린다.
  static const String androidUpdateUrl = appDistributionTesterUrl;

  /// 업데이트 필요 화면의 iOS 업데이트 버튼. App Store에 내기 전에는 기기 등록 배포(Firebase App
  /// Distribution)의 테스터 페이지이고, App Store에 내면 App Store 주소로 바꾼다(docs/decisions.md 2026-11-15
  /// '업데이트 필요 화면을 첫 테스터 빌드에 넣는다').
  static const String iosUpdateUrl = appDistributionTesterUrl;
}

/// [baseUrl]을 서버 주소로 써도 되는지. release 빌드는 https 주소만 받는다(Android 네트워크 보안 설정과
/// iOS ATS는 dio 요청에 걸리지 않으므로 앱이 직접 막는다). debug·profile 빌드는 로컬 에뮬레이터의 http
/// 주소를 받는다(docs/architecture.md '실행 방법').
bool isAllowedApiBase(String baseUrl, {required bool release}) {
  if (!release) return true;
  final uri = Uri.tryParse(baseUrl);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}
