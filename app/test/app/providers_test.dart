// 앱 전역 provider 테스트. docs/architecture.md '모션 프리셋', '데모 모드'.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('motionLevelProvider', () {
    MotionLevel levelFor({
      MotionLevelSetting setting = MotionLevelSetting.auto,
      bool osDisablesAnimations = false,
      int? androidSdkInt,
    }) {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(
            AsyncValue.data(
              AppSettings.defaults.copyWith(motionLevel: setting),
            ),
          ),
          systemDisableAnimationsProvider.overrideWithBuild(
            (ref, notifier) => osDisablesAnimations,
          ),
          androidSdkIntProvider.overrideWithValue(androidSdkInt),
        ],
      );
      addTearDown(container.dispose);
      return container.read(motionLevelProvider);
    }

    test('auto면 iOS와 Android 10 이상은 full이다', () {
      expect(levelFor(), MotionLevel.full);
      expect(levelFor(androidSdkInt: 29), MotionLevel.full);
    });

    test('auto면 Android 10(API 29) 미만은 light다', () {
      expect(levelFor(androidSdkInt: 28), MotionLevel.light);
      expect(levelFor(androidSdkInt: 24), MotionLevel.light);
    });

    test('auto면 OS가 애니메이션을 끄라고 할 때 off다(낮은 Android보다 먼저)', () {
      expect(levelFor(osDisablesAnimations: true), MotionLevel.off);
      expect(
        levelFor(osDisablesAnimations: true, androidSdkInt: 24),
        MotionLevel.off,
      );
    });

    test('settings의 motionLevel이 auto가 아니면 그 값이 우선한다', () {
      expect(
        levelFor(
          setting: MotionLevelSetting.full,
          osDisablesAnimations: true,
          androidSdkInt: 24,
        ),
        MotionLevel.full,
      );
      expect(
        levelFor(setting: MotionLevelSetting.light, androidSdkInt: 34),
        MotionLevel.light,
      );
      expect(levelFor(setting: MotionLevelSetting.off), MotionLevel.off);
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
      final db = AppDatabase.memory();
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

      final entry = await container
          .read(appModeProvider.notifier)
          .exitDemo(container.read(databaseProvider));

      expect(entry, DemoEntry.me);
      expect(container.read(appModeProvider), AppMode.real);
      expect(preferences.getString('app_mode'), 'real');
      expect(preferences.containsKey('demo_entry'), isFalse);
      expect(await db.select(db.courses).get(), isEmpty);
      expect(await db.select(db.classSlots).get(), isEmpty);
    });
  });
}
