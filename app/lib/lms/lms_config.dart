// LMS 설정 읽기. docs/lms.md '원격 스위치', docs/architecture.md '환경 변수'.
//
// Remote Config의 `lms_*` 값은 이 파일에서만 읽는다. 앱 열기 뒤의 `fetchAndActivate()`가 끝난 뒤에만
// 읽는다(`remoteConfigFetchProvider`). 지금은 원격 스위치(`lms_enabled`)와 요청 상수(`lms_request_params`)가
// 있는지만 보고, 요청 상수의 구조와 해석(설정 파서, 모르는 `version`이면 설정 없음)과 실행 중 갱신은
// LMS 연동이 이 파일에 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// LMS 설정의 지금 상태.
@immutable
class LmsConfig {
  const LmsConfig({required this.enabled, required this.hasRequestParams});

  /// 원격 스위치(`lms_enabled`). false면 LMS 조회와 로그인·다시 로그인을 막고 'LMS 연동을 잠시
  /// 멈췄어요'를 보인다.
  final bool enabled;

  /// 요청 상수(`lms_request_params`)를 받았는지. false면 로그인 버튼을 끄고 '설정을 받는 중이에요'를
  /// 보인다.
  final bool hasRequestParams;

  @override
  bool operator ==(Object other) =>
      other is LmsConfig &&
      other.enabled == enabled &&
      other.hasRequestParams == hasRequestParams;

  @override
  int get hashCode => Object.hash(enabled, hasRequestParams);
}

/// Remote Config에서 LMS 값을 읽는 함수. 테스트는 덮어쓴다.
final lmsRemoteValuesProvider =
    Provider<({bool enabled, String requestParams}) Function()>(
      (ref) => () {
        final config = FirebaseRemoteConfig.instance;
        return (
          enabled: config.getBool(RemoteConfigKeys.lmsEnabled),
          requestParams: config.getString(RemoteConfigKeys.lmsRequestParams),
        );
      },
    );

/// LMS 설정. `fetchAndActivate()`가 끝나기 전에는 불러오는 중이고, 그동안 로그인 버튼은 꺼져 있다.
final lmsConfigProvider = AsyncNotifierProvider<LmsConfigController, LmsConfig>(
  LmsConfigController.new,
);

/// [lmsConfigProvider]의 노티파이어.
class LmsConfigController extends AsyncNotifier<LmsConfig> {
  @override
  Future<LmsConfig> build() async {
    await ref.watch(remoteConfigFetchProvider).done;
    final values = ref.watch(lmsRemoteValuesProvider)();
    return LmsConfig(
      enabled: values.enabled,
      hasRequestParams: values.requestParams.isNotEmpty,
    );
  }
}
