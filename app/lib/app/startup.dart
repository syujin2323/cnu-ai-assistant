// 앱 시작 작업. docs/architecture.md '실행 방법', docs/lms.md '쿠키 금고'·'세션 상태'.
//
// - [runStartupTasks]: runApp 전에 기다린다. 설치 표식을 확인하고 LMS 상태를 정리한다.
//   시작 위치 규칙이 첫 화면을 고르기 전에 맞는 값을 읽어야 하기 때문이다.
// - [runDeferredStartupTasks]: runApp 뒤에 기다리지 않고 돌린다. 보관 기간이 지난 기록을 지운다.
//
// 모두 앱 모드와 관계없이 실제 모드의 폰 DB(`app.sqlite`)에서 한다. 설치 표식과 LMS 상태(`lms*` 키)는
// 그 DB에만 있고 데모 DB(`app_demo.sqlite`)에는 없다. 데모 DB로 표식을 보면 데모 모드로 다시 켤
// 때마다 실제 계정의 학번·비밀번호·쿠키를 지우게 된다.
//
// 실패해도 앱은 뜬다. 폰 DB를 읽지 못하면 아무것도 지우지 않는다(잠깐의 오류로 로그인 정보를
// 지우지 않게).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/retention_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/session_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// runApp 전에 기다리는 시작 작업. [realDb]는 실제 모드의 폰 DB다.
///
/// 1. 설치 표식: `settings.installedAt`이 없으면 새 설치로 보고 보안 저장소(쿠키 금고, 학번·비밀번호,
///    설치 토큰)와 shared_preferences의 앱 값(`onboarding_done`, `app_mode`, `demo_entry`)을 비운 뒤
///    표식을 적는다. iOS Keychain 값은 앱을 지워도 남고, iOS 백업·기기 이전에는 폰 DB와 보안
///    저장소가 빠지고 shared_preferences만 따라오기 때문이다.
/// 2. LMS 상태: 로그인 화면에서 앱이 꺼져 `connecting`으로 남았으면 시작 전 상태로 돌린다
///    ([sessionStateAtStartup]).
Future<void> runStartupTasks({
  required AppDatabase realDb,
  required SharedPreferences preferences,
  required FlutterSecureStorage secureStorage,
  Clock clock = const Clock(),
}) async {
  final settings = SettingsRepository(realDb);
  final AppSettings current;
  switch (await settings.read()) {
    case Ok(:final value):
      current = value;
    case Err(:final error):
      _logFailure('startup_settings_read_failed', error);
      return;
  }
  if (current.installedAt == null) {
    await _resetForNewInstall(settings, preferences, secureStorage, clock);
  }
  await _settleLmsSessionState(
    settings,
    current.lmsSessionState,
    secureStorage,
  );
}

/// runApp 뒤에 기다리지 않고 돌리는 시작 작업. 보관 기간이 지난 기록을 지운다.
Future<void> runDeferredStartupTasks({
  required AppDatabase realDb,
  Clock clock = const Clock(),
}) async {
  switch (await RetentionRepository(realDb).deleteExpired(now: clock.now())) {
    case Ok(:final value):
      appLog('retention_cleanup', area: 'startup', data: {'deleted': value});
    case Err(:final error):
      _logFailure('retention_cleanup_failed', error);
  }
}

/// 설치 표식이 없는 첫 실행. 보안 저장소를 비우지 못하면 표식을 적지 않아 다음 실행에 다시 시도한다.
Future<void> _resetForNewInstall(
  SettingsRepository settings,
  SharedPreferences preferences,
  FlutterSecureStorage secureStorage,
  Clock clock,
) async {
  try {
    await secureStorage.deleteAll();
  } on Exception catch (error) {
    appLog(
      'startup_secure_storage_clear_failed',
      area: 'startup',
      data: {'error': errorKind(error)},
    );
    return;
  }
  for (final key in [
    PrefKeys.onboardingDone,
    PrefKeys.appMode,
    PrefKeys.demoEntry,
  ]) {
    await preferences.remove(key);
  }
  final written = await settings.write(SettingKeys.installedAt, clock.now());
  if (written case Err(:final error)) {
    _logFailure('startup_install_marker_write_failed', error);
  }
}

/// `connecting`으로 남은 LMS 상태를 시작 전 상태로 돌린다. 학번·비밀번호가 있는지 읽지 못하면
/// 없는 것으로 보고 `disconnected`로 둔다(다시 로그인하면 된다).
Future<void> _settleLmsSessionState(
  SettingsRepository settings,
  LmsSessionState saved,
  FlutterSecureStorage secureStorage,
) async {
  if (saved != LmsSessionState.connecting) return;
  var hasSavedCredentials = false;
  try {
    hasSavedCredentials = await secureStorage.containsKey(
      key: SecureKeys.lmsCredential,
    );
  } on Exception catch (error) {
    appLog(
      'startup_credential_check_failed',
      area: 'startup',
      data: {'error': errorKind(error)},
    );
  }
  final next = sessionStateAtStartup(
    saved,
    hasSavedCredentials: hasSavedCredentials,
  );
  final written = await settings.write(SettingKeys.lmsSessionState, next);
  if (written case Err(:final error)) {
    _logFailure('startup_lms_state_write_failed', error);
  }
}

void _logFailure(String event, AppError error) =>
    appLog(event, area: 'startup', data: {'error': error.toString()});
