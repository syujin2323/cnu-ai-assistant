import 'dart:convert';

import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Remote Config 앱 기본값은 문서의 키·값과 같다', () {
    // docs/architecture.md '환경 변수'의 앱 기본값(lms_sync_budget JSON 포함)을 그대로 옮겼다.
    // 자동 조회는 3시간(180분) 간격·하루 8회다(docs/lms.md '호출 예산').
    expect(
      remoteConfigDefaults.keys,
      unorderedEquals([
        'lms_enabled',
        'lms_request_params',
        'lms_login_success_pattern',
        'lms_sync_budget',
        'min_app_version',
      ]),
    );
    expect(remoteConfigDefaults['lms_enabled'], isTrue);
    expect(remoteConfigDefaults['lms_request_params'], '');
    expect(remoteConfigDefaults['lms_login_success_pattern'], '');
    expect(remoteConfigDefaults['min_app_version'], '0.0.0');
    const documented = {
      'listMinIntervalMin': 10,
      'listMaxPerDay': 8,
      'detailMaxPerDay': 2,
      'foregroundPollMin': 180,
      'openStaleMin': 180,
      'quietHours': {'start': '01:00', 'end': '06:00'},
    };
    expect(
      jsonDecode(remoteConfigDefaults['lms_sync_budget']! as String),
      documented,
    );
    // 해석에 실패할 때 쓰는 값도 같은 상수다.
    expect(lmsSyncBudgetDefaults, documented);
  });

  group('configureRemoteConfig', () {
    test('설정·앱 기본값·지난 값 적용을 차례로 하고, 실패가 없으면 빈 목록이다', () async {
      final rc = _FakeRemoteConfig();

      expect(await configureRemoteConfig(rc), isEmpty);

      expect(rc.calls, ['settings', 'defaults', 'activate']);
      expect(rc.givenSettings!.fetchTimeout, const Duration(seconds: 5));
      expect(
        rc.givenSettings!.minimumFetchInterval,
        const Duration(minutes: 15),
      );
      expect(rc.givenDefaults, remoteConfigDefaults);
    });

    test('한 단계가 실패해도 나머지를 하고 실패한 단계 이름을 돌려준다', () async {
      // 앱 기본값을 넣지 못하면 lms_enabled가 정적 기본값 false로 읽혀 LMS를 멈춘 것으로 보이므로,
      // 설정이 실패해도 기본값은 넣어야 한다.
      for (final failing in ['settings', 'defaults', 'activate']) {
        final rc = _FakeRemoteConfig(failing: {failing});

        expect(await configureRemoteConfig(rc), [failing], reason: failing);
        expect(rc.calls, ['settings', 'defaults', 'activate'], reason: failing);
      }
      final rc = _FakeRemoteConfig(failing: {'settings', 'activate'});
      expect(await configureRemoteConfig(rc), ['settings', 'activate']);
    });
  });
}

/// 호출을 기록하고 [failing] 단계에서 FirebaseException을 던지는 Remote Config.
class _FakeRemoteConfig implements FirebaseRemoteConfig {
  _FakeRemoteConfig({this.failing = const {}});

  final Set<String> failing;
  final calls = <String>[];
  RemoteConfigSettings? givenSettings;
  Map<String, dynamic>? givenDefaults;

  void _call(String step) {
    calls.add(step);
    if (failing.contains(step)) {
      throw FirebaseException(plugin: 'firebase_remote_config', code: step);
    }
  }

  @override
  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async {
    _call('settings');
    givenSettings = remoteConfigSettings;
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaultParameters) async {
    _call('defaults');
    givenDefaults = defaultParameters;
  }

  @override
  Future<bool> activate() async {
    _call('activate');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
