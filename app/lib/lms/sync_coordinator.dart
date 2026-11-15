// LMS 동기화. docs/lms.md '동기화'·'호출 예산'·'세션 상태'·'세션 복원'·'원격 스위치'.
//
// 계기마다 [SyncCoordinator.run]을 부른다. 한 번에 하나만 돈다. 같은 isolate의 두 번째 요청은 진행 중인 Future를
// 받고, 다른 isolate(R1의 백그라운드 작업)와는 폰 DB의 `sync_lease`로 가린다. 차례는 이렇다.
//
// 1. 데모 모드·원격 스위치 꺼짐·설정 없음이면 LMS를 부르지 않고 `skipped`로 남긴다. 업데이트가 필요하거나, 로그인한
//    세션이 없거나, LMS 상태가 `active`·`restoring`이 아니면 기록 없이 끝낸다.
// 2. 자동 계기(앱 열기·쓰는 동안·백그라운드)는 호출 예산을 본다. 조용한 시간이면 `skipped`(`quiet_hours`), 마지막
//    성공이 간격 안이면 기록 없이 끝내고, 자동 조회가 실패한 뒤 최소 간격 안이거나 오늘 횟수를 다 썼으면
//    `skipped`(`budget`)다. 사용자 새로 고침과 로그인 직후는 예산을 보지 않는다.
// 3. 잠금을 잡고(못 잡으면 `skipped`(`lease`)) 금고의 쿠키와 User-Agent로 준비 요청 → (전체면) 과목 목록 → 할 일
//    목록을 묻고 판별해 [LmsSyncRepository]로 쓴다. 도중에 데모 모드에 들어가거나 원격 스위치가 꺼지면 다음 조회
//    앞에서 멈추고 `cancelled`(이유 코드)로 남긴다.
// 4. '재로그인 필요'·'복원 필요'면 `restoring`으로 바꾸고 세션 복원 1단계(홈 요청)를 한 뒤 그 조회를 한 번 다시
//    한다. 시작할 때 이미 `restoring`이면 복원부터 한다. 다시 받은 조회가 정상·빈 목록이면 `active`, 또
//    '재로그인 필요'·'복원 필요'면 `reconnectRequired`다(저장된 비밀번호로 다시 로그인하는 3단계는 조용한 재로그인
//    PR이 그 앞에 더한다). 네트워크 실패·서버 오류면 상태를 두고 다음 계기에 다시 한다.
// 5. 범위마다 `sync_runs`에 한 줄을 남기고, 정상·빈 목록이면 `lmsLastSuccessAt`을 올리며, 요청에서 받은 쿠키를 금고에
//    다시 쓴다. 해석 실패는 필드 이름만 담아 오류 보고(Crashlytics 비치명)로도 보낸다.
//
// 과목별 상세 조회(`detail`)는 상세 응답의 꼴을 확인한 뒤 더한다. 그전까지 전체(`full`)는 과목 목록과 할 일 목록이다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/crash_reports.dart';
import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/data/repositories/lms_sync_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_lease_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_run_repository.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_lease.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:cnu_ai_assistant/lms/parsers/todo_list_parser.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_runner.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 동기화 한 번(범위 하나)의 결과(docs/lms.md '동기화'의 `SyncResult`).
final class SyncResult {
  const SyncResult(
    this.kind, {
    this.changedCount = 0,
    this.failedCourseIds = const [],
    this.duration = Duration.zero,
    this.detail,
  });

  final SyncResultKind kind;

  /// 새로 보였거나 바뀌었거나 사라진 항목 수.
  final int changedCount;

  /// 상세 조회에 실패한 과목(`courses.id`). 상세 조회를 붙이면 채운다.
  final List<int> failedCourseIds;

  final Duration duration;

  /// `sync_runs.detail`에 남긴 값(건너뛴 이유 코드, 해석 실패의 필드 이름).
  final String? detail;
}

/// LMS 동기화를 돌린다.
class SyncCoordinator {
  SyncCoordinator({
    required this._config,
    required this._vault,
    required this._settings,
    required this._syncRuns,
    required this._leases,
    required this._store,
    required this._clock,
    required this._schoolDomain,
    required this._createDio,
    required this._sleep,
    required this._isDemo,
    required this._updateRequired,
    required this._reportEvent,
  });

  final Future<LmsConfig> Function() _config;
  final CookieVault _vault;

