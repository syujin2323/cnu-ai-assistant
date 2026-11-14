// 하루 시간표 항목 테스트. docs/screens.md '02 홈'·'09 일간'.
//
// 2026-11-16은 월요일이다. 하루 창 09:00–18:00, 수업 여유 10분을 규칙으로 둔다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const monday = 16;

Rule rule(RuleKind kind, RuleParams params, {int id = 100}) {
  final when = DateTime(2026, 11, 1);
  return Rule(
    id: id,
    kind: kind,
    params: params,
    active: true,
    source: EntrySource.manual,
    createdAt: when,
    updatedAt: when,
  );
}

final config = PlannerConfig.from([
  rule(
    RuleKind.workWindow,
    const RuleParams(startMin: 540, endMin: 1080),
    id: 1,
  ),
  rule(RuleKind.classBuffer, const RuleParams(minutes: 10), id: 2),
  rule(
    RuleKind.meal,
    const RuleParams(startMin: 690, endMin: 810, minutes: 0),
    id: 3,
  ),
]);

ClassSlot slot(
  int id, {
  required int weekday,
  required int startMin,
  required int endMin,
}) => ClassSlot(
  id: id,
  courseId: id,
  weekday: weekday,
  startMin: startMin,
  endMin: endMin,
  place: '공학관 $id',
  campus: Campus.daedeok,
  online: false,
  source: SlotSource.auto,
);

ClassException exception(
  int id,
  int slotId,
  String date,
  ClassExceptionKind kind, {
  String? place,
  int? startMin,
  int? endMin,
}) => ClassException(
  id: id,
  date: date,
  classSlotId: slotId,
  kind: kind,
  place: place,
  source: EntrySource.manual,
  startMin: startMin,
  endMin: endMin,
);

PlanBlock block(
  int id,
  int taskId,
  DateTime start,
  DateTime end,
  PlanBlockStatus status,
) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.manual,
);

List<DayItem> items(
  Schedule schedule, {
  List<TaskEntry> tasks = const [],
  bool includeSuggested = false,
  int day = monday,
  List<Rule> rules = const [],
}) {
  final date = DateTime(2026, 11, day);
  final plannerConfig = rules.isEmpty
      ? config
      : PlannerConfig.from([
          rule(
            RuleKind.workWindow,
            const RuleParams(startMin: 540, endMin: 1080),
            id: 1,
          ),
          rule(RuleKind.classBuffer, const RuleParams(minutes: 10), id: 2),
          ...rules,
        ]);
  return dayItems(
    date,
    schedule: schedule,
    availability: dayAvailability(
      date,
      schedule: schedule,
      config: plannerConfig,
      dayBoundaryMin: Defaults.dayBoundaryMin,
    ),
    tasks: tasks,
    dayBoundaryMin: Defaults.dayBoundaryMin,
    includeSuggested: includeSuggested,
  );
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 항목을 '종류 시작–끝' 꼴로.
List<String> describe(List<DayItem> list) => [
  for (final item in list)
    '${switch (item) {
      ClassItem() => '수업',
      EventItem() => '일정',
      FixedItem() => '고정',
      TravelItem() => '이동',
      MealItem() => '점심',
      BlockItem() => '블록',
    }} ${_hhmm(item.span.start)}–${_hhmm(item.span.end)}',
];

