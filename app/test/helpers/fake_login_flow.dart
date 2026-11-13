// 로그인 폼 화면 테스트가 함께 쓰는 가짜 로그인 흐름과 LMS 설정 덮어쓰기. LMS에 요청하지 않고 폼이
// 결과(성공, 틀림, 점검, 네트워크 실패, 해석 실패)와 진행 줄을 어떻게 다루는지만 본다.

import 'dart:async';
import 'dart:math' show min;

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// `fetchAndActivate()`를 마친 것으로 두고 LMS 원격 값을 [enabled]·[requestParams]로 둔다.
/// 요청 상수는 비어 있지 않으면 받은 것으로 본다(합성 값).
List<Override> lmsConfigOverrides({
  bool enabled = true,
  String requestParams = '{}',
}) => [
  remoteConfigFetchProvider.overrideWithValue(RemoteConfigFetch()..markDone()),
  lmsRemoteValuesProvider.overrideWithValue(
    () => (enabled: enabled, requestParams: requestParams),
  ),
];

/// 로그인 한 번에 넘어온 값.
typedef LoginCall = ({LoginMode mode, String studentId, String password});

/// 가짜 로그인 흐름. [results]를 부른 차례대로 돌려주고(다 쓰면 마지막 값), 모드의 단계마다 `onStage`를
/// 부른다. [holdStages]면 단계마다 [advance]를 부를 때까지 기다린다(진행 줄 확인용).
class FakeLoginFlow implements LoginFlow {
  FakeLoginFlow({
    this.savedId,
    this.results = const [Ok(null)],
    this.holdStages = false,
  });

  /// 저장된 학번.
  final String? savedId;

  final List<Result<void>> results;
  final bool holdStages;

  /// 결과를 돌려주기 바로 앞에 부른다. 실제 흐름이 LMS 상태를 쓰는 것을 흉내 낸다.
  Future<void> Function()? beforeResult;

  /// 지금까지의 로그인.
  final List<LoginCall> calls = [];

  Completer<void>? _hold;

  /// 붙잡아 둔 단계를 넘긴다.
  void advance() {
    final hold = _hold;
    _hold = null;
    hold?.complete();
  }

  @override
  Future<String?> savedStudentId() async => savedId;

  @override
  Future<Result<void>> run({
    required LoginMode mode,
    required String studentId,
    required String password,
    required void Function(LoginStage stage) onStage,
  }) async {
    calls.add((mode: mode, studentId: studentId, password: password));
    for (final stage in LoginStage.of(mode)) {
      onStage(stage);
      if (holdStages) await (_hold = Completer<void>()).future;
    }
    await beforeResult?.call();
    return results[min(calls.length, results.length) - 1];
  }
}

/// 로그인 흐름을 [flow]로 바꾸는 덮어쓰기.
Override loginFlowOverride(LoginFlow flow) =>
    loginFlowProvider.overrideWithValue(flow);
