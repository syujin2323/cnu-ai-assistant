// LMS 동기화. docs/lms.md '동기화'·'호출 예산'·'세션 상태'·'세션 복원'·'원격 스위치'.
//
// 계기마다 [SyncCoordinator.run]을 부른다. 한 번에 하나만 돈다. 같은 isolate의 두 번째 요청은 진행 중인 Future를
// 받고, 다른 isolate(R1의 백그라운드 작업)와는 폰 DB의 `sync_lease`로 가린다. 차례는 이렇다.
//
// 1. 데모 모드·원격 스위치 꺼짐·설정 없음이면 LMS를 부르지 않고 `skipped`로 남긴다. 업데이트가 필요하거나, 로그인한
//    세션이 없거나, LMS 상태가 `active`·`restoring`이 아니면 기록 없이 끝낸다. 다만 `reconnectRequired`라도 보안
//    저장소에 학번·비밀번호가 있고 거절 표시(`lmsCredentialRejected`)가 없으면 복원으로 간다.
// 2. 자동 계기(앱 열기·쓰는 동안·백그라운드)는 호출 예산을 본다. 조용한 시간이면 `skipped`(`quiet_hours`), 마지막
//    성공이 간격 안이면 기록 없이 끝내고, 자동 조회가 실패한 뒤 최소 간격 안이거나 오늘 횟수를 다 썼으면
//    `skipped`(`budget`)다. 사용자 새로 고침과 로그인 직후는 예산을 보지 않는다.
// 3. 잠금을 잡고(못 잡으면 `skipped`(`lease`)) 금고의 쿠키와 User-Agent로 준비 요청 → (전체면) 과목 목록 → 할 일
//    목록을 묻고 판별해 [LmsSyncRepository]로 쓴다. 도중에 데모 모드에 들어가거나 원격 스위치가 꺼지면 다음 조회
//    앞에서 멈추고 `cancelled`(이유 코드)로 남긴다.
// 4. '재로그인 필요'·'복원 필요'면 `restoring`으로 바꾸고 세션 복원 1단계(홈 요청)를 한 뒤 그 조회를 한 번 다시
//    한다. 그래도 끊겨 있으면 3단계로 저장된 학번·비밀번호로 화면 없이 한 번 다시 로그인하고, 새 쿠키로 준비 요청부터
//    다시 해 묻는다. 시작할 때 `restoring`이거나 위의 `reconnectRequired`면 복원부터 한다. 다시 받은 조회가 정상·빈
//    목록이면 `active`다. 저장된 값이 없거나, 거절 표시가 있거나, 다시 로그인이 '학번·비밀번호 틀림'(거절 표시를
//    남김)·'해석 실패'이거나, 다시 로그인한 뒤에도 끊겨 있으면 `reconnectRequired`다. 네트워크 실패·서버 오류면
//    `restoring`에 두고 다음 계기에 1단계부터 다시 한다(숨은 WebView 2단계는 L0 실험 뒤).
// 5. 범위마다 `sync_runs`에 한 줄을 남기고, 정상·빈 목록이면 `lmsLastSuccessAt`을 올리며, 요청에서 받은 쿠키를 금고에
//    다시 쓴다. 해석 실패는 필드 이름만 담아 오류 보고(Crashlytics 비치명)로도 보낸다.
//
// 과목별 상세 조회(`detail`)는 상세 응답의 꼴을 확인한 뒤 더한다. 그전까지 전체(`full`)는 과목 목록과 할 일 목록이다.
//
// 시간표 불러오기(`timetable`, docs/lms.md '시간표 (통합정보시스템)')도 같은 차례(설정·상태·잠금·세션 복원)를 지난다.
// 과목 목록을 묻고 쓴 뒤 과목마다 강의계획서 요청(LMS. 세션이 끊겼는지 여기서 가림)과 그 뒤 요청(통합정보시스템)을 차례로
// 보내 시간표 글자를 읽고, 폰 DB의 불러온 수업과 견줘(`domain/timetable_refresh.dart`) 새 수업은 바로 넣고 바뀌거나
// 없어진 수업은 결과([SyncResult.timetableChanges])로 내놓는다(반영은 13 화면이 고른 것만
// `TimetableRefreshRepository`가 함). 불러온 시각은 `settings`의 `lmsTimetableImportedAt`에 적는다. 과목 하나가
// 실패하면 그 과목만 건너뛴다(`partial`). 동기화 기록(`sync_runs`)과 마지막 확인 시각에는 남기지 않고, 다른 범위가 도는
// 중이면 끝나기를 기다렸다가 한다.

