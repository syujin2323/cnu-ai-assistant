// 앱 전역 provider 테스트. docs/architecture.md '모션 프리셋', '데모 모드'.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
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
