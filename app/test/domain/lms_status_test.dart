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
  bool lastAttemptOffline = false,
  DateTime? lastSuccessAt,
  bool byUserRefresh = false,
}) => lmsStatus(
  demo: demo,
  enabled: enabled,
  session: session,
  lastAttempt: lastAttempt,
  lastAttemptOffline: lastAttemptOffline,
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

  test('네트워크 실패가 오프라인으로 끝났으면 오프라인이고, 그 밖의 결과에서는 오프라인 표시를 보지 않는다', () {
    expect(
      _status(
        lastAttempt: SyncResultKind.networkFailure,
        lastAttemptOffline: true,
      ),
      _is(LmsStatusKind.offline, 'LMS 정보 3시간 전 · 오프라인'),
    );
    expect(
      _status(
        lastAttempt: SyncResultKind.serverError,
        lastAttemptOffline: true,
      ),
      _is(LmsStatusKind.maintenance, 'LMS 정보 3시간 전 · 점검 중'),
    );
    // 다시 로그인이 필요하면 오프라인보다 먼저다.
    expect(
      _status(
        session: LmsSessionState.reconnectRequired,
        lastAttempt: SyncResultKind.networkFailure,
        lastAttemptOffline: true,
      ).kind,
      LmsStatusKind.reloginNeeded,
    );
  });

  group('01·02·03 위의 띠', () {
    LmsBand? band(LmsStatus status) => lmsBand(status, now: _now);

    test('점검 중·연결 실패는 받아 둔 정보와 마지막 확인을 알린다', () {
      expect(
        band(_status(lastAttempt: SyncResultKind.serverError)),
        const LmsBand(
          kind: LmsStatusKind.maintenance,
          title: 'LMS가 점검 중이에요',
          sub: '받아 둔 정보로 보여 드려요 · 마지막 확인 3시간 전',
          directAdd: false,
        ),
      );
      expect(
        band(_status(lastAttempt: SyncResultKind.networkFailure)),
        const LmsBand(
          kind: LmsStatusKind.connectionFailed,
          title: 'LMS에 연결할 수 없어요',
          sub: '받아 둔 정보로 보여 드려요 · 마지막 확인 3시간 전',
          directAdd: false,
        ),
      );
      // 사용자 새로 고침 뒤 10분은 방금이고, 확인한 적이 없으면 받아 둔 정보가 없다고 한다.
      expect(
        band(
          _status(
            lastAttempt: SyncResultKind.serverError,
            lastSuccessAt: _now.subtract(const Duration(minutes: 5)),
            byUserRefresh: true,
          ),
        )?.sub,
        '받아 둔 정보로 보여 드려요 · 마지막 확인 방금',
      );
      expect(
        band(
          lmsStatus(
            demo: false,
            enabled: true,
            session: LmsSessionState.active,
            lastAttempt: SyncResultKind.networkFailure,
            lastSuccessAt: null,
            byUserRefresh: false,
            now: _now,
          ),
        )?.sub,
        '아직 받아 둔 LMS 정보가 없어요',
      );
    });

    test('오프라인은 폰의 정보로 쓴다고 알리고 직접 입력하기를 둔다', () {
      expect(
        band(
          _status(
            lastAttempt: SyncResultKind.networkFailure,
            lastAttemptOffline: true,
          ),
        ),
        const LmsBand(
          kind: LmsStatusKind.offline,
          title: '인터넷에 연결되지 않았어요',
          sub: '폰에 저장된 정보로 그대로 쓸 수 있어요. 말로 추가는 연결되면 다시 돼요',
          directAdd: true,
        ),
      );
    });

    test('그 밖의 상태에서는 띠가 없다', () {
      for (final status in [
        _status(),
        _status(session: LmsSessionState.reconnectRequired),
        _status(session: LmsSessionState.disconnected),
        _status(enabled: false),
        _status(demo: true),
        _status(lastAttempt: SyncResultKind.parseFailure),
      ]) {
        expect(band(status), isNull, reason: '${status.kind}');
      }
    });

    test('다시 확인한 결과의 토스트', () {
      String? message(SyncResultKind kind, {bool offline = false}) =>
          lmsRetryMessage(kind, offline: offline);
      for (final kind in [
        SyncResultKind.normal,
        SyncResultKind.empty,
        SyncResultKind.partial,
      ]) {
        expect(message(kind), 'LMS 정보를 새로 받았어요');
      }
      expect(
        message(SyncResultKind.serverError),
        '아직 점검 중이에요 · 받아 둔 정보는 그대로예요',
      );
      expect(
        message(SyncResultKind.networkFailure, offline: true),
        '아직 인터넷에 연결되지 않았어요 · 받아 둔 정보는 그대로예요',
      );
      expect(
        message(SyncResultKind.networkFailure),
        '아직 LMS에 연결할 수 없어요 · 받아 둔 정보는 그대로예요',
      );
      expect(
        message(SyncResultKind.parseFailure),
        'LMS 정보를 읽지 못했어요 · 받아 둔 정보는 그대로예요',
      );
      // 다시 로그인 칩이 대신 보이거나 받지 않았으면 알리지 않는다.
      for (final kind in [
        SyncResultKind.reloginRequired,
        SyncResultKind.restoreRequired,
        SyncResultKind.skipped,
        SyncResultKind.cancelled,
      ]) {
        expect(message(kind), isNull, reason: '$kind');
      }
    });
  });
}
