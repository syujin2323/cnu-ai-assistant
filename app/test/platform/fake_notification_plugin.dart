// 테스트용 가짜 알림 플러그인. 플랫폼 채널을 부르지 않고 받은 호출만 적는다.

import 'package:cnu_ai_assistant/platform/notifications.dart';

/// [scheduleDaily]로 받은 예약 하나.
typedef ScheduledDaily = ({
  int id,
  String channelId,
  String title,
  String body,
  int minuteOfDay,
  String payload,
  bool exact,
});

class FakeNotificationPlugin implements NotificationPlugin {
  FakeNotificationPlugin({this.exactAllowed = true});

  /// [canScheduleExact]가 돌려줄 값.
  bool exactAllowed;

  final List<ScheduledDaily> scheduled = [];
  final List<int> cancelled = [];
  int cancelAllCount = 0;
  int permissionRequests = 0;

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

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
    scheduled.add((
      id: id,
      channelId: channelId,
      title: title,
      body: body,
      minuteOfDay: minuteOfDay,
      payload: payload,
      exact: exact,
    ));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCount++;
}
