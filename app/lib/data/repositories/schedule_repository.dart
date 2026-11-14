// 배치 계산의 입력(`Schedule`)을 폰 DB에서 읽는 저장소. docs/architecture.md '도메인 기본값과 배치 엔진'
// 1단계.
//
// 수업 칸과 고정 일정은 매주 되풀이하므로 모두 읽는다. 수업 예외는 [start]의 전날부터 [end]의 날짜까지 읽고
// (자정을 넘는 수업이 전날 날짜에 묶이므로), 일정과 블록은 [start]–[end]와 겹치는 것만 읽는다(모든 상태의
// 블록. 빈 시간 계산은 확정·완료 블록만 뺀다). 표의 시각 열은 그 순간의 UTC 문자열로 저장되고 견줄 값은
// 변환기를 거치지 않으므로 [kstToUtc]로 바꿔 넘긴다. 이 저장소는 읽기만 하고, 각 표의 쓰기는 그 표의
// 저장소가 한다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:drift/drift.dart';

/// 배치 계산의 입력을 읽는 저장소.
class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDatabase _db;

  /// [start]부터 [end] 전까지(한국 시각)에 걸친 일정을 한 트랜잭션에서 한 번 읽는다. 배치 엔진이 쓴다.
  /// [end]가 [start]보다 늦지 않으면 [ArgumentError]다.
  Future<Result<Schedule>> read({
    required DateTime start,
    required DateTime end,
  }) {
    _checkRange(start, end);
    return guardStorage(
      'schedule.read',
      () => _db.transaction(() => _read(start, end)),
    );
  }

  /// [read]와 같은 범위를 지금 읽고, 다섯 표(수업 칸·수업 예외·고정 일정·일정·블록) 가운데 하나가
  /// 바뀔 때마다 다시 읽는다. 화면이 쓴다. 읽은 결과는 바뀐 순서대로 온다.
  Stream<Schedule> watch({required DateTime start, required DateTime end}) {
    _checkRange(start, end);
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.classSlots,
            _db.classExceptions,
            _db.fixedBlocks,
            _db.events,
            _db.planBlocks,
          },
        )
        .watch()
        .asyncMap((_) => _read(start, end));
  }

  Future<Schedule> _read(DateTime start, DateTime end) async {
    final from = kstToUtc(start);
    final to = kstToUtc(end);
    final firstDate = isoDate(DateTime(start.year, start.month, start.day - 1));
    final lastDate = isoDate(end);
    final classSlots = await (_db.select(
      _db.classSlots,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
    final classExceptions =
        await (_db.select(_db.classExceptions)
              ..where((t) => t.date.isBetweenValues(firstDate, lastDate))
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    final fixedBlocks = await (_db.select(
      _db.fixedBlocks,
    )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
    final events =
        await (_db.select(_db.events)
              ..where(
                (t) =>
                    t.startAt.isSmallerThanValue(to) &
                    t.endAt.isBiggerThanValue(from),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    final planBlocks =
        await (_db.select(_db.planBlocks)
              ..where(
                (t) =>
                    t.startAt.isSmallerThanValue(to) &
                    t.endAt.isBiggerThanValue(from),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    return Schedule(
      classSlots: classSlots,
      classExceptions: classExceptions,
      fixedBlocks: fixedBlocks,
      events: events,
      planBlocks: planBlocks,
    );
  }

  static void _checkRange(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }
}
