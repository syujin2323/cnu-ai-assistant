// LMS 상태 줄의 상태와 문구. docs/screens.md 'LMS 상태 줄과 다시 로그인'.
//
// 상태는 앱 모드, 원격 스위치(`lms_enabled`), 세션 상태(`settings`의 `lmsSessionState`), 마지막 동기화 시도의
// 결과(`sync_runs`, 건너뛴 기록 제외) 순서로 정한다(앞의 것이 먼저). 문구의 시각은 마지막 확인
// (`lmsLastSuccessAt`)이고 [lmsInfoText]로 쓴다. 네트워크 실패는 그 기록의 `detail`이 `offline`(연결 없음·주소
// 해석 실패)이면 오프라인, 아니면(시간 초과·연결 거부·보안 연결 오류) 연결 실패다(docs/decisions.md 2026-11-19
// '점검·오프라인 안내는 01·02·03 맨 위의 띠이고 연결 없음·주소 해석 실패를 오프라인으로 본다'). 정하지 않은 것(임시):
// - 표에 없는 결과(해석 실패, 복원 필요 등)는 연동됨처럼 마지막 확인 시각만 보인다.

import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// LMS 상태 줄의 상태(docs/screens.md의 표).
enum LmsStatusKind {
  /// 연동됨.
  synced,

  /// 다시 로그인 필요.
  reloginNeeded,

  /// 연결 실패(시간 초과·연결 거부·보안 연결 오류).
  connectionFailed,

  /// 오프라인(연결 없음·주소 해석 실패).
  offline,

  /// LMS 점검·서버 오류.
  maintenance,

  /// 연동 멈춤(원격 스위치 꺼짐).
  paused,

  /// 로그인 전.
  beforeLogin,

  /// 데모 모드.
  demo,
}

/// LMS 상태 줄 하나. [lastSuccessAt]·[byUserRefresh]는 LMS 정보 시트의 '마지막 확인'에 쓴다.
final class LmsStatus {
  const LmsStatus({
    required this.kind,
    required this.text,
    this.lastSuccessAt,
    this.byUserRefresh = false,
  });

  final LmsStatusKind kind;

  /// 상태 줄 문구.
  final String text;

  /// 마지막 확인(성공한 동기화의 시작 시각). 확인에 성공한 적이 없으면 null이다.
  final DateTime? lastSuccessAt;

  /// 마지막 확인을 남긴 동기화가 사용자 새로 고침이었는지.
  final bool byUserRefresh;

  @override
  bool operator ==(Object other) =>
      other is LmsStatus &&
      other.kind == kind &&
      other.text == text &&
      other.lastSuccessAt == lastSuccessAt &&
      other.byUserRefresh == byUserRefresh;

  @override
  int get hashCode => Object.hash(kind, text, lastSuccessAt, byUserRefresh);

  @override
  String toString() => 'LmsStatus($kind, $text)';
}

/// 데모 모드의 상태 줄 문구.
const String lmsDemoText = '샘플 데이터 · 데모';

/// 원격 스위치가 꺼졌을 때의 상태 줄 문구.
const String lmsPausedText = 'LMS 연동을 잠시 멈췄어요';

/// 로그인 전의 상태 줄 문구.
const String lmsBeforeLoginText = 'LMS 로그인 전';

/// 지금 LMS 상태. [demo]는 데모 모드인지, [enabled]는 원격 스위치, [session]은 세션 상태, [lastAttempt]는
/// 마지막 동기화 시도의 결과(기록이 없으면 null), [lastAttemptOffline]은 그 결과가 오프라인으로 끝난 네트워크
/// 실패인지(`sync_runs.detail`이 [SyncRunDetail.offline]), [lastSuccessAt]·[byUserRefresh]는 마지막 확인과 그것을
/// 남긴 동기화가 사용자 새로 고침이었는지다.
LmsStatus lmsStatus({
  required bool demo,
  required bool enabled,
  required LmsSessionState session,
  required SyncResultKind? lastAttempt,
  bool lastAttemptOffline = false,
  required DateTime? lastSuccessAt,
  required bool byUserRefresh,
  required DateTime now,
}) {
  if (demo) return const LmsStatus(kind: LmsStatusKind.demo, text: lmsDemoText);
  LmsStatus status(LmsStatusKind kind, String text) => LmsStatus(
    kind: kind,
    text: text,
    lastSuccessAt: lastSuccessAt,
    byUserRefresh: byUserRefresh,
  );
  if (!enabled) return status(LmsStatusKind.paused, lmsPausedText);
  if (session.beforeLogin) {
    return status(LmsStatusKind.beforeLogin, lmsBeforeLoginText);
  }
  final info = lmsInfoText(
    lastSuccessAt: lastSuccessAt,
    now: now,
    byUserRefresh: byUserRefresh,
  );
  if (session == LmsSessionState.reconnectRequired) {
    return status(LmsStatusKind.reloginNeeded, '$info · 다시 로그인');
  }
  return switch (lastAttempt) {
    SyncResultKind.networkFailure when lastAttemptOffline => status(
      LmsStatusKind.offline,
      '$info · 오프라인',
    ),
    SyncResultKind.networkFailure => status(
      LmsStatusKind.connectionFailed,
      '$info · 연결할 수 없어요',
    ),
    SyncResultKind.serverError => status(
      LmsStatusKind.maintenance,
      '$info · 점검 중',
    ),
    _ => status(LmsStatusKind.synced, info),
  };
}

