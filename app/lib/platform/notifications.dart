// 로컬 알림. docs/architecture.md '알림', '데모 모드'.
//
// - Android 알림 채널은 [NotificationChannels]의 넷뿐이고, 앱 시작 때 [LocalNotificationPlugin.initialize]가
//   한 번에 만든다. 알림을 띄우는 코드는 이 네 ID만 쓴다. 중요도·소리는 만든 뒤 바꿀 수 없으므로
//   바꿔야 하면 새 ID(`reminder_v2`)를 만들고 옛 채널을 지운다. iOS는 같은 이름을 `threadIdentifier`로 쓴다.
// - 예약은 `zonedSchedule`만 쓰고 시각은 `Asia/Seoul` 고정의 `TZDateTime`이다. Android는
//   `canScheduleExactNotifications()`가 true일 때만 정확한 알람(`exactAllowWhileIdle`)으로 예약한다.
// - payload는 go_router 경로 문자열 하나다. 알림을 누르면 받은 경로를 그대로 넘기고, 화면 위젯은
//   부르지 않는다. 앱을 켠 알림의 payload는 bootstrap이 [NotificationPlugin.launchPayload]로 읽는다.
// - 플러그인은 [NotificationPlugin] 뒤에 둔다. 위젯 테스트는 플랫폼 채널 없이 가짜를 넣는다.
//   기본값은 아무것도 하지 않는 [NoopNotificationPlugin]이고, bootstrap이 실제 플러그인으로 덮어쓴다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android 알림 채널 ID 넷. docs/architecture.md '알림'.
abstract final class NotificationChannels {
  /// 아침 브리핑·저녁 체크인. 중요도 높음, 소리 있음.
  static const String briefing = 'briefing';

  /// D-3·D-1·시작 10분 전. 중요도 높음, 소리 있음.
  static const String reminder = 'reminder';

  /// 마감 당일. 중요도 높음, 소리 있음.
  static const String dueToday = 'due_today';

  /// 마감 변경·영상 공개 등. 기본 중요도, 소리 없음.
  static const String update = 'update';
}

/// 예약 알림의 고정 ID. 할 일·일정별 알림은 이 값과 겹치지 않는 범위를 쓴다.
abstract final class NotificationIds {
  /// 데일리 브리핑(매일 같은 시각에 되풀이).
  static const int briefing = 1;
}

/// 데일리 브리핑 알림의 문구와 payload.
abstract final class BriefingNotificationContent {
  static const String title = '데일리 브리핑';
  static const String body = '오늘의 일정과 할 일을 확인해 보세요.';

  /// `Routes.briefing`과 같은 경로.
  static const String payload = '/briefing';
}

/// 알림 플러그인과 맞닿는 면. 테스트는 가짜로 바꾼다.
///
/// 구현은 예외를 밖으로 던지지 않는다. 플랫폼 호출이 실패하면 로그만 남기고 실패를 뜻하는 값
/// (false, null)을 돌려준다.
abstract interface class NotificationPlugin {
  /// 플러그인·시간대를 준비하고 채널을 만든다. 앱이 켜져 있을 때 알림을 누르면 [onTap]에
  /// payload를 넘긴다.
  Future<void> initialize({required void Function(String payload) onTap});

  /// 앱을 켠 알림의 payload. 알림으로 켜지지 않았으면 null이다.
  Future<String?> launchPayload();

  /// 알림 권한을 묻는다(Android 13 이상 `POST_NOTIFICATIONS`, iOS 권한 창). 허용했으면 true.
  Future<bool> requestPermission();

  /// 정확한 시각에 예약할 수 있는지. iOS는 늘 true다.
  Future<bool> canScheduleExact();

  /// 매일 [minuteOfDay](자정 기준 분, 한국 시간)에 되풀이하는 알림을 예약한다. 같은 [id]의
  /// 예약은 바꾼다. [exact]가 false면 정확하지 않은 예약(최대 한 시간 늦을 수 있음)이다.
  Future<void> scheduleDaily({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required int minuteOfDay,
    required String payload,
    required bool exact,
  });

  /// [id]의 예약·표시된 알림을 지운다.
  Future<void> cancel(int id);

  /// 모든 예약·표시된 알림을 지운다.
  Future<void> cancelAll();
}

