// 09 일간의 데이터. docs/screens.md '09 일간'.
//
// 시간표는 02 홈과 같은 계산을 그 날짜로 한 `dayHomeProvider`(제안 블록 포함)이고, 시간표 밖(주 범위·날짜 줄·머리·
// 종일 일정·'모두 확정'·빈 날 카드·마감 줄)은 `domain/day_view.dart`의 [dayView]가 정한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/day_view.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 09 일간이 그리는 하루.
final class DayViewData {
  const DayViewData({required this.home, required this.view});

  /// 시간표(제안 블록 포함).
  final TodayHome home;

  /// 시간표 밖에 보일 것.
  final DayView view;
}

/// 논리적 하루 [date](그날 0시)의 09 일간. 시간표를 아직 읽지 못했으면 불러오는 중이고 읽지 못했으면 오류다.
final dayViewProvider = Provider.family<AsyncValue<DayViewData>, DateTime>((
  ref,
  date,
) {
  final home = ref.watch(dayHomeProvider(date));
  final tasks = ref.watch(taskEntriesProvider).value ?? const <TaskEntry>[];
  return home.whenData(
    (home) => DayViewData(
      home: home,
      view: dayView(
        date: home.date,
        items: home.items,
        allDayEvents: home.allDay,
        entries: tasks,
        free: home.free,
        now: home.now,
        dayBoundaryMin: home.dayBoundaryMin,
      ),
    ),
  );
});