void main() {
  test('그날 수업에 휴강·시험·장소 변경을 붙이고, 보강은 저장된 시각(없으면 평소 시각)에 넣는다', () {
    final schedule = Schedule(
      classSlots: [
        slot(1, weekday: 1, startMin: 540, endMin: 615),
        slot(2, weekday: 1, startMin: 780, endMin: 855),
        slot(3, weekday: 1, startMin: 900, endMin: 975),
        slot(4, weekday: 3, startMin: 600, endMin: 675),
        slot(5, weekday: 1, startMin: 1000, endMin: 1060),
      ],
      classExceptions: [
        exception(1, 1, '2026-11-16', ClassExceptionKind.cancelled),
        exception(2, 2, '2026-11-16', ClassExceptionKind.exam, place: '대강당'),
        exception(
          3,
          3,
          '2026-11-16',
          ClassExceptionKind.placeChange,
          place: '자연과학관 105',
        ),
        exception(
          4,
          4,
          '2026-11-16',
          ClassExceptionKind.makeup,
          startMin: 1140,
          endMin: 1200,
        ),
        exception(5, 1, '2026-11-16', ClassExceptionKind.makeup),
        exception(6, 5, '2026-11-17', ClassExceptionKind.cancelled),
      ],
    );
    final classes = items(schedule).whereType<ClassItem>().toList();
    expect(
      [
        for (final c in classes)
          '${c.slot.id} ${_hhmm(c.span.start)} ${c.cancelled ? '휴강' : ''}'
              '${c.exam ? '시험' : ''}${c.makeup ? '보강' : ''} ${c.place}',
      ],
      [
        '1 09:00 휴강 공학관 1',
        '1 09:00 보강 공학관 1',
        '2 13:00 시험 대강당',
        '3 15:00  자연과학관 105',
        '5 16:40  공학관 5',
        '4 19:00 보강 공학관 4',
      ],
    );
  });

  test('자정을 넘는 수업과 다음 날 하루 경계 전 수업은 그 논리적 하루에 든다', () {
    final schedule = Schedule(
      classSlots: [
        slot(1, weekday: 1, startMin: 1320, endMin: 1530),
        // 화요일 01:00–02:00은 월요일 논리적 하루의 끝이다.
        slot(2, weekday: 2, startMin: 60, endMin: 120),
      ],
    );
    expect(describe(items(schedule)), ['수업 22:00–01:30', '수업 01:00–02:00']);
    // 화요일 논리적 하루(04:00부터)에는 들지 않는다.
    expect(items(schedule, day: monday + 1).whereType<ClassItem>(), isEmpty);
  });

  test('일정은 종일 일정을 빼고 논리적 하루 안으로 잘라 넣는다', () {
    final schedule = Schedule(
      classSlots: const [],
      events: [
        Event(
          id: 1,
          title: '회의',
          startAt: at(monday, 19),
          endAt: at(monday, 20),
          allDay: false,
          source: EventSource.manual,
        ),
        Event(
          id: 2,
          title: '생일',
          startAt: at(monday, 0),
          endAt: at(monday + 1, 0),
          allDay: true,
          source: EventSource.manual,
        ),
        Event(
          id: 3,
          title: '밤샘',
          startAt: at(monday, 23),
          endAt: at(monday + 1, 6),
          allDay: false,
          source: EventSource.manual,
        ),
      ],
    );
    final list = items(schedule);
    expect(describe(list), ['일정 19:00–20:00', '일정 23:00–04:00']);
    expect((list.first as EventItem).event.title, '회의');
  });

  test('고정 일정·이동·점심은 빈 시간 계산과 같은 자리이고, 고정 일정의 앞뒤 여유는 넣지 않는다', () {
    final schedule = Schedule(
      classSlots: [slot(1, weekday: 1, startMin: 600, endMin: 675)],
      fixedBlocks: const [
        FixedBlock(
          id: 7,
          name: '알바',
          weekdays: [1],
          startMin: 1080,
          endMin: 1260,
          bufferMin: 10,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
        ),
      ],
    );
    final list = items(
      schedule,
      rules: [
        rule(
          RuleKind.travel,
          const RuleParams(minutes: 30, position: TravelPosition.dayEdges),
        ),
      ],
    );
    expect(describe(list), [
      '이동 09:30–10:00',
      '수업 10:00–11:15',
      '이동 11:15–11:45',
      '점심 11:45–12:25',
      '고정 18:00–21:00',
    ]);
    expect(list.whereType<FixedItem>().single.block.name, '알바');
  });

  test('블록은 확정·완료·놓침을 넣고, 제안은 includeSuggested일 때만, 지운 블록은 넣지 않는다', () {
    final schedule = Schedule(
      classSlots: const [],
      planBlocks: [
        block(1, 1, at(monday, 9), at(monday, 10), PlanBlockStatus.confirmed),
        block(2, 1, at(monday, 10, 30), at(monday, 11), PlanBlockStatus.done),
        block(3, 2, at(monday, 12), at(monday, 13), PlanBlockStatus.missed),
        block(4, 2, at(monday, 14), at(monday, 15), PlanBlockStatus.suggested),
        block(5, 2, at(monday, 16), at(monday, 17), PlanBlockStatus.dismissed),
        block(
          6,
          9,
          at(monday + 1, 9),
          at(monday + 1, 10),
          PlanBlockStatus.confirmed,
        ),
      ],
    );
    final tasks = [
      TaskEntry(
        task: Task(
          id: 1,
          title: '보고서',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          partialGoalMin: 60,
        ),
      ),
    ];
    final home = items(schedule, tasks: tasks).whereType<BlockItem>().toList();
    expect([for (final b in home) b.block.id], [1, 2, 3]);
    expect(home.first.entry!.task.title, '보고서');
    expect(home.first.partial, isTrue);
    expect(home[2].entry, isNull);
    expect(home[2].partial, isFalse);

    final day = items(
      schedule,
      tasks: tasks,
      includeSuggested: true,
    ).whereType<BlockItem>();
    expect([for (final b in day) b.block.id], [1, 2, 3, 4]);
  });

  test('LMS에서 사라진 할 일의 블록은 gone이다', () {
    final key = 'k';
    final schedule = Schedule(
      classSlots: const [],
      planBlocks: [
        block(1, 1, at(monday, 9), at(monday, 10), PlanBlockStatus.confirmed),
      ],
    );
    final tasks = [
      TaskEntry(
        task: Task(
          id: 1,
          title: '과제',
          kind: TaskKind.assignment,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
          lmsKey: key,
        ),
        lmsItem: LmsItem(
          id: 1,
          remoteKey: key,
          courseId: 1,
          courseName: '과목',
          title: '과제',
          kind: LmsItemKind.assignment,
          dueTimeUnknown: false,
          firstSeenAt: at(1, 9),
          lastSeenAt: at(1, 9),
          missCount: Defaults.lmsGoneMissCount,
          contentHash: key,
        ),
      ),
    ];
    expect(
      items(schedule, tasks: tasks).whereType<BlockItem>().single.gone,
      isTrue,
    );
  });

  test('같은 시각이면 수업 → 일정 → 고정 일정 → 블록 순서다', () {
    final schedule = Schedule(
      classSlots: [slot(9, weekday: 1, startMin: 540, endMin: 600)],
      events: [
        Event(
          id: 5,
          title: '겹친 일정',
          startAt: at(monday, 9),
          endAt: at(monday, 10),
          allDay: false,
          source: EventSource.manual,
        ),
      ],
      fixedBlocks: const [
        FixedBlock(
          id: 3,
          name: '겹친 고정',
          weekdays: [1],
          startMin: 540,
          endMin: 600,
          bufferMin: 0,
          kind: FixedBlockKind.other,
          source: EntrySource.manual,
        ),
      ],
      planBlocks: [
        block(1, 1, at(monday, 9), at(monday, 10), PlanBlockStatus.confirmed),
      ],
    );
    expect(describe(items(schedule)), [
      '수업 09:00–10:00',
      '일정 09:00–10:00',
      '고정 09:00–10:00',
      '블록 09:00–10:00',
    ]);
  });
}