/// 아무것도 하지 않는 플러그인. bootstrap이 덮어쓰기 전의 기본값이고 위젯 테스트가 쓴다.
class NoopNotificationPlugin implements NotificationPlugin {
  const NoopNotificationPlugin();

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> scheduleDaily({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required int minuteOfDay,
    required String payload,
    required bool exact,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// 앱이 쓰는 알림 플러그인. bootstrap이 [LocalNotificationPlugin]으로 덮어쓴다.
final notificationPluginProvider = Provider<NotificationPlugin>(
  (ref) => const NoopNotificationPlugin(),
);

/// 데일리 브리핑 알림 예약.
final briefingNotificationsProvider = Provider<BriefingNotifications>(
  (ref) => BriefingNotifications(ref.watch(notificationPluginProvider)),
);

/// 데일리 브리핑 알림을 예약하거나 지운다.
class BriefingNotifications {
  const BriefingNotifications(this._plugin);

  final NotificationPlugin _plugin;

  /// 앱 모드와 브리핑 시각에 맞춰 다시 예약한다.
  ///
  /// 데모 모드에서는 알림을 예약하지 않고 예약된 알림을 모두 지운다. 실제 모드에서는 매일
  /// [briefingMin]에 `/briefing`을 여는 알림을 예약한다.
  Future<void> sync({required AppMode mode, required int briefingMin}) async {
    if (mode == AppMode.demo) {
      await _plugin.cancelAll();
      return;
    }
    await _plugin.scheduleDaily(
      id: NotificationIds.briefing,
      channelId: NotificationChannels.briefing,
      title: BriefingNotificationContent.title,
      body: BriefingNotificationContent.body,
      minuteOfDay: briefingMin,
      payload: BriefingNotificationContent.payload,
      exact: await _plugin.canScheduleExact(),
    );
  }
}

/// [now] 뒤로 처음 오는 [minuteOfDay] 시각. 지금이 바로 그 시각이면 다음 날이다.
tz.TZDateTime nextDailyAt(tz.TZDateTime now, int minuteOfDay) {
  RangeError.checkValueInInterval(minuteOfDay, 0, 1439, 'minuteOfDay');
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final today = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (today.isAfter(now)) return today;
  return tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day + 1,
    hour,
    minute,
  );
}

/// 채널 하나의 이름·중요도·소리.
typedef _ChannelSpec = ({String name, Importance importance, bool sound});

const Map<String, _ChannelSpec> _channels = {
  NotificationChannels.briefing: (
    name: '브리핑',
    importance: Importance.high,
    sound: true,
  ),
  NotificationChannels.reminder: (
    name: '리마인더',
    importance: Importance.high,
    sound: true,
  ),
  NotificationChannels.dueToday: (
    name: '마감 당일',
    importance: Importance.high,
    sound: true,
  ),
  NotificationChannels.update: (
    name: '변경 알림',
    importance: Importance.defaultImportance,
    sound: false,
  ),
};

/// `flutter_local_notifications`를 쓰는 실제 플러그인.
class LocalNotificationPlugin implements NotificationPlugin {
  /// [_clock]으로 다음 예약 시각을 정한다.
  LocalNotificationPlugin(this._clock);

  final Clock _clock;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  tz.Location? _seoul;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {
    try {
      tz_data.initializeTimeZones();
      final seoul = tz.getLocation('Asia/Seoul');
      tz.setLocalLocation(seoul);
      _seoul = seoul;
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // 권한은 시작할 때 묻지 않고 브리핑 시각을 정할 때 묻는다([requestPermission]).
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.startsWith('/')) onTap(payload);
        },
      );
      final android = _android;
      if (android != null) {
        for (final MapEntry(key: id, value: spec) in _channels.entries) {
          await android.createNotificationChannel(
            AndroidNotificationChannel(
              id,
              spec.name,
              importance: spec.importance,
              playSound: spec.sound,
            ),
          );
        }
      }
    } catch (error) {
      _log('notifications_init_failed', error);
    }
  }

  @override
  Future<String?> launchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      final payload = details.notificationResponse?.payload;
      return payload != null && payload.startsWith('/') ? payload : null;
    } catch (error) {
      _log('notifications_launch_details_failed', error);
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _android?.requestNotificationsPermission() ?? false;
      }
      return await _ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    } catch (error) {
      _log('notifications_permission_failed', error);
      return false;
    }
  }

  @override
  Future<bool> canScheduleExact() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (error) {
      _log('notifications_exact_check_failed', error);
      return false;
    }
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required int minuteOfDay,
    required String payload,
    required bool exact,
  }) async {
    final seoul = _seoul;
    final spec = _channels[channelId];
    if (seoul == null || spec == null) {
      appLog(
        'notifications_schedule_skipped',
        area: 'notifications',
        data: {'ready': seoul != null, 'knownChannel': spec != null},
      );
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        scheduledDate: nextDailyAt(
          tz.TZDateTime.from(_clock.now(), seoul),
          minuteOfDay,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            spec.name,
            importance: spec.importance,
            priority: spec.importance == Importance.high
                ? Priority.high
                : Priority.defaultPriority,
            playSound: spec.sound,
          ),
          iOS: DarwinNotificationDetails(threadIdentifier: channelId),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      _log('notifications_schedule_failed', error);
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      _log('notifications_cancel_failed', error);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error) {
      _log('notifications_cancel_all_failed', error);
    }
  }

  static void _log(String event, Object error) =>
      appLog(event, area: 'notifications', data: {'error': errorKind(error)});
}
