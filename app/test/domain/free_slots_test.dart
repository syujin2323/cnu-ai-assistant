import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
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
    int boundary = Defaults.dayBoundaryMin,
  }) => freeSlots(
    DateTime(2026, 10, day),
    schedule: schedule,
    config: PlannerConfig.from([...baseRules, if (!meals) noLunch, ...rules]),
    dayBoundaryMin: boundary,
  );

  DayAvailability availability(
    Schedule schedule, {
    List<Rule> rules = const [],
    int day = monday,
    bool meals = false,
    int boundary = Defaults.dayBoundaryMin,
    bool nightWindow = false,
  }) => dayAvailability(
    DateTime(2026, 10, day),
    schedule: schedule,
    config: PlannerConfig.from([...baseRules, if (!meals) noLunch, ...rules]),
    dayBoundaryMin: boundary,
    nightWindow: nightWindow,
  );

  Rule window(int startMin, int endMin, {List<int>? weekdays}) => rule(
    RuleKind.workWindow,
    RuleParams(startMin: startMin, endMin: endMin),
    weekdays: weekdays,
  );

  Rule blackout(int startMin, int endMin, {List<int>? weekdays}) => rule(
    RuleKind.blackout,
    RuleParams(startMin: startMin, endMin: endMin),
    id: 101,
    weekdays: weekdays,
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

    test('다른 수업 시간과 겹치는 이동은 놓지 않는다', () {
      // 14:00–15:00 대면 수업 바로 뒤 15:00–17:00 실시간 온라인 수업: 마지막 대면 수업 뒤의 이동은 놓지 않는다.
      final thenOnline = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 840, endMin: 900),
          classSlot(id: 2, startMin: 900, endMin: 1020, online: true),
        ],
      );
      final day = availability(
        thenOnline,
        rules: [travel(TravelPosition.dayEdges)],
      );
      expect(
        [
          for (final busy in day.busy)
            if (busy.kind == BusyKind.travel) busy.span,
        ],
        [span(at(monday, 13), at(monday, 14))],
      );
      // 온라인 수업이 30분 뒤에 시작해 이동(60분)과 일부만 겹쳐도 놓지 않는다.
      final gap = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 840, endMin: 900),
          classSlot(id: 2, startMin: 930, endMin: 1020, online: true),
        ],
      );
      expect(free(gap, rules: [travel(TravelPosition.dayEdges)]), [
        span(at(monday, 9), at(monday, 13)),
        span(at(monday, 15, 10), at(monday, 15, 30)),
        span(at(monday, 17), at(monday, 18)),
      ]);
      // 붙어 있는 대면 수업 사이의 이동(매 수업 앞뒤)도 놓지 않는다.
      final backToBack = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 600, endMin: 660),
          classSlot(id: 2, startMin: 660, endMin: 720),
        ],
      );
      expect(free(backToBack, rules: [travel(TravelPosition.everyClass)]), [
        span(at(monday, 13), at(monday, 18)),
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

    test('하루 첫 수업은 시작이 가장 이른 수업, 마지막 수업은 끝이 가장 늦은 수업이다', () {
      // 수 13:00–16:00 정규 수업에 월 14:00–15:00 수업의 보강이 겹친다. 마지막 이동은 늦게 시작한 보강이
      // 아니라 16:00에 끝나는 정규 수업 뒤에 건다.
      const wednesday = monday + 2;
      final schedule = Schedule(
        classSlots: [
          classSlot(
            id: 1,
            weekday: DateTime.wednesday,
            startMin: 780,
            endMin: 960,
          ),
          classSlot(id: 2, startMin: 840, endMin: 900),
        ],
        classExceptions: [
          ClassException(
            id: 1,
            date: '2026-10-$wednesday',
            classSlotId: 2,
            kind: ClassExceptionKind.makeup,
            source: EntrySource.manual,
          ),
        ],
      );
      expect(
        free(
          schedule,
          rules: [travel(TravelPosition.dayEdges)],
          day: wednesday,
        ),
        [
          span(at(wednesday, 9), at(wednesday, 12)),
          span(at(wednesday, 17), at(wednesday, 18)),
        ],
      );
    });

    test('시작이 같은 두 수업은 입력 순서와 관계없이 같은 결과다', () {
      final short = classSlot(id: 1, startMin: 840, endMin: 900);
      final long = classSlot(id: 2, startMin: 840, endMin: 960);
      for (final order in [
        [short, long],
        [long, short],
      ]) {
        expect(
          free(
            Schedule(classSlots: order),
            rules: [travel(TravelPosition.dayEdges)],
          ),
          [
            span(at(monday, 9), at(monday, 13)),
            span(at(monday, 17), at(monday, 18)),
          ],
          reason: '입력 순서 ${order.map((slot) => slot.id)}',
        );
      }
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

    test('하루 경계를 걸치는 하루 창은 경계에서 나눠 각 논리적 하루에 드는 조각을 모두 쓴다', () {
      // 02:00–10:00: 월 04:00–10:00과, 화요일 창의 화 02:00–04:00(월의 논리적 하루).
      expect(free(const Schedule(), rules: [window(120, 600)]), [
        span(at(monday, 4), at(monday, 10)),
        span(at(monday + 1, 2), at(monday + 1, 4)),
      ]);
      // 20:00–다음 날 09:20: 일요일 창의 월 04:00–09:20과, 월요일 창의 월 20:00–화 04:00.
      expect(free(const Schedule(), rules: [window(1200, 2000)]), [
        span(at(monday, 4), at(monday, 9, 20)),
        span(at(monday, 20), at(monday + 1, 4)),
      ]);
    });
  });

  group('규칙의 새벽 구간(실제 시각)', () {
    // docs/decisions.md 2026-11-14 '규칙의 시각 구간은 실제 시각으로 놓는다'.
    test('밤 12시–새벽 3시 하루 창은 그날 밤에 놓는다', () {
      expect(free(const Schedule(), rules: [window(0, 180)]), [
        span(at(monday + 1, 0), at(monday + 1, 3)),
      ]);
    });

    test('늦은 하루 창 끝의 새벽 피할 시간과 야식도 그날 밤에 건다', () {
      // 하루 창 20:00–02:00, 피할 시간 01:00–03:00, 야식 00:00–01:00 사이 30분.
      final snack = rule(
        RuleKind.meal,
        const RuleParams(startMin: 0, endMin: 60, minutes: 30),
        id: 102,
      );
      final rules = [window(1200, 1560), blackout(60, 180), snack];
      // 피할 시간이 01:00부터 막고, 야식은 남은 조각의 끝(00:30–01:00)에 붙는다.
      expect(free(const Schedule(), rules: rules), [
        span(at(monday, 20), at(monday + 1, 0, 30)),
      ]);
    });

    test('야식은 그 시간대가 놓인 날(다음 날 새벽)의 식사 고정 일정이 대신한다', () {
      // 하루 창 20:00–02:00, 야식 00:00–01:00 사이 30분, 화요일 00:00–00:20 식사 고정 일정.
      final snack = rule(
        RuleKind.meal,
        const RuleParams(startMin: 0, endMin: 60, minutes: 30),
        id: 102,
      );
      final lateSnack = FixedBlock(
        id: 1,
        name: '야식',
        weekdays: const [DateTime.tuesday],
        startMin: 0,
        endMin: 20,
        bufferMin: 0,
        kind: FixedBlockKind.meal,
        source: EntrySource.manual,
      );
      expect(
        free(
          Schedule(fixedBlocks: [lateSnack]),
          rules: [window(1200, 1560), snack],
        ),
        [
          span(at(monday, 20), at(monday + 1, 0)),
          span(at(monday + 1, 0, 20), at(monday + 1, 2)),
        ],
      );
    });

    test('하루 경계를 걸치는 식사 시간대는 시작하는 논리적 하루에서 한 번만 비운다', () {
      // 하루 창 02:00–10:00, 식사 03:00–05:00 사이 30분. 월 03:00에 시작하는 시간대는 일요일 몫이라
      // 월요일에는 화 03:00에 시작하는 시간대만 비운다(화 03:30–04:00).
      final meal = rule(
        RuleKind.meal,
        const RuleParams(startMin: 180, endMin: 300, minutes: 30),
        id: 102,
      );
      expect(free(const Schedule(), rules: [window(120, 600), meal]), [
        span(at(monday, 4), at(monday, 10)),
        span(at(monday + 1, 2), at(monday + 1, 3, 30)),
      ]);
    });

    test('요일을 고른 새벽 구간은 그 구간이 시작하는 달력일의 요일로 고른다', () {
      // '화요일 01:00–03:00 피할 시간'은 실제 화요일 새벽(월요일 논리적 하루의 끝)이다.
      final rules = [
        window(1200, 1560),
        blackout(60, 180, weekdays: [DateTime.tuesday]),
      ];
      expect(free(const Schedule(), rules: rules), [
        span(at(monday, 20), at(monday + 1, 1)),
      ]);
      // 화요일 논리적 하루의 끝(수요일 새벽)은 막지 않는다.
      expect(free(const Schedule(), rules: rules, day: monday + 1), [
        span(at(monday + 1, 20), at(monday + 2, 2)),
      ]);
    });

    test('전날 밤 시작해 자정을 넘는 피할 시간이 아침을 막는다', () {
      // 수면 23:00–10:00.
      expect(free(const Schedule(), rules: [blackout(1380, 2040)]), [
        span(at(monday, 10), at(monday, 18)),
      ]);
    });

    test('그 요일 하루 창이 모두 전날 몫이면 빈 시간이 없고, 결과는 고칠 수 있는 목록이다', () {
      // 월요일만 00:00–03:00. 그 시간(월 새벽)은 일요일 논리적 하루에 든다.
      final rules = [
        window(0, 180, weekdays: [DateTime.monday]),
      ];
      final mondaySlots = free(const Schedule(), rules: rules);
      expect(mondaySlots, isEmpty);
      mondaySlots.add(span(at(monday, 9), at(monday, 10)));
      expect(free(const Schedule(), rules: rules, day: monday - 1), [
        span(at(monday - 1, 9), at(monday - 1, 18)),
        span(at(monday, 0), at(monday, 3)),
      ]);
    });
  });

  group('하루 경계를 바꿀 때', () {
    test('경계 06:00이면 05:00–12:00 하루 창은 그날 06:00–12:00과 다음 날 05:00–06:00이다', () {
      expect(free(const Schedule(), rules: [window(300, 720)], boundary: 360), [
        span(at(monday, 6), at(monday, 12)),
        span(at(monday + 1, 5), at(monday + 1, 6)),
      ]);
    });

    test('경계 03:00이면 20:00–04:00 하루 창은 그날 03:00–04:00과 20:00–다음 날 03:00이다', () {
      expect(
        free(const Schedule(), rules: [window(1200, 1680)], boundary: 180),
        [
          span(at(monday, 3), at(monday, 4)),
          span(at(monday, 20), at(monday + 1, 3)),
        ],
      );
    });

    test('경계 전 새벽 수업은 전날 논리적 하루라 이동 시간을 걸지 않는다', () {
      // 경계 06:00, 하루 창 06:00–12:00, 월 05:30–06:30·10:00–11:00 대면 수업, day_edges 60분.
      final schedule = Schedule(
        classSlots: [
          classSlot(id: 1, startMin: 330, endMin: 390),
          classSlot(id: 2, startMin: 600, endMin: 660),
        ],
      );
      final rules = [
        window(360, 720),
        rule(
          RuleKind.travel,
          const RuleParams(minutes: 60, position: TravelPosition.dayEdges),
          id: 102,
        ),
      ];
      // 05:30 수업 뒤에는 여유 10분만, 이동은 10:00 수업 앞뒤에 건다.
      expect(free(schedule, rules: rules, boundary: 360), [
        span(at(monday, 6, 40), at(monday, 9)),
      ]);
    });

    test('하루 창과 이동 시간 모두 넘긴 경계로 나눈다', () {
      // 경계 06:00, 하루 창 05:00–12:00, 월 05:00–05:30 대면 수업, 여유 0분, day_edges 60분.
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 300, endMin: 330)],
      );
      final rules = [
        window(300, 720),
        rule(RuleKind.classBuffer, const RuleParams(minutes: 0), id: 102),
        rule(
          RuleKind.travel,
          const RuleParams(minutes: 60, position: TravelPosition.dayEdges),
          id: 103,
        ),
      ];
      // 05:00 수업은 일요일 논리적 하루라 월요일 하루 창에도 이동 시간에도 들지 않는다.
      expect(free(schedule, rules: rules, boundary: 360), [
        span(at(monday, 6), at(monday, 12)),
        span(at(monday + 1, 5), at(monday + 1, 6)),
      ]);
    });

    test('하루 경계가 0–1439 밖이면 수업이 없어도 RangeError다', () {
      expect(
        () => free(const Schedule(), boundary: -60),
        throwsA(isA<RangeError>()),
      );
      expect(
        () => free(const Schedule(), boundary: 1440),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('ruleSpansInLogicalDay', () {
    List<TimeSpan> spans(DateTime day, Map<int, List<MinuteRange>> byWeekday) =>
        ruleSpansInLogicalDay(
          day,
          dayBoundaryMin: Defaults.dayBoundaryMin,
          rangesFor: (weekday) => byWeekday[weekday] ?? const [],
        );

    test('요일은 구간이 시작하는 달력일이고 그 논리적 하루 안 조각만 돌려준다', () {
      // 배치 엔진의 선호 시간대도 이렇게 놓는다.
      final byWeekday = {
        DateTime.tuesday: const [MinuteRange(60, 180)],
      };
      expect(spans(DateTime(2026, 10, monday), byWeekday), [
        span(at(monday + 1, 1), at(monday + 1, 3)),
      ]);
      expect(spans(DateTime(2026, 10, monday + 1), byWeekday), isEmpty);
    });

    test('겹치거나 맞닿은 조각은 하나로 합친다', () {
      // 월 23:00–다음 날 01:00과 화 01:00–02:00, 화 01:30–03:00.
      final byWeekday = {
        DateTime.monday: const [MinuteRange(1380, 1500)],
        DateTime.tuesday: const [MinuteRange(60, 120), MinuteRange(90, 180)],
      };
      expect(spans(DateTime(2026, 10, monday), byWeekday), [
        span(at(monday, 23), at(monday + 1, 3)),
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

  group('dayAvailability', () {
    // docs/architecture.md '도메인 기본값과 배치 엔진' 1단계. 02 홈·09 일간·11 주간이 같은 결과를 쓴다.
    Rule travel(int minutes, TravelPosition position) => rule(
      RuleKind.travel,
      RuleParams(minutes: minutes, position: position),
      id: 102,
    );

    test('바쁜 구간마다 이유와 그 행의 id를 시작 순서로 담고, 빈 구간은 freeSlots와 같다', () {
      final schedule = Schedule(
        classSlots: [classSlot(startMin: 600, endMin: 660)],
        fixedBlocks: [fixedBlock(startMin: 780, endMin: 840, bufferMin: 15)],
        events: [event(at(monday, 15), at(monday, 15, 30))],
        planBlocks: [
          planBlock(
            at(monday, 17),
            at(monday, 17, 30),
            PlanBlockStatus.confirmed,
          ),
        ],
      );
      final rules = [travel(30, TravelPosition.dayEdges), blackout(960, 990)];
      final result = availability(schedule, rules: rules);

      expect(result.windows, [span(at(monday, 9), at(monday, 18))]);
      expect(result.busy, [
        BusySpan(
          span(at(monday, 9, 30), at(monday, 10)),
          BusyKind.travel,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 9, 50), at(monday, 10)),
          BusyKind.classBuffer,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 10), at(monday, 11)),
          BusyKind.classTime,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 11), at(monday, 11, 10)),
          BusyKind.classBuffer,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 11), at(monday, 11, 30)),
          BusyKind.travel,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 12, 45), at(monday, 13)),
          BusyKind.fixedBuffer,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 13), at(monday, 14)),
          BusyKind.fixedBlock,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 14), at(monday, 14, 15)),
          BusyKind.fixedBuffer,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 15), at(monday, 15, 30)),
          BusyKind.event,
          sourceId: 1,
        ),
        BusySpan(span(at(monday, 16), at(monday, 16, 30)), BusyKind.blackout),
        BusySpan(
          span(at(monday, 17), at(monday, 17, 30)),
          BusyKind.planBlock,
          sourceId: PlanBlockStatus.confirmed.index + 1,
        ),
      ]);
      final expectedFree = [
        span(at(monday, 9), at(monday, 9, 30)),
        span(at(monday, 11, 30), at(monday, 12, 45)),
        span(at(monday, 14, 15), at(monday, 15)),
        span(at(monday, 15, 30), at(monday, 16)),
        span(at(monday, 16, 30), at(monday, 17)),
        span(at(monday, 17, 30), at(monday, 18)),
      ];
      expect(result.free, expectedFree);
      expect(free(schedule, rules: rules), expectedFree);
    });

    test('이동 시간이 수업 앞뒤 여유보다 짧아도 이동은 실제 분만큼 담고, 빈 시간은 큰 값으로 뺀다', () {
      final result = availability(
        Schedule(classSlots: [classSlot(startMin: 600, endMin: 660)]),
        rules: [travel(5, TravelPosition.everyClass)],
      );
      expect(result.travel, [
        span(at(monday, 9, 55), at(monday, 10)),
        span(at(monday, 11), at(monday, 11, 5)),
      ]);
      expect(result.free, [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 11, 10), at(monday, 18)),
      ]);
    });

    test('식사로 비운 구간을 바쁜 구간과 meals에 담는다', () {
      final lunch = rule(
        RuleKind.meal,
        const RuleParams(startMin: 720, endMin: 840, minutes: 30),
        id: 103,
      );
      final result = availability(
        const Schedule(),
        rules: [lunch],
        meals: true,
      );
      final meal = span(at(monday, 12), at(monday, 12, 30));
      expect(result.meals, [meal]);
      expect(result.busy, [BusySpan(meal, BusyKind.meal)]);
      expect(result.free, [
        span(at(monday, 9), at(monday, 12)),
        span(at(monday, 12, 30), at(monday, 18)),
      ]);
    });

    test('하루 창 밖의 바쁜 구간도 담고, 논리적 하루에 걸친 것은 그 안으로 잘라 담는다', () {
      final result = availability(
        Schedule(
          classSlots: [classSlot(startMin: 420, endMin: 480, online: true)],
          events: [
            event(at(monday, 2), at(monday, 5)),
            event(at(monday + 1, 10), at(monday + 1, 11)),
          ],
        ),
      );
      expect(result.busy, [
        BusySpan(
          span(at(monday, 4), at(monday, 5)),
          BusyKind.event,
          sourceId: 1,
        ),
        BusySpan(
          span(at(monday, 7), at(monday, 8)),
          BusyKind.classTime,
          sourceId: 1,
        ),
      ]);
      expect(result.free, [span(at(monday, 9), at(monday, 18))]);
    });

    test('결과의 목록은 바꿀 수 없다', () {
      final result = availability(const Schedule());
      expect(() => result.free.clear(), throwsUnsupportedError);
      expect(() => result.windows.clear(), throwsUnsupportedError);
      expect(() => result.busy.clear(), throwsUnsupportedError);
    });
  });

  group('밤 시간 쓰기', () {
    // docs/architecture.md '도메인 기본값과 배치 엔진' 6단계. 하루 창 끝을 다음 날 01:00(임시)까지 늘린다.
    final nightEnd = at(monday + 1, 1);

    test('그날만 하루 창 끝을 다음 날 01:00까지 늘린다', () {
      final night = availability(const Schedule(), nightWindow: true);
      expect(night.windows, [span(at(monday, 9), nightEnd)]);
      expect(night.free, [span(at(monday, 9), nightEnd)]);
      expect(availability(const Schedule()).windows, [
        span(at(monday, 9), at(monday, 18)),
      ]);
      expect(Defaults.nightWindowEndMin, 1500);
    });

    test('하루 창이 01:00보다 늦게 끝나면 줄이지 않는다', () {
      final late = [window(600, 1560)];
      expect(
        availability(const Schedule(), rules: late, nightWindow: true).windows,
        [span(at(monday, 10), at(monday + 1, 2))],
      );
    });

    test('하루 경계 03:00에서도 01:00까지 열고, 늘린 밤에도 새벽 피할 시간이 걸린다', () {
      expect(
        availability(
          const Schedule(),
          boundary: 180,
          nightWindow: true,
        ).windows,
        [span(at(monday, 9), nightEnd)],
      );
      expect(
        availability(
          const Schedule(),
          rules: [blackout(0, 30)],
          nightWindow: true,
        ).free,
        [
          span(at(monday, 9), at(monday + 1, 0)),
          span(at(monday + 1, 0, 30), nightEnd),
        ],
      );
    });
  });

  group('보강 시각', () {
    // docs/architecture.md '도메인 기본값과 배치 엔진' 1단계: 보강은 저장된 보강 시각(없으면 평소 시각).
    const wednesday = monday + 2;

    ClassException exception(
      int day,
      ClassExceptionKind kind, {
      int id = 1,
      int? startMin,
      int? endMin,
    }) => ClassException(
      id: id,
      date: '2026-10-$day',
      classSlotId: 1,
      kind: kind,
      source: EntrySource.manual,
      startMin: startMin,
      endMin: endMin,
    );

    final usual = classSlot(startMin: 600, endMin: 660);

    test('저장된 보강 시각에 막는다', () {
      final result = availability(
        Schedule(
          classSlots: [usual],
          classExceptions: [
            exception(
              wednesday,
              ClassExceptionKind.makeup,
              startMin: 840,
              endMin: 900,
            ),
          ],
        ),
        day: wednesday,
      );
      expect(result.free, [
        span(at(wednesday, 9), at(wednesday, 13, 50)),
        span(at(wednesday, 15, 10), at(wednesday, 18)),
      ]);
      expect(result.busy.where((b) => b.kind == BusyKind.classTime), [
        BusySpan(
          span(at(wednesday, 14), at(wednesday, 15)),
          BusyKind.classTime,
          sourceId: 1,
        ),
      ]);
    });

    test('같은 날 휴강과 다른 시각 보강이 함께 있으면 보강 시각만 막는다', () {
      final schedule = Schedule(
        classSlots: [usual],
        classExceptions: [
          exception(monday, ClassExceptionKind.cancelled),
          exception(
            monday,
            ClassExceptionKind.makeup,
            id: 2,
            startMin: 960,
            endMin: 1020,
          ),
        ],
      );
      expect(free(schedule), [
        span(at(monday, 9), at(monday, 15, 50)),
        span(at(monday, 17, 10), at(monday, 18)),
      ]);
    });

    test('보강 날의 하루 첫 수업·마지막 수업 이동 시간은 보강 시각에 건다', () {
      final schedule = Schedule(
        classSlots: [usual],
        classExceptions: [
          exception(
            wednesday,
            ClassExceptionKind.makeup,
            startMin: 840,
            endMin: 900,
          ),
        ],
      );
      final travelRule = rule(
        RuleKind.travel,
        const RuleParams(minutes: 30, position: TravelPosition.dayEdges),
        id: 102,
      );
      expect(free(schedule, rules: [travelRule], day: wednesday), [
        span(at(wednesday, 9), at(wednesday, 13, 30)),
        span(at(wednesday, 15, 30), at(wednesday, 18)),
      ]);
    });

    test('평소 요일에 시각 없는 보강을 또 적어도 평소 시각에 한 번만 막는다', () {
      final result = availability(
        Schedule(
          classSlots: [usual],
          classExceptions: [exception(monday, ClassExceptionKind.makeup)],
        ),
      );
      expect(
        result.busy.where((b) => b.kind == BusyKind.classTime),
        hasLength(1),
      );
      expect(result.free, [
        span(at(monday, 9), at(monday, 9, 50)),
        span(at(monday, 11, 10), at(monday, 18)),
      ]);
    });
  });
}
