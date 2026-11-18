// 03 할 일 '주간 할 일'의 기준 테스트. docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/task_week.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-16(월) 10:00.
final now = DateTime(2026, 11, 16, 10);

TaskEntry entry({DateTime? due, TaskStatus status = TaskStatus.todo}) =>
    TaskEntry(
      task: Task(
        id: 1,
        title: '할 일',
        kind: TaskKind.assignment,
        dueAt: due,
        dueTimeUnknown: false,
        status: status,
      ),
    );

bool weekly(TaskEntry entry, {DateTime? at}) => inWeeklyTasks(
  entry,
  now: at ?? now,
  dayBoundaryMin: Defaults.dayBoundaryMin,
);

void main() {
  test('오늘부터 7일 뒤까지 마감인 일과 마감이 지났는데 안 끝낸 일이 든다', () {
    expect(weekly(entry(due: DateTime(2026, 11, 16, 23, 59))), isTrue);
    expect(weekly(entry(due: DateTime(2026, 11, 23, 23, 59))), isTrue);
    expect(weekly(entry(due: DateTime(2026, 11, 24, 9))), isFalse);
    expect(weekly(entry(due: DateTime(2026, 11, 10, 9))), isTrue);
  });

  test('마감이 없거나 남지 않은 일(끝냄·숨김)은 들지 않는다', () {
    expect(weekly(entry()), isFalse);
    expect(
      weekly(entry(due: DateTime(2026, 11, 17), status: TaskStatus.done)),
      isFalse,
    );
    expect(
      weekly(entry(due: DateTime(2026, 11, 17), status: TaskStatus.hidden)),
      isFalse,
    );
  });

  test('날은 마감 문구와 같이 센다(정확히 00:00이면 전날, 하루 경계 전 새벽도 오늘)', () {
    // 24:00 마감(다음 날 00:00)은 전날로 세므로 7일 뒤 24:00까지 든다.
    expect(weekly(entry(due: DateTime(2026, 11, 24))), isTrue);
    // 하루 경계(04:00) 전 새벽 02:00에는 논리적 오늘이 전날이다.
    expect(
      weekly(
        entry(due: DateTime(2026, 11, 23, 9)),
        at: DateTime(2026, 11, 16, 2),
      ),
      isFalse,
    );
  });
}
