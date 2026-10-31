// 앱 시작 순서. docs/architecture.md '실행 방법'.
//
// `Firebase.initializeApp` → App Check `activate` → Remote Config 설정·지난 실행에서 받은 값 적용 →
// 폰 DB 열기까지만 기다린 뒤 `runApp`을 부른다(`main.dart`). 알림 플러그인 준비와 앱을 켠 알림의
// payload 읽기는 Firebase와 함께 시작하고, 브리핑 알림 예약은 기다리지 않는다. Remote Config `fetchAndActivate()`는
// runApp 뒤에 시작하고 화면은 기다리지 않는다([fetchRemoteConfigAfterLaunch]).
// 위젯 테스트는 Firebase 없이 `RootApp`만 띄우므로 이 파일을 부르지 않는다.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/features/me/me_controller.dart';
import 'package:cnu_ai_assistant/firebase_options.dart';
import 'package:cnu_ai_assistant/platform/notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// runApp 전에 기다릴 준비를 하고, 앱 전체가 쓸 provider 컨테이너를 돌려준다.
///
/// 폰 DB는 이 컨테이너의 `databaseProvider`로 열어 두므로, 첫 화면은 같은 인스턴스를 바로 읽는다.
Future<ProviderContainer> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();

  // Firebase와 상관없는 준비는 함께 시작해 시작 시간을 늘리지 않는다.
  final preferences = SharedPreferences.getInstance();
  final dateFormatting = initializeDateFormatting('ko');
  final androidSdkInt = _readAndroidSdkInt();
  // 알림 플러그인·시간대를 준비하고, 앱을 켠 알림이 있으면 그 payload를 읽는다.
  // 앱이 켜져 있을 때 알림을 누르면 payload 경로로 이동한다(알림 코드는 화면을 직접 부르지 않는다).
  final notifications = LocalNotificationPlugin(const Clock());
  ProviderContainer? started;
  final launchPayload = _initNotifications(
    notifications,
    onTap: (payload) => started?.read(routerProvider).push(payload),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  await _applyRemoteConfigDefaults();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(await preferences),
      androidSdkIntProvider.overrideWithValue(await androidSdkInt),
      notificationPluginProvider.overrideWithValue(notifications),
      launchPayloadProvider.overrideWithValue(await launchPayload),
    ],
  );
  started = container;
  await dateFormatting;
  // 폰 DB를 연다(처음이면 표를 만든다). 첫 화면이 기다리지 않고 DB를 읽게 여기서 끝낸다.
  await container.read(databaseProvider).customSelect('SELECT 1').get();
  // 앱을 열 때 데일리 브리핑 알림을 다시 예약하고(데모면 모두 지운다), 데모에 들어가고 나올 때도
  // 다시 예약하게 켜 둔다. 화면은 예약을 기다리지 않는다.
  container.read(briefingSyncOnModeChangeProvider);
  unawaited(container.read(briefingSyncProvider)());
  return container;
}

/// 알림 플러그인을 준비하고 앱을 켠 알림의 payload를 돌려준다. 실패해도 앱은 뜬다(플러그인이
/// 로그만 남긴다).
Future<String?> _initNotifications(
  NotificationPlugin notifications, {
  required void Function(String payload) onTap,
}) async {
  await notifications.initialize(onTap: onTap);
  return notifications.launchPayload();
}

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

/// 번들한 Pretendard 글꼴의 OFL을 '오픈소스 라이선스' 화면에 올린다.
void _registerFontLicense() {
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

/// Remote Config의 가져오기 설정과 앱 기본값을 넣고, 지난 실행에서 받아 둔 값을 적용한다.
/// 실패해도 앱은 뜨고, 그때는 Remote Config를 읽는 쪽이 기본값으로 동작한다.
Future<void> _applyRemoteConfigDefaults() async {
  try {
    await configureRemoteConfig(FirebaseRemoteConfig.instance);
  } catch (error) {
    appLog(
      'remote_config_setup_failed',
      area: 'bootstrap',
      data: {'error': errorKind(error)},
    );
  }
}

/// 모션 등급 판정에 쓰는 Android SDK 버전. Android가 아니거나 읽지 못하면 null.
Future<int?> _readAndroidSdkInt() async {
  if (!Platform.isAndroid) return null;
  try {
    return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  } catch (error) {
    appLog(
      'device_info_failed',
      area: 'bootstrap',
      data: {'error': errorKind(error)},
    );
    return null;
  }
}