  /// 실제 모드 폰 DB의 저장소들(LMS 데이터와 상태는 앱 모드와 관계없이 실제 DB에 있다).
  final SettingsRepository _settings;
  final SyncRunRepository _syncRuns;
  final SyncLeaseRepository _leases;
  final LmsSyncRepository _store;

  final Clock _clock;
  final String _schoolDomain;
  final Dio Function() _createDio;
  final Future<void> Function(Duration) _sleep;
  final bool Function() _isDemo;
  final bool Function() _updateRequired;
  final void Function(String event, Map<String, Object> data) _reportEvent;

  final _runningChanges = StreamController<bool>.broadcast();
  Future<SyncResult>? _current;

  /// 지금 동기화가 도는지.
  bool get isRunning => _current != null;

  /// [isRunning]이 바뀔 때마다 새 값을 낸다.
  Stream<bool> get runningChanges => _runningChanges.stream;

  /// [trigger]로 [scope] 범위를 동기화한다. 이미 돌고 있으면 그 Future를 돌려준다.
  Future<SyncResult> run({
    required SyncTrigger trigger,
    required SyncScope scope,
  }) {
    if (_current case final current?) return current;
    final future = _run(trigger, scope);
    _current = future;
    _runningChanges.add(true);
    return future.whenComplete(() {
      _current = null;
      if (!_runningChanges.isClosed) _runningChanges.add(false);
    });
  }

  /// provider가 버려질 때 부른다.
  void dispose() => unawaited(_runningChanges.close());

