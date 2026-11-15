// LMS 상태 줄의 상태와 문구. docs/screens.md 'LMS 상태 줄과 다시 로그인'.
//
// 상태는 앱 모드, 원격 스위치(`lms_enabled`), 세션 상태(`settings`의 `lmsSessionState`), 마지막 동기화 시도의
// 결과(`sync_runs`, 건너뛴 기록 제외) 순서로 정한다(앞의 것이 먼저). 문구의 시각은 마지막 확인
// (`lmsLastSuccessAt`)이고 [lmsInfoText]로 쓴다. 정하지 않은 것(임시):
// - '오프라인'은 '연결 실패'와 가르는 기준을 정할 때(20 시스템) 더한다. 지금은 네트워크 실패를 모두 연결
//   실패로 본다.
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

  /// 연결 실패(네트워크 실패).
  connectionFailed,

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
/// 마지막 동기화 시도의 결과(기록이 없으면 null), [lastSuccessAt]·[byUserRefresh]는 마지막 확인과 그것을 남긴
/// 동기화가 사용자 새로 고침이었는지다.
LmsStatus lmsStatus({
  required bool demo,
  required bool enabled,
  required LmsSessionState session,
  required SyncResultKind? lastAttempt,
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
