// 사용 지표 저장소: 지표에 쓰는 기록을 읽는다. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표.
//
// 지표는 실제 모드의 숫자만 보내므로 부르는 쪽은 실제 DB(`app.sqlite`)를 넘긴다. 폰 DB를 읽지 못하면
// [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

/// 지표를 만들 기록.
final class MetricsSource {
  const MetricsSource({
    required this.briefings,
    required this.autoBlockStarts,
    required this.syncRuns,
  });

  /// 날짜(`YYYY-MM-DD`) → 그날의 브리핑 기록.
  final Map<String, Briefing> briefings;

  /// 자동으로 놓은 블록(제안·확정·완료·놓침·지움)의 시작 시각.
  final List<DateTime> autoBlockStarts;

  /// 동기화 기록.
  final List<SyncRun> syncRuns;
}

/// 사용 지표 저장소.
class MetricsRepository {
  MetricsRepository(this._db);

  final AppDatabase _db;

  /// 앱을 쓴 날(그날 01 계획을 본 것으로 적은 논리적 하루) 가운데 [from](`YYYY-MM-DD`)부터의 날짜.
  Future<Result<List<String>>> activeDaysFrom(String from) => guardStorage(
    'metrics.activeDaysFrom',
    () async => [
      for (final row
          in await (_db.select(_db.briefings)..where(
                (t) =>
                    t.date.isBiggerOrEqualValue(from) & t.openedAt.isNotNull(),
              ))
              .get())
        row.date,
    ],
  );

  /// [start]부터 [end] 앞까지(한국 시각) 시작하는 자동 블록이 있는지. 상태는 보지 않는다.
  Future<Result<bool>> hasAutoBlocks({
    required DateTime start,
    required DateTime end,
  }) => guardStorage('metrics.hasAutoBlocks', () async {
    final row =
        await (_db.select(_db.planBlocks)
              ..where((t) => _autoBlocksIn(t, start, end))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  });

  /// [days](`YYYY-MM-DD`)의 브리핑 기록과, [from]부터 [to] 앞까지(한국 시각)의 자동 블록 시작 시각·동기화
  /// 기록을 한 트랜잭션에서 읽는다.
  Future<Result<MetricsSource>> read({
    required List<String> days,
    required DateTime from,
    required DateTime to,
  }) => guardStorage(
    'metrics.read',
    () => _db.transaction(() async {
      final briefings = await (_db.select(
        _db.briefings,
      )..where((t) => t.date.isIn(days))).get();
      final blocks = await (_db.select(
        _db.planBlocks,
      )..where((t) => _autoBlocksIn(t, from, to))).get();
      final runs =
          await (_db.select(_db.syncRuns)..where(
                (t) =>
                    t.startedAt.isBiggerOrEqualValue(kstToUtc(from)) &
                    t.startedAt.isSmallerThanValue(kstToUtc(to)),
              ))
              .get();
      return MetricsSource(
        briefings: {for (final row in briefings) row.date: row},
        autoBlockStarts: [for (final block in blocks) block.startAt],
        syncRuns: runs,
      );
    }),
  );

  Expression<bool> _autoBlocksIn(
    $PlanBlocksTable t,
    DateTime start,
    DateTime end,
  ) =>
      t.source.equalsValue(BlockSource.auto) &
      t.startAt.isBiggerOrEqualValue(kstToUtc(start)) &
      t.startAt.isSmallerThanValue(kstToUtc(end));
}