  Future<SyncResult> _run(SyncTrigger trigger, SyncScope scope) async {
    final startedAt = _clock.now();
    final stopwatch = Stopwatch()..start();
    String? budgetNote;

    Future<SyncResult> finish(
      SyncResultKind kind, {
      int changed = 0,
      String? detail,
    }) async {
      final note = detail ?? budgetNote;
      final elapsed = stopwatch.elapsedMilliseconds;
      final added = await _syncRuns.add(
        startedAt: startedAt,
        trigger: trigger,
        scope: scope,
        result: kind,
        changedCount: changed,
        elapsedMs: elapsed,
        detail: note,
      );
      if (added case Err(:final error)) {
        appLog('sync_run_write_failed', area: 'lms', data: errorLogData(error));
      }
      appLog(
        'lms_sync',
        area: 'lms',
        data: {
          'trigger': trigger.name,
          'scope': scope.name,
          'kind': kind.name,
          'changed': changed,
          'ms': elapsed,
          'detail': ?note,
        },
      );
      return SyncResult(
        kind,
        changedCount: changed,
        duration: stopwatch.elapsed,
        detail: note,
      );
    }

    if (_isDemo()) {
      return finish(SyncResultKind.skipped, detail: SyncRunDetail.demoMode);
    }
    if (_updateRequired()) return const SyncResult(SyncResultKind.skipped);
    final config = await _config();
    if (!config.enabled) {
      return finish(SyncResultKind.skipped, detail: SyncRunDetail.switchOff);
    }
    final params = config.requestParams;
    final sync = params?.sync;
    final parse = params?.parse;
    if (params == null || sync == null || parse == null) {
      return finish(
        SyncResultKind.skipped,
        detail: SyncRunDetail.configMissing,
      );
    }
    if (config.budgetParseFailed) budgetNote = SyncRunDetail.budgetParseFailed;

    final AppSettings settings;
    switch (await _settings.read()) {
      case Ok(:final value):
        settings = value;
      case Err(:final error):
        appLog(
          'lms_sync_settings_failed',
          area: 'lms',
          data: errorLogData(error),
        );
        return const SyncResult(SyncResultKind.skipped);
    }
    final state = settings.lmsSessionState;
    if (state != LmsSessionState.active && state != LmsSessionState.restoring) {
      return const SyncResult(SyncResultKind.skipped);
    }

    if (SyncRunRepository.autoTriggers.contains(trigger)) {
      final budget = config.budget;
      if (budget.isQuietAt(startedAt)) {
        return finish(SyncResultKind.skipped, detail: SyncRunDetail.quietHours);
      }
      final lastSuccess = settings.lmsLastSuccessAt;
      final staleMin = trigger == SyncTrigger.periodic
          ? budget.foregroundPollMin
          : budget.openStaleMin;
      if (lastSuccess != null &&
          startedAt.difference(lastSuccess) < Duration(minutes: staleMin)) {
        return const SyncResult(SyncResultKind.skipped);
      }
      if (await _syncRuns.lastAutoList() case Ok(value: final last?)
          when !SyncRunRepository.successResults.contains(last.result) &&
              startedAt.difference(last.startedAt) <
                  Duration(minutes: budget.listMinIntervalMin)) {
        return finish(SyncResultKind.skipped, detail: SyncRunDetail.budget);
      }
      if (await _syncRuns.countAutoCallsToday(now: startedAt)
          case Ok(:final value)
          when value[SyncScope.list]! >= budget.listMaxPerDay) {
        return finish(SyncResultKind.skipped, detail: SyncRunDetail.budget);
      }
    }

    final LmsSession session;
    switch (await _vault.readSession()) {
      case Ok(value: final value?):
        session = value;
      case Ok():
        // 로그인한 쿠키가 없다(개발용 '로그인 없이 다음으로' 등). LMS를 부르지 않는다.
        return const SyncResult(SyncResultKind.skipped);
      case Err(:final error):
        appLog('lms_sync_vault_failed', area: 'lms', data: errorLogData(error));
        return const SyncResult(SyncResultKind.skipped);
    }
    if (session.userAgent.trim().isEmpty) {
      await _writeState(LmsSessionState.reconnectRequired);
      return const SyncResult(SyncResultKind.skipped);
    }

    final String token;
    switch (await _leases.acquire(LeaseHolder.foreground, now: startedAt)) {
      case Ok(value: final value?):
        token = value;
      case Ok():
        return finish(SyncResultKind.skipped, detail: SyncRunDetail.lease);
      case Err(:final error):
        appLog('lms_sync_lease_failed', area: 'lms', data: errorLogData(error));
        return finish(SyncResultKind.skipped, detail: SyncRunDetail.lease);
    }

    final jar = LmsCookieJar(
      schoolDomain: _schoolDomain,
      cookies: session.cookies,
    );
    final dio = _createDio();
    try {
      final runner = LmsRequestRunner(
        client: LmsClient(
          dio: dio,
          jar: jar,
          userAgent: session.userAgent,
          schoolDomain: _schoolDomain,
          clock: _clock,
          sleep: _sleep,
        ),
        ciphers: params.ciphers,
        schoolDomain: _schoolDomain,
      );
      final attempt = await _fetch(
        runner: runner,
        params: params,
        sync: sync,
        parse: parse,
        scope: scope,
        startedAt: startedAt,
        restoreFirst: state == LmsSessionState.restoring,
      );
      if (attempt.kind == SyncResultKind.parseFailure) {
        _reportEvent('lms_parse_failure', {
          'scope': scope.name,
          'field': ?attempt.field,
        });
      }
      if (attempt.kind == SyncResultKind.normal ||
          attempt.kind == SyncResultKind.empty) {
        final advanced = await _settings.advanceLmsLastSuccessAt(startedAt);
        if (advanced case Err(:final error)) {
          appLog(
            'lms_last_success_failed',
            area: 'lms',
            data: errorLogData(error),
          );
        }
      }
      return await finish(
        attempt.kind,
        changed: attempt.changed,
        detail: attempt.field,
      );
    } finally {
      await _saveCookies(jar, session, params);
      dio.close(force: true);
      final released = await _leases.release(token);
      if (released case Err(:final error)) {
        appLog(
          'lms_sync_release_failed',
          area: 'lms',
          data: errorLogData(error),
        );
      }
    }
  }

