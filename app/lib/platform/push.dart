// 서버 신호 푸시(R1). docs/architecture.md '앱과 서버 사이 약속 (API)'의 서버 신호 푸시와 '앱 코드 규약'의 백그라운드
// 작업, docs/lms.md '동기화'.
//
// 서버는 15분마다 토픽 `sync-0`–`sync-11` 가운데 하나에 data만 담은 `{"kind": "sync"}`를 보낸다(토픽마다 3시간에
// 한 번). 앱은 0–11 가운데 하나를 한 번 무작위로 골라 기억하고, 원격 스위치 `push_signal_enabled`가 켜져 있으며 실제
// 모드에서 LMS에 로그인한 상태(로그인 전이 아님)인 동안만 그 토픽을 구독한다. 그 밖(스위치 꺼짐, 데모 모드, 로그아웃·
// 데이터 삭제로 로그인 전)이 되면 구독을 풀고 FCM 토큰을 지운다. FCM 자동 초기화는 네이티브 설정에서 꺼 두었고, 구독할
// 때만 켜고 풀 때 다시 끈다(그 밖에는 FCM 토큰을 만들지 않음).
//
// 신호를 받으면 [handleBackgroundPush]가 백그라운드 작업과 같은 `runBackgroundSync`를 부른다. LMS를 부를지는 코디네이터가
// 호출 예산으로 정한다. 모르는 `kind`는 무시하고, 앱이 화면에 있을 때 오는 메시지는 쓰지 않는다(앱 열기·쓰는 동안 계기가
// 있음).

import 'dart:async';
import 'dart:math';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/platform/background.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버가 나눠 보내는 토픽 수(`functions/src/push/sync_signal.ts`와 같음).
const syncSignalTopicCount = 12;

/// 고른 토픽 번호(int, 0–11)를 두는 shared_preferences 키. 데이터 삭제로 지우지 않는다(다시 로그인해도 같은 칸).
const syncSignalTopicKey = 'sync_signal_topic';

/// FCM을 켰는지(bool)를 두는 shared_preferences 키. 구독하려고 자동 초기화를 켜기 전에 true로 적고, 자동 초기화를 끄고
/// 토큰까지 지운 뒤에 false로 적는다(구독이 실패하거나 iOS에서 준비가 안 됐어도, 풀 때 정리할 것이 남았음을 알게).
const syncSignalSubscribedKey = 'sync_signal_subscribed';

/// FCM 백그라운드 메시지 진입점. bootstrap이 Firebase를 연 뒤 `FirebaseMessaging.onBackgroundMessage`에 건다. 최상위
/// 함수여야 하고, 빌드가 지우지 않게 표시한다.
@pragma('vm:entry-point')
Future<void> handleBackgroundPush(RemoteMessage message) =>
    handleSyncSignal(message.data);

/// 서버 신호면 백그라운드 동기화를 부른다. 모르는 `kind`는 무시한다. [run]은 테스트가 바꾼다.
Future<void> handleSyncSignal(
  Map<String, dynamic> data, {
  Future<Object?> Function() run = runBackgroundSync,
}) async {
  if (!isSyncSignal(data)) return;
  await run();
}

/// data가 서버 신호(`{"kind": "sync"}`)인지.
bool isSyncSignal(Map<String, dynamic> data) => data['kind'] == 'sync';

/// 토픽을 구독해 둘지. 원격 스위치가 켜져 있고, 실제 모드이며, LMS에 로그인한 상태(로그인 전이 아님)일 때만이다.
bool syncSignalWanted({
  required bool enabled,
  required AppMode mode,
  required LmsSessionState state,
}) => enabled && mode == AppMode.real && !state.beforeLogin;

/// 서버 신호를 쓸지(Remote Config `push_signal_enabled`, 기본 false). 처리방침에 FCM을 적고 시행일이 된 뒤 관리자가
/// 켠다. 앱을 켤 때 Remote Config 받기가 끝난 뒤(실패·시간 초과 포함)의 값 하나만 쓰고, 그 전에는 값이 없다(구독을
/// 바꾸지 않고 개인정보 처리 안내 시트에도 줄을 넣지 않음. 두 곳이 늘 같은 값을 봄). 실행 중에 바뀐 값은 다음 실행부터
/// 따른다. 읽지 못하면 꺼진 것으로 본다. 테스트는 덮어쓴다.
final pushSignalEnabledProvider = FutureProvider<bool>((ref) async {
  await ref.watch(remoteConfigFetchProvider).done;
  try {
    return FirebaseRemoteConfig.instance.getBool(
      RemoteConfigKeys.pushSignalEnabled,
    );
  } on Exception catch (error) {
    appLog(
      'push_signal_switch_read_failed',
      area: 'push',
      data: {'error': errorKind(error)},
    );
    return false;
  }
});

/// 토픽을 구독해 둘지. 원격 스위치나 설정을 아직 읽지 못했으면 null이다(그동안은 바꾸지 않음).
final syncSignalWantedProvider = Provider<bool?>((ref) {
  final enabled = ref.watch(pushSignalEnabledProvider).value;
  final mode = ref.watch(appModeProvider);
  final settings = ref.watch(settingsProvider).value;
  if (enabled == null || settings == null) return null;
  return syncSignalWanted(
    enabled: enabled,
    mode: mode,
    state: settings.lmsSessionState,
  );
});

/// FCM 호출. 테스트는 가짜로 바꾼다.
abstract interface class PushClient {
  Future<void> setAutoInitEnabled(bool enabled);

