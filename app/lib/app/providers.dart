// 앱 전역 provider. docs/architecture.md '앱 코드 규약', '데모 모드', '모션 프리셋'.
//
// provider는 `Provider`(의존성·설정), `NotifierProvider`·`AsyncNotifierProvider`(화면 상태·동작),
// `StreamProvider`(drift `watch()` 결과) 셋만 쓴다. 코드 생성과 legacy provider는 쓰지 않는다.
// 기능별 provider는 그 기능 폴더의 `<화면>_controller.dart`에 둔다.
//
// 루트 scope는 `main.dart` 한 곳뿐이다. 테스트는 `overrides`로 [databaseProvider]·
// [motionLevelProvider]·[sharedPreferencesProvider] 등을 바꾼다. 데모 모드는 overrides를 쓰지 않고
// [databaseProvider]가 [appModeProvider]를 보고 폰 DB 파일을 고른다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/config.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `shared_preferences` 키. 보안 저장소에는 두지 않는다(iOS Keychain 값은 앱을 지워도 남는다).
abstract final class PrefKeys {
  /// 온보딩을 끝냈는지(bool).
  static const String onboardingDone = 'onboarding_done';

  /// 앱 모드. `AppMode`의 이름(`real`/`demo`).
  static const String appMode = 'app_mode';

  /// 데모 모드에 들어온 곳. [DemoEntry]의 이름(`onboarding`/`me`).
  static const String demoEntry = 'demo_entry';
}

/// 데모 모드에 들어온 곳. 데모 띠의 '끝내기'는 여기로 돌아간다.
enum DemoEntry {
  /// 온보딩 첫 화면의 '둘러보기'. 끝내면 온보딩 첫 화면으로 돌아간다.
  onboarding,

  /// 나 화면의 '데모 모드 들어가기'. 끝내면 `/me`로 돌아간다.
  me,
}

/// `SharedPreferences` 인스턴스. `main.dart`(bootstrap)와 테스트가 덮어쓴다.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap or tests',
  ),
);

/// Android의 SDK 버전. Android가 아니면 null이다. bootstrap이 `device_info_plus`로 읽어 덮어쓴다.
final androidSdkIntProvider = Provider<int?>((ref) => null);

/// 지금 앱 모드. `shared_preferences`의 `app_mode`를 읽고, 데모에 들어가고 나올 때 바꾼다.
final appModeProvider = NotifierProvider<AppModeController, AppMode>(
  AppModeController.new,
);

/// 앱 모드를 읽고 바꾼다. 데모 모드 전환 장치(docs/architecture.md '데모 모드').
class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() {
    final saved = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.appMode);
    return saved == AppMode.demo.name ? AppMode.demo : AppMode.real;
  }

  /// 데모 모드에 들어간다. 들어온 곳을 남기면 [databaseProvider]가 데모 DB 파일로 바뀐다.
  ///
  /// 샘플 데이터는 `data/demo/demo_seed.dart`가 데모 DB를 처음 열 때 넣는다(다음 PR).
  Future<void> enterDemo(DemoEntry entry) async {
    if (state == AppMode.demo) return;
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.setString(PrefKeys.demoEntry, entry.name);
    await preferences.setString(PrefKeys.appMode, AppMode.demo.name);
    // 예약 알림 취소는 모드가 바뀌면 `briefingSyncOnModeChangeProvider`(features/me/me_controller.dart)가 한다.
    if (!ref.mounted) return;
    state = AppMode.demo;
  }

  /// 데모 모드를 끝낸다. 데모 DB를 비우고 실제 DB로 돌아간 뒤, 들어온 곳을 돌려준다.
  ///
  /// [demoDatabase]는 부르는 쪽이 `databaseProvider`에서 읽어 넘긴 지금의 데모 DB다.
  /// [databaseProvider]가 이 provider를 보므로 이 노티파이어가 그것을 `ref.read`하면
  /// 순환 의존(Riverpod `CircularDependencyError`)이 된다. 데모 모드가 아니면 비우지 않는다.
  Future<DemoEntry> exitDemo(AppDatabase demoDatabase) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final entry =
        DemoEntry.values.asNameMap()[preferences.getString(
          PrefKeys.demoEntry,
        )] ??
        (preferences.getBool(PrefKeys.onboardingDone) ?? false
            ? DemoEntry.me
            : DemoEntry.onboarding);
    if (state != AppMode.demo) return entry;
    await _clearDatabase(demoDatabase);
    await preferences.setString(PrefKeys.appMode, AppMode.real.name);
    await preferences.remove(PrefKeys.demoEntry);
    // 실제 DB로 알림을 다시 예약하는 일은 `briefingSyncOnModeChangeProvider`가 한다.
    if (!ref.mounted) return entry;
    state = AppMode.real;
    return entry;
  }

  /// 데모 DB의 모든 표를 비운다. 데모 DB는 실제 DB와 다른 파일이라 실제 데이터에는 닿지 않는다.
  static Future<void> _clearDatabase(AppDatabase db) {
    return db.transaction(() async {
      // 표 사이 외래 키가 지우는 순서에 걸리지 않게 검사를 트랜잭션 끝으로 미룬다.
      await db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
    });
  }
}