  /// 준비 요청 뒤 조회를 하고, 세션이 끊겼으면 복원해 한 번 다시 한다. 상태 전이도 여기서 쓴다.
  Future<_Attempt> _fetch({
    required LmsRequestRunner runner,
    required LmsRequestParams params,
    required LmsSyncSpec sync,
    required LmsParseConfig parse,
    required SyncScope scope,
    required DateTime startedAt,
    required bool restoreFirst,
  }) async {
    final vars = {...sync.vars};
    Uri? base;
    for (final step in sync.steps) {
      switch (await runner.run(step, vars, base: base)) {
        case LmsStepNotSent(:final field):
          return _Attempt(SyncResultKind.parseFailure, field: field);
        case final LmsStepSent sent:
          if (lmsTransportFailure(sent.response, params.markers)
              case final kind?) {
            return _Attempt(_kindOf(kind));
          }
          final status = sent.response.statusCode!;
          if (status < 200 || status >= 300) {
            return const _Attempt(SyncResultKind.parseFailure, field: 'status');
          }
          if (sent.missing case final missing?) {
            return _Attempt(SyncResultKind.parseFailure, field: missing);
          }
          vars.addAll(sent.values);
          base = sent.response.finalUrl;
      }
    }

    final classifier = LmsResponseClassifier.of(params);
    Future<_Attempt> query() => _query(
      runner: runner,
      classifier: classifier,
      sync: sync,
      parse: parse,
      vars: vars,
      scope: scope,
      startedAt: startedAt,
    );

    var restored = restoreFirst;
    if (restoreFirst) await _restoreViaHome(runner, params);
    var attempt = await query();
    if (attempt.sessionLost && !restored) {
      await _writeState(LmsSessionState.restoring);
      restored = true;
      await _restoreViaHome(runner, params);
      attempt = await query();
    }
    if (attempt.kind == SyncResultKind.normal ||
        attempt.kind == SyncResultKind.empty) {
      if (restored) await _writeState(LmsSessionState.active);
    } else if (attempt.sessionLost) {
      await _writeState(LmsSessionState.reconnectRequired);
    }
    return attempt;
  }

  /// 진행 중인 동기화를 멈출 까닭. 데모 모드에 들어갔으면 `demo_mode`, 원격 스위치가 꺼졌으면(실행 중에 바뀐 값)
  /// `switch_off`이고, 둘 다 아니면 null이다.
  Future<String?> _stopReason() async {
    if (_isDemo()) return SyncRunDetail.demoMode;
    if (!(await _config()).enabled) return SyncRunDetail.switchOff;
    return null;
  }

  /// (전체면) 과목 목록과 할 일 목록을 묻고 쓴다. 데모 모드에 들어갔거나 원격 스위치가 꺼졌으면 그 자리에서
  /// 멈춘다.
  Future<_Attempt> _query({
    required LmsRequestRunner runner,
    required LmsResponseClassifier classifier,
    required LmsSyncSpec sync,
    required LmsParseConfig parse,
    required Map<String, String> vars,
    required SyncScope scope,
    required DateTime startedAt,
  }) async {
    if (scope == SyncScope.full) {
      if (await _stopReason() case final reason?) {
        return _Attempt(SyncResultKind.cancelled, field: reason);
      }
      final courses = await _request(
        runner,
        classifier,
        sync.courses,
        vars,
        courseListSchema,
      );
      final records = courses.records;
      if (records == null) return _Attempt(courses.kind, field: courses.field);
      final written = await _store.upsertCourses(
        records,
        semester: sync.semester,
        now: startedAt,
      );
      if (written case Err(:final error)) {
        appLog('lms_sync_store_failed', area: 'lms', data: errorLogData(error));
        return const _Attempt(SyncResultKind.parseFailure, field: 'storage');
      }
    }
    if (await _stopReason() case final reason?) {
      return _Attempt(SyncResultKind.cancelled, field: reason);
    }
    final todos = await _request(
      runner,
      classifier,
      sync.todos,
      vars,
      todoListSchema(parse),
    );
    final records = todos.records;
    if (records == null) return _Attempt(todos.kind, field: todos.field);
    switch (await _store.applyTodoList(
      records,
      semester: sync.semester,
      now: startedAt,
    )) {
      case Ok(:final value):
        return _Attempt(todos.kind, changed: value.changedCount);
      case Err(:final error):
        appLog('lms_sync_store_failed', area: 'lms', data: errorLogData(error));
        return const _Attempt(SyncResultKind.parseFailure, field: 'storage');
    }
  }

  /// [spec]을 보내고 판별한다. 정상·빈 목록이면 해석한 값을 담는다.
  Future<({SyncResultKind kind, List<T>? records, String? field})> _request<T>(
    LmsRequestRunner runner,
    LmsResponseClassifier classifier,
    LmsRequestSpec spec,
    Map<String, String> vars,
    LmsSchema<List<T>> schema,
  ) async {
    switch (await runner.run(spec, vars)) {
      case LmsStepNotSent(:final field):
        return (kind: SyncResultKind.parseFailure, records: null, field: field);
      case LmsStepSent(:final response):
        final classified = classifier.classify(response, schema);
        final kind = _kindOf(classified.outcome.kind);
        final ok =
            kind == SyncResultKind.normal || kind == SyncResultKind.empty;
        return (
          kind: kind,
          records: ok ? classified.value ?? <T>[] : null,
          field: classified.failedField,
        );
    }
  }

