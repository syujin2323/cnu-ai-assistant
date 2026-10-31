// 나·설정의 provider. docs/architecture.md '내 규칙', '알림', '데모 모드'.
//
// 브리핑 시각은 하나만 두는 `notify` 규칙의 `briefingMin`이다. 바꾸면 그 행에 합쳐 저장하고
// 데일리 브리핑 알림을 다시 예약한다. 앱을 열 때와 데모에 들어가고 나올 때도 다시 예약한다
// (데모에서는 예약하지 않고 모두 지운다).

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/platform/notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `rules` 표 저장소.
final rulesRepositoryProvider = Provider<RulesRepository>(
  (ref) =>
      RulesRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

/// 기본값 위에 `notify` 규칙을 덮은 알림 설정.
final notifyConfigProvider = StreamProvider<NotifyConfig>(
  (ref) => ref.watch(rulesRepositoryProvider).watchAll().map(NotifyConfig.from),
);

/// 정확한 시각에 알림을 예약할 수 있는지. false면 설정 화면에 늦을 수 있다고 적는다.
final exactAlarmAllowedProvider =
    AsyncNotifierProvider<ExactAlarmAllowed, bool>(ExactAlarmAllowed.new);

/// [exactAlarmAllowedProvider]의 노티파이어.
class ExactAlarmAllowed extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(notificationPluginProvider).canScheduleExact();
}

/// 지금 폰 DB의 규칙과 앱 모드로 데일리 브리핑 알림을 다시 예약하는 함수.
typedef BriefingSync = Future<void> Function();

/// 데일리 브리핑 알림을 다시 예약한다. bootstrap(앱을 열 때)과 브리핑 시각을 바꿀 때 부른다.
///
/// 규칙을 읽지 못하면 기본 브리핑 시각으로 예약한다.
final briefingSyncProvider = Provider<BriefingSync>((ref) {
  return () async {
    final mode = ref.read(appModeProvider);
    var briefingMin = Defaults.briefingMin;
    if (mode == AppMode.real) {
      switch (await ref.read(rulesRepositoryProvider).all()) {
        case Ok(:final value):
          briefingMin = NotifyConfig.from(value).briefingMin;
        case Err(:final error):
          appLog(
            'briefing_sync_rules_failed',
            area: 'notifications',
            data: {'error': error.toString()},
          );
      }
    }
    await ref
        .read(briefingNotificationsProvider)
        .sync(mode: mode, briefingMin: briefingMin);
  };
});

/// 앱 모드가 바뀌면(데모에 들어가고 나올 때) 브리핑 알림을 다시 예약한다. bootstrap이 읽어 켜 둔다.
final briefingSyncOnModeChangeProvider = Provider<void>((ref) {
  ref.listen(appModeProvider, (previous, next) {
    if (previous != next) unawaited(ref.read(briefingSyncProvider)());
  });
});

/// 브리핑 시각을 바꾸는 함수. 저장했으면 true, 값 검사에 걸리거나 폰 DB에 쓰지 못했으면 false다.
typedef BriefingTimeSave = Future<bool> Function(int minuteOfDay);

/// 브리핑 시각을 바꾼다. `notify` 규칙에 합쳐 저장하고(`source` `manual`), 실제 모드면 알림
/// 권한을 물은 뒤 알림을 다시 예약한다. 화면이 닫혀도 끝까지 하도록 위젯의 ref가 아니라
/// provider의 ref로 한다.
final saveBriefingTimeProvider = Provider<BriefingTimeSave>((ref) {
  return (minuteOfDay) async {
    final result = await ref
        .read(rulesRepositoryProvider)
        .saveSingle(RuleKind.notify, RuleParams(briefingMin: minuteOfDay));
    switch (result) {
      case Ok(:final value) when value.isEmpty:
        break;
      case Ok(:final value):
        appLog(
          'briefing_time_invalid',
          area: 'me',
          data: {'issues': value.length},
        );
        return false;
      case Err(:final error):
        appLog(
          'briefing_time_save_failed',
          area: 'me',
          data: {'error': error.toString()},
        );
        return false;
    }
    if (ref.read(appModeProvider) == AppMode.real) {
      await ref.read(notificationPluginProvider).requestPermission();
      ref.invalidate(exactAlarmAllowedProvider);
    }
    await ref.read(briefingSyncProvider)();
    return true;
  };
});