/// 폰 DB. 앱 모드에 따라 `app.sqlite`(real) 또는 `app_demo.sqlite`(demo)를 연다.
/// 화면 쪽 `AppDatabase` 인스턴스는 이 provider 하나로만 만든다.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open(ref.watch(appModeProvider));
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// `settings` 표 저장소.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// 설정 값. 표에 없는 키는 기본값으로 채워진다.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// OS가 애니메이션을 끄라고 하는지(iOS '동작 줄이기', Android '애니메이션 삭제').
///
/// provider는 `BuildContext`가 없어 `MediaQuery.disableAnimationsOf(context)`를 부를 수 없으므로,
/// 그 값의 원천인 `PlatformDispatcher.accessibilityFeatures.disableAnimations`를 읽고
/// 설정이 바뀌면 다시 알린다.
final systemDisableAnimationsProvider =
    NotifierProvider<SystemDisableAnimations, bool>(
      SystemDisableAnimations.new,
    );

/// [systemDisableAnimationsProvider]의 노티파이어.
class SystemDisableAnimations extends Notifier<bool>
    with WidgetsBindingObserver {
  @override
  bool build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return _read(binding);
  }

  @override
  void didChangeAccessibilityFeatures() {
    state = _read(WidgetsBinding.instance);
  }

  static bool _read(WidgetsBinding binding) =>
      binding.platformDispatcher.accessibilityFeatures.disableAnimations;
}

/// Android 10(API 29). 이보다 낮으면 모션 등급을 `light`로 둔다.
const int _android10SdkInt = 29;

/// 모션 등급(docs/architecture.md '모션 프리셋').
///
/// `settings`의 `motionLevel`이 `auto`가 아니면 그 값이 우선한다. `auto`면 OS가 애니메이션을
/// 끄라고 할 때 `off`, Android 10 미만이면 `light`, 그 밖에는 `full`이다. 판정 기준은 이것뿐이고
/// RAM·Vulkan·프레임 측정은 보지 않는다. 화면 테스트는 이 provider를 `off`로 덮어쓴다.
final motionLevelProvider = Provider<MotionLevel>((ref) {
  final setting =
      ref.watch(
        settingsProvider.select((settings) => settings.value?.motionLevel),
      ) ??
      MotionLevelSetting.auto;
  switch (setting) {
    case MotionLevelSetting.full:
      return MotionLevel.full;
    case MotionLevelSetting.light:
      return MotionLevel.light;
    case MotionLevelSetting.off:
      return MotionLevel.off;
    case MotionLevelSetting.auto:
      if (ref.watch(systemDisableAnimationsProvider)) return MotionLevel.off;
      final sdkInt = ref.watch(androidSdkIntProvider);
      if (sdkInt != null && sdkInt < _android10SdkInt) return MotionLevel.light;
      return MotionLevel.full;
  }
});

/// 앱 서버 API 클라이언트. 주소는 `AppConfig.apiBase`(`--dart-define=API_BASE_URL`로 덮어씀).
/// 데모 모드에서는 서버를 부르지 않는다(부르는 쪽이 [appModeProvider]를 본다).
final apiProvider = Provider<ServerApi>((ref) {
  final api = ServerApi(baseUrl: AppConfig.apiBase);
  ref.onDispose(api.close);
  return api;
});

/// 지금 시각. 테스트는 `FixedClock`으로 덮어쓴다.
final clockProvider = Provider<Clock>((ref) => const Clock());

/// Remote Config `fetchAndActivate()`가 끝났는지.
///
/// bootstrap이 runApp 뒤에 시작한 `fetchAndActivate()`가 끝나면(성공·실패·시간 초과 모두)
/// [RemoteConfigFetch.markDone]을 부른다. 앱 열기 계기의 동기화와 `lms/lms_config.dart`의
/// 읽기는 [RemoteConfigFetch.done]을 기다린 뒤에만 시작한다(docs/architecture.md '실행 방법').
final remoteConfigFetchProvider = Provider<RemoteConfigFetch>(
  (ref) => RemoteConfigFetch(),
);

/// [remoteConfigFetchProvider]의 값.
class RemoteConfigFetch {
  final Completer<void> _completer = Completer<void>();

  /// `fetchAndActivate()`가 끝나면 완료된다.
  Future<void> get done => _completer.future;

  /// 끝났는지.
  bool get isDone => _completer.isCompleted;

  /// 끝났음을 알린다. 여러 번 불러도 된다.
  void markDone() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
