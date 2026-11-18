// LMS 로그인 흐름. docs/lms.md '로그인'·'학번·비밀번호와 자동 재로그인'·'세션 상태'.
//
// 앱 화면(14 온보딩 1단계, 다시 로그인)에서 받은 학번·비밀번호로 요청 상수(`lms_request_params`의 `login`)대로
// 로그인한다(요청은 `login_request.dart`의 [performLmsLogin]). 로그인 폼(`features/lms_connect/`)은 이 흐름의
// 단계를 진행 줄로 보이고 결과로 다음 화면을 정한다.
//
// '로그인'을 누르면 LMS 상태를 `connecting`으로 쓴다. 성공하면 학번·비밀번호와 쿠키(User-Agent 함께)를 보안 저장소에
// 두고 상태를 `active`, 마지막 로그인 시각(`lmsLastConnectedAt`)을 지금으로 쓰며 저장된 비밀번호 거절
// 표시(`lmsCredentialRejected`)를 지운다. 실패하면 아무것도 저장하지 않고
// `connecting`에 둔다. 로그인 화면을 성공 없이 떠나면 [LoginFlow.abandon]이 시작 전 상태로 돌린다. LMS 상태는 앱
// 모드와 관계없이 실제 모드의 폰 DB에 쓴다.
//
// 저장까지 마치면 진행 줄의 뒤 단계를 차례로 기다린다. 처음 로그인은 이번 학기 시간표 → LMS 할 일(전체 동기화),
// 다시 로그인은 할 일 새로 불러오기(갱신)다(docs/lms.md '로그인'·'동기화'). 단계마다 [lmsLoginStageWait]까지만
// 기다리고, 넘으면 그 불러오기는 화면 뒤에서 이어 가며 다음 단계로 넘어간다. 뒤 단계의 결과와 관계없이 성공이다
// (불러오지 못하거나 수업이 0개여도 다음 화면으로 감, docs/decisions.md 2026-11-18 '온보딩 진행 줄은 불러오기를
// 단계마다 20초까지 기다린다').

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/login_request.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_runner.dart';
import 'package:cnu_ai_assistant/lms/session_state.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
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

/// 로그인 뒤 진행 줄의 단계 하나(시간표·할 일)를 기다리는 최대 시간(임시). 넘으면 그 불러오기는 화면 뒤에서 이어
/// 가고 다음 단계로 넘어간다(docs/decisions.md 2026-11-18 '온보딩 진행 줄은 불러오기를 단계마다 20초까지 기다린다').
const lmsLoginStageWait = Duration(seconds: 20);

/// 로그인 흐름.
abstract interface class LoginFlow {
  /// 저장된 학번. 없으면 null이고, 다시 로그인 화면은 학번 칸도 받는다.
  Future<String?> savedStudentId();

  /// [studentId]·[password]로 로그인하고 [mode]의 단계를 차례로 지나며, 단계를 시작할 때마다
  /// [onStage]를 부른다. 로그인과 저장에 성공하면 뒤 단계(시간표·할 일)가 끝나거나 기다림 상한을 넘은 뒤 [Ok]이고,
  /// 실패면 판별 결과([LmsOutcome])나 저장 실패([StorageError])를 담은 [Err]다(뒤 단계는 부르지 않음).
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
    // 로그인 직후의 불러오기(docs/lms.md '동기화'·'시간표 (통합정보시스템)'). 무엇을 어떤 차례로 기다릴지는 로그인
    // 흐름이 정한다.
    syncAfterLogin: (scope) => ref
        .read(syncCoordinatorProvider)
        .run(trigger: SyncTrigger.login, scope: scope),
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
    this._syncAfterLogin,
    this._stageWait = lmsLoginStageWait,
  });

  /// 로그인에 성공해 저장까지 마친 뒤 진행 줄의 뒤 단계로 [SyncScope] 범위의 동기화를 부른다. 그 동기화가 끝나면
  /// 끝난다. null이면 뒤 단계 없이 끝난다(테스트).
  final Future<void> Function(SyncScope scope)? _syncAfterLogin;

  /// 진행 줄의 뒤 단계 하나를 기다리는 최대 시간.
  final Duration _stageWait;

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
        final saved = await _save(params, jar, studentId, password);
        if (saved is Ok) await _loadAfterLogin(mode, onStage);
        return saved;
    }
  }

  /// 진행 줄의 뒤 단계를 차례로 부르고 단계마다 [_stageWait]까지 기다린다. 넘으면 그 동기화는 화면 뒤에서 이어 가고
  /// 다음 단계로 넘어간다(다음 동기화는 코디네이터가 앞 동기화가 끝난 뒤에 함). 결과는 보지 않는다.
  Future<void> _loadAfterLogin(
    LoginMode mode,
    void Function(LoginStage stage) onStage,
  ) async {
    final sync = _syncAfterLogin;
    if (sync == null) return;
    final stages = switch (mode) {
      LoginMode.first => const [
        (LoginStage.timetable, SyncScope.timetable),
        (LoginStage.tasks, SyncScope.full),
      ],
      LoginMode.relogin => const [(LoginStage.tasks, SyncScope.list)],
    };
    for (final (stage, scope) in stages) {
      onStage(stage);
      var finished = true;
      await sync(scope).timeout(
        _stageWait,
        onTimeout: () {
          finished = false;
        },
      );
      if (!finished) {
        appLog(
          'lms_login_stage_timeout',
          area: 'lms',
          data: {'stage': stage.name},
        );
      }
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
        SettingKeys.lmsCredentialRejected: false,
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
