// 미배정 할 일 목록([unassignedTasks], [todayUnassigned]) 테스트.
// docs/architecture.md '도메인 기본값, 빈 시간과 여유도' 3단계.

import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-29(목) 20:00. 수업이 없으면 기본 하루 창(08:00–23:00) 안에서 오늘 남은 빈 시간은
  // 20:00–23:00, 180분이다.
  final now = DateTime(2026, 10, 29, 20);
  const boundary = 240;

  Task task(
    int id,
    DateTime due,
    int estimate, {
    TaskStatus status = TaskStatus.todo,
  }) => Task(
    id: id,
    title: '할 일$id',
    kind: TaskKind.assignment,
    dueAt: due,
    dueTimeUnknown: false,
    estimateMin: estimate,
    status: status,
  );

  final tonight = DateTime(2026, 10, 29, 23);
  final data = CalendarData(
    tasks: [
      task(1, tonight, 180), // 여유 0분 → 급함
      task(2, DateTime(2026, 11, 3, 23), 60), // 여유 많음 → 여유
      task(3, tonight, 60, status: TaskStatus.done), // 완료 → 빠짐
      task(4, DateTime(2026, 11, 3, 23), 120), // 확정 블록으로 다 정함 → 빠짐
      task(5, tonight, 300), // 빈 시간보다 많음 → 시간 부족
    ],
    schedule: Schedule(
      planBlocks: [
        PlanBlock(
          id: 1,
          taskId: 4,
          startAt: DateTime(2026, 10, 30, 9),
          endAt: DateTime(2026, 10, 30, 11),
          status: PlanBlockStatus.confirmed,
          source: BlockSource.manual,
        ),
      ],
    ),
  );

  test('완료했거나 시간을 다 정한 할 일은 빠지고, 여유도가 작은 순서로 온다', () {
    final list = unassignedTasks(data, now: now, dayBoundaryMin: boundary);
    expect(list.map((u) => u.task.id), [5, 1, 2]);
    expect(list[0].shortOfTime, isTrue);
    expect(list[0].urgency, Urgency.high);
    expect(list[1].remainingMin, 180);
    expect(list[1].urgency, Urgency.high);
    expect(list[1].shortOfTime, isFalse);
    expect(list[2].urgency, Urgency.low);
  });

  test('오늘 해야 할 것은 마감이 내일까지이거나 급한 것이다', () {
    final list = unassignedTasks(data, now: now, dayBoundaryMin: boundary);
    expect(
      todayUnassigned(
        list,
        now: now,
        dayBoundaryMin: boundary,
      ).map((u) => u.task.id),
      [5, 1],
    );
  });

  test('할 일이 없으면 빈 목록이다', () {
    expect(
      unassignedTasks(const CalendarData(), now: now, dayBoundaryMin: boundary),
      isEmpty,
    );
  });
}
