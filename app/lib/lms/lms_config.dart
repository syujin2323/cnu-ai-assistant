// LMS 설정 읽기. docs/lms.md '원격 스위치'·'호출 예산', docs/architecture.md '환경 변수'.
//
// Remote Config의 `lms_*` 값은 이 파일에서만 읽는다. 앱 열기 뒤의 `fetchAndActivate()`가 끝난 뒤에만
// 읽는다(`remoteConfigFetchProvider`). 원격 스위치(`lms_enabled`), 요청 상수(`lms_request_params`,
// `request_params.dart`가 해석), 호출 예산(`lms_sync_budget`, `sync_budget.dart`가 해석)을 내놓는다. 실행 중
// 갱신(`onConfigUpdated`)은 동기화를 붙이는 PR이 이 파일에 더한다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/sync_budget.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 학교 도메인. 요청 상수의 주소와 쿠키 도메인, 앱 안 WebView가 여는 주소는 이 도메인이나 그 하위 도메인의
/// https 주소여야 한다(docs/lms.md 첫 문단·'원격 스위치'). 요청 상수가 이 밖을 가리키면 '설정 없음'이다.
const lmsSchoolDomain = 'cnu.ac.kr';

/// 학교 도메인. 테스트는 합성 샘플의 호스트(`example.invalid`)로 덮어쓴다.
final lmsSchoolDomainProvider = Provider<String>((ref) => lmsSchoolDomain);

/// LMS 설정의 지금 상태.
@immutable
class LmsConfig {
  const LmsConfig({
    required this.enabled,
    required this.requestParams,
    this.budget = LmsSyncBudget.defaults,
    this.budgetParseFailed = false,
  });

  /// 원격 스위치(`lms_enabled`). false면 LMS 조회와 로그인·다시 로그인을 막고 'LMS 연동을 잠시
  /// 멈췄어요'를 보인다.
  final bool enabled;

  /// 해석한 요청 상수(`lms_request_params`). null이면 '설정 없음'이고, 로그인 버튼을 끄고 '설정을 받는
  /// 중이에요'를 보이며 조회하지 않는다.
  final LmsRequestParams? requestParams;

  /// 호출 예산(`lms_sync_budget`). 해석하지 못했으면 기본값이다.
  final LmsSyncBudget budget;

  /// 호출 예산을 해석하지 못해 기본값을 쓰는지. 동기화가 그 계기의 `sync_runs` 행에 `budget_parse_failed`를
  /// 남긴다.
  final bool budgetParseFailed;

  /// 요청 상수를 받았는지.
  bool get hasRequestParams => requestParams != null;

  @override
  bool operator ==(Object other) =>
      other is LmsConfig &&
      other.enabled == enabled &&
      other.requestParams == requestParams &&
      other.budget == budget &&
      other.budgetParseFailed == budgetParseFailed;

  @override
  int get hashCode =>
      Object.hash(enabled, requestParams, budget, budgetParseFailed);
}

/// Remote Config에서 읽은 LMS 값.
typedef LmsRemoteValues = ({
  bool enabled,
  String requestParams,
  String syncBudget,
});

/// Remote Config에서 LMS 값을 읽는 함수. 테스트는 덮어쓴다.
final lmsRemoteValuesProvider = Provider<LmsRemoteValues Function()>(
  (ref) => () {
    final config = FirebaseRemoteConfig.instance;
    return (
      enabled: config.getBool(RemoteConfigKeys.lmsEnabled),
      requestParams: config.getString(RemoteConfigKeys.lmsRequestParams),
      syncBudget: config.getString(RemoteConfigKeys.lmsSyncBudget),
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
    final parsed = parseLmsRequestParams(
      values.requestParams,
      schoolDomain: ref.watch(lmsSchoolDomainProvider),
    );
    if (parsed.problem case final problem?) {
      appLog(
        'lms_request_params_invalid',
        area: 'lms',
        data: {'reason': problem.name},
      );
    }
    final budget = LmsSyncBudget.parse(values.syncBudget);
    if (budget.parseFailed) appLog('lms_sync_budget_invalid', area: 'lms');
    return LmsConfig(
      enabled: values.enabled,
      requestParams: parsed.params,
      budget: budget.budget,
      budgetParseFailed: budget.parseFailed,
    );
  }
}
