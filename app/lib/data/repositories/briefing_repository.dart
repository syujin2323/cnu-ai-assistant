import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

/// `briefings`·`alerts` 표 저장소. docs/architecture.md '데일리 브리핑과 중요 브리핑'.
///
/// 읽기 스트림은 provider가 그대로 받고, 쓰기는 예외 대신 [Result]를 돌려준다.
class BriefingRepository {
  BriefingRepository(this._db);

  final AppDatabase _db;

  /// 오늘([date], `YYYY-MM-DD`) 브리핑을 연 것으로 적고 그 행을 돌려준다.
  ///
  /// 행이 없으면 [body]·[fromAt](직전 마지막 접속)으로 만든다. 이미 있으면 처음 연 시각과
  /// 범위는 그대로 둔다.
  Future<Result<Briefing>> openToday({
    required String date,
    required DateTime now,
    required String body,
    required DateTime? fromAt,
  }) async {
    try {
      return Ok(
        await _db.transaction(() async {
          final existing = await (_db.select(
            _db.briefings,
          )..where((b) => b.date.equals(date))).getSingleOrNull();
          if (existing == null) {
            await _db
                .into(_db.briefings)
                .insert(
                  BriefingsCompanion.insert(
                    date: date,
                    createdAt: now,
                    body: body,
                    cardsJson: '{}',
                    usedTemplate: true,
                    openedAt: Value(now),
                    fromAt: Value(fromAt),
                  ),
                );
          } else if (existing.openedAt == null) {
            await (_db.update(_db.briefings)
                  ..where((b) => b.id.equals(existing.id)))
                .write(BriefingsCompanion(openedAt: Value(now)));
          }
          return (_db.select(
            _db.briefings,
          )..where((b) => b.date.equals(date))).getSingle();
        }),
      );
    } on Exception catch (error) {
      return Err(_error('briefing.openToday', error));
    }
  }

  /// 중요 알림을 새것부터 낸다. 바뀔 때마다 다시 낸다.
  Stream<List<Alert>> watchAlerts() => (_db.select(
    _db.alerts,
  )..orderBy([(a) => OrderingTerm.desc(a.createdAt)])).watch();

  /// 알림을 더한다(동기화·일정 변경을 알아챈 코드가 부른다).
  Future<Result<int>> addAlert({
    required AlertLevel level,
    required AlertSource source,
    required String body,
    required DateTime createdAt,
    int? refId,
  }) async {
    try {
      return Ok(
        await _db
            .into(_db.alerts)
            .insert(
              AlertsCompanion.insert(
                level: level,
                source: source,
                createdAt: createdAt,
                body: body,
                refId: Value(refId),
              ),
            ),
      );
    } on Exception catch (error) {
      return Err(_error('briefing.addAlert', error));
    }
  }

  /// [until]까지 생긴 안 본 알림을 본 것으로 적는다.
  Future<Result<void>> markSeen({required DateTime until}) async {
    try {
      await (_db.update(_db.alerts)..where(
            (a) => a.seenAt.isNull() & a.createdAt.isSmallerOrEqualValue(until),
          ))
          .write(AlertsCompanion(seenAt: Value(until)));
      return const Ok(null);
    } on Exception catch (error) {
      return Err(_error('briefing.markSeen', error));
    }
  }

  static StorageError _error(String operation, Object error) =>
      StorageError(operation, causeType: error.runtimeType.toString());
}
