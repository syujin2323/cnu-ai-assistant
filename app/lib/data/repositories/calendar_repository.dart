import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';

/// 캘린더 보기와 미배정 할 일이 읽는 표(수업·고정 일정·일정·블록·할 일·과목·사캠 항목·
/// 내 규칙)를 한 묶음으로 읽는 저장소.
///
/// 학생 한 명의 한 학기 데이터라 행이 적어 기간으로 자르지 않고 모두 읽는다. 날짜별
/// 펼치기는 `domain/calendar_items.dart`의 [itemsOn]이 한다.
class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

  /// 지금 묶음을 내고, 관련 표가 바뀔 때마다 다시 읽어 낸다.
  ///
  /// `calendarDataProvider`(StreamProvider)가 그대로 받으므로 읽기 실패는 스트림 오류다.
  ///
  /// 바뀜 감지는 drift의 스트림 쿼리(`readsFrom`)에 맡긴다. 그래야 provider가 정리될 때
  /// 구독이 함께 끝나 DB를 닫을 수 있다.
  Stream<CalendarData> watch() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.courses,
          _db.classSlots,
          _db.classExceptions,
          _db.fixedBlocks,
          _db.events,
          _db.tasks,
          _db.planBlocks,
          _db.lmsItems,
          _db.rules,
        },
      )
      .watch()
      .asyncMap((_) => _read());

  Future<CalendarData> _read() async => CalendarData(
    schedule: Schedule(
      classSlots: await _db.select(_db.classSlots).get(),
      classExceptions: await _db.select(_db.classExceptions).get(),
      fixedBlocks: await _db.select(_db.fixedBlocks).get(),
      events: await _db.select(_db.events).get(),
      planBlocks: await _db.select(_db.planBlocks).get(),
    ),
    courses: await _db.select(_db.courses).get(),
    tasks: await _db.select(_db.tasks).get(),
    lmsItems: await _db.select(_db.lmsItems).get(),
    rules: await _db.select(_db.rules).get(),
  );
}
