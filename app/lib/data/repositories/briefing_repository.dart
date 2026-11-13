// 아침 브리핑 기록 저장소(`briefings` 표). docs/architecture.md '아침 브리핑'.
//
// 브리핑 내용은 열 때 폰 DB와 배치 엔진으로 계산하므로 저장하지 않고, 그날(논리적 하루) 브리핑을 본 것과
// 확정한 것만 적는다. 하루는 `date`(`YYYY-MM-DD`)가 겹치지 않는 한 행이다. 본 것은 01 아침 브리핑이 화면에
// 뜨는 순간 적는다(docs/decisions.md 2026-11-13 '아침 브리핑은 뜨는 순간 본 것으로 기록한다'). 폰 DB를
// 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/briefing.dart';
import 'package:drift/drift.dart';

/// 아침 브리핑 기록 저장소.
class BriefingRepository {
  BriefingRepository(this._db);

  final AppDatabase _db;

  /// [day](논리적 하루)의 브리핑을 본 것으로 기록했는지.
  Future<Result<bool>> isSeen(DateTime day) => guardStorage(
    'briefings.isSeen',
    () async => (await _row(day))?.openedAt != null,
  );

  /// [day]의 브리핑을 [at]에 본 것으로 기록한다. 이미 기록했으면 처음 시각을 그대로 둔다.
  Future<Result<void>> markSeen(DateTime day, {required DateTime at}) =>
      guardStorage(
        'briefings.markSeen',
        () => _db.transaction(() async {
          final row = await _row(day);
          if (row == null) {
            await _db
                .into(_db.briefings)
                .insert(
                  BriefingsCompanion.insert(
                    date: isoDate(day),
                    createdAt: at,
                    openedAt: Value(at),
                  ),
                );
          } else if (row.openedAt == null) {
            await _update(row.id, BriefingsCompanion(openedAt: Value(at)));
          }
        }),
      );

  /// [day]의 브리핑에서 'N개 확정하기'를 [at]에 눌렀다고 기록한다. 다시 확정하면 마지막 시각으로 바꾸고,
  /// 본 것으로 기록하지 않았으면 함께 기록한다. 01 아침 브리핑 화면 PR이 부른다.
  Future<Result<void>> markConfirmed(DateTime day, {required DateTime at}) =>
      guardStorage(
        'briefings.markConfirmed',
        () => _db.transaction(() async {
          final row = await _row(day);
          if (row == null) {
            await _db
                .into(_db.briefings)
                .insert(
                  BriefingsCompanion.insert(
                    date: isoDate(day),
                    createdAt: at,
                    openedAt: Value(at),
                    confirmedAt: Value(at),
                  ),
                );
          } else {
            await _update(
              row.id,
              BriefingsCompanion(
                openedAt: Value(row.openedAt ?? at),
                confirmedAt: Value(at),
              ),
            );
          }
        }),
      );

  Future<Briefing?> _row(DateTime day) => (_db.select(
    _db.briefings,
  )..where((briefing) => briefing.date.equals(isoDate(day)))).getSingleOrNull();

  Future<void> _update(int id, BriefingsCompanion values) => (_db.update(
    _db.briefings,
  )..where((briefing) => briefing.id.equals(id))).write(values);
}
