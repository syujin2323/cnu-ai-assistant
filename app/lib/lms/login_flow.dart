// LMS 로그인 흐름. docs/lms.md '로그인'·'학번·비밀번호와 자동 재로그인'·'세션 상태'.
//
// 앱 화면(14 온보딩 1단계, 다시 로그인)에서 받은 학번·비밀번호로 요청 상수(`lms_request_params`의 `login`)대로
// 로그인한다([performLmsLogin]).
//   ① 준비 요청(`steps`)을 차례로 보내 값을 뽑고,
//   ② 로그인 요청을 보내 결과 규칙(`results`)으로 성공·학번·비밀번호 틀림·해석 실패를 가르고,
//   ③ 성공이면 세션 넘기기 요청(`handoff`)을 보낸다.
// 모든 요청은 먼저 네트워크 실패와 서버 오류·점검(5xx·429·점검 표식)을 거른다. 로그인 폼(`features/lms_connect/`)은
// 이 흐름의 단계를 진행 줄로 보이고 결과로 다음 화면을 정한다.
//
// '로그인'을 누르면 LMS 상태를 `connecting`으로 쓴다. 성공하면 학번·비밀번호와 쿠키(User-Agent 함께)를 보안 저장소에
// 두고 상태를 `active`, 마지막 로그인 시각(`lmsLastConnectedAt`)을 지금으로 쓴다. 실패하면 아무것도 저장하지 않고
// `connecting`에 둔다. 로그인 화면을 성공 없이 떠나면 [LoginFlow.abandon]이 시작 전 상태로 돌린다. LMS 상태는 앱
// 모드와 관계없이 실제 모드의 폰 DB에 쓴다.
//
// 진행 줄은 지금 로그인 단계만 지난다. 처음 로그인의 이번 학기 시간표와 LMS 할 일 불러오기는 시간표·동기화 PR이 이
// 흐름에 더한다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_runner.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:cnu_ai_assistant/lms/session_state.dart';
import 'package:dio/dio.dart' show Dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 로그인 폼의 모드.
enum LoginMode {
  /// 14 온보딩 1단계: 학번·비밀번호와 개인정보 처리 안내 동의를 받는다.
  first,

  /// 다시 로그인: 저장된 학번을 고정하고 비밀번호만 받는다.
  relogin,
}

/// 로그인 흐름의 단계(진행 줄). 처음 로그인은 셋, 다시 로그인은 [login]·[tasks] 둘이다.
enum LoginStage {
  /// LMS 로그인.
  login,

  /// 이번 학기 시간표(통합정보시스템).
  timetable,

  /// LMS 할 일.
  tasks;

  /// [mode]가 지나는 단계.
  static List<LoginStage> of(LoginMode mode) => switch (mode) {
    LoginMode.first => values,
    LoginMode.relogin => const [login, tasks],
  };
}

/// 로그인 흐름.
abstract interface class LoginFlow {
  /// 저장된 학번. 없으면 null이고, 다시 로그인 화면은 학번 칸도 받는다.
  Future<String?> savedStudentId();

  /// [studentId]·[password]로 로그인하고 [mode]의 단계를 차례로 지나며, 단계를 시작할 때마다
  /// [onStage]를 부른다. 성공이면 [Ok], 실패면 판별 결과([LmsOutcome])나 저장 실패([StorageError])를 담은 [Err]다.
  Future<Result<void>> run({
    required LoginMode mode,
    required String studentId,
    required String password,
    required void Function(LoginStage stage) onStage,
  });

  /// 로그인 화면을 성공 없이 떠났다(뒤로 가기, '로그인 없이 둘러보기'). LMS 상태가 `connecting`이면 시작 전
  /// 상태로 돌린다(docs/lms.md '세션 상태' 1번). 던지지 않는다.
  Future<void> abandon();
}

/// 로그인 흐름. 화면 테스트는 덮어쓴다.
final loginFlowProvider = Provider<LoginFlow>((ref) {
  final realDb = ref.watch(realDatabaseProvider);
  return LmsLoginFlow(
    config: () => ref.read(lmsConfigProvider.future),
    vault: ref.watch(cookieVaultProvider),
    settings: SettingsRepository(realDb),
    clock: ref.watch(clockProvider),
    schoolDomain: ref.watch(lmsSchoolDomainProvider),
    createDio: () => createLmsDio(adapter: ref.read(lmsHttpAdapterProvider)),
    sleep: ref.watch(lmsSleepProvider),
  );
});

/// 요청 상수대로 LMS에 로그인하는 흐름.
class LmsLoginFlow implements LoginFlow {
  LmsLoginFlow({
    required this._config,
    required this._vault,
    required this._settings,
    required this._clock,
    required this._schoolDomain,
    required this._createDio,
    required this._sleep,
  });

