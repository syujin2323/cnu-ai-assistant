/// 동기화 잠금을 가진 쪽.
enum LeaseHolder { foreground, background }

/// 동기화 잠금. `sync_lease` 표의 한 행이고 [id]는 늘 1이다(docs/lms.md '동기화').
///
/// 행이 없거나 [expiresAt]이 지났으면 한 트랜잭션 안에서 자기 것으로 바꿔 넣고,
/// 끝나면 행을 지운다.
class SyncLease {
  const SyncLease({
    required this.id,
    required this.holder,
    this.runId,
    required this.expiresAt,
  });

  final int id;

  final LeaseHolder holder;

  /// 지금 도는 `sync_runs.id`.
  final int? runId;

  final DateTime expiresAt;
}
