// LMS 계정: 로그아웃. docs/lms.md '로그아웃, 데이터 삭제'.
//
// 10 나 › LMS 계정의 '로그아웃'이 부른다. 이 폰에서 학번·비밀번호와 쿠키 금고, WebView 쿠키를 지우고, 폰 DB에서
// 불러온 시간표(그 수업 예외 포함)와 LMS 할 일(LMS 원본, 그 할 일의 블록)을 지운 뒤 LMS 상태를 `disconnected`로 쓴다.
// 직접 넣은 것과 내 규칙, LMS 과목, 바뀜·동기화 기록은 남긴다. 비밀값을 먼저 지우고, 하나라도 실패하면 거기서
// 멈춰 그 오류를 돌려준다(다시 누르면 처음부터 다시 지운다). 화면 이동(14 온보딩 1단계)은 부르는 쪽이 한다. 폰
// DB는 앱 모드와 관계없이 실제 모드의 파일이다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/local_data_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;

/// WebView 쿠키를 모두 지우는 함수. 테스트는 덮어쓴다(WebView 플랫폼이 없음).
final lmsClearWebViewCookiesProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await WebViewCookieManager().clearCookies();
  },
);

/// LMS 계정.
final lmsAccountProvider = Provider<LmsAccount>((ref) {
  final realDb = ref.watch(realDatabaseProvider);
  return LmsAccount(
    vault: ref.watch(cookieVaultProvider),
    localData: LocalDataRepository(realDb),
    settings: SettingsRepository(realDb),
    clearWebViewCookies: ref.watch(lmsClearWebViewCookiesProvider),
  );
});

/// LMS 계정.
class LmsAccount {
  LmsAccount({
    required this._vault,
    required this._localData,
    required this._settings,
    required this._clearWebViewCookies,
  });

  final CookieVault _vault;

  final LocalDataRepository _localData;

  final SettingsRepository _settings;

  final Future<void> Function() _clearWebViewCookies;

  /// 로그아웃한다. 던지지 않는다.
  Future<Result<void>> logout() async {
    if (await _vault.clear() case Err(:final error)) return _failed(error);
    try {
      await _clearWebViewCookies();
    } on Exception catch (error) {
      appLog(
        'lms_logout_webview_failed',
        area: 'lms',
        data: {'error': errorKind(error)},
      );
      return const Err(
        StorageError('webview.clearCookies', causeType: 'Exception'),
      );
    }
    if (await _localData.deleteLmsData() case Err(:final error)) {
      return _failed(error);
    }
    if (await _settings.write(
          SettingKeys.lmsSessionState,
          LmsSessionState.disconnected,
        )
        case Err(:final error)) {
      return _failed(error);
    }
    appLog('lms_logout', area: 'lms');
    return const Ok(null);
  }

  Err<void> _failed(AppError error) {
    appLog('lms_logout_failed', area: 'lms', data: errorLogData(error));
    return Err(error);
  }
}
