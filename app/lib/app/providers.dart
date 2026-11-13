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
import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/data/api/server_api.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/demo/demo_seed.dart';
import 'package:cnu_ai_assistant/data/repositories/briefing_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/demo_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  /// 14 온보딩 1단계(로그인 화면)의 '로그인 없이 둘러보기'. 끝내면 1단계로 돌아간다.
  onboarding,

  /// 나 탭의 '데모 모드 들어가기'. 끝내면 `/me`로 돌아간다.
  me,
}

/// `SharedPreferences` 인스턴스. `main.dart`(bootstrap)와 테스트가 덮어쓴다.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in bootstrap or tests',
  ),
);

/// 지금 앱 모드. `shared_preferences`의 `app_mode`를 읽고, 데모에 들어가고 나올 때 바꾼다.
final appModeProvider = NotifierProvider<AppModeController, AppMode>(
  AppModeController.new,
);

/// 앱 모드를 읽고 바꾼다. 데모 모드 전환 장치(docs/architecture.md '데모 모드').
///
/// 샘플은 데모 DB를 열 때 넣고(`AppDatabase`의 데모 시드, [databaseProvider]가 넘김) 끝낼 때 비운다
/// ([DemoRepository]). 이 노티파이어는 [databaseProvider]를 읽지 않는다. 그 provider가 이것을 보므로
/// 읽으면 순환 의존이 되고, 모드를 바꾸기 전에 읽은 DB는 실제 DB일 수 있어 비우기를 잘못 붙이면 실제
/// 데이터를 지운다. 들어가기와 끝내기는 진행 중이면 같은 Future를 돌려준다(두 번 눌러도 한 번만 함).
/// 데모를 끝내면 데모 DB를 닫으므로 그때 돌던 데모 DB 저장은 닫힌 DB의 `StorageError`로 끝난다. 데모에
/// 들어갈 때는 실제 DB(`app.sqlite`)가 열린 채라 그때 돌던 저장은 그대로 끝난다.
class AppModeController extends Notifier<AppMode> {
  Future<void>? _entering;
  Future<Result<DemoEntry>>? _exiting;

  @override
  AppMode build() {
    final saved = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.appMode);
    return saved == AppMode.demo.name ? AppMode.demo : AppMode.real;
  }

  /// 데모 모드에 들어간다. 들어온 곳을 남기면 [databaseProvider]가 데모 DB 파일로 바뀐다.
  Future<void> enterDemo(DemoEntry entry) =>
      _entering ??= _enter(entry).whenComplete(() => _entering = null);

  Future<void> _enter(DemoEntry entry) async {
    if (state == AppMode.demo) return;
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.setString(PrefKeys.demoEntry, entry.name);
    await preferences.setString(PrefKeys.appMode, AppMode.demo.name);
    // (알림은 재설계 예정) 재설계 때 다시 본다. 그전까지 여기에 알림 코드를 붙이지 않는다.
    if (!ref.mounted) return;
    state = AppMode.demo;
  }

  /// 데모 모드를 끝낸다. 데모 DB를 비우고 실제 DB로 돌아간 뒤, 들어온 곳을 돌려준다. 데모 DB를 비우지
  /// 못하면 모드를 바꾸지 않고 [Err]다(데모 띠가 안내한다).
  ///
  /// [demoDatabase]는 부르는 쪽이 `databaseProvider`에서 읽어 넘긴 지금의 데모 DB다. 데모 모드가 아니면
  /// 비우지 않는다.
  Future<Result<DemoEntry>> exitDemo(AppDatabase demoDatabase) =>
      _exiting ??= _exit(demoDatabase).whenComplete(() => _exiting = null);

  Future<Result<DemoEntry>> _exit(AppDatabase demoDatabase) async {
    final preferences = ref.read(sharedPreferencesProvider);
    final entry =
        DemoEntry.values.asNameMap()[preferences.getString(
          PrefKeys.demoEntry,
        )] ??
        (preferences.getBool(PrefKeys.onboardingDone) ?? false
            ? DemoEntry.me
            : DemoEntry.onboarding);
    if (state != AppMode.demo) return Ok(entry);
    if (await DemoRepository(demoDatabase).clearAll() case Err(:final error)) {
      appLog('demo_exit_failed', area: 'app', data: errorLogData(error));
      return Err(error);
    }
    await preferences.setString(PrefKeys.appMode, AppMode.real.name);
    await preferences.remove(PrefKeys.demoEntry);
    // (알림은 재설계 예정) 재설계 때 다시 본다. 그전까지 여기에 알림 코드를 붙이지 않는다.
    if (ref.mounted) state = AppMode.real;
    return Ok(entry);
  }
}

