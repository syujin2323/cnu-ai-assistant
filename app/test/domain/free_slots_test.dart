import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-12는 월요일이다. 날짜는 10월의 일(日)로, 시각은 그날 0시 기준 분으로 적는다.
  const monday = 12;

  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  TimeSpan span(DateTime start, DateTime end) => TimeSpan(start, end);

  // 저장 시각이 같으므로 id가 큰 규칙이 나중에 저장한 것이다. 각 테스트의 규칙(기본 100)이
  // 아래 기본 규칙(1, 2)을 덮는다.
  Rule rule(
    RuleKind kind,
    RuleParams params, {
    int id = 100,
    List<int>? weekdays,
  }) {
    final at = DateTime(2026, 10, 1);
    return Rule(
      id: id,
      kind: kind,
      params: params,
      weekdays: weekdays,
      active: true,
      source: EntrySource.manual,
      createdAt: at,
      updatedAt: at,
    );
  }

  // 기본값(임시값)이 바뀌어도 기대값이 그대로이도록 하루 창 09:00–18:00, 수업 여유 10분을 규칙으로 둔다.
  final baseRules = [
    rule(
      RuleKind.workWindow,
      const RuleParams(startMin: 540, endMin: 1080),
      id: 1,
    ),
    rule(RuleKind.classBuffer, const RuleParams(minutes: 10), id: 2),
  ];

  List<TimeSpan> free(
    Schedule schedule, {
    List<Rule> rules = const [],
    int day = monday,
  }) => freeSlots(
    DateTime(2026, 10, day),
    schedule: schedule,
    config: PlannerConfig.from([...baseRules, ...rules]),
    dayBoundaryMin: Defaults.dayBoundaryMin,
  );

  ClassSlot classSlot({
    int id = 1,
    int weekday = DateTime.monday,
    required int startMin,
    required int endMin,
    bool online = false,
  }) => ClassSlot(
    id: id,
    courseId: id,
    weekday: weekday,
    startMin: startMin,
    endMin: endMin,
    campus: Campus.daedeok,
    online: online,
    source: SlotSource.manual,
  );

  FixedBlock fixedBlock({
    List<int> weekdays = const [DateTime.monday],
    required int startMin,
    required int endMin,
    int bufferMin = 0,
  }) => FixedBlock(
    id: 1,
    name: '알바',
    weekdays: weekdays,
    startMin: startMin,
    endMin: endMin,
    bufferMin: bufferMin,
    kind: FixedBlockKind.work,
    source: EntrySource.manual,
  );

  Event event(DateTime start, DateTime end, {bool allDay = false}) => Event(
    id: 1,
    title: '회의',
    startAt: start,
    endAt: end,
    allDay: allDay,
    source: EventSource.manual,
  );

  PlanBlock planBlock(DateTime start, DateTime end, PlanBlockStatus status) =>
      PlanBlock(
        id: status.index + 1,
        taskId: 1,
        startAt: start,
        endAt: end,
        status: status,
        source: BlockSource.auto,
      );

  test('일정이 없으면 기본 하루 창 전체가 빈 시간이다', () {
    final slots = freeSlots(
      DateTime(2026, 10, monday, 15, 30),
      schedule: const Schedule(),
      config: PlannerConfig.from(const []),
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );
    expect(slots, [
      span(
        DateTime(2026, 10, monday, 0, Defaults.dayWindowStartMin),
        DateTime(2026, 10, monday, 0, Defaults.dayWindowEndMin),
      ),
    ]);
  });

  group('수업', () {
    test('수업과 앞뒤 여유를 뺀다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 675)],
      );
      expect(free(schedule), [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 11, 25), at(monday, 18)),
      ]);
    });

    test('실시간 비대면 수업은 여유를 두지 않는다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 660, online: true)],
      );
      expect(free(schedule), [
        span(at(monday, 9), at(monday, 10)),
        span(at(monday, 11), at(monday, 18)),
      ]);
    });

    test('다른 요일의 수업은 빼지 않는다', () {
      final schedule = Schedule(
        classSlots: [
          classSlot(weekday: DateTime.tuesday, startMin: 600, endMin: 660),
        ],
      );
      expect(free(schedule), [span(at(monday, 9), at(monday, 18))]);
    });

    test('휴강한 날은 빼지 않고, 보강은 요일이 달라도 그 날짜에 뺀다', () {
      const wednesday = monday + 2;
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 660)],
        classExceptions: [
          ClassException(
            id: 1,
            date: '2026-10-$monday',
            classSlotId: 1,
            kind: ClassExceptionKind.cancelled,
            source: EntrySource.manual,
          ),
          ClassException(
            id: 2,
            date: '2026-10-$wednesday',
            classSlotId: 1,
            kind: ClassExceptionKind.makeup,
            source: EntrySource.manual,
          ),
        ],
      );
      expect(free(schedule), [span(at(monday, 9), at(monday, 18))]);
      expect(free(schedule, day: wednesday), [
        span(at(wednesday, 9), at(wednesday, 9, 50)),
        span(at(wednesday, 11, 10), at(wednesday, 18)),
      ]);
    });
  });

  group('이동 시간', () {
    // 10:00–11:00, 14:00–15:00 대면 수업.
    final twoClasses = Schedule(
      classSlots: [
        classSlot(id: 1, startMin: 600, endMin: 660),
        classSlot(id: 2, startMin: 840, endMin: 900),
      ],
    );

    Rule travel(TravelPosition position, {List<int>? weekdays}) => rule(
      RuleKind.travel,
      RuleParams(minutes: 60, position: position),
      weekdays: weekdays,
    );

    test('하루 첫 수업 전과 마지막 수업 뒤에만 걸고, 여유와 겹치면 큰 값을 쓴다', () {
      expect(free(twoClasses, rules: [travel(TravelPosition.dayEdges)]), [
        span(at(monday, 11, 10), at(monday, 13, 50)),
        span(at(monday, 16), at(monday, 18)),
      ]);
    });

    test('매 수업 앞뒤에 건다', () {
      expect(free(twoClasses, rules: [travel(TravelPosition.everyClass)]), [
        span(at(monday, 12), at(monday, 13)),
        span(at(monday, 16), at(monday, 18)),
      ]);
    });

    test('실시간 비대면 수업만 있는 날은 쓰지 않는다', () {
      final online = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 660, online: true)],
      );
      expect(free(online, rules: [travel(TravelPosition.everyClass)]), [
        span(at(monday, 9), at(monday, 10)),
        span(at(monday, 11), at(monday, 18)),
      ]);
    });

    test('규칙의 요일이 아니면 쓰지 않는다', () {
      final rules = [
        travel(TravelPosition.dayEdges, weekdays: [DateTime.tuesday]),
      ];
      expect(free(twoClasses, rules: rules), [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 11, 10), at(monday, 13, 50)),
        span(at(monday, 15, 10), at(monday, 18)),
      ]);
    });
  });

  test('피할 시간을 뺀다', () {
    final rules = [
      rule(RuleKind.blackout, const RuleParams(startMin: 720, endMin: 780)),
    ];
    expect(free(const Schedule(), rules: rules), [
      span(at(monday, 9), at(monday, 12)),
      span(at(monday, 13), at(monday, 18)),
    ]);
  });

  test('고정 일정과 앞뒤 여유를 뺀다', () {
    final schedule = Schedule(
      fixedBlocks: [fixedBlock(startMin: 780, endMin: 840, bufferMin: 15)],
    );
    expect(free(schedule), [
      span(at(monday, 9), at(monday, 12, 45)),
      span(at(monday, 14, 15), at(monday, 18)),
    ]);
  });

  test('일정을 빼고 종일 일정은 시간을 막지 않는다', () {
    final schedule = Schedule(
      events: [
        event(at(monday, 15), at(monday, 16, 30)),
        event(at(monday, 0), at(monday + 1, 0), allDay: true),
      ],
    );
    expect(free(schedule), [
      span(at(monday, 9), at(monday, 15)),
      span(at(monday, 16, 30), at(monday, 18)),
    ]);
  });

  test('확정·완료 블록만 빼고 제안·놓침·지운 블록은 빼지 않는다', () {
    final schedule = Schedule(
      planBlocks: [
        planBlock(at(monday, 10), at(monday, 11), PlanBlockStatus.confirmed),
        planBlock(at(monday, 13), at(monday, 14), PlanBlockStatus.done),
        planBlock(at(monday, 15), at(monday, 16), PlanBlockStatus.suggested),
        planBlock(at(monday, 16), at(monday, 17), PlanBlockStatus.missed),
        planBlock(at(monday, 9), at(monday, 10), PlanBlockStatus.dismissed),
      ],
    );
    expect(free(schedule), [
      span(at(monday, 9), at(monday, 10)),
      span(at(monday, 11), at(monday, 13)),
      span(at(monday, 14), at(monday, 18)),
    ]);
  });

  test('겹치는 바쁜 시간은 한 번만 뺀다', () {
    final schedule = Schedule(
      classSlots: [classSlot(startMin: 600, endMin: 720)],
      events: [event(at(monday, 11), at(monday, 13))],
    );
    expect(free(schedule), [
      span(at(monday, 9), at(monday, 9, 50)),
      span(at(monday, 13), at(monday, 18)),
    ]);
  });

  test('빈 시간이 없으면 빈 목록이다', () {
    final schedule = Schedule(events: [event(at(monday, 8), at(monday, 19))]);
    expect(free(schedule), isEmpty);
  });

  test('15분씩 쪼개진 빈 시간도 그대로 돌려준다', () {
    // 09:15부터 30분 일정과 15분 빈 시간이 번갈아 온다.
    final schedule = Schedule(
      events: [
        for (var start = 555; start < 1080; start += 45)
          event(at(monday, 0, start), at(monday, 0, start + 30)),
      ],
    );
    final slots = free(schedule);
    expect(slots, hasLength(12));
    expect(slots.every((slot) => slot.minutes == 15), isTrue);
    expect(slots.first, span(at(monday, 9), at(monday, 9, 15)));
  });

  group('자정을 넘는 일정', () {
    // 하루 창 20:00–02:00(다음 날).
    final lateWindow = [
      rule(RuleKind.workWindow, const RuleParams(startMin: 1200, endMin: 1560)),
    ];

    test('자정을 넘는 고정 일정과 일정을 뺀다', () {
      final schedule = Schedule(
        fixedBlocks: [fixedBlock(startMin: 1320, endMin: 1410)],
        events: [event(at(monday, 23, 50), at(monday + 1, 1))],
      );
      expect(free(schedule, rules: lateWindow), [
        span(at(monday, 20), at(monday, 22)),
        span(at(monday, 23, 30), at(monday, 23, 50)),
        span(at(monday + 1, 1), at(monday + 1, 2)),
      ]);
    });

    test('전날 시작해 자정을 넘은 고정 일정도 뺀다', () {
      // 일요일 22:00–다음 날 09:30 밤샘 알바.
      final schedule = Schedule(
        fixedBlocks: [
          fixedBlock(
            weekdays: [DateTime.sunday],
            startMin: 1320,
            endMin: 1440 + 570,
          ),
        ],
      );
      expect(free(schedule), [span(at(monday, 9, 30), at(monday, 18))]);
    });

    test('하루 창이 논리적 하루를 넘으면 그 하루 안으로 자른다', () {
      final early = [
        rule(RuleKind.workWindow, const RuleParams(startMin: 120, endMin: 600)),
      ];
      expect(free(const Schedule(), rules: early), [
        span(
          DateTime(2026, 10, monday, 0, Defaults.dayBoundaryMin),
          at(monday, 10),
        ),
      ]);

      final late = [
        rule(
          RuleKind.workWindow,
          const RuleParams(startMin: 1200, endMin: 2000),
        ),
      ];
      expect(free(const Schedule(), rules: late), [
        span(
          at(monday, 20),
          DateTime(2026, 10, monday + 1, 0, Defaults.dayBoundaryMin),
        ),
      ]);
    });
  });
}
