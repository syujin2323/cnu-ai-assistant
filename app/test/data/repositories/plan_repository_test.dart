// 일정 추가·할 일 배치 저장소([PlanRepository])와 되돌리기 테스트. docs/architecture.md '폰 DB'.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트가 시각을 옮길 수 있는 시계.
class _MovableClock extends Clock {
  _MovableClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

void main() {
  late AppDatabase db;
  late _MovableClock clock;
  late PlanRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    clock = _MovableClock(DateTime(2026, 10, 29, 10));
    repository = PlanRepository(db, clock);
  });
  tearDown(() => db.close());

  Future<int> addTask() => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );

  test('배치하면 확정 블록과 되돌리기 기록이 생기고, 10초 안에 되돌리면 지워진다', () async {
    final taskId = await addTask();
    final result = await repository.placeTask(
      taskId: taskId,
      startAt: DateTime(2026, 10, 29, 14),
      endAt: DateTime(2026, 10, 29, 16),
      source: BlockSource.manual,
    );
    expect(result, isA<Ok<int>>());
    final block = await db.select(db.planBlocks).getSingle();
    expect(block.status, PlanBlockStatus.confirmed);
    final undo = await db.select(db.undoLog).getSingle();
    expect(undo.targetTable, 'plan_blocks');
    expect(undo.rowId, block.id);

    clock.current = clock.current.add(const Duration(seconds: 9));
    expect(await repository.undoLast(), isA<Ok<bool>>());
    expect(await db.select(db.planBlocks).get(), isEmpty);
    expect(await db.select(db.undoLog).get(), isEmpty);
  });

  test('10초가 지나면 되돌리지 않고 기록만 버린다', () async {
    await repository.addEvent(
      title: '헬스',
      startAt: DateTime(2026, 10, 29, 19),
      endAt: DateTime(2026, 10, 29, 20),
      allDay: false,
      source: EventSource.manual,
    );
    clock.current = clock.current.add(const Duration(seconds: 11));

    final result = await repository.undoLast();
    expect((result as Ok<bool>).value, isFalse);
    expect(await db.select(db.events).get(), hasLength(1));
    expect(await db.select(db.undoLog).get(), isEmpty);
  });
}
