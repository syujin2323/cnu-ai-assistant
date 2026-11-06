// 앱 시작 작업 테스트. docs/architecture.md '실행 방법', docs/lms.md '쿠키 금고'·'세션 상태'.
//
// 실제 모드의 폰 DB는 메모리 DB, 보안 저장소와 shared_preferences는 모의 값으로 바꾼다.

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/startup.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase realDb;

  setUp(() => realDb = AppDatabase.memory());

  tearDown(() => realDb.close());

  final firstRun = DateTime(2026, 11, 6, 9);

  /// 보안 저장소를 [values]로 채운다. 모의 저장소는 이 맵을 그대로 읽고 고친다.
  Map<String, String> secureStorageWith(Map<String, String> values) {
    final storage = Map.of(values);
    FlutterSecureStorage.setMockInitialValues(storage);
    return storage;
  }

  Future<SharedPreferences> preferencesWith(Map<String, Object> values) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<void> start(SharedPreferences preferences, {DateTime? at}) =>
      runStartupTasks(
        realDb: realDb,
        preferences: preferences,
        secureStorage: appSecureStorage,
        clock: FixedClock(at ?? firstRun),
      );

  SettingsRepository settings() => SettingsRepository(realDb);

  Future<AppSettings> readSettings() async => switch (await settings().read()) {
    Ok(:final value) => value,
    Err(:final error) => fail('settings read failed: $error'),
  };

  const signedIn = {
    SecureKeys.lmsCredential: '합성-학번-비밀번호',
    SecureKeys.lmsCookieVault: '합성-금고',
    SecureKeys.installToken: '합성-설치-토큰',
  };
  final appValues = <String, Object>{
    PrefKeys.onboardingDone: true,
    PrefKeys.appMode: AppMode.demo.name,
    PrefKeys.demoEntry: DemoEntry.me.name,
  };

  group('설치 표식', () {
    test('표식이 없으면 보안 저장소와 앱 값을 비우고 표식을 적는다', () async {
      final secure = secureStorageWith(signedIn);
      final preferences = await preferencesWith(appValues);

      await start(preferences);

      expect(secure, isEmpty);
      expect(preferences.getBool(PrefKeys.onboardingDone), isNull);
      expect(preferences.getString(PrefKeys.appMode), isNull);
      expect(preferences.getString(PrefKeys.demoEntry), isNull);
      expect((await readSettings()).installedAt, firstRun);
    });

    test('표식이 있으면 비우지 않으므로 처음 한 번만 비운다', () async {
      secureStorageWith({});
      final preferences = await preferencesWith({});
      await start(preferences);

      // 첫 실행 뒤 로그인하고 온보딩을 끝낸 상태.
      final secure = secureStorageWith(signedIn);
      await preferences.setBool(PrefKeys.onboardingDone, true);
      await start(preferences, at: firstRun.add(const Duration(days: 1)));

      expect(secure, signedIn);
      expect(preferences.getBool(PrefKeys.onboardingDone), isTrue);
      expect((await readSettings()).installedAt, firstRun);
    });

    test('app_mode가 demo여도 실제 DB에 표식이 있으면 실제 계정 정보를 지우지 않는다', () async {
      await settings().write(SettingKeys.installedAt, firstRun);
      final secure = secureStorageWith(signedIn);
      final preferences = await preferencesWith(appValues);

      await start(preferences, at: firstRun.add(const Duration(days: 3)));

      expect(secure, signedIn);
      expect(preferences.getString(PrefKeys.appMode), AppMode.demo.name);
      expect(preferences.getString(PrefKeys.demoEntry), DemoEntry.me.name);
    });

    test('데이터 삭제로 표식이 없어진 뒤 다시 켜면 다시 비우고 표식을 만든다', () async {
      secureStorageWith({});
      final preferences = await preferencesWith({});
      await start(preferences);

      await realDb.delete(realDb.settings).go();
      final secure = secureStorageWith(signedIn);
      final later = firstRun.add(const Duration(days: 10));
      await start(preferences, at: later);

      expect(secure, isEmpty);
      expect((await readSettings()).installedAt, later);
    });
  });

  group('LMS 상태 정리', () {
    Future<LmsSessionState> startFrom(
      LmsSessionState saved, {
      required Map<String, String> secure,
    }) async {
      await settings().write(SettingKeys.installedAt, firstRun);
      await settings().write(SettingKeys.lmsSessionState, saved);
      secureStorageWith(secure);
      await start(await preferencesWith({}));
      return (await readSettings()).lmsSessionState;
    }

    test('로그인 중 꺼져 connecting으로 남았고 학번·비밀번호가 있으면 reconnectRequired다', () async {
      expect(
        await startFrom(LmsSessionState.connecting, secure: signedIn),
        LmsSessionState.reconnectRequired,
      );
    });

    test('로그인 중 꺼져 connecting으로 남았고 학번·비밀번호가 없으면 disconnected다', () async {
      expect(
        await startFrom(LmsSessionState.connecting, secure: {}),
        LmsSessionState.disconnected,
      );
    });

    test('connecting이 아니면 그대로 둔다', () async {
      expect(
        await startFrom(LmsSessionState.active, secure: {}),
        LmsSessionState.active,
      );
    });
  });

  testWidgets(
    'onboarding_done=true·app_mode=demo가 남았는데 실제 DB가 비었으면 real 모드 /onboarding으로 연다',
    (tester) async {
      // iOS 백업 복원·기기 이전처럼 shared_preferences만 따라온 상태.
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      secureStorageWith({});
      final preferences = await preferencesWith(appValues);
      await tester.runAsync(() => start(preferences));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            realDatabaseProvider.overrideWithValue(realDb),
            motionLevelProvider.overrideWithValue(MotionLevel.off),
            briefingOpenedTodayProvider.overrideWithValue(() async => false),
            launchPayloadProvider.overrideWithValue(null),
          ],
          child: const RootApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RootApp)),
      );
      expect(container.read(appModeProvider), AppMode.real);
      expect(container.read(databaseProvider), same(realDb));
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
