// 데일리 브리핑 알림 예약 테스트. docs/architecture.md '알림', '데모 모드'.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/me/me_controller.dart';
import 'package:cnu_ai_assistant/platform/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'fake_notification_plugin.dart';

void main() {
  group('BriefingNotifications', () {
    test('실제 모드는 브리핑 채널로 매일 그 시각에 /briefing을 예약한다', () async {
      final plugin = FakeNotificationPlugin();
      await BriefingNotifications(plugin)
          .sync(mode: AppMode.real, briefingMin: 450);

      expect(plugin.cancelAllCount, 0);
      expect(plugin.scheduled, [
        (
          id: NotificationIds.briefing,
          channelId: NotificationChannels.briefing,
          title: '데일리 브리핑',
          body: '오늘의 일정과 할 일을 확인해 보세요.',
          minuteOfDay: 450,
          payload: '/briefing',
          exact: true,
        ),
      ]);
    });

    test('정확한 알람을 쓸 수 없으면 정확하지 않은 예약이다', () async {
      final plugin = FakeNotificationPlugin(exactAllowed: false);
      await BriefingNotifications(plugin)
          .sync(mode: AppMode.real, briefingMin: 480);

      expect(plugin.scheduled.single.exact, isFalse);
    });

    test('데모 모드는 예약하지 않고 모두 지운다', () async {
      final plugin = FakeNotificationPlugin();
      await BriefingNotifications(plugin)
          .sync(mode: AppMode.demo, briefingMin: 480);

      expect(plugin.scheduled, isEmpty);
      expect(plugin.cancelAllCount, 1);
    });
  });

  group('briefingSyncProvider', () {
    late AppDatabase db;
    late FakeNotificationPlugin plugin;

    Future<ProviderContainer> container(AppMode mode) async {
      SharedPreferences.setMockInitialValues({'app_mode': mode.name});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(db),
          notificationPluginProvider.overrideWithValue(plugin),
          clockProvider.overrideWithValue(
            FixedClock(DateTime(2026, 10, 29, 10)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      db = AppDatabase.memory();
      plugin = FakeNotificationPlugin();
    });
    tearDown(() => db.close());

    test('규칙이 없으면 기본 브리핑 시각으로 예약한다', () async {
      final c = await container(AppMode.real);
      await c.read(briefingSyncProvider)();

      expect(plugin.scheduled.single.minuteOfDay, 480);
    });

    test('notify 규칙의 briefingMin으로 예약한다', () async {
      final c = await container(AppMode.real);
      await c
          .read(rulesRepositoryProvider)
          .saveSingle(RuleKind.notify, const RuleParams(briefingMin: 420));
      await c.read(briefingSyncProvider)();

      expect(plugin.scheduled.single.minuteOfDay, 420);
    });

    test('데모 모드면 예약하지 않고 모두 지운다', () async {
      final c = await container(AppMode.demo);
      await c.read(briefingSyncProvider)();

      expect(plugin.scheduled, isEmpty);
      expect(plugin.cancelAllCount, 1);
    });

    test('데모에 들어가면 모두 지우고, 나오면 다시 예약한다', () async {
      final c = await container(AppMode.real);
      c.read(briefingSyncOnModeChangeProvider);

      await c.read(appModeProvider.notifier).enterDemo(DemoEntry.me);
      await pumpEventQueue();
      expect(plugin.cancelAllCount, 1);
      expect(plugin.scheduled, isEmpty);

      await c.read(appModeProvider.notifier).exitDemo(db);
      await pumpEventQueue();
      expect(plugin.scheduled.single.minuteOfDay, 480);
    });
  });

  group('nextDailyAt', () {
    setUpAll(tz_data.initializeTimeZones);

    test('오늘 그 시각이 지났으면 내일, 아니면 오늘이다', () {
      final seoul = tz.getLocation('Asia/Seoul');
      final now = tz.TZDateTime(seoul, 2026, 10, 31, 9);

      expect(nextDailyAt(now, 600), tz.TZDateTime(seoul, 2026, 10, 31, 10));
      expect(nextDailyAt(now, 540), tz.TZDateTime(seoul, 2026, 11, 1, 9));
      expect(nextDailyAt(now, 480), tz.TZDateTime(seoul, 2026, 11, 1, 8));
    });
  });
}
