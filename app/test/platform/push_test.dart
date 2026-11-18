// 서버 신호 푸시 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'의 서버 신호 푸시.
//
// 신호 가리기, 구독해 둘 때, 토픽 구독·해지의 차례와 저장, 상태가 바뀔 때 다시 맞추기를 본다. FCM 대신 부른 것을 적는
// 가짜를 쓴다.

import 'dart:async';
import 'dart:math';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/platform/push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 부른 것을 차례로 적는 가짜 FCM.
class _FakePushClient implements PushClient {
  final calls = <String>[];
  bool isReady = true;
  Object? failOn;

  Future<void> _record(String call) async {
    calls.add(call);
    if (failOn != null && call.startsWith('$failOn')) throw StateError('합성');
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) => _record('autoInit:$enabled');

  @override
  Future<bool> ready() async {
    calls.add('ready');
    return isReady;
  }

  @override
  Future<void> subscribe(String topic) => _record('subscribe:$topic');

  @override
  Future<void> unsubscribe(String topic) => _record('unsubscribe:$topic');

  @override
  Future<void> deleteToken() => _record('deleteToken');
}

void main() {
  group('신호', () {
    test('kind가 sync일 때만 서버 신호이고 백그라운드 동기화를 부른다', () async {
      var runs = 0;
      Future<Object?> run() async => runs++;

      await handleSyncSignal({'kind': 'sync'}, run: run);
      await handleSyncSignal({'kind': 'other'}, run: run);
      await handleSyncSignal({}, run: run);

      expect(runs, 1);
      expect(isSyncSignal({'kind': 'sync'}), isTrue);
      expect(isSyncSignal({'kind': 'SYNC'}), isFalse);
    });
  });

  test('스위치가 켜져 있고 실제 모드에서 LMS에 로그인한 동안만 구독해 둔다', () {
    for (final state in LmsSessionState.values) {
      expect(
        syncSignalWanted(enabled: true, mode: AppMode.real, state: state),
        !state.beforeLogin,
        reason: state.name,
      );
      expect(
        syncSignalWanted(enabled: false, mode: AppMode.real, state: state),
        isFalse,
      );
      expect(
        syncSignalWanted(enabled: true, mode: AppMode.demo, state: state),
        isFalse,
      );
    }
  });

  group('SyncSignalSubscription', () {
    late _FakePushClient client;
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      client = _FakePushClient();
    });

    SyncSignalSubscription subscription([int seed = 1]) =>
        SyncSignalSubscription(
          client: client,
          preferences: preferences,
          random: Random(seed),
        );

    test('구독하면 자동 초기화를 켜고 고른 토픽 하나를 구독하며, 번호는 처음 한 번만 고른다', () async {
      final topic = 'sync-${Random(1).nextInt(syncSignalTopicCount)}';

      await subscription().apply(true);
      await subscription(99).apply(true);

      expect(client.calls, [
        'autoInit:true',
        'ready',
        'subscribe:$topic',
        'autoInit:true',
        'ready',
        'subscribe:$topic',
      ]);
      expect(
        preferences.getInt(syncSignalTopicKey),
        int.parse(topic.substring(5)),
      );
      expect(preferences.getBool(syncSignalSubscribedKey), isTrue);
    });

    test('구독을 풀면 자동 초기화를 끄고 같은 토픽을 푼 뒤 FCM 토큰을 지운다', () async {
      final sub = subscription();
      await sub.apply(true);
      final topic = client.calls[2].substring('subscribe:'.length);
      client.calls.clear();

      await sub.apply(false);

      expect(client.calls, [
        'autoInit:false',
        'unsubscribe:$topic',
        'deleteToken',
      ]);
      expect(preferences.getBool(syncSignalSubscribedKey), isFalse);
    });

    test('구독한 적이 없으면 풀 때 FCM을 부르지 않는다', () async {
      await subscription().apply(false);
      expect(client.calls, isEmpty);
    });

    test('구독할 준비가 안 됐으면(iOS APNs 토큰 없음) 구독하지 않고 다음에 다시 한다', () async {
      client.isReady = false;
      final sub = subscription();

      await sub.apply(true);
      expect(client.calls, ['autoInit:true', 'ready']);
      // 자동 초기화는 켰으므로 풀 때 정리하도록 표시를 켜 둔다.
      expect(preferences.getBool(syncSignalSubscribedKey), isTrue);

      client.isReady = true;
      await sub.apply(true);
      expect(client.calls.last, startsWith('subscribe:sync-'));
    });

    test('구독하지 못한 채 풀어도 자동 초기화를 끄고 토큰을 지운다', () async {
      final sub = subscription();
      client.failOn = 'subscribe';
      await sub.apply(true);
      expect(preferences.getBool(syncSignalSubscribedKey), isTrue);

      client.failOn = 'unsubscribe';
      client.calls.clear();
      await sub.apply(false);

      // 구독 해지가 실패해도 토큰을 지우면 그 토큰의 구독도 끝난다.
      expect(client.calls.map((call) => call.split(':').first), [
        'autoInit',
        'unsubscribe',
        'deleteToken',
      ]);
      expect(preferences.getBool(syncSignalSubscribedKey), isFalse);
    });

    test('토큰을 지우지 못하면 던지지 않고 표시를 켜 둔 채 다음에 다시 한다', () async {
      final sub = subscription();
      await sub.apply(true);

      client.failOn = 'deleteToken';
      await sub.apply(false);
      expect(preferences.getBool(syncSignalSubscribedKey), isTrue);

      client.failOn = null;
      client.calls.clear();
      await sub.apply(false);
      expect(client.calls.last, 'deleteToken');
      expect(preferences.getBool(syncSignalSubscribedKey), isFalse);
    });

    test('저장된 토픽 번호가 범위 밖이면 다시 고른다', () async {
      await preferences.setInt(syncSignalTopicKey, syncSignalTopicCount);

      await subscription().apply(true);

      final index = preferences.getInt(syncSignalTopicKey)!;
      expect(index, inInclusiveRange(0, syncSignalTopicCount - 1));
      expect(client.calls.last, 'subscribe:sync-$index');
    });

    test('잇달아 불러도 부른 차례대로 처리한다', () async {
      final sub = subscription();
      unawaited(sub.apply(true));
      await sub.apply(false);

      expect(client.calls.map((call) => call.split(':').first), [
        'autoInit',
        'ready',
        'subscribe',
        'autoInit',
        'unsubscribe',
        'deleteToken',
      ]);
    });
  });

  test('원격 스위치는 Remote Config 받기가 끝난 뒤에 읽고, 그 전에는 값이 없다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(pushSignalEnabledProvider, (_, _) {});

    await pumpEventQueue();
    expect(container.read(pushSignalEnabledProvider).hasValue, isFalse);

    container.read(remoteConfigFetchProvider).markDone();
    await pumpEventQueue();
    // 이 테스트에는 Firebase가 없어 읽지 못하므로 꺼진 것으로 본다.
    expect(container.read(pushSignalEnabledProvider).value, isFalse);
  });

  /// 로그인한 설정과 [enabled]로 원격 스위치를 덮어쓴 컨테이너.
  ProviderContainer loggedInContainer({
    required SharedPreferences preferences,
    required _FakePushClient client,
    required Future<bool> Function() enabled,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushSignalEnabledProvider.overrideWith((ref) => enabled()),
        settingsProvider.overrideWith(
          (ref) => Stream.value(
            AppSettings.defaults.copyWith(
              lmsSessionState: LmsSessionState.active,
            ),
          ),
        ),
        syncSignalSubscriptionProvider.overrideWithValue(
          SyncSignalSubscription(
            client: client,
            preferences: preferences,
            random: Random(1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('이미 로그인된 상태로 앱을 켜면 듣기 시작하자마자 구독한다', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final client = _FakePushClient();
    final container = loggedInContainer(
      preferences: preferences,
      client: client,
      enabled: () async => true,
    );
    // 설정과 원격 스위치를 이미 읽은 상태다.
    container.listen(syncSignalWantedProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(syncSignalWantedProvider), isTrue);

    listenSyncSignalSubscription(container);
    await pumpEventQueue();

    expect(client.calls.last, startsWith('subscribe:sync-'));
  });

  test('원격 스위치를 읽기 전에는 지난 실행의 구독을 풀지 않는다', () async {
    SharedPreferences.setMockInitialValues({syncSignalSubscribedKey: true});
    final preferences = await SharedPreferences.getInstance();
    final client = _FakePushClient();
    final enabled = Completer<bool>();
    final container = loggedInContainer(
      preferences: preferences,
      client: client,
      enabled: () => enabled.future,
    );
    container.listen(settingsProvider, (_, _) {});
    await pumpEventQueue();

    listenSyncSignalSubscription(container);
    await pumpEventQueue();
    expect(client.calls, isEmpty);

    enabled.complete(true);
    await pumpEventQueue();
    expect(client.calls.map((call) => call.split(':').first), [
      'autoInit',
      'ready',
      'subscribe',
    ]);
  });

  test('앱을 켤 때 지금 상태로 맞추고, 로그인 상태가 바뀔 때마다 다시 맞춘다', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final client = _FakePushClient();
    final settings = StreamController<AppSettings>();
    addTearDown(settings.close);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        pushSignalEnabledProvider.overrideWith((ref) async => true),
        settingsProvider.overrideWith((ref) => settings.stream),
        syncSignalSubscriptionProvider.overrideWithValue(
          SyncSignalSubscription(
            client: client,
            preferences: preferences,
            random: Random(1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    listenSyncSignalSubscription(container);
    // 설정을 아직 읽지 못했으면 바꾸지 않는다.
    await pumpEventQueue();
    expect(client.calls, isEmpty);

    settings.add(
      AppSettings.defaults.copyWith(lmsSessionState: LmsSessionState.active),
    );
    await pumpEventQueue();
    expect(client.calls.last, startsWith('subscribe:sync-'));

    // 다른 설정만 바뀌면 다시 부르지 않는다.
    final before = client.calls.length;
    settings.add(
      AppSettings.defaults.copyWith(
        lmsSessionState: LmsSessionState.active,
        aiEnabled: true,
      ),
    );
    await pumpEventQueue();
    expect(client.calls, hasLength(before));

    // 로그아웃으로 로그인 전이 되면 푼다.
    settings.add(AppSettings.defaults);
    await pumpEventQueue();
    expect(client.calls.last, 'deleteToken');
    expect(preferences.getBool(syncSignalSubscribedKey), isFalse);
  });
}