  /// 토픽을 구독할 수 있는지. iOS는 APNs 토큰이 있어야 한다(없으면 다음 기회에 다시 함).
  Future<bool> ready();

  Future<void> subscribe(String topic);

  Future<void> unsubscribe(String topic);

  /// 이 앱 인스턴스의 FCM 토큰을 지운다(그 토큰으로 보낸 메시지는 더 오지 않음).
  Future<void> deleteToken();
}

/// [FirebaseMessaging]을 쓰는 [PushClient].
class FirebasePushClient implements PushClient {
  FirebasePushClient([FirebaseMessaging? messaging])
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      _messaging.setAutoInitEnabled(enabled);

  @override
  Future<bool> ready() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    // 앱을 켠 직후에는 APNs 토큰이 아직 없을 수 있다. 조금 기다려 보고, 없으면 다음 기회에 다시 한다(Debug 빌드는
    // 푸시 권한(entitlement)이 없어 늘 없음).
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _messaging.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);

  @override
  Future<void> unsubscribe(String topic) =>
      _messaging.unsubscribeFromTopic(topic);

  // `unregister()`는 설치 ID(FID)로 직접 보내는 새 방식의 짝이다. Android는 매니페스트에서 그 방식을 따로 켜야 해서,
  // 켜지 않은 이 앱에서는 'API disabled'로 실패한다(2026-11-18 에뮬레이터에서 확인). 이 앱은 토큰으로 토픽을 구독하므로
  // 그 토큰을 지우는 `deleteToken()`을 쓴다. 플러그인이 이것을 빼면 그때 다시 본다.
  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _messaging.deleteToken();
}

/// 토픽 구독을 원하는 상태에 맞춘다. 부를 때마다 차례로 처리하고 던지지 않는다.
class SyncSignalSubscription {
  SyncSignalSubscription({
    required this._client,
    required this._preferences,
    Random? random,
  }) : _random = random ?? Random();

  final PushClient _client;
  final SharedPreferences _preferences;
  final Random _random;
  Future<void> _queue = Future.value();

  /// [wanted]면 토픽을 구독하고(켤 때마다 다시 구독해 백업 복원·기기 이전에도 맞음), 아니면 FCM을 켰던 때만 자동
  /// 초기화를 끄고 구독을 푼 뒤 FCM 토큰을 지운다. 실패하면 기록만 남기고, 다음에 부를 때(상태가 바뀌거나 다음 실행)
  /// 다시 한다.
  Future<void> apply(bool wanted) =>
      _queue = _queue.then((_) => _apply(wanted));

  Future<void> _apply(bool wanted) async {
    final active = _preferences.getBool(syncSignalSubscribedKey) ?? false;
    if (!wanted && !active) return;
    try {
      final topic = await _topic();
      if (wanted) {
        await _preferences.setBool(syncSignalSubscribedKey, true);
        await _client.setAutoInitEnabled(true);
        if (!await _client.ready()) {
          appLog('sync_signal_not_ready', area: 'push');
          return;
        }
        await _client.subscribe(topic);
      } else {
        // 자동 초기화를 먼저 끈다. 켜 둔 채 토큰을 지우면 다음 실행에서 FCM이 토큰을 다시 만든다.
        await _client.setAutoInitEnabled(false);
        try {
          await _client.unsubscribe(topic);
        } catch (error) {
          // 토큰을 지우면 그 토큰의 구독도 끝나므로 이어서 지운다(구독하지 못했던 때, iOS APNs 토큰이 없을 때 등).
          appLog(
            'sync_signal_unsubscribe_failed',
            area: 'push',
            data: {'error': errorKind(error)},
          );
        }
        await _client.deleteToken();
        await _preferences.setBool(syncSignalSubscribedKey, false);
      }
      appLog(
        'sync_signal_subscription',
        area: 'push',
        data: {'wanted': wanted},
      );
    } catch (error) {
      appLog(
        'sync_signal_subscription_failed',
        area: 'push',
        data: {'wanted': wanted, 'error': errorKind(error)},
      );
    }
  }

  /// 고른 토픽. 처음이거나 저장된 번호가 범위 밖이면 무작위로 골라 둔다.
  Future<String> _topic() async {
    var index = _preferences.getInt(syncSignalTopicKey);
    if (index == null || index < 0 || index >= syncSignalTopicCount) {
      index = _random.nextInt(syncSignalTopicCount);
      await _preferences.setInt(syncSignalTopicKey, index);
    }
    return 'sync-$index';
  }
}

/// 앱의 토픽 구독.
final syncSignalSubscriptionProvider = Provider<SyncSignalSubscription>(
  (ref) => SyncSignalSubscription(
    client: FirebasePushClient(),
    preferences: ref.watch(sharedPreferencesProvider),
  ),
);

/// 앱을 켤 때 Remote Config를 받은 뒤 한 번 부른다. 지금 상태로 구독을 맞추고, 그 뒤로는 구독해 둘지가 바뀔 때마다
/// 맞춘다(로그인, 로그아웃·데이터 삭제, 데모 모드 들고 나기).
void listenSyncSignalSubscription(ProviderContainer container) {
  container.listen<bool?>(syncSignalWantedProvider, (_, wanted) {
    if (wanted == null) return;
    unawaited(container.read(syncSignalSubscriptionProvider).apply(wanted));
  }, fireImmediately: true);
}
