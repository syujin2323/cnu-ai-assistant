// 앱 시작 작업 테스트. docs/architecture.md '실행 방법', docs/lms.md '쿠키 금고'·'세션 상태'.
//
// 실제 모드의 폰 DB는 메모리 DB, 보안 저장소와 shared_preferences는 모의 값으로 바꾼다.

import 'dart:io';

import 'package:cnu_ai_assistant/app/app.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/startup.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/db/demo_database_files.dart';
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
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart' show NativeDatabase;
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

  group('지금 모드의 폰 DB 열기', () {
    // docs/decisions.md 2026-11-14 '앱을 켤 때 데모 DB를 열지 못하면 실제 모드로 돌아간다'.
    setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
    tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);

    /// 손상된 DB 파일(SQLite 파일이 아님). 열 때 실패한다.
    Future<AppDatabase> corrupt() async {
      final directory = await Directory.systemTemp.createTemp('corrupt_db');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/db.sqlite');
      await file.writeAsString('SQLite 파일이 아니다. ' * 200);
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      return db;
    }

    Future<ProviderContainer> containerWith(
      SharedPreferences preferences, {
      required AppDatabase real,
      required AppDatabase demo,
      required _FakeDemoFiles files,
    }) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          realDatabaseProvider.overrideWithValue(real),
          databaseProvider.overrideWith(
            (ref) => switch (ref.watch(appModeProvider)) {
              AppMode.real => ref.watch(realDatabaseProvider),
              AppMode.demo => demo,
            },
          ),
          demoDatabaseFilesProvider.overrideWithValue(files),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('데모 모드인데 데모 DB를 열지 못하면 데모를 버리고(파일 지움) 실제 모드로 연다', () async {
      final preferences = await preferencesWith({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final files = _FakeDemoFiles();
      final container = await containerWith(
        preferences,
        real: realDb,
        demo: await corrupt(),
        files: files,
      );

      await openCurrentDatabase(container);

      expect(container.read(appModeProvider), AppMode.real);
      expect(container.read(databaseProvider), same(realDb));
      expect(preferences.getString('app_mode'), 'real');
      expect(preferences.containsKey('demo_entry'), isFalse);
      expect(files.deletes, 1);
    });

    test('데모 DB가 열리면 아무것도 바꾸지 않는다', () async {
      final preferences = await preferencesWith({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final files = _FakeDemoFiles();
      final demo = AppDatabase.memory();
      addTearDown(demo.close);
      final container = await containerWith(
        preferences,
        real: realDb,
        demo: demo,
        files: files,
      );

      await openCurrentDatabase(container);

      expect(container.read(appModeProvider), AppMode.demo);
      expect(preferences.getString('demo_entry'), 'me');
      expect(files.deletes, 0);
    });

    test('실제 DB를 열지 못하면 그대로 던져 시작 실패 화면으로 간다(실제 데이터는 지우지 않음)', () async {
      final preferences = await preferencesWith({});
      final files = _FakeDemoFiles();
      final demo = AppDatabase.memory();
      addTearDown(demo.close);
      final container = await containerWith(
        preferences,
        real: await corrupt(),
        demo: demo,
        files: files,
      );

      await expectLater(openCurrentDatabase(container), throwsA(anything));
      expect(files.deletes, 0);
    });
  });

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

/// 데모 DB 파일 지우기를 센다(실제 파일은 건드리지 않음).
class _FakeDemoFiles implements DemoDatabaseFiles {
  int deletes = 0;

  @override
  Future<Result<void>> delete() async {
    deletes++;
    return const Ok(null);
  }
}
