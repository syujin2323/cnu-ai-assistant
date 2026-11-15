// 요청 상수대로 LMS에 로그인하는 요청. docs/lms.md '로그인'·'세션 복원'.
//
// 요청 상수(`lms_request_params`의 `login`)대로
//   ① 준비 요청(`steps`)을 차례로 보내 값을 뽑고,
//   ② 로그인 요청을 보내 결과 규칙(`results`)으로 성공·학번·비밀번호 틀림·해석 실패를 가르고,
//   ③ 성공이면 세션 넘기기 요청(`handoff`)을 보낸다.
// 모든 요청은 먼저 네트워크 실패와 서버 오류·점검(5xx·429·점검 표식)을 거른다. 앱 화면의 로그인 흐름
// (`login_flow.dart`)과 동기화의 세션 복원 3단계(저장된 학번·비밀번호로 다시 로그인, `sync_coordinator.dart`)가 함께
// 쓴다. 쿠키는 넘긴 실행기([LmsRequestRunner])의 쿠키 상자에 쌓이고, 저장은 부르는 쪽이 한다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_runner.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';

/// [performLmsLogin]의 결과.
sealed class LmsLoginAttempt {
  const LmsLoginAttempt();
}

/// 로그인에 성공했다. 쿠키는 넘긴 실행기의 쿠키 상자에 있다.
final class LmsLoginSucceeded extends LmsLoginAttempt {
  const LmsLoginSucceeded();
}

/// 로그인에 실패했다. [field]는 해석 실패의 까닭(못 찾은 변수 이름, `status`, `result`, `handoff`, 요청을 만들지 못한
/// 까닭)이다. 모두 이름 꼴이라 로그에 남겨도 된다.
final class LmsLoginFailed extends LmsLoginAttempt {
  const LmsLoginFailed(this.outcome, {this.field});

  final LmsOutcome outcome;

  final String? field;
}

/// 요청 상수 [params]대로 로그인한다. 학번·비밀번호는 로그인 요청의 변수(`studentId`·`password`)로만 쓰고 로그에
/// 남기지 않는다. 던지지 않는다.
Future<LmsLoginAttempt> performLmsLogin({
  required LmsRequestParams params,
  required LmsRequestRunner runner,
  required String studentId,
  required String password,
}) async {
  final login = params.login;
  final vars = <String, String>{};
  Uri? base;

  LmsLoginFailed parseFailure({int? status, String? field}) => LmsLoginFailed(
    LmsOutcome(LmsOutcomeKind.parseFailure, statusCode: status),
    field: field,
  );
  LmsLoginFailed? transport(LmsStepSent sent) =>
      switch (lmsTransportFailure(sent.response, params.markers)) {
        null => null,
        final kind => LmsLoginFailed(
          LmsOutcome(kind, statusCode: sent.response.statusCode),
        ),
      };

  for (final step in login.steps) {
    switch (await runner.run(step, vars, base: base)) {
      case LmsStepNotSent(:final field):
        return parseFailure(field: field);
      case final LmsStepSent sent:
        if (transport(sent) case final failed?) return failed;
        final status = sent.response.statusCode!;
        if (status < 200 || status >= 300) {
          return parseFailure(status: status, field: 'status');
        }
        if (sent.missing case final missing?) {
          return parseFailure(status: status, field: missing);
        }
        vars.addAll(sent.values);
        base = sent.response.finalUrl;
    }
  }

  switch (await runner.run(login.request, {
    ...vars,
    'studentId': studentId,
    'password': password,
  }, base: base)) {
    case LmsStepNotSent(:final field):
      return parseFailure(field: field);
    case final LmsStepSent sent:
      if (transport(sent) case final failed?) return failed;
      final status = sent.response.statusCode;
      switch (login.resultOf(sent.json, sent.response.body)) {
        case LmsLoginResult.wrongCredentials:
          return LmsLoginFailed(
            LmsOutcome(LmsOutcomeKind.wrongCredentials, statusCode: status),
          );
        case LmsLoginResult.parseFailure:
          return parseFailure(status: status, field: 'result');
        case LmsLoginResult.success:
          if (sent.missing case final missing?) {
            return parseFailure(status: status, field: missing);
          }
          vars.addAll(sent.values);
          base = sent.response.finalUrl;
      }
  }

  final handoff = login.handoff;
  if (handoff == null) return const LmsLoginSucceeded();
  switch (await runner.run(handoff, vars, base: base)) {
    case LmsStepNotSent(:final field):
      return parseFailure(field: field);
    case final LmsStepSent sent:
      if (transport(sent) case final failed?) return failed;
      final status = sent.response.statusCode!;
      final finalUrl = sent.response.finalUrl;
      if (status < 200 ||
          status >= 300 ||
          (finalUrl != null && params.isLoginUrl(finalUrl))) {
        return parseFailure(status: status, field: 'handoff');
      }
      return const LmsLoginSucceeded();
  }
}