import 'dart:async';

import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
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
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/login_request.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:cnu_ai_assistant/lms/parsers/timetable_parser.dart';
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
    this.timetableChanges = const [],
  });

  final SyncResultKind kind;

  /// 새로 보였거나 바뀌었거나 사라진 항목 수. 시간표 불러오기는 바로 넣은 새 수업 칸 수다.
  final int changedCount;

  /// 조회에 실패한 과목(`courses.id`). 시간표 불러오기는 시간표를 받지 못해 건너뛴 과목이고, 상세 조회는 붙이면
  /// 채운다.
  final List<int> failedCourseIds;

  /// 시간표 불러오기에서 반영할지 물을 바뀜(학교 쪽 시간·강의실이 바뀐 수업, 원래 값과 다르게 고친 수업, 없어진 수업).
  /// 13 화면이 보이고 고른 것만 `TimetableRefreshRepository.apply`로 반영한다. 다른 범위는 늘 비어 있다.
  final List<TimetableChange> timetableChanges;

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
  SyncScope? _currentScope;

  /// 지금 동기화가 도는지.
  bool get isRunning => _current != null;

  /// [isRunning]이 바뀔 때마다 새 값을 낸다.
  Stream<bool> get runningChanges => _runningChanges.stream;

  /// [trigger]로 [scope] 범위를 동기화한다. 이미 돌고 있으면 그 Future를 돌려준다. 다만 시간표 불러오기와 할 일
  /// 동기화는 서로의 결과로 대신할 수 없으므로, 다른 쪽이 도는 중이면 끝나기를 기다렸다가 한다.
  Future<SyncResult> run({
    required SyncTrigger trigger,
    required SyncScope scope,
  }) {
    if (_current case final current?) {
      final timetable = scope == SyncScope.timetable;
      if (timetable == (_currentScope == SyncScope.timetable)) return current;
      return current.then((_) => run(trigger: trigger, scope: scope));
    }
    final future = _run(trigger, scope);
    _current = future;
    _currentScope = scope;
    _runningChanges.add(true);
    return future.whenComplete(() {
      _current = null;
      _currentScope = null;
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
      List<int> failedCourseIds = const [],
      List<TimetableChange> timetableChanges = const [],
    }) async {
      final note = detail ?? budgetNote;
      final elapsed = stopwatch.elapsedMilliseconds;
      if (scope != SyncScope.timetable) {
        final added = await _syncRuns.add(
          startedAt: startedAt,
          trigger: trigger,
          scope: scope,
          result: kind,
          changedCount: changed,
          elapsedMs: elapsed,
          detail: note,
          failedCourseIds: failedCourseIds.isEmpty ? null : failedCourseIds,
        );
        if (added case Err(:final error)) {
          appLog(
            'sync_run_write_failed',
            area: 'lms',
            data: errorLogData(error),
          );
        }
      }
      appLog(
        'lms_sync',
        area: 'lms',
        data: {
          'trigger': trigger.name,
          'scope': scope.name,
          'kind': kind.name,
          'changed': changed,
          'failed': failedCourseIds.length,
          'asks': timetableChanges.length,
          'ms': elapsed,
          'detail': ?note,
        },
      );
      return SyncResult(
        kind,
        changedCount: changed,
        failedCourseIds: failedCourseIds,
        duration: stopwatch.elapsed,
        detail: note,
        timetableChanges: timetableChanges,
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
    if (params == null ||
        sync == null ||
        parse == null ||
        (scope == SyncScope.timetable &&
            (params.timetable == null || parse.timetableSlot == null))) {
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
    switch (state) {
      case LmsSessionState.active || LmsSessionState.restoring:
        break;
      case LmsSessionState.reconnectRequired
          when !settings.lmsCredentialRejected:
        // 저장된 학번·비밀번호가 있고 거절되지 않았으면 다음 계기에 복원한다(docs/lms.md '세션 상태' 3번).
        if (!await _hasCredential()) {
          return const SyncResult(SyncResultKind.skipped);
        }
      default:
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

    final dio = _createDio();
    final connection = _connect(
      dio,
      params,
      LmsCookieJar(schoolDomain: _schoolDomain, cookies: session.cookies),
      session.userAgent,
    );
    try {
      final attempt = await _fetch(
        connection: connection,
        dio: dio,
        params: params,
        sync: sync,
        parse: parse,
        scope: scope,
        startedAt: startedAt,
        state: state,
        credentialRejected: settings.lmsCredentialRejected,
      );
      if (attempt.kind == SyncResultKind.parseFailure) {
        _reportEvent('lms_parse_failure', {
          'scope': scope.name,
          'field': ?attempt.field,
        });
      }
      if (scope != SyncScope.timetable &&
          (attempt.kind == SyncResultKind.normal ||
              attempt.kind == SyncResultKind.empty)) {
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
        failedCourseIds: attempt.failedCourseIds,
        timetableChanges: attempt.timetableChanges,
      );
    } finally {
      await _saveCookies(connection.jar, connection.userAgent, params);
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

  /// 준비 요청 뒤 조회를 하고, 세션이 끊겼으면 복원한다(docs/lms.md '세션 복원': 1단계 홈 요청 → 다시 묻기, 그래도
  /// 끊겨 있으면 3단계 저장된 학번·비밀번호로 다시 로그인 → 다시 묻기). 상태 전이도 여기서 쓴다.
  Future<_Attempt> _fetch({
    required _Connection connection,
    required Dio dio,
    required LmsRequestParams params,
    required LmsSyncSpec sync,
    required LmsParseConfig parse,
    required SyncScope scope,
    required DateTime startedAt,
    required LmsSessionState state,
    required bool credentialRejected,
  }) async {
    // 다시 로그인 필요에서 온 계기(저장된 값이 있고 거절되지 않음)는 복원부터 한다.
    if (state == LmsSessionState.reconnectRequired) {
      await _writeState(LmsSessionState.restoring);
    }
    final prepared = await _prepare(connection.runner, params, sync);
    if (prepared.failure case final failure?) return failure;
    var vars = prepared.vars;

    final classifier = LmsResponseClassifier.of(params);
    Future<_Attempt> query() => scope == SyncScope.timetable
        ? _queryTimetable(
            runner: connection.runner,
            classifier: classifier,
            params: params,
            sync: sync,
            timetable: params.timetable!,
            slotPattern: parse.timetableSlot!,
            vars: vars,
            startedAt: startedAt,
          )
        : _query(
            runner: connection.runner,
            classifier: classifier,
            sync: sync,
            parse: parse,
            vars: vars,
            scope: scope,
            startedAt: startedAt,
          );

    var restoring = state != LmsSessionState.active;
    if (restoring) await _restoreViaHome(connection.runner, params);
    var attempt = await query();
    if (attempt.sessionLost && !restoring) {
      await _writeState(LmsSessionState.restoring);
      restoring = true;
      await _restoreViaHome(connection.runner, params);
      attempt = await query();
    }
    if (!restoring) return attempt;

    var stopped = false;
    if (attempt.sessionLost) {
      switch (await _reloginWithSaved(
        dio: dio,
        params: params,
        connection: connection,
        rejected: credentialRejected,
      )) {
        case _ReloginSucceeded():
          final again = await _prepare(connection.runner, params, sync);
          if (again.failure case final failure?) {
            attempt = failure;
          } else {
            vars = again.vars;
            attempt = await query();
          }
        case _ReloginStopped(:final result):
          stopped = true;
          attempt = result ?? attempt;
        case _ReloginPostponed(:final result):
          attempt = result;
      }
    }
    if (attempt.kind == SyncResultKind.normal ||
        attempt.kind == SyncResultKind.empty) {
      await _writeState(LmsSessionState.active);
    } else if (stopped || attempt.sessionLost) {
      await _writeState(LmsSessionState.reconnectRequired);
    }
    return attempt;
  }

  /// 준비 요청(`sync.steps`, 요청 본문 암호화에 쓰는 키 받기 등)을 보내 변수를 채운다. 실패하면 `failure`가 그
  /// 시도다.
  Future<({Map<String, String> vars, _Attempt? failure})> _prepare(
    LmsRequestRunner runner,
    LmsRequestParams params,
    LmsSyncSpec sync,
  ) async {
    final vars = {...sync.vars};
    Uri? base;
    for (final step in sync.steps) {
      switch (await runner.run(step, vars, base: base)) {
        case LmsStepNotSent(:final field):
          return (
            vars: vars,
            failure: _Attempt(SyncResultKind.parseFailure, field: field),
          );
        case final LmsStepSent sent:
          if (lmsTransportFailure(sent.response, params.markers)
              case final kind?) {
            return (
              vars: vars,
              failure: _Attempt(
                _kindOf(kind),
                field: _offlineField(sent.response.offline),
              ),
            );
          }
          final status = sent.response.statusCode!;
          if (status < 200 || status >= 300) {
            return (
              vars: vars,
              failure: const _Attempt(
                SyncResultKind.parseFailure,
                field: 'status',
              ),
            );
          }
          if (sent.missing case final missing?) {
            return (
              vars: vars,
              failure: _Attempt(SyncResultKind.parseFailure, field: missing),
            );
          }
          vars.addAll(sent.values);
          base = sent.response.finalUrl;
      }
    }
    return (vars: vars, failure: null);
  }

  /// 세션 복원 3단계(docs/lms.md '세션 복원'): 보안 저장소의 학번·비밀번호로 화면 없이 한 번 로그인한다. 저장된 값이
  /// 없거나 거절 표시가 있으면 하지 않는다. 성공하면 [connection]을 새 쿠키 상자로 바꾸고, '학번·비밀번호 틀림'이면
  /// 거절 표시를 남긴다. 학번·비밀번호는 로그인 요청의 변수로만 쓰고 로그에 남기지 않는다.
  Future<_Relogin> _reloginWithSaved({
    required Dio dio,
    required LmsRequestParams params,
    required _Connection connection,
    required bool rejected,
  }) async {
    if (rejected) return const _ReloginStopped();
    final LmsCredential credential;
    switch (await _vault.readCredential()) {
      case Ok(value: final value?):
        credential = value;
      case Ok():
        return const _ReloginStopped();
      case Err(:final error):
        appLog(
          'lms_relogin_vault_failed',
          area: 'lms',
          data: errorLogData(error),
        );
        return const _ReloginPostponed(
          _Attempt(SyncResultKind.parseFailure, field: 'storage'),
        );
    }
    final fresh = _connect(
      dio,
      params,
      LmsCookieJar(schoolDomain: _schoolDomain),
      params.userAgent,
    );
    final stopwatch = Stopwatch()..start();
    final attempt = await performLmsLogin(
      params: params,
      runner: fresh.runner,
      studentId: credential.studentId,
      password: credential.password,
    );
    final log = {'ms': stopwatch.elapsedMilliseconds};
    switch (attempt) {
      case LmsLoginSucceeded():
        appLog('lms_relogin', area: 'lms', data: {...log, 'kind': 'success'});
        // 새 쿠키와 요청 상수의 User-Agent는 이번 동기화가 끝날 때 금고에 쓴다.
        connection.replaceWith(fresh);
        return const _ReloginSucceeded();
      case LmsLoginFailed(:final outcome, :final field):
        appLog(
          'lms_relogin',
          area: 'lms',
          data: {...log, ...errorLogData(outcome), 'field': ?field},
        );
        switch (outcome.kind) {
          case LmsOutcomeKind.wrongCredentials:
            final written = await _settings.write(
              SettingKeys.lmsCredentialRejected,
              true,
            );
            if (written case Err(:final error)) {
              appLog(
                'lms_relogin_reject_write_failed',
                area: 'lms',
                data: errorLogData(error),
              );
            }
            return const _ReloginStopped(
              _Attempt(SyncResultKind.reloginRequired),
            );
          case LmsOutcomeKind.networkFailure || LmsOutcomeKind.serverError:
            return _ReloginPostponed(
              _Attempt(
                _kindOf(outcome.kind),
                field: _offlineField(outcome.offline),
              ),
            );
          default:
            return _ReloginStopped(
              _Attempt(
                SyncResultKind.parseFailure,
                field: field == null ? 'relogin' : 'relogin.$field',
              ),
            );
        }
    }
  }

  /// 보안 저장소에 학번·비밀번호가 있는지. 읽지 못하면 없는 것으로 본다.
  Future<bool> _hasCredential() async =>
      switch (await _vault.readCredential()) {
        Ok(value: _?) => true,
        _ => false,
      };

  /// [jar]와 [userAgent]로 요청하는 실행기를 만든다.
  _Connection _connect(
    Dio dio,
    LmsRequestParams params,
    LmsCookieJar jar,
    String userAgent,
  ) => _Connection(
    jar,
    userAgent,
    LmsRequestRunner(
      client: LmsClient(
        dio: dio,
        jar: jar,
        userAgent: userAgent,
        schoolDomain: _schoolDomain,
        clock: _clock,
        sleep: _sleep,
      ),
      ciphers: params.ciphers,
      schoolDomain: _schoolDomain,
    ),
  );

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

  /// 시간표 불러오기: 과목 목록을 묻고 쓴 뒤 과목마다 시간표를 읽고([_courseTimetable]), 폰 DB의 불러온 수업과 견줘
  /// 새 수업은 넣고 반영할지 물을 바뀜을 내놓는다. 세션이 끊기면 그 자리에서 멈추고(복원은 [_fetch]가 함), 과목 하나가
  /// 실패하면 그 과목만 건너뛴다(그 과목의 수업은 견주지 않음). 모든 과목이 실패하면 첫 실패의 종류다.
  Future<_Attempt> _queryTimetable({
    required LmsRequestRunner runner,
    required LmsResponseClassifier classifier,
    required LmsRequestParams params,
    required LmsSyncSpec sync,
    required LmsTimetableSpec timetable,
    required RegExp slotPattern,
    required Map<String, String> vars,
    required DateTime startedAt,
  }) async {
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
    final Map<String, int> ids;
    switch (await _store.upsertCourses(
      records,
      semester: sync.semester,
      now: startedAt,
    )) {
      case Ok(:final value):
        ids = value;
      case Err(:final error):
        appLog('lms_sync_store_failed', area: 'lms', data: errorLogData(error));
        return const _Attempt(SyncResultKind.parseFailure, field: 'storage');
    }

    final slotsByCourse = <int, List<ImportedClassSlot>>{};
    final failed = <int>[];
    _Attempt? firstFailure;
    final reported = <String>{};
    for (final record in records) {
      if (await _stopReason() case final reason?) {
        return _Attempt(SyncResultKind.cancelled, field: reason);
      }
      final courseDbId = ids[record.remoteId];
      final parts = lmsCourseIdParts(record.remoteId);
      if (courseDbId == null || parts == null) continue;
      final result = await _courseTimetable(
        runner: runner,
        classifier: classifier,
        params: params,
        timetable: timetable,
        slotPattern: slotPattern,
        vars: {...vars, 'courseId': parts.courseId, 'classNo': parts.classNo},
      );
      if (result.sessionLost) return result;
      if (result.kind != SyncResultKind.normal) {
        failed.add(courseDbId);
        firstFailure ??= result;
        appLog(
          'lms_timetable_course_failed',
          area: 'lms',
          data: {'kind': result.kind.name, 'field': ?result.field},
        );
        if (result.kind == SyncResultKind.parseFailure &&
            reported.add(result.field ?? '')) {
          _reportEvent('lms_parse_failure', {
            'scope': SyncScope.timetable.name,
            'field': ?result.field,
          });
        }
        continue;
      }
      slotsByCourse[courseDbId] = result.slots;
    }
    if (records.isNotEmpty && slotsByCourse.isEmpty && firstFailure != null) {
      return firstFailure;
    }
    final TimetableDiff diff;
    switch (await _store.importedSlots(semester: sync.semester)) {
      case Ok(:final value):
        diff = compareTimetable(
          existing: value.slots,
          fetched: slotsByCourse,
          // 과목 목록이 빈 목록으로 오면 일시적인 빈 응답일 수 있어 빠진 과목으로 보지 않는다.
          dropped: records.isEmpty
              ? const <int>{}
              : value.courseIds.difference(ids.values.toSet()),
        );
      case Err(:final error):
        appLog('lms_sync_store_failed', area: 'lms', data: errorLogData(error));
        return const _Attempt(SyncResultKind.parseFailure, field: 'storage');
    }
    switch (await _store.addImportedSlots(diff.added)) {
      case Ok(:final value):
        final written = await _settings.write(
          SettingKeys.lmsTimetableImportedAt,
          startedAt,
        );
        if (written case Err(:final error)) {
          appLog(
            'lms_timetable_time_failed',
            area: 'lms',
            data: errorLogData(error),
          );
        }
        return _Attempt(
          records.isEmpty
              ? SyncResultKind.empty
              : failed.isEmpty
              ? SyncResultKind.normal
              : SyncResultKind.partial,
          changed: value,
          failedCourseIds: failed,
          timetableChanges: diff.changes,
        );
      case Err(:final error):
        appLog('lms_sync_store_failed', area: 'lms', data: errorLogData(error));
        return const _Attempt(SyncResultKind.parseFailure, field: 'storage');
    }
  }

  /// 과목 하나의 시간표를 읽는다. 강의계획서 요청(LMS)은 판별기로 세션이 끊겼는지 가리고, 그 뒤 요청(통합정보시스템)은
  /// 연결 실패·서버 오류와 상태 코드, 꼭 뽑아야 하는 값만 본다. 정상이면 [_Attempt.slots]에 수업 칸을 담는다.
  Future<_Attempt> _courseTimetable({
    required LmsRequestRunner runner,
    required LmsResponseClassifier classifier,
    required LmsRequestParams params,
    required LmsTimetableSpec timetable,
    required RegExp slotPattern,
    required Map<String, String> vars,
  }) async {
    _Attempt failure(String field) =>
        _Attempt(SyncResultKind.parseFailure, field: 'timetable.$field');
    Uri? base;
    switch (await runner.run(timetable.courseInfo, vars)) {
      case LmsStepNotSent(:final field):
        return failure(field);
      case final LmsStepSent sent:
        final outcome = classifier.classify(sent.response, _anyJson).outcome;
        final kind = _kindOf(outcome.kind);
        if (kind != SyncResultKind.normal) {
          return kind == SyncResultKind.parseFailure
              ? failure('course_info')
              : _Attempt(kind, field: _offlineField(outcome.offline));
        }
        if (sent.missing case final missing?) return failure(missing);
        vars.addAll(sent.values);
        base = sent.response.finalUrl;
    }
    for (final step in timetable.steps) {
      switch (await runner.run(step, vars, base: base)) {
        case LmsStepNotSent(:final field):
          return failure(field);
        case final LmsStepSent sent:
          if (lmsTransportFailure(sent.response, params.markers)
              case final kind?) {
            return _Attempt(
              _kindOf(kind),
              field: _offlineField(sent.response.offline),
            );
          }
          final status = sent.response.statusCode!;
          if (status < 200 || status >= 300) return failure('status');
          if (sent.missing case final missing?) return failure(missing);
          vars.addAll(sent.values);
          base = sent.response.finalUrl;
      }
    }
    final slots = parseTimetableSlots(
      vars[timetable.slotText] ?? '',
      slotPattern,
    );
    if (slots == null) return failure('slot');
    return _Attempt(SyncResultKind.normal, slots: slots);
  }

  /// 강의계획서 응답은 꼴을 보지 않고 세션 상태만 가린다.
  static LmsSchemaResult<Object?> _anyJson(Object? json) =>
      LmsSchemaMatch(json, itemCount: 1);

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
          field:
              _offlineField(classified.outcome.offline) ??
              classified.failedField,
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
    String userAgent,
    LmsRequestParams params,
  ) async {
    if (await _vault.readSession() case Ok(value: null) || Err()) return;
    final nowUtc = kstToUtc(_clock.now());
    final written = await _vault.writeSession(
      LmsSession(
        savedAt: nowUtc,
        userAgent: userAgent,
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

  /// 오프라인(연결 없음·주소 해석 실패)으로 응답을 받지 못했으면 `sync_runs.detail`에 남길 [SyncRunDetail.offline]이고,
  /// 아니면 null이다. 상태 줄과 01·02·03의 띠가 이것으로 오프라인과 연결 실패를 가른다.
  static String? _offlineField(bool offline) =>
      offline ? SyncRunDetail.offline : null;

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
  const _Attempt(
    this.kind, {
    this.changed = 0,
    this.field,
    this.failedCourseIds = const [],
    this.slots = const [],
    this.timetableChanges = const [],
  });

  final SyncResultKind kind;
  final int changed;

  /// 해석 실패의 필드 이름이나 멈춘 이유 코드.
  final String? field;

  /// 시간표 불러오기에서 실패해 건너뛴 과목(`courses.id`).
  final List<int> failedCourseIds;

  /// 과목 하나의 시간표를 읽은 수업 칸([SyncCoordinator._courseTimetable]).
  final List<ImportedClassSlot> slots;

  /// 시간표 불러오기에서 반영할지 물을 바뀜.
  final List<TimetableChange> timetableChanges;

  /// 세션이 끊겼다는 판별인지.
  bool get sessionLost =>
      kind == SyncResultKind.reloginRequired ||
      kind == SyncResultKind.restoreRequired;
}

/// 동기화 한 번이 LMS에 보내는 요청의 쿠키 상자·User-Agent·실행기. 세션 복원 3단계에서 다시 로그인하면 새것으로
/// 바뀐다.
final class _Connection {
  _Connection(this.jar, this.userAgent, this.runner);

  LmsCookieJar jar;
  String userAgent;
  LmsRequestRunner runner;

  void replaceWith(_Connection other) {
    jar = other.jar;
    userAgent = other.userAgent;
    runner = other.runner;
  }
}

/// 세션 복원 3단계(저장된 학번·비밀번호로 다시 로그인)의 결과.
sealed class _Relogin {
  const _Relogin();
}

/// 다시 로그인했다. 이어서 준비 요청부터 다시 해 묻는다.
final class _ReloginSucceeded extends _Relogin {
  const _ReloginSucceeded();
}

/// 복원을 멈추고 `reconnectRequired`로 둔다(저장된 값이 없음·거절됨·재로그인 응답 해석 실패). [result]가 있으면
/// 이번 동기화의 결과를 그것으로 남긴다.
final class _ReloginStopped extends _Relogin {
  const _ReloginStopped([this.result]);

  final _Attempt? result;
}

/// 지금은 못 했다(네트워크 실패·서버 오류·보안 저장소 읽기 실패). `restoring`에 두고 다음 계기에 다시 한다.
final class _ReloginPostponed extends _Relogin {
  const _ReloginPostponed(this.result);

  final _Attempt result;
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
