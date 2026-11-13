/// 동기화 잠금을 가진 쪽.
enum LeaseHolder { foreground, background }

/// 동기화 잠금. `sync_lease` 표의 한 행이고 [id]는 늘 1이다(docs/lms.md '동기화').
///
/// 행이 없거나 [expiresAt]이 지났을 때만 새 [token]으로 잡고, 늘리기와 풀기는 자기 [token]일
/// 때만 한다(`data/repositories/sync_lease_repository.dart`).
class SyncLease {
  const SyncLease({
    required this.id,
    required this.holder,
    required this.token,
    required this.expiresAt,
  });

  final int id;

  final LeaseHolder holder;

  /// 잠금을 잡을 때 만든 난수. 같은 [holder]가 둘이어도(R1의 백그라운드 작업과 서버 신호 푸시)
  /// 누가 잡았는지 가린다.
  final String token;

  final DateTime expiresAt;
}
