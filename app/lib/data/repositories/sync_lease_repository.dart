import 'dart:convert';
import 'dart:math';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/sync_lease.dart';
import 'package:drift/drift.dart';

/// 동기화 잠금(`sync_lease` 한 행)을 잡고 늘리고 푸는 저장소. docs/lms.md '동기화'.
///
/// 앱과 백그라운드 작업(R1)은 다른 isolate에서 폰 DB 연결을 따로 열므로 잠금은 메모리가 아니라 이
/// 표에 건다. 잡을 때마다 새 토큰(난수)을 만들고, 늘리기와 풀기는 자기 토큰일 때만 한다. 그래서
/// 만료된 뒤 다른 쪽이 가져간 잠금을 늦게 끝난 쪽이 늘리거나 지우지 못한다. 폰 DB를 읽거나 쓰지
/// 못하면 [StorageError]를 담은 [Err]다([guardStorage]).
class SyncLeaseRepository {
  SyncLeaseRepository(this._db);

  final AppDatabase _db;

  static final _random = Random.secure();

  /// 임대 시간. 과목 하나를 끝낼 때마다 [extend]로 다시 이만큼 늘린다.
  static const leaseDuration = Duration(minutes: 5);

  /// [holder]로 잠금을 잡는다. 행이 없거나 [now]에 이미 만료됐으면 새 토큰으로 바꿔 넣고 그 토큰을,
  /// 다른 쪽이 잡고 있으면 null을 돌려준다(그 요청은 `skipped`로 끝낸다).
  ///
  /// 확인과 쓰기는 한 트랜잭션이다. drift 트랜잭션은 시작부터 쓰기 잠금을 잡으므로(BEGIN IMMEDIATE)
  /// 두 연결이 함께 잡아도 하나만 잡는다. 늦은 쪽은 지금은 기다리지 않고 잠김(`StorageError.code`
  /// 5)으로 끝난다.
  Future<Result<String?>> acquire(LeaseHolder holder, {required DateTime now}) {
    final token = _newToken();
    return guardStorage(
      'syncLease.acquire',
      () => _db.transaction(() async {
        final current = await _db.select(_db.syncLeases).getSingleOrNull();
        if (current != null && current.expiresAt.isAfter(now)) return null;
        await _db
            .into(_db.syncLeases)
            .insertOnConflictUpdate(
              SyncLeasesCompanion.insert(
                holder: holder,
                token: token,
                expiresAt: now.add(leaseDuration),
              ),
            );
        return token;
      }),
    );
  }

  /// 잠금을 [now]부터 [leaseDuration]만큼으로 다시 늘린다. 지금 잠금이 [token]의 것일 때만 늘리고
  /// true, 다른 쪽이 가져갔거나 풀렸으면 false다.
  Future<Result<bool>> extend(String token, {required DateTime now}) {
    return guardStorage('syncLease.extend', () async {
      final changed =
          await (_db.update(_db.syncLeases)..where(
                (lease) => lease.id.equals(1) & lease.token.equals(token),
              ))
              .write(
                SyncLeasesCompanion(expiresAt: Value(now.add(leaseDuration))),
              );
      return changed == 1;
    });
  }

  /// 잠금을 푼다(행을 지운다). 지금 잠금이 [token]의 것일 때만 지우고 true, 아니면 false다.
  Future<Result<bool>> release(String token) {
    return guardStorage('syncLease.release', () async {
      final deleted = await (_db.delete(
        _db.syncLeases,
      )..where((lease) => lease.id.equals(1) & lease.token.equals(token))).go();
      return deleted == 1;
    });
  }

  /// 잠금마다 새로 만드는 토큰. 16바이트 난수를 base64url(22자)로 적는다.
  static String _newToken() =>
      base64UrlEncode([for (var i = 0; i < 16; i++) _random.nextInt(256)])
          .replaceAll('=', '');
}