  /// 세션 복원 1단계: 홈을 금고의 쿠키로 열어 응답의 쿠키를 받는다(docs/lms.md '세션 복원').
  Future<void> _restoreViaHome(
    LmsRequestRunner runner,
    LmsRequestParams params,
  ) async {
    final home = LmsRequestSpec(
      method: LmsMethod.get,
      url: LmsTemplate(params.homeUrl.toString()),
    );
    final sent = await runner.run(home, const {});
    appLog(
      'lms_restore_home',
      area: 'lms',
      data: {
        'status': ?switch (sent) {
          LmsStepSent(:final response) => response.statusCode,
          LmsStepNotSent() => null,
        },
      },
    );
  }

  /// 이번 동기화에서 받은 쿠키를 금고에 다시 쓴다. 그사이 로그아웃했으면(금고가 비었으면) 쓰지 않는다.
  Future<void> _saveCookies(
    LmsCookieJar jar,
    LmsSession session,
    LmsRequestParams params,
  ) async {
    if (await _vault.readSession() case Ok(value: null) || Err()) return;
    final nowUtc = kstToUtc(_clock.now());
    final written = await _vault.writeSession(
      LmsSession(
        savedAt: nowUtc,
        userAgent: session.userAgent,
        cookies: jar.cookiesFor(params.cookieDomains, nowUtc),
      ),
    );
    if (written case Err(:final error)) {
      appLog('lms_sync_cookies_failed', area: 'lms', data: errorLogData(error));
    }
  }

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

  static SyncResultKind _kindOf(LmsOutcomeKind kind) => switch (kind) {
    LmsOutcomeKind.normal => SyncResultKind.normal,
    LmsOutcomeKind.empty => SyncResultKind.empty,
    LmsOutcomeKind.reloginRequired => SyncResultKind.reloginRequired,
    LmsOutcomeKind.restoreRequired => SyncResultKind.restoreRequired,
    LmsOutcomeKind.serverError => SyncResultKind.serverError,
    LmsOutcomeKind.networkFailure => SyncResultKind.networkFailure,
    _ => SyncResultKind.parseFailure,
  };
}

/// 조회 한 번의 결과.
final class _Attempt {
  const _Attempt(this.kind, {this.changed = 0, this.field});

  final SyncResultKind kind;
  final int changed;

  /// 해석 실패의 필드 이름이나 멈춘 이유 코드.
  final String? field;

  /// 세션이 끊겼다는 판별인지.
  bool get sessionLost =>
      kind == SyncResultKind.reloginRequired ||
      kind == SyncResultKind.restoreRequired;
}

/// 앱의 LMS 동기화. LMS 데이터와 상태는 앱 모드와 관계없이 실제 DB에 쓴다.
final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final realDb = ref.watch(realDatabaseProvider);
  final coordinator = SyncCoordinator(
    config: () => ref.read(lmsConfigProvider.future),
    vault: ref.watch(cookieVaultProvider),
    settings: SettingsRepository(realDb),
    syncRuns: SyncRunRepository(realDb),
    leases: SyncLeaseRepository(realDb),
    store: LmsSyncRepository(realDb),
    clock: ref.watch(clockProvider),
    schoolDomain: ref.watch(lmsSchoolDomainProvider),
    createDio: () => createLmsDio(adapter: ref.read(lmsHttpAdapterProvider)),
    sleep: ref.watch(lmsSleepProvider),
    isDemo: () => ref.read(appModeProvider) == AppMode.demo,
    updateRequired: () => ref.read(updateRequiredProvider),
    reportEvent: (event, data) =>
        ref.read(crashReportsProvider).recordEvent(event, data: data),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// LMS 동기화가 지금 도는지(03 할 일 LMS 정보 시트의 '불러오는 중'과 [새로 고침]).
final lmsSyncingProvider = StreamProvider<bool>((ref) async* {
  final coordinator = ref.watch(syncCoordinatorProvider);
  yield coordinator.isRunning;
  yield* coordinator.runningChanges;
});
