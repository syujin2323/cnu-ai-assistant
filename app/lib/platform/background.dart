// 백그라운드 동기화(R1). docs/architecture.md '앱 코드 규약'의 백그라운드 작업·'플랫폼 프로젝트 설정', docs/lms.md
// '동기화'.
//
// 앱을 켤 때 [scheduleBackgroundSync]가 workmanager에 주기 작업 하나를 등록한다(Android WorkManager는
// [backgroundSyncInterval]마다, iOS BGTaskScheduler는 iOS가 정한 때. iOS가 작업 뒤 다음 작업을 예약하는 최소 간격은
// `AppDelegate.swift`의 3시간). OS가 깨우면 workmanager가 별도 Flutter 엔진에서 [callbackDispatcher]를 부르고,
// [runBackgroundSync]가 그 엔진에서 Firebase → 폰 DB → provider → Remote Config(`fetchAndActivate`)를 다시 준비한
// 뒤 갱신(`list`)을 `SyncCoordinator.run(trigger: background)`으로 부른다. LMS를 부를지는 코디네이터가 정한다(원격
// 스위치, 데모 모드, 업데이트 필요, `settings`의 LMS 상태, 호출 예산). 쓴 결과는 폰 DB로만 전해지므로 앱으로 돌아올
// 때 `LmsAutoSync`가 화면의 스트림을 다시 읽게 한다. 같은 파일을 두 엔진이 함께 쓰는 충돌은 WAL·`busy_timeout`·
// `sync_lease`가 막는다. 서버 신호 푸시(FCM)는 따로 붙인다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/firebase_options.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// 작업 이름. iOS `AppDelegate.swift`의 `BackgroundTasks.syncIdentifier`, Info.plist의
/// `BGTaskSchedulerPermittedIdentifiers`와 같아야 한다(test/platform/background_test.dart가 확인).
const backgroundSyncTask = 'io.github.syujin2323.cnuaiassistant.backgroundSync';

/// Android 주기 작업의 간격(임시. iOS 다음 예약의 최소 간격, 호출 예산 `openStaleMin` 기본값과 같음). iOS는 이 값을
/// 쓰지 않는다. 깨워도 LMS를 부를지는 호출 예산이 정한다.
const backgroundSyncInterval = Duration(hours: 3);

/// 앱을 켤 때 부른다. 백그라운드 엔진의 진입점을 알리고 주기 작업을 등록한다. 이미 있으면 새 설정으로 바꾸므로
/// 켤 때마다 불러도 된다. 실패해도 던지지 않는다. [workmanager]는 테스트가 바꾼다.
Future<void> scheduleBackgroundSync({Workmanager? workmanager}) async {
  final manager = workmanager ?? Workmanager();
  try {
    await manager.initialize(callbackDispatcher);
    await manager.registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: backgroundSyncInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (error) {
    appLog(
      'background_schedule_failed',
      area: 'background',
      data: {'error': errorKind(error)},
    );
  }
}

/// workmanager가 백그라운드 엔진에서 부르는 진입점. 최상위 함수여야 하고, 빌드가 지우지 않게 표시한다.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == backgroundSyncTask) await runBackgroundSync();
    // 실패해도 성공으로 끝내 OS가 곧바로 다시 돌리지 않게 한다(다음 주기와 호출 예산에 맡김).
    return true;
  });
}

/// 백그라운드 작업 한 번. 별도 엔진이므로 Firebase·폰 DB·provider를 다시 준비하고, 끝나면 컨테이너를 버리고 폰
/// DB를 닫는다. 동기화 결과를 돌려주고, 준비하다 실패하면 기록만 남기고 null이다(던지지 않음). 매개변수는
/// 테스트가 바꾼다.
Future<SyncResult?> runBackgroundSync({
  Future<void> Function() prepareFirebase = _prepareFirebase,
  Future<void> Function() fetchRemoteConfig = _fetchRemoteConfig,
  AppDatabase Function() openDatabase = _openRealDatabase,
  Future<SharedPreferences> Function() preferences =
      SharedPreferences.getInstance,
  List<Override> overrides = const [],
}) async {
  AppDatabase? db;
  ProviderContainer? container;
  try {
    await prepareFirebase();
    db = openDatabase();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await preferences()),
        realDatabaseProvider.overrideWithValue(db),
        // 화면 없이 도는 작업이라 실행 중 값 바뀜은 듣지 않고 아래의 fetchAndActivate만 쓴다.
        lmsRemoteUpdatesProvider.overrideWithValue(const Stream.empty()),
        ...overrides,
      ],
    );
    await fetchRemoteConfig();
    container.read(remoteConfigFetchProvider).markDone();
    // 업데이트가 필요한 빌드는 LMS를 부르지 않는다(코디네이터가 updateRequiredProvider로 봄). 화면이 없어 듣는
    // 쪽이 없으면 Riverpod이 최소 버전 스트림을 멈추므로, 끝날 때까지 듣고 두 값을 먼저 읽어 둔다.
    container.listen(updateRequiredProvider, (_, _) {});
    await container.read(appVersionProvider.future);
    await container.read(minAppVersionProvider.future);
    final result = await container
        .read(syncCoordinatorProvider)
        .run(trigger: SyncTrigger.background, scope: SyncScope.list);
    appLog(
      'background_sync',
      area: 'background',
      data: {'kind': result.kind.name},
    );
    return result;
  } catch (error) {
    appLog(
      'background_sync_failed',
      area: 'background',
      data: {'error': errorKind(error)},
    );
    return null;
  } finally {
    container?.dispose();
    await db?.close();
  }
}

/// Firebase를 열고 Remote Config의 설정·앱 기본값·지난 값 적용을 한다(앱 시작과 같음, app/bootstrap.dart).
Future<void> _prepareFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await configureRemoteConfig(FirebaseRemoteConfig.instance);
}

/// 원격 스위치를 보려고 Remote Config 값을 받아 적용한다. 받지 못하면 마지막으로 적용한 값(없으면 앱 기본값)이다.
Future<void> _fetchRemoteConfig() async {
  try {
    await FirebaseRemoteConfig.instance.fetchAndActivate();
  } catch (error) {
    appLog(
      'background_remote_config_failed',
      area: 'background',
      data: {'error': errorKind(error)},
    );
  }
}

AppDatabase _openRealDatabase() => AppDatabase.open(AppMode.real);
