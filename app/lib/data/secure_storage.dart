// 보안 저장소(flutter_secure_storage). docs/lms.md '학번·비밀번호와 자동 재로그인'·'쿠키 금고',
// docs/architecture.md '앱과 서버 사이 약속 (API)'.
//
// 값은 이 기기에만 두고 앱 서버로 보내지 않는다. iOS 접근 수준은 first_unlock_this_device라
// 백업·기기 이전으로 옮겨지지 않는다. 다만 iOS Keychain 값은 앱을 지워도 남으므로, 설치 표식이
// 없는 첫 실행에 이 저장소를 모두 비운다(`app/startup.dart`).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 보안 저장소의 키.
abstract final class SecureKeys {
  /// 저장된 학번·비밀번호.
  static const String lmsCredential = 'lms_credential';

  /// 쿠키 금고.
  static const String lmsCookieVault = 'lms_cookie_vault';

  /// 설치 토큰.
  static const String installToken = 'install_token';
}

/// 앱의 보안 저장소. 모든 키를 이 설정으로 읽고 쓴다.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
