// LMS 상태 줄의 상태와 문구 테스트. docs/screens.md 'LMS 상태 줄과 다시 로그인'.

import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 16, 12);
final _threeHoursAgo = _now.subtract(const Duration(hours: 3));

LmsStatus _status({
  bool demo = false,
  bool enabled = true,
  LmsSessionState session = LmsSessionState.active,
  SyncResultKind? lastAttempt = SyncResultKind.normal,
  DateTime? lastSuccessAt,
  bool byUserRefresh = false,
}) => lmsStatus(
  demo: demo,
  enabled: enabled,
  session: session,
  lastAttempt: lastAttempt,
  lastSuccessAt: lastSuccessAt ?? _threeHoursAgo,
  byUserRefresh: byUserRefresh,
  now: _now,
);

Matcher _is(LmsStatusKind kind, String text) => isA<LmsStatus>()
    .having((status) => status.kind, 'kind', kind)
    .having((status) => status.text, 'text', text);

void main() {
  test('연동됨은 마지막 확인 시각이다(표에 없는 결과도 같음)', () {
    for (final result in [
      null,
      SyncResultKind.normal,
      SyncResultKind.empty,
      SyncResultKind.partial,
      SyncResultKind.parseFailure,
      SyncResultKind.reloginRequired,
      SyncResultKind.restoreRequired,
      SyncResultKind.cancelled,
    ]) {
      expect(
        _status(lastAttempt: result),
        _is(LmsStatusKind.synced, 'LMS 정보 3시간 전'),
        reason: '$result',
      );
    }
    // 세션 복원 중에도 마지막 시도 결과로 본다.
    expect(
      _status(session: LmsSessionState.restoring),
      _is(LmsStatusKind.synced, 'LMS 정보 3시간 전'),
    );
  });

  test('사용자 새로 고침 뒤 10분은 방금이고, 확인한 적이 없으면 받기 전이다', () {
    expect(
      _status(
        lastSuccessAt: _now.subtract(const Duration(minutes: 5)),
        byUserRefresh: true,
      ),
      _is(LmsStatusKind.synced, 'LMS 정보 방금'),
    );
    expect(
      lmsStatus(
        demo: false,
        enabled: true,
        session: LmsSessionState.active,
        lastAttempt: null,
        lastSuccessAt: null,
        byUserRefresh: false,
        now: _now,
      ),
      _is(LmsStatusKind.synced, 'LMS 정보 받기 전'),
    );
  });

  test('네트워크 실패는 연결할 수 없어요, 서버 오류는 점검 중을 붙인다(복원 중에도)', () {
    for (final session in [LmsSessionState.active, LmsSessionState.restoring]) {
      expect(
        _status(session: session, lastAttempt: SyncResultKind.networkFailure),
        _is(LmsStatusKind.connectionFailed, 'LMS 정보 3시간 전 · 연결할 수 없어요'),
      );
      expect(
        _status(session: session, lastAttempt: SyncResultKind.serverError),
        _is(LmsStatusKind.maintenance, 'LMS 정보 3시간 전 · 점검 중'),
      );
    }
  });

  test('다시 로그인이 필요하면 마지막 시도 결과보다 먼저 다시 로그인이다', () {
    for (final result in [
      SyncResultKind.normal,
      SyncResultKind.networkFailure,
      SyncResultKind.serverError,
    ]) {
      expect(
        _status(
          session: LmsSessionState.reconnectRequired,
          lastAttempt: result,
        ),
        _is(LmsStatusKind.reloginNeeded, 'LMS 정보 3시간 전 · 다시 로그인'),
      );
    }
  });

  test('로그인 전(로그인하는 중 포함)은 시각 없이 LMS 로그인 전이다', () {
    for (final session in [
      LmsSessionState.disconnected,
      LmsSessionState.connecting,
    ]) {
      expect(
        _status(session: session, lastAttempt: SyncResultKind.networkFailure),
        _is(LmsStatusKind.beforeLogin, 'LMS 로그인 전'),
      );
    }
  });

  test('원격 스위치가 꺼졌으면 세션 상태와 결과보다 먼저 연동 멈춤이다', () {
    for (final session in LmsSessionState.values) {
      expect(
        _status(
          enabled: false,
          session: session,
          lastAttempt: SyncResultKind.networkFailure,
        ),
        _is(LmsStatusKind.paused, 'LMS 연동을 잠시 멈췄어요'),
        reason: '$session',
      );
    }
  });

  test('데모 모드면 무엇보다 먼저 샘플 데이터 · 데모로 고정이다', () {
    expect(
      _status(
        demo: true,
        enabled: false,
        session: LmsSessionState.reconnectRequired,
        lastAttempt: SyncResultKind.networkFailure,
      ),
      _is(LmsStatusKind.demo, '샘플 데이터 · 데모'),
    );
  });

  test('정보 시트가 쓰도록 마지막 확인과 그것이 새로 고침이었는지를 담는다', () {
    final status = _status(
      session: LmsSessionState.reconnectRequired,
      byUserRefresh: true,
    );
    expect(status.lastSuccessAt, _threeHoursAgo);
    expect(status.byUserRefresh, isTrue);
    expect(
      status,
      _status(session: LmsSessionState.reconnectRequired, byUserRefresh: true),
    );
    expect(status, isNot(_status(session: LmsSessionState.reconnectRequired)));
  });
}