/// 01 계획·02 홈·03 할 일 맨 위의 띠(docs/screens.md '20 시스템'). 점검 중·연결 실패·오프라인일 때만 있다.
final class LmsBand {
  const LmsBand({
    required this.kind,
    required this.title,
    required this.sub,
    required this.directAdd,
  });

  /// 띠를 띄운 상태(점검 중·연결 실패·오프라인).
  final LmsStatusKind kind;

  final String title;

  final String sub;

  /// [직접 입력하기]를 둘지. 오프라인이면 말로 추가(06 AI 비서) 대신 직접 추가 폼을 연다.
  final bool directAdd;

  @override
  bool operator ==(Object other) =>
      other is LmsBand &&
      other.kind == kind &&
      other.title == title &&
      other.sub == sub &&
      other.directAdd == directAdd;

  @override
  int get hashCode => Object.hash(kind, title, sub, directAdd);

  @override
  String toString() => 'LmsBand($kind, $title, $sub)';
}

/// [status]의 띠. 점검 중·연결 실패·오프라인이 아니면 null이다. 점검·오프라인 문구는 최종 프로토타입('20 시스템 ·
/// 사캠 점검 중')이고 연결 실패는 디자인 전 임시 문구다. [now]는 지금이다(마지막 확인 시각).
LmsBand? lmsBand(LmsStatus status, {required DateTime now}) {
  final lastSuccessAt = status.lastSuccessAt;
  final stored = lastSuccessAt == null
      ? '아직 받아 둔 LMS 정보가 없어요'
      : '받아 둔 정보로 보여 드려요 · 마지막 확인 '
            '${lastCheckedText(lastSuccessAt: lastSuccessAt, now: now, byUserRefresh: status.byUserRefresh)}';
  return switch (status.kind) {
    LmsStatusKind.maintenance => LmsBand(
      kind: status.kind,
      title: 'LMS가 점검 중이에요',
      sub: stored,
      directAdd: false,
    ),
    LmsStatusKind.connectionFailed => LmsBand(
      kind: status.kind,
      title: 'LMS에 연결할 수 없어요',
      sub: stored,
      directAdd: false,
    ),
    LmsStatusKind.offline => LmsBand(
      kind: status.kind,
      title: '인터넷에 연결되지 않았어요',
      sub: '폰에 저장된 정보로 그대로 쓸 수 있어요. 말로 추가는 연결되면 다시 돼요',
      directAdd: true,
    ),
    _ => null,
  };
}

/// 띠의 [다시 확인]으로 다시 받은 결과의 토스트 문구(임시). [offline]은 네트워크 실패의 까닭이 오프라인인지
/// (`sync_runs.detail`이 [SyncRunDetail.offline])다. 다시 로그인이 필요하거나(칩이 대신 보임) 건너뛰었으면 null이다.
String? lmsRetryMessage(SyncResultKind kind, {required bool offline}) =>
    switch (kind) {
      SyncResultKind.normal ||
      SyncResultKind.empty ||
      SyncResultKind.partial => 'LMS 정보를 새로 받았어요',
      SyncResultKind.serverError => '아직 점검 중이에요 · 받아 둔 정보는 그대로예요',
      SyncResultKind.networkFailure when offline =>
        '아직 인터넷에 연결되지 않았어요 · 받아 둔 정보는 그대로예요',
      SyncResultKind.networkFailure => '아직 LMS에 연결할 수 없어요 · 받아 둔 정보는 그대로예요',
      SyncResultKind.parseFailure => 'LMS 정보를 읽지 못했어요 · 받아 둔 정보는 그대로예요',
      SyncResultKind.reloginRequired ||
      SyncResultKind.restoreRequired ||
      SyncResultKind.skipped ||
      SyncResultKind.cancelled => null,
    };