/// 실제 모드의 폰 DB(`app.sqlite`). 앱 모드와 관계없이 앱 수명 동안 열어 둔다.
///
/// 설치 표식(`installedAt`)과 LMS 상태(`lms*` 키)는 데모 모드에서도 늘 이 DB에서 읽고 쓴다
/// (docs/lms.md '쿠키 금고'). bootstrap이 runApp 전에 열어 시작 작업을 한 인스턴스로 덮어쓴다.
final realDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open(AppMode.real);
  ref.onDispose(() => unawaited(db.close()));
  return db;
});

/// 화면이 보는 폰 DB. real이면 [realDatabaseProvider]의 `app.sqlite`를 그대로 쓰고, demo면
/// `app_demo.sqlite`를 따로 열고(표가 모두 비었으면 샘플을 넣음) 데모를 끝내면 닫는다. 화면 쪽 `AppDatabase` 인스턴스는 이 provider
/// 하나로만 얻는다. 설치 표식·LMS 상태는 이 provider가 아니라 [realDatabaseProvider]로 다룬다.
final databaseProvider = Provider<AppDatabase>((ref) {
  switch (ref.watch(appModeProvider)) {
    case AppMode.real:
      return ref.watch(realDatabaseProvider);
    case AppMode.demo:
      final db = AppDatabase.open(
        AppMode.demo,
        demoSeeder: seedDemo,
        clock: ref.read(clockProvider),
      );
      ref.onDispose(() => unawaited(db.close()));
      return db;
  }
});

/// `settings` 표 저장소. 지금 모드의 폰 DB를 보므로 데모 모드에서는 데모 DB의 설정이다.
/// 설치 표식·LMS 상태(`lms*` 키)는 앱 모드와 관계없이 실제 DB에서 읽고 쓴다(`app/startup.dart`).
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// `rules` 표 저장소(내 규칙). 지금 모드의 폰 DB를 본다.
final rulesRepositoryProvider = Provider<RulesRepository>(
  (ref) => RulesRepository(ref.watch(databaseProvider)),
);

/// 아침 브리핑 기록 저장소. 지금 모드의 폰 DB를 본다(데모에서는 데모 DB의 기록).
final briefingRepositoryProvider = Provider<BriefingRepository>(
  (ref) => BriefingRepository(ref.watch(databaseProvider)),
);

/// 되돌리기 저장소. 지금 모드의 폰 DB를 본다.
final undoRepositoryProvider = Provider<UndoRepository>(
  (ref) => UndoRepository(ref.watch(databaseProvider)),
);

/// 설정 값. 표에 없는 키는 기본값으로 채워진다.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// 모션 등급(docs/architecture.md '모션 프리셋'). 앱은 늘 [MotionLevel.full]이다. 앱 안의 모션 선택은
/// 없고 OS의 동작 줄이기·애니메이션 삭제와 기기를 보지 않는다(docs/decisions.md 2026-11-13 '모션은 모든
/// 사람에게 같게 보인다'). 화면 테스트는 이 provider를 [MotionLevel.off]로 덮어쓴다.
final motionLevelProvider = Provider<MotionLevel>((ref) => MotionLevel.full);

/// 앱 서버 API 클라이언트. 주소는 `AppConfig.apiBase`(`--dart-define=API_BASE_URL`로 덮어씀).
/// 데모 모드에서는 요청을 보내지 않고 오류를 돌려준다(`ServerApi.demo`).
final apiProvider = Provider<ServerApi>((ref) {
  final api = ServerApi(
    baseUrl: AppConfig.apiBase,
    demo: ref.watch(appModeProvider) == AppMode.demo,
  );
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
