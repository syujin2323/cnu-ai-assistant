// 03 할 일 '주간 할 일'의 기준. docs/screens.md '03 할 일'. 10 나의 학기 카드('이번 주 할 일 N개')도 같은 기준으로
// 센다.

import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 주간 할 일에 드는지: 남은 할 일 가운데 오늘부터 7일 뒤까지 마감인 일과 마감이 지났는데 안 끝낸 일이다. 마감
/// 날짜는 마감 문구와 같은 규칙([dueDayOffset])으로 센다. 마감이 없는 일은 들지 않는다.
bool inWeeklyTasks(
  TaskEntry entry, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final dueAt = entry.task.dueAt;
  if (!entry.isRemaining || dueAt == null) return false;
  return dueDayOffset(dueAt, now: now, dayBoundaryMin: dayBoundaryMin) <= 7;
}
