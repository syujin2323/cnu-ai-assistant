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
  // 식사 보호는 '식사 보호' 묶음에서만 보도록, 기본 점심을 0분으로 바꾼 규칙도 둔다([free]의 meals).
  final noLunch = rule(
    RuleKind.meal,
    const RuleParams(startMin: 690, endMin: 810, minutes: 0),
    id: 3,
  );
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
    bool meals = false,
  }) => freeSlots(
    DateTime(2026, 10, day),
    schedule: schedule,
    config: PlannerConfig.from([...baseRules, if (!meals) noLunch, ...rules]),
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

  test('일정이 없으면 기본 하루 창에서 기본 식사 시간만 뺀다', () {
    final slots = freeSlots(
      DateTime(2026, 10, monday, 15, 30),
      schedule: const Schedule(),
      config: PlannerConfig.from(const []),
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );
    // 하루 창 전체가 비어 있으면 식사는 식사 시간대의 시작에 둔다.
    DateTime minute(int value) => DateTime(2026, 10, monday, 0, value);
    expect(slots, [
      span(
        minute(Defaults.dayWindowStartMin),
        minute(Defaults.mealWindowStartMin),
      ),
      span(
        minute(Defaults.mealWindowStartMin + Defaults.mealMin),
        minute(Defaults.dayWindowEndMin),
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

    Rule travel(
      TravelPosition position, {
      int minutes = 60,
      List<int>? weekdays,
    }) => rule(
      RuleKind.travel,
      RuleParams(minutes: minutes, position: position),
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

    test('그 논리적 하루의 수업만 보므로 다음 날 첫 수업은 이날의 마지막 수업이 아니다', () {
      // 월 10:00–11:00, 화 09:00–10:00.
      final schedule = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 600, endMin: 660),
          classSlot(
            id: 2,
            weekday: DateTime.tuesday,
            startMin: 540,
            endMin: 600,
          ),
        ],
      );
      expect(free(schedule, rules: [travel(TravelPosition.dayEdges)]), [
        span(at(monday, 12), at(monday, 18)),
      ]);
    });

    test('하루 경계 전 새벽 수업은 전날 논리적 하루의 마지막 수업이다', () {
      // 하루 창 20:00–02:00. 월 21:00–22:00과 화 01:00–01:30은 월의 논리적 하루, 화 10:00–11:00은 화의
      // 논리적 하루다.
      final schedule = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 1260, endMin: 1320),
          classSlot(id: 2, weekday: DateTime.tuesday, startMin: 60, endMin: 90),
          classSlot(
            id: 3,
            weekday: DateTime.tuesday,
            startMin: 600,
            endMin: 660,
          ),
        ],
      );
      final rules = [
        rule(
          RuleKind.workWindow,
          const RuleParams(startMin: 1200, endMin: 1560),
        ),
        travel(TravelPosition.dayEdges, minutes: 30),
      ];
      expect(free(schedule, rules: rules), [
        span(at(monday, 20), at(monday, 20, 30)),
        span(at(monday, 22, 10), at(monday + 1, 0, 50)),
      ]);
    });

    test('이동 시간이 수업 앞뒤 여유보다 짧으면 여유를 쓴다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 660)],
      );
      expect(
        free(schedule, rules: [travel(TravelPosition.dayEdges, minutes: 5)]),
        [
          span(at(monday, 9), at(monday, 9, 50)),
          span(at(monday, 11, 10), at(monday, 18)),
        ],
      );
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
      // 일정 21:30–다음 날 00:10, 고정 일정 23:00–다음 날 01:00. 일정을 빼지 않거나 고정 일정을 24:00에서
      // 자르면 결과가 달라진다.
      final schedule = Schedule(
        fixedBlocks: [fixedBlock(startMin: 1380, endMin: 1500)],
        events: [event(at(monday, 21, 30), at(monday + 1, 0, 10))],
      );
      expect(free(schedule, rules: lateWindow), [
        span(at(monday, 20), at(monday, 21, 30)),
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

  group('식사 보호', () {
    // 점심 11:30–13:30 사이 40분.
    final lunch = rule(
      RuleKind.meal,
      const RuleParams(startMin: 690, endMin: 810, minutes: 40),
    );

    List<TimeSpan> withLunch(
      Schedule schedule, {
      List<Rule> rules = const [],
    }) => free(schedule, rules: [lunch, ...rules], meals: true);

    test('시간대 양쪽이 트여 있으면 시간대 시작에 둔다', () {
      expect(withLunch(const Schedule()), [
        span(at(monday, 9), at(monday, 11, 30)),
        span(at(monday, 12, 10), at(monday, 18)),
      ]);
    });

    test('시간대 안에서 수업이 끝나면 수업 직후에 둔다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 720)],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 12, 50), at(monday, 18)),
      ]);
    });

    test('시간대 안에서 수업이 시작하면 수업 직전에 둔다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 780, endMin: 900)],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 12, 10)),
        span(at(monday, 15, 10), at(monday, 18)),
      ]);
    });

    test('식사 시간이 들어갈 조각이 없으면 가장 긴 조각을 비운다', () {
      // 11:00–12:00, 12:30–14:00 수업 사이에 10분만 빈다.
      final schedule = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 660, endMin: 720),
          classSlot(id: 2, startMin: 750, endMin: 840),
        ],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 10, 50)),
        span(at(monday, 14, 10), at(monday, 18)),
      ]);
    });

    test('점심을 거르는 날: 시간대에 빈 조각이 없으면 비울 것이 없다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 660, endMin: 840)],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 10, 50)),
        span(at(monday, 14, 10), at(monday, 18)),
      ]);
    });

    test('그날 겹치는 식사 고정 일정이 있으면 고정 일정이 대신한다', () {
      FixedBlock lunchBlock(int weekday) => FixedBlock(
        id: 1,
        name: '점심',
        weekdays: [weekday],
        startMin: 720,
        endMin: 750,
        bufferMin: 0,
        kind: FixedBlockKind.meal,
        source: EntrySource.manual,
      );
      expect(withLunch(Schedule(fixedBlocks: [lunchBlock(DateTime.monday)])), [
        span(at(monday, 9), at(monday, 12)),
        span(at(monday, 12, 30), at(monday, 18)),
      ]);
      // 다른 요일의 식사 고정 일정은 이날의 식사를 대신하지 않는다.
      expect(withLunch(Schedule(fixedBlocks: [lunchBlock(DateTime.tuesday)])), [
        span(at(monday, 9), at(monday, 11, 30)),
        span(at(monday, 12, 10), at(monday, 18)),
      ]);
    });

    test('식사 시간대와 겹치지 않는 식사 고정 일정은 점심을 대신하지 않는다', () {
      final dinnerBlock = FixedBlock(
        id: 1,
        name: '저녁',
        weekdays: const [DateTime.monday],
        startMin: 1080,
        endMin: 1140,
        bufferMin: 0,
        kind: FixedBlockKind.meal,
        source: EntrySource.manual,
      );
      expect(withLunch(Schedule(fixedBlocks: [dinnerBlock])), [
        span(at(monday, 9), at(monday, 11, 30)),
        span(at(monday, 12, 10), at(monday, 18)),
      ]);
    });

    test('식사 시간이 들어가는 조각이 여럿이면 가장 긴 조각이 아니라 가장 이른 조각에 둔다', () {
      // 시간대 안의 빈 조각은 11:30–12:15(45분)와 12:35–13:30(55분)이다.
      final schedule = Schedule(
        events: [
          event(at(monday, 11), at(monday, 11, 30)),
          event(at(monday, 12, 15), at(monday, 12, 35)),
          event(at(monday, 13, 30), at(monday, 14)),
        ],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 11)),
        span(at(monday, 12, 10), at(monday, 12, 15)),
        span(at(monday, 12, 35), at(monday, 13, 30)),
        span(at(monday, 14), at(monday, 18)),
      ]);
    });

    test('식사 시간이 들어가는 조각이 없으면 앞 조각이 아니라 가장 긴 조각을 통째로 비운다', () {
      // 시간대 안의 빈 조각은 11:30–11:40(10분)과 12:30–13:00(30분)이다.
      final schedule = Schedule(
        events: [
          event(at(monday, 11), at(monday, 11, 30)),
          event(at(monday, 11, 40), at(monday, 12, 30)),
          event(at(monday, 13), at(monday, 14)),
        ],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 11)),
        span(at(monday, 11, 30), at(monday, 11, 40)),
        span(at(monday, 14), at(monday, 18)),
      ]);
    });

    test('양쪽이 바쁜 시간대 안의 빈 조각에서는 앞 수업 직후에 둔다', () {
      // 10:00–11:30, 13:30–15:00 수업 사이 11:40–13:20이 빈다.
      final schedule = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 600, endMin: 690),
          classSlot(id: 2, startMin: 810, endMin: 900),
        ],
      );
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 12, 20), at(monday, 13, 20)),
        span(at(monday, 15, 10), at(monday, 18)),
      ]);
    });

    test('식사가 아닌 고정 일정은 식사를 대신하지 않는다', () {
      final schedule = Schedule(
        fixedBlocks: [fixedBlock(startMin: 720, endMin: 750)],
      );
      // 11:30–12:00(30분)에는 들어가지 않으므로 알바 직후 12:30–13:10에 둔다.
      expect(withLunch(schedule), [
        span(at(monday, 9), at(monday, 12)),
        span(at(monday, 13, 10), at(monday, 18)),
      ]);
    });

    test('저녁 규칙은 점심에 더해 비우고, 하루 창 끝에 붙어 있으면 끝에 둔다', () {
      final dinner = rule(
        RuleKind.meal,
        const RuleParams(startMin: 1020, endMin: 1140, minutes: 40),
        id: 101,
      );
      // 시간대 안의 빈 조각 17:00–18:00(60분)이 하루 창 끝에 붙어 있으므로 17:20–18:00을 비운다.
      expect(withLunch(const Schedule(), rules: [dinner]), [
        span(at(monday, 9), at(monday, 11, 30)),
        span(at(monday, 12, 10), at(monday, 17, 20)),
      ]);
    });
  });
}
