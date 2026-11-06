// Remote Config 설정과 앱 기본값. docs/architecture.md '환경 변수'와 '실행 방법'.
//
// 값을 읽는 곳은 따로 있다. 사캠 값(`lms_*`)은 `lms/lms_config.dart` 하나에서만 읽는다.

import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Remote Config 키 이름.
abstract final class RemoteConfigKeys {
  /// 사캠 연동 원격 스위치.
  static const lmsEnabled = 'lms_enabled';

  /// 사캠·통합정보시스템 요청 상수(JSON 문자열). 값은 레포에 두지 않는다.
  static const lmsRequestParams = 'lms_request_params';

  /// 로그인 성공 판정 패턴(Dart `RegExp` 문자열). 앱 화면 로그인에서 쓸지는 사캠 연동 때 확인한다.
  static const lmsLoginSuccessPattern = 'lms_login_success_pattern';

  /// 조회 간격·하루 최대 횟수·조회하지 않는 시간(JSON 문자열).
  static const lmsSyncBudget = 'lms_sync_budget';

  /// (R1) 최소 지원 앱 버전 `X.Y.Z`.
  static const minAppVersion = 'min_app_version';
}

/// `lms_sync_budget`의 앱 기본값(임시값). docs/architecture.md '환경 변수'의 JSON과 같다.
///
/// 자동 조회는 마지막 성공에서 3시간(180분)이 지났을 때 앱을 열거나 쓰는 동안 하고,
/// 하루 8회를 넘지 않는다(docs/lms.md '호출 예산'). 가져온 값을 해석하지 못할 때도 이 값을 쓴다.
const Map<String, Object> lmsSyncBudgetDefaults = {
  'listMinIntervalMin': 10,
  'listMaxPerDay': 8,
  'detailMaxPerDay': 2,
  'foregroundPollMin': 180,
  'openStaleMin': 180,
  'quietHours': {'start': '01:00', 'end': '06:00'},
};

/// 앱 안 기본값. 가져온 값이 없을 때(첫 실행, 오프라인) 이 값으로 동작한다.
///
/// 요청 상수와 로그인 성공 패턴은 빈 문자열이다. 요청 상수가 비어 있는 동안 로그인 버튼은
/// 비활성이고 '설정을 받는 중이에요'를 보인다(docs/lms.md '원격 스위치'의 '설정 없음').
final Map<String, Object> remoteConfigDefaults = {
  RemoteConfigKeys.lmsEnabled: true,
  RemoteConfigKeys.lmsRequestParams: '',
  RemoteConfigKeys.lmsLoginSuccessPattern: '',
  RemoteConfigKeys.lmsSyncBudget: jsonEncode(lmsSyncBudgetDefaults),
  RemoteConfigKeys.minAppVersion: '0.0.0',
};

/// 앱 시작 때 `runApp` 전에 한 번 부른다.
///
/// 가져오기 시간 초과 5초(기본 1분), 최소 가져오기 간격 15분(기본 12시간이면 다음
/// 실행에도 옛 값이 남는다)으로 두고, 앱 기본값을 넣은 뒤 지난 실행에서 가져온 값을
/// 적용한다. 네트워크를 쓰는 `fetchAndActivate()`는 여기서 부르지 않는다. `runApp`
/// 뒤에 시작하고 화면은 그 결과를 기다리지 않는다.
Future<void> configureRemoteConfig(FirebaseRemoteConfig rc) async {
  await rc.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 5),
      minimumFetchInterval: const Duration(minutes: 15),
    ),
  );
  await rc.setDefaults(remoteConfigDefaults);
  await rc.activate();
}
