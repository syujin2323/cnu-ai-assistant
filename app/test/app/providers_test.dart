// 앱 전역 provider 테스트. docs/architecture.md '모션 프리셋', '데모 모드'.

import 'dart:async';
import 'dart:io';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('motionLevelProvider', () {
    testWidgets('OS가 애니메이션을 끄라고 해도 늘 full이다(앱 안의 모션 선택도 없다)', (tester) async {
      // docs/decisions.md 2026-11-13 '모션은 모든 사람에게 같게 보인다'.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(motionLevelProvider), MotionLevel.full);
    });
  });

  group('appModeProvider', () {
    Future<AppMode> modeFor(Map<String, Object> preferences) async {
      SharedPreferences.setMockInitialValues(preferences);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(appModeProvider);
    }

    test('shared_preferences의 app_mode를 읽고, 없으면 real이다', () async {
      expect(await modeFor({}), AppMode.real);
      expect(await modeFor({'app_mode': 'real'}), AppMode.real);
      expect(await modeFor({'app_mode': 'demo'}), AppMode.demo);
    });

    test('데모를 끝내면 외래 키로 이어진 행까지 데모 DB를 모두 비우고 real로 돌아간다', () async {
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final preferences = await SharedPreferences.getInstance();
      // 끝내기는 비운 데모 DB를 닫으므로, 비웠는지는 같은 파일을 다시 열어(다음 데모처럼) 본다.
      final directory = await Directory.systemTemp.createTemp('demo_exit');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/app_demo.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // 실제 databaseProvider처럼 앱 모드를 보게 해 순환 의존이 없는지도 함께 본다.
          databaseProvider.overrideWith((ref) {
            ref.watch(appModeProvider);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      // 과목(부모)과 그 과목의 시간표 칸(자식). 부모가 먼저 지워져도 실패하지 않아야 한다.
      final courseId = await db
          .into(db.courses)
          .insert(CoursesCompanion.insert(name: '과목A'));
      await db
          .into(db.classSlots)
          .insert(
            ClassSlotsCompanion.insert(
              courseId: courseId,
              weekday: 1,
              startMin: 540,
              endMin: 615,
              campus: Campus.daedeok,
              online: false,
              source: SlotSource.manual,
            ),
          );

      final result = await container
          .read(appModeProvider.notifier)
          .exitDemo(container.read(databaseProvider));

      expect(result, const Ok(DemoEntry.me));
      expect(container.read(appModeProvider), AppMode.real);
      expect(preferences.getString('app_mode'), 'real');
      expect(preferences.containsKey('demo_entry'), isFalse);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(await reopened.select(reopened.courses).get(), isEmpty);
      expect(await reopened.select(reopened.classSlots).get(), isEmpty);
    });

    test('끝내기는 데모 DB를 비운 직후 스스로 닫아, 그 뒤의 데모 DB 저장은 Err다', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final realDb = AppDatabase.memory();
      final demoDb = AppDatabase.memory();
      addTearDown(realDb.close);
      addTearDown(demoDb.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          // provider가 데모 DB를 닫지 않게 두어(늦게 닫히는 경우) 끝내기가 스스로 닫는지만 본다.
          databaseProvider.overrideWith(
            (ref) => switch (ref.watch(appModeProvider)) {
              AppMode.real => realDb,
              AppMode.demo => demoDb,
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appModeProvider.notifier).exitDemo(demoDb),
        const Ok(DemoEntry.me),
      );
      expect(
        await SettingsRepository(demoDb).write(SettingKeys.aiEnabled, true),
        isA<Err<void>>(),
      );
    });

    group('데모 끝내기·들어가기를 거듭 부를 때', () {
      late SharedPreferences preferences;
      late AppDatabase realDb;
      late AppDatabase demoDb;
      late ProviderContainer container;

      setUp(() async {
        // 실제·데모 메모리 DB 둘을 함께 여므로 같은 연결을 두 번 쓸 때 내는 drift 경고를 끈다.
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        SharedPreferences.setMockInitialValues({
          'app_mode': 'demo',
          'demo_entry': 'onboarding',
        });
        preferences = await SharedPreferences.getInstance();
        realDb = AppDatabase.memory();
        demoDb = AppDatabase.memory();
        addTearDown(realDb.close);
        addTearDown(demoDb.close);
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            // 실제처럼 모드가 바뀌면 데모 DB를 닫는다.
            databaseProvider.overrideWith((ref) {
              switch (ref.watch(appModeProvider)) {
                case AppMode.real:
                  return realDb;
                case AppMode.demo:
                  ref.onDispose(() => unawaited(demoDb.close()));
                  return demoDb;
              }
            }),
          ],
        );
        addTearDown(container.dispose);
        await demoDb
            .into(demoDb.courses)
            .insert(CoursesCompanion.insert(name: '샘플 과목'));
      });

      test('끝내기를 끝나기 전에 또 부르면 같은 Future이고 비우기는 한 번만 한다', () async {
        final controller = container.read(appModeProvider.notifier);
        final db = container.read(databaseProvider);

        final first = controller.exitDemo(db);
        final second = controller.exitDemo(db);

        expect(second, same(first));
        expect(await first, const Ok(DemoEntry.onboarding));
        expect(container.read(appModeProvider), AppMode.real);
        // 끝난 뒤에 다시 부르면(이미 real) 비우지 않고 들어온 곳만 돌려준다.
        expect(await controller.exitDemo(db), const Ok(DemoEntry.onboarding));
      });

      test('데모 DB를 비우지 못하면 모드와 들어온 곳을 그대로 두고 Err다', () async {
        await demoDb.customStatement(
          'CREATE TRIGGER keep_courses BEFORE DELETE ON courses '
          "BEGIN SELECT RAISE(ABORT, 'test'); END",
        );

        final result = await container
            .read(appModeProvider.notifier)
            .exitDemo(container.read(databaseProvider));

        expect(result, isA<Err<DemoEntry>>());
        expect(container.read(appModeProvider), AppMode.demo);
        expect(preferences.getString('app_mode'), 'demo');
        expect(preferences.getString('demo_entry'), 'onboarding');
        expect(await demoDb.select(demoDb.courses).get(), hasLength(1));
      });

      test('들어가기를 끝나기 전에 또 부르면 같은 Future다', () async {
        expect(
          await container
              .read(appModeProvider.notifier)
              .exitDemo(container.read(databaseProvider)),
          isA<Ok<DemoEntry>>(),
        );
        final controller = container.read(appModeProvider.notifier);

        final first = controller.enterDemo(DemoEntry.me);
        final second = controller.enterDemo(DemoEntry.onboarding);

        expect(second, same(first));
        await first;
        expect(container.read(appModeProvider), AppMode.demo);
        expect(preferences.getString('demo_entry'), 'me');
      });
    });
  });

  group('apiProvider', () {
    test('데모 모드에 들어가면 요청을 보내지 않는 클라이언트로 바뀐다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final real = container.read(apiProvider);
      expect(real.demo, isFalse);

      await container
          .read(appModeProvider.notifier)
          .enterDemo(DemoEntry.onboarding);

      final demo = container.read(apiProvider);
      expect(demo.demo, isTrue);
      expect(demo, isNot(same(real)));
    });
  });
}
