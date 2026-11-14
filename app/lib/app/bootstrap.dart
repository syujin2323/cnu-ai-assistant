// 앱 시작 순서. docs/architecture.md '실행 방법'.
//
// 서버 주소 확인(release는 https만, [isAllowedApiBase]) → `Firebase.initializeApp` → App Check
// `activate` → Remote Config 설정·앱 기본값·지난 실행에서 받은 값 적용(세 단계를 따로) → 실제 모드의 폰 DB
// 열기 → 시작 작업(설치 표식 확인, LMS 상태 정리, `app/startup.dart`) → 지금 모드의 폰 DB 열기까지만
// 기다린 뒤 `runApp`을 부른다(`main.dart`). 데모 DB를 열지 못하면 데모를 버리고 실제 모드로 연다. 이 가운데
// 하나라도 실패하면 [BootFailed]를 돌려주고, main은 앱 대신 20 시스템의 시작 실패 화면을 띄운다(OS 시작
// 화면에서 멈추지 않게). 먼저 시작한 준비도 기다려, 그 오류가 잡히지 않은 채 남지 않게 한다. Remote Config
// `fetchAndActivate()`([fetchRemoteConfigAfterLaunch])와 보관 기간이 지난 기록 정리는 runApp 뒤에 시작하고
// 화면은 기다리지 않는다. 위젯 테스트는 Firebase 없이 `RootApp`만 띄우므로 이 파일을 부르지 않는다.

import 'package:cnu_ai_assistant/app/config.dart';
import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/startup.dart';
import 'package:cnu_ai_assistant/app/startup_failure.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/firebase_options.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kReleaseMode;
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 시작의 결과.
sealed class BootOutcome {
  const BootOutcome();
}

/// 시작했다. [container]는 앱 전체가 쓸 provider 컨테이너이고, 폰 DB를 `databaseProvider`로 열어 두어
/// 첫 화면이 같은 인스턴스를 바로 읽는다.
final class BootReady extends BootOutcome {
  const BootReady(this.container);

  final ProviderContainer container;
}

/// 시작하지 못했다. [reason]으로 시작 실패 화면의 문구를 고른다.
final class BootFailed extends BootOutcome {
  const BootFailed(this.reason);

  final StartupFailure reason;
}

/// runApp 전에 기다릴 준비를 한다. 실패해도 던지지 않고 [BootFailed]를 돌려준다. [다시 시도]로 여러 번
/// 불릴 수 있다.
Future<BootOutcome> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isAllowedApiBase(AppConfig.apiBase, release: kReleaseMode)) {
    appLog('insecure_api_base', area: 'bootstrap');
    return const BootFailed(StartupFailure.other);
  }

  // Firebase와 상관없는 준비는 함께 시작해 시작 시간을 늘리지 않는다.
  // 세로 폰만 지원한다(docs/decisions.md 2026-11-06 '화면은 세로 폰만 지원한다'). targetSdk 36의
  // Android 16은 큰 화면(태블릿·폴더블)에서 이 고정을 따르지 않으므로 화면은 넓은 폭에서도 넘치지 않아야 한다.
  final orientation = SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final preferences = SharedPreferences.getInstance();
  final dateFormatting = initializeDateFormatting('ko');

  AppDatabase? realDb;
  ProviderContainer? container;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await _activateAppCheck();
    await configureRemoteConfig(FirebaseRemoteConfig.instance);

    // 앱 모드와 관계없이 실제 모드의 폰 DB를 열고(처음이면 표를 만든다) 그 DB로 시작 작업을 한다.
    // 시작 작업은 DB를 읽지 못해도 넘어가므로 여는 것은 먼저 따로 확인한다. 설치 표식이 없으면 app_mode도
    // 지우므로 appModeProvider가 읽기 전, 컨테이너를 만들기 전에 끝낸다. 데모 모드에서는 이 DB와 데모 DB가
    // 함께 열린다. drift의 '같은 DB 클래스를 여러 번 만듦' 경고는 두 인스턴스가 같은 연결을 쓸 때를 알리는
    // 것이고, 두 DB는 다른 파일이라 끈다.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final sharedPreferences = await preferences;
    realDb = AppDatabase.open(AppMode.real);
    await realDb.customSelect('SELECT 1').get();
    await runStartupTasks(
      realDb: realDb,
      preferences: sharedPreferences,
      secureStorage: appSecureStorage,
    );

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        realDatabaseProvider.overrideWithValue(realDb),
      ],
    );
    await dateFormatting;
    await orientation;
    // 지금 모드의 폰 DB를 연다(데모면 데모 DB). 첫 화면이 기다리지 않고 DB를 읽게 여기서 끝낸다. 데모 DB를
    // 열지 못하면 데모를 버리고 실제 모드로 연다(`openCurrentDatabase`).
    await openCurrentDatabase(container);
    return BootReady(container);
  } catch (error) {
    appLog(
      'bootstrap_failed',
      area: 'bootstrap',
      data: {'error': errorKind(error)},
    );
    container?.dispose();
    await _settle([realDb?.close(), orientation, preferences, dateFormatting]);
    return BootFailed(classifyStartupError(error));
  }
}

/// [futures]가 모두 끝나기를 기다리고 오류는 버린다(실패한 시작을 정리할 때).
Future<void> _settle(List<Future<Object?>?> futures) async {
  for (final future in futures) {
    if (future == null) continue;
    try {
      await future;
    } catch (_) {
      // 시작이 이미 실패했다. 정리 중의 오류는 화면에 더할 것이 없다.
    }
  }
}

/// runApp 뒤에 부른다. 보관 기간이 지난 기록을 실제 DB에서 지운다. 화면은 기다리지 않는다.
Future<void> runDeferredStartupTasksAfterLaunch(ProviderContainer container) =>
    runDeferredStartupTasks(realDb: container.read(realDatabaseProvider));

/// runApp 뒤에 부른다. Remote Config 값을 받아 적용하고, 끝나면(실패·시간 초과 포함) 알린다.
///
/// 오프라인이거나 시간 초과(5초)면 마지막으로 활성화된 값, 그것도 없으면 `setDefaults` 값으로 동작한다.
Future<void> fetchRemoteConfigAfterLaunch(ProviderContainer container) async {
  try {
    await FirebaseRemoteConfig.instance.fetchAndActivate();
  } catch (error) {
    appLog(
      'remote_config_fetch_failed',
      area: 'bootstrap',
      data: {'error': errorKind(error)},
    );
  } finally {
    container.read(remoteConfigFetchProvider).markDone();
  }
}

/// 번들한 Pretendard 글꼴의 OFL을 '오픈소스 라이선스' 화면에 올린다. main에서 한 번 부른다(시작을 다시
/// 시도해도 한 번만 올리게).
void registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Pretendard'], text);
  });
}

/// App Check를 켠다. 디버그·프로필 빌드는 디버그 제공자(디버그 토큰은 Firebase 콘솔에 등록하고
/// 레포에 두지 않는다), 릴리스 빌드는 Play Integrity(Android)와 App Attest(iOS)다.
/// R0는 서버가 검증 결과를 기록만 하므로(`APP_CHECK_ENFORCE` false) 실패해도 앱은 계속 뜬다.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleAppAttestProvider()
          : const AppleDebugProvider(),
    );
  } catch (error) {
    appLog(
      'app_check_activate_failed',
      area: 'bootstrap',
      data: {'error': errorKind(error)},
    );
  }
}
