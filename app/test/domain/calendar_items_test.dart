// 날짜마다 캘린더 항목을 펼치는 [itemsOn] 테스트. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-29는 목요일이다.
  final thu = DateTime(2026, 10, 29);
  final fri = DateTime(2026, 10, 30);

  const course = Course(id: 1, name: '자료구조', alias: '자구');
  const slot = ClassSlot(
    id: 10,
    courseId: 1,
    weekday: DateTime.thursday,
    startMin: 600,
    endMin: 675,
    place: '공대5호관 412',
    campus: Campus.daedeok,
    online: false,
    source: SlotSource.manual,
  );
  Task task(int id, DateTime? dueAt, {TaskStatus status = TaskStatus.todo}) =>
      Task(
        id: id,
        title: '과제$id',
        kind: TaskKind.assignment,
        dueAt: dueAt,
        dueTimeUnknown: false,
        status: status,
      );
  PlanBlock block(int taskId, DateTime start, PlanBlockStatus status) =>
      PlanBlock(
        id: taskId * 100,
        taskId: taskId,
        startAt: start,
        endAt: start.add(const Duration(hours: 2)),
        status: status,
        source: BlockSource.manual,
      );

  test('수업은 그 요일에 과목 별칭으로 나오고, 휴강이면 빠지고 보강이면 다른 요일에도 나온다', () {
    final data = CalendarData(
      courses: const [course],
      schedule: Schedule(
        classSlots: const [slot],
        classExceptions: const [
          ClassException(
            id: 1,
            date: '2026-10-30',
            classSlotId: 10,
            kind: ClassExceptionKind.makeup,
            source: EntrySource.manual,
          ),
        ],
      ),
    );
    final thuItems = itemsOn(thu, data);
    expect(thuItems.single.kind, CalendarItemKind.classSession);
    expect(thuItems.single.title, '자구');
    expect(thuItems.single.start, DateTime(2026, 10, 29, 10));
    expect(thuItems.single.end, DateTime(2026, 10, 29, 11, 15));
    expect(thuItems.single.place, '공대5호관 412');
    expect(itemsOn(fri, data).single.title, '자구');

    final cancelled = CalendarData(
      courses: const [course],
      schedule: Schedule(
        classSlots: const [slot],
        classExceptions: const [
          ClassException(
            id: 2,
            date: '2026-10-29',
            classSlotId: 10,
            kind: ClassExceptionKind.cancelled,
            source: EntrySource.manual,
          ),
        ],
      ),
    );
    expect(itemsOn(thu, cancelled), isEmpty);
  });

  test('종일 일정이 먼저, 나머지는 시작 시각 순이고 여러 날에 걸친 일정은 날마다 나온다', () {
    final data = CalendarData(
      schedule: Schedule(
        fixedBlocks: const [
          FixedBlock(
            id: 1,
            name: '편의점 알바',
            weekdays: [DateTime.thursday],
            startMin: 1080,
            endMin: 1320,
            bufferMin: 0,
            kind: FixedBlockKind.work,
            source: EntrySource.manual,
          ),
        ],
        events: [
          Event(
            id: 1,
            title: '해커톤',
            startAt: thu,
            endAt: DateTime(2026, 10, 31),
            allDay: true,
            source: EventSource.manual,
          ),
          Event(
            id: 2,
            title: '멘토링',
            startAt: DateTime(2026, 10, 29, 17),
            endAt: DateTime(2026, 10, 29, 18),
            allDay: false,
            source: EventSource.manual,
          ),
        ],
      ),
    );
    expect(itemsOn(thu, data).map((i) => i.title), ['해커톤', '멘토링', '편의점 알바']);
    expect(itemsOn(thu, data).first.allDay, isTrue);
    expect(itemsOn(fri, data).map((i) => i.title), ['해커톤']);
    expect(itemsOn(DateTime(2026, 10, 31), data), isEmpty);
  });

  test('마감은 끝나지 않은 확정 블록이 있으면 배치됨이고, 완료한 할 일의 마감은 나오지 않는다', () {
    final due = DateTime(2026, 10, 29, 23, 59);
    final data = CalendarData(
      tasks: [
        task(1, due),
        task(2, due),
        task(3, due, status: TaskStatus.done),
      ],
      schedule: Schedule(
        planBlocks: [
          block(1, DateTime(2026, 10, 29, 19), PlanBlockStatus.confirmed),
          block(2, DateTime(2026, 10, 28, 19), PlanBlockStatus.done),
        ],
      ),
    );
    final items = itemsOn(thu, data);
    expect(items.map((i) => (i.kind, i.title)), [
      (CalendarItemKind.block, '과제1'),
      (CalendarItemKind.deadline, '과제1'),
      (CalendarItemKind.deadline, '과제2'),
    ]);
    expect(items[1].placed, isTrue);
    expect(items[2].placed, isFalse);
    expect(items[1].taskId, 1);
    // 완료한 블록은 그 날에 그대로 보인다.
    expect(
      itemsOn(DateTime(2026, 10, 28), data).single.kind,
      CalendarItemKind.block,
    );
  });

  test('제안·지운 블록(옛 값)은 그리지 않는다', () {
    final data = CalendarData(
      tasks: [task(1, null)],
      schedule: Schedule(
        planBlocks: [
          block(1, DateTime(2026, 10, 29, 9), PlanBlockStatus.suggested),
          block(1, DateTime(2026, 10, 29, 13), PlanBlockStatus.dismissed),
        ],
      ),
    );
    expect(itemsOn(thu, data), isEmpty);
  });
}