  final Future<LmsConfig> Function() _config;

  final CookieVault _vault;

  /// 실제 모드 폰 DB의 설정(LMS 상태는 앱 모드와 관계없이 여기에 쓴다).
  final SettingsRepository _settings;

  final Clock _clock;

  final String _schoolDomain;

  final Dio Function() _createDio;

  final Future<void> Function(Duration) _sleep;

  @override
  Future<String?> savedStudentId() async =>
      switch (await _vault.readCredential()) {
        Ok(:final value) => value?.studentId,
        Err() => null,
      };

  @override
  Future<Result<void>> run({
    required LoginMode mode,
    required String studentId,
    required String password,
    required void Function(LoginStage stage) onStage,
  }) async {
    final config = await _config();
    final params = config.requestParams;
    if (!config.enabled || params == null) {
      return const Err(LmsOutcome(LmsOutcomeKind.parseFailure));
    }
    await _writeState(LmsSessionState.connecting);
    onStage(LoginStage.login);

    final stopwatch = Stopwatch()..start();
    final dio = _createDio();
    final jar = LmsCookieJar(schoolDomain: _schoolDomain);
    final LmsLoginAttempt attempt;
    try {
      attempt = await performLmsLogin(
        params: params,
        runner: LmsRequestRunner(
          client: LmsClient(
            dio: dio,
            jar: jar,
            userAgent: params.userAgent,
            schoolDomain: _schoolDomain,
            clock: _clock,
            sleep: _sleep,
          ),
          ciphers: params.ciphers,
          schoolDomain: _schoolDomain,
        ),
        studentId: studentId,
        password: password,
      );
    } finally {
      dio.close(force: true);
    }
    final log = {'mode': mode.name, 'ms': stopwatch.elapsedMilliseconds};
    switch (attempt) {
      case LmsLoginFailed(:final outcome, :final field):
        appLog(
          'lms_login',
          area: 'lms',
          data: {...log, ...errorLogData(outcome), 'field': ?field},
        );
        return Err(outcome);
      case LmsLoginSucceeded():
        appLog('lms_login', area: 'lms', data: {...log, 'kind': 'success'});
        return _save(params, jar, studentId, password);
    }
  }

  /// 로그인에 성공한 학번·비밀번호와 쿠키를 저장하고 상태를 `active`로 쓴다. 하나라도 쓰지 못하면 그 오류다(상태는
  /// `connecting`에 남아 다시 시도하거나 다음 시작 때 정리된다).
  Future<Result<void>> _save(
    LmsRequestParams params,
    LmsCookieJar jar,
    String studentId,
    String password,
  ) async {
    final nowUtc = kstToUtc(_clock.now());
    final writes = <Future<Result<void>> Function()>[
      () => _vault.writeCredential(
        LmsCredential(studentId: studentId, password: password),
      ),
      () => _vault.writeSession(
        LmsSession(
          savedAt: nowUtc,
          userAgent: params.userAgent,
          cookies: jar.cookiesFor(params.cookieDomains, nowUtc),
        ),
      ),
      () => _settings.writeAll({
        SettingKeys.lmsSessionState: LmsSessionState.active,
        SettingKeys.lmsLastConnectedAt: _clock.now(),
      }),
    ];
    for (final write in writes) {
      if (await write() case Err(:final error)) {
        appLog('lms_login_save_failed', area: 'lms', data: errorLogData(error));
        return Err(error);
      }
    }
    return const Ok(null);
  }

  @override
  Future<void> abandon() async {
    final current = await _settings.read();
    if (current case Ok(:final value)
        when value.lmsSessionState == LmsSessionState.connecting) {
      final hasCredential = switch (await _vault.readCredential()) {
        Ok(value: _?) => true,
        _ => false,
      };
      await _writeState(
        sessionStateLeavingLogin(
          LmsSessionState.connecting,
          hasSavedCredentials: hasCredential,
        ),
      );
    }
  }

  /// LMS 상태를 쓴다. 쓰지 못하면 기록만 남긴다(로그인은 이어 가고, 남은 `connecting`은 다음 시작 때 정리된다).
  Future<void> _writeState(LmsSessionState state) async {
    final written = await _settings.write(SettingKeys.lmsSessionState, state);
    if (written case Err(:final error)) {
      appLog(
        'lms_session_state_write_failed',
        area: 'lms',
        data: {'state': state.name, ...errorLogData(error)},
      );
    }
  }
}

/// [performLmsLogin]의 결과.
sealed class LmsLoginAttempt {
  const LmsLoginAttempt();
}

/// 로그인에 성공했다. 쿠키는 흐름의 쿠키 상자에 있다.
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
