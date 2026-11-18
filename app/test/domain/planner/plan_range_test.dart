// 배치 엔진(planRange) 테스트. docs/architecture.md '도메인 기본값과 배치 엔진'의 테스트 케이스와
// docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)'.
//
// 기본값(임시값)이 바뀌어도 기대값이 그대로이도록 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분(식사 보호는
// 점심 테스트에서만)을 규칙으로 둔다. 2026-11-16은 월요일이고, 지금은 그날 08:00이다. 시간표가 있어야 배치하므로
// 기본으로 일요일 09:00–10:00 수업 하나를 둔다(평일 빈 시간을 막지 않음).

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-[day] [hour]:[minute].
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const monday = 16;

Rule rule(
  RuleKind kind,
  RuleParams params, {
  int id = 100,
  List<int>? weekdays,
  bool active = true,
}) {
  final when = DateTime(2026, 11, 1);
  return Rule(
    id: id,
    kind: kind,
    params: params,
    weekdays: weekdays,
    active: active,
    source: EntrySource.manual,
    createdAt: when,
    updatedAt: when,
  );
}

final baseRules = [
  rule(
    RuleKind.workWindow,
    const RuleParams(startMin: 540, endMin: 1080),
    id: 1,
  ),
  rule(RuleKind.classBuffer, const RuleParams(minutes: 10), id: 2),
];
final noLunch = rule(
  RuleKind.meal,
  const RuleParams(startMin: 690, endMin: 810, minutes: 0),
  id: 3,
);

ClassSlot slot(
  int id, {
  int courseId = 1,
  required int weekday,
  required int startMin,
  required int endMin,
  bool online = false,
}) => ClassSlot(
  id: id,
  courseId: courseId,
  weekday: weekday,
  startMin: startMin,
  endMin: endMin,
  place: online ? null : '공학관 201',
  online: online,
  source: SlotSource.manual,
);

final sundayClass = slot(
  900,
  courseId: 9,
  weekday: DateTime.sunday,
  startMin: 540,
  endMin: 600,
);

Task task(
  int id, {
  TaskKind kind = TaskKind.assignment,
  DateTime? due,
  int? estimate,
  int? spent,
  int? courseId,
  String? lmsKey,
  TaskStatus status = TaskStatus.todo,
  int? partialGoal,
  String? nightFrom,
  String? deferredUntil,
}) => Task(
  id: id,
  title: '할 일 $id',
  kind: kind,
  dueAt: due,
  dueTimeUnknown: false,
  estimateMin: estimate,
  spentMin: spent,
  status: status,
  lmsKey: lmsKey,
  courseId: courseId,
  partialGoalMin: partialGoal,
  nightWindowFrom: nightFrom,
  deferredUntil: deferredUntil,
);

/// LMS 할 일([task]와 그 원본).
TaskEntry lms(
  int id, {
  LmsItemKind kind = LmsItemKind.assignment,
  required DateTime due,
  int courseId = 1,
  DateTime? openAt,
  int? videoMin,
  int? requiredMin,
  bool? submitted,
  bool? officiallyDone,
  int missCount = 0,
  int? estimate,
  int? spent,
}) {
  final key = 'k:$id';
  return TaskEntry(
    task: task(
      id,
      kind: TaskKind.values.byName(kind.name),
      due: due,
      lmsKey: key,
      estimate: estimate,
      spent: spent,
    ),
    lmsItem: LmsItem(
      id: id,
      remoteKey: key,
      courseId: courseId,
      courseName: '과목 $courseId',
      title: '할 일 $id',
      kind: kind,
      dueAt: due,
      dueTimeUnknown: false,
      openAt: openAt,
      videoMin: videoMin,
      requiredMin: requiredMin,
      submitted: submitted,
      officiallyDone: officiallyDone,
      firstSeenAt: at(1, 9),
      lastSeenAt: at(1, 9),
      missCount: missCount,
      contentHash: key,
    ),
  );
}

PlanBlock block(
  int id,
  int taskId,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
  BlockSource source = BlockSource.manual,
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: source,
);

Schedule scheduleOf({
  List<ClassSlot>? slots,
  List<ClassException> exceptions = const [],
  List<FixedBlock> fixed = const [],
  List<Event> events = const [],
  List<PlanBlock> blocks = const [],
}) => Schedule(
  classSlots: slots ?? [sundayClass],
  classExceptions: exceptions,
  fixedBlocks: fixed,
  events: events,
  planBlocks: blocks,
);

PlannerConfig configOf(List<Rule> rules, {bool lunch = false}) =>
    PlannerConfig.from([...baseRules, if (!lunch) noLunch, ...rules]);

PlanResult plan(
  List<TaskEntry> tasks, {
  Schedule? schedule,
  List<Rule> rules = const [],
  bool lunch = false,
  DateTime? now,
  int days = Defaults.planHorizonDays,
}) {
  final when = now ?? at(monday, 8);
  return planRange(
    now: when,
    from: logicalDate(when, dayBoundaryMin: Defaults.dayBoundaryMin),
    days: days,
    schedule: schedule ?? scheduleOf(),
    tasks: tasks,
    config: configOf(rules, lunch: lunch),
    dayBoundaryMin: Defaults.dayBoundaryMin,
  );
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 블록을 '할 일 id 날 시작–끝' 꼴로.
List<String> describe(PlanResult result) => [
  for (final b in result.blocks)
    '${b.taskId} ${b.startAt.day} ${_hhmm(b.startAt)}–${_hhmm(b.endAt)}',
];

/// 할 일마다 놓은 분의 합.
Map<int, int> placedMinutes(PlanResult result) {
  final minutes = <int, int>{};
  for (final b in result.blocks) {
    minutes[b.taskId] =
        (minutes[b.taskId] ?? 0) + b.endAt.difference(b.startAt).inMinutes;
  }
  return minutes;
}

/// 어느 계획이든 지켜야 하는 것을 본다: 빈 시간 안(제안·지운 블록을 뺀 일정으로 계산), 지금 뒤, 마감 전,
/// 시작은 5분 단위, 길이는 최대 조각 이하, 블록 사이와 확정·완료 블록과 15분 이상, 근거가 있음.
void expectSound(
  PlanResult result, {
  required Schedule schedule,
  required PlannerConfig config,
  required DateTime now,
  required List<TaskEntry> tasks,
}) {
  final dues = {for (final e in tasks) e.task.id: e.task.dueAt};
  final busyFree = Schedule(
    classSlots: schedule.classSlots,
    classExceptions: schedule.classExceptions,
    fixedBlocks: schedule.fixedBlocks,
    events: schedule.events,
    planBlocks: [
      for (final b in schedule.planBlocks)
        if (b.status == PlanBlockStatus.confirmed ||
            b.status == PlanBlockStatus.done)
          b,
    ],
  );
  final study = [
    for (final b in busyFree.planBlocks) TimeSpan(b.startAt, b.endAt),
  ];
  final placed = <TimeSpan>[];
  for (final b in result.blocks) {
    final span = TimeSpan(b.startAt, b.endAt);
    final day = logicalDate(b.startAt, dayBoundaryMin: Defaults.dayBoundaryMin);
    final free = dayAvailability(
      day,
      schedule: busyFree,
      config: config,
      dayBoundaryMin: Defaults.dayBoundaryMin,
      nightWindow: true,
    ).free;
    expect(
      free.any(
        (f) => !span.start.isBefore(f.start) && !span.end.isAfter(f.end),
      ),
      isTrue,
      reason: '빈 시간 안: $span',
    );
    expect(span.start.isBefore(now), isFalse, reason: '지금 뒤: $span');
    expect(span.end.isAfter(dues[b.taskId]!), isFalse, reason: '마감 전: $span');
    expect(span.start.minute % 5, 0, reason: '5분 단위: $span');
    expect(span.minutes, lessThanOrEqualTo(config.maxBlockMin));
    expect(b.source, BlockSource.auto);
    expect(b.reason, isNotNull);
    for (final other in [...placed, ...study]) {
      final apart = span.start.isAfter(other.start)
          ? span.start.difference(other.end)
          : other.start.difference(span.end);
      expect(
        apart.inMinutes,
        greaterThanOrEqualTo(Defaults.blockGapMin),
        reason: '블록 사이 15분: $span, $other',
      );
    }
    placed.add(span);
  }
}

void main() {
  test('시간표가 없으면 아무것도 놓지 않는다', () {
    final result = plan([
      lms(1, due: at(monday + 2, 23, 59)),
    ], schedule: scheduleOf(slots: const []));
    expect(result.blocks, isEmpty);
    expect(result.shortages, isEmpty);
    expect(result.ranked, isEmpty);
  });

  test('남은 할 일만 놓는다: 마감 없음·마감 지남·지평 밖·끝냄·LMS 제출·출석 인정·사라진 일은 빼고, 날짜 1이 아니면 ArgumentError다', () {
    final result = plan([
      TaskEntry(task: task(1, kind: TaskKind.personal)),
      lms(2, due: at(monday, 7)),
      lms(3, due: at(monday + 14, 12)),
      TaskEntry(
        task: task(4, due: at(monday + 2, 18), status: TaskStatus.done),
      ),
      lms(5, due: at(monday + 2, 18), submitted: true),
      lms(
        6,
        kind: LmsItemKind.video,
        due: at(monday + 2, 18),
        officiallyDone: true,
      ),
      lms(7, due: at(monday + 2, 18), missCount: Defaults.lmsGoneMissCount),
      lms(8, due: at(monday + 2, 18)),
    ]);
    expect(placedMinutes(result), {8: 60});
    expect(result.ranked, [8]);
    expect(
      () => planRange(
        now: at(monday, 8),
        from: at(monday, 0),
        days: 0,
        schedule: scheduleOf(),
        tasks: const [],
        config: configOf(const []),
        dayBoundaryMin: Defaults.dayBoundaryMin,
      ),
      throwsArgumentError,
    );
  });

  test(
    '예상 시간: 할 일의 값 → 예상 시간 규칙 → 종류별 기본값(과제 60·퀴즈 30·팀플 120·개인 60)이고 한 만큼은 뺀다',
    () {
      final due = at(monday + 4, 23, 59);
      final result = plan(
        [
          lms(1, due: due),
          lms(2, kind: LmsItemKind.quiz, due: due),
          lms(3, kind: LmsItemKind.team, due: due),
          TaskEntry(
            task: task(4, kind: TaskKind.personal, due: due),
          ),
          lms(5, due: due, estimate: 90),
          lms(6, due: due, courseId: 2),
          lms(7, due: due, spent: 20),
        ],
        rules: [
          rule(
            RuleKind.estimate,
            const RuleParams(
              courseId: 2,
              taskKind: TaskKind.assignment,
              minutes: 150,
            ),
          ),
        ],
      );
      expect(placedMinutes(result), {
        1: 60,
        2: 30,
        3: 120,
        4: 60,
        5: 90,
        6: 150,
        7: 40,
      });
    },
  );

  test('예상 시간을 모르는 토론·시험은 놓지 않고, 할 일의 값이나 규칙이 있으면 놓는다', () {
    final due = at(monday + 4, 23, 59);
    final result = plan(
      [
        lms(1, kind: LmsItemKind.discussion, due: due),
        lms(2, kind: LmsItemKind.exam, due: due),
        lms(3, kind: LmsItemKind.discussion, due: due, estimate: 45),
        lms(4, kind: LmsItemKind.exam, due: due),
      ],
      rules: [
        rule(
          RuleKind.estimate,
          const RuleParams(taskKind: TaskKind.exam, minutes: 180),
        ),
      ],
    );
    expect(placedMinutes(result), {2: 180, 3: 45, 4: 180});
  });

  test('영상은 인정 시간 전체, 없으면 영상 길이, 둘 다 없으면 30분이고 한 만큼은 빼지 않는다', () {
    final due = at(monday + 4, 23, 59);
    final result = plan([
      lms(1, kind: LmsItemKind.video, due: due, videoMin: 52, requiredMin: 45),
      lms(2, kind: LmsItemKind.video, due: due, videoMin: 52),
      lms(3, kind: LmsItemKind.video, due: due),
      lms(4, kind: LmsItemKind.video, due: due, requiredMin: 40, spent: 30),
    ]);
    expect(placedMinutes(result), {1: 45, 2: 52, 3: 30, 4: 40});
  });

  test('공개 전 영상은 공개 뒤에만 놓는다', () {
    final result = plan([
      lms(
        1,
        kind: LmsItemKind.video,
        due: at(monday + 4, 23, 59),
        openAt: at(monday + 2, 13, 2),
        requiredMin: 40,
      ),
    ]);
    expect(describe(result), ['1 18 13:05–13:45']);
  });

  test('아직 끝나지 않은 확정 블록만큼 덜 놓고, 끝난 확정 블록은 빼지 않는다', () {
    final schedule = scheduleOf(
      blocks: [
        block(1, 1, at(monday, 7), at(monday, 7, 30)),
        block(2, 1, at(monday + 1, 9), at(monday + 1, 9, 30)),
      ],
    );
    final result = plan([
      lms(1, due: at(monday + 4, 23, 59), estimate: 90),
    ], schedule: schedule);
    expect(placedMinutes(result), {1: 60});
  });

  test('마감 12시간 전까지 끝나게 놓고, 그 안에 다 들어가지 않을 때만 그 여유에도 놓는다', () {
    // 화요일 22:00 마감 → 12시간 전은 화요일 10:00. 월요일 09:00–18:00이 비어 있다.
    final early = plan([lms(1, due: at(monday + 1, 22), estimate: 60)]);
    expect(describe(early), ['1 16 09:00–10:00']);

    // 월요일을 막으면 화요일 09:00–10:00에 들어가지 않으므로 그 여유(10:00–18:00)도 쓴다.
    final busyMonday = scheduleOf(
      events: [
        Event(
          id: 1,
          title: '종일 행사',
          startAt: at(monday, 9),
          endAt: at(monday, 18),
          allDay: false,
          source: EventSource.manual,
        ),
      ],
    );
    final late = plan([
      lms(1, due: at(monday + 1, 22), estimate: 120),
    ], schedule: busyMonday);
    expect(placedMinutes(late), {1: 120});
    expect(late.blocks.last.endAt.isAfter(at(monday + 1, 10)), isTrue);
    expect(late.shortages, isEmpty);
  });

  test('날짜만 있는 마감(23:59)과 24:00 마감(다음 날 00:00)도 12시간 전까지 놓는다', () {
    final result = plan([
      lms(1, due: at(monday + 1, 23, 59), estimate: 60),
      lms(2, due: at(monday + 2, 0), estimate: 60),
    ], now: at(monday + 1, 8));
    expect(
      result.blocks.every((b) => !b.endAt.isAfter(at(monday + 1, 12))),
      isTrue,
    );
    expect(placedMinutes(result), {1: 60, 2: 60});
  });

  test('블록은 120분(max_block 규칙이면 그 값)을 넘지 않게 나누고, 남는 조각이 25분보다 짧게 남지 않게 한다', () {
    final due = at(monday + 6, 23, 59);
    final big = plan([lms(1, kind: LmsItemKind.team, due: due, estimate: 250)]);
    expect([
      for (final b in big.blocks) b.endAt.difference(b.startAt).inMinutes,
    ], everyElement(lessThanOrEqualTo(120)));
    expect(placedMinutes(big), {1: 250});
    // 250 = 120 + 105 + 25가 아니라 짧은 꼬리 없이 나뉜다.
    expect([
      for (final b in big.blocks) b.endAt.difference(b.startAt).inMinutes,
    ], everyElement(greaterThanOrEqualTo(Defaults.minChunkMin)));

    final short = plan(
      [lms(1, kind: LmsItemKind.team, due: due, estimate: 120)],
      rules: [rule(RuleKind.maxBlock, const RuleParams(minutes: 45))],
    );
    expect([
      for (final b in short.blocks) b.endAt.difference(b.startAt).inMinutes,
    ], everyElement(lessThanOrEqualTo(45)));
    expect(placedMinutes(short), {1: 120});
  });

  test('자동으로 놓는 블록끼리, 그리고 확정·완료 블록과도 15분을 띄운다', () {
    final schedule = scheduleOf(
      blocks: [
        block(1, 9, at(monday, 9), at(monday, 10)),
        block(
          2,
          9,
          at(monday, 12),
          at(monday, 13),
          status: PlanBlockStatus.done,
        ),
      ],
    );
    final tasks = [
      for (var id = 1; id <= 4; id++) lms(id, due: at(monday, 23, 59)),
    ];
    final result = plan(tasks, schedule: schedule, now: at(monday, 8));
    expectSound(
      result,
      schedule: schedule,
      config: configOf(const []),
      now: at(monday, 8),
      tasks: tasks,
    );
    expect(result.blocks.first.startAt, at(monday, 10, 15));
  });

  test('하루 최대 공부량(그날의 확정·완료 블록 포함)을 넘지 않는다', () {
    final schedule = scheduleOf(
      blocks: [block(1, 9, at(monday, 9), at(monday, 10))],
    );
    final result = plan(
      [
        for (var id = 1; id <= 6; id++)
          lms(id, due: at(monday + 1, 23, 59), estimate: 90),
      ],
      schedule: schedule,
      rules: [rule(RuleKind.dailyCap, const RuleParams(minutes: 180))],
    );
    final byDay = <int, int>{};
    for (final b in result.blocks) {
      byDay[b.startAt.day] =
          (byDay[b.startAt.day] ?? 0) + b.endAt.difference(b.startAt).inMinutes;
    }
    expect(byDay[monday]! + 60, lessThanOrEqualTo(180));
    expect(byDay[monday + 1], lessThanOrEqualTo(180));
    expect(result.shortages, isNotEmpty);
  });

  test('고르게 펼친다: 마감이 넉넉한 일은 하루에 몰지 않고 날마다 빈 시간에 비례해 나눈다', () {
    final due = at(monday + 6, 23, 59);
    final result = plan([
      for (var id = 1; id <= 6; id++)
        lms(id, kind: LmsItemKind.team, due: due, estimate: 120),
    ]);
    expect(placedMinutes(result).values.fold<int>(0, (a, b) => a + b), 720);
    final byDay = <int, int>{};
    for (final b in result.blocks) {
      byDay[b.startAt.day] =
          (byDay[b.startAt.day] ?? 0) + b.endAt.difference(b.startAt).inMinutes;
    }
    // 하루 9시간이 비어 있으므로 한두 날에 몰면 하루 4–6시간이 된다. 고르게 펼치면 날마다 2시간 남짓이다.
    expect(byDay.length, greaterThanOrEqualTo(5));
    expect(byDay.values, everyElement(lessThanOrEqualTo(150)));
  });

  test('마감 12시간 여유를 지키려고 목표·남길 몫을 넘겨서라도 그 전에 놓는다', () {
    // A1–A3(화 08:00 마감)이 월요일 360분을 먼저 차지한다. B(화 12:00 마감, 12시간 전은 화 00:00)는 월요일의
    // 남길 몫을 넘지만, 화요일 09:00–12:00(마감 12시간 안)보다 월요일에 놓는다.
    final result = plan([
      for (var id = 1; id <= 3; id++)
        lms(id, kind: LmsItemKind.team, due: at(monday + 1, 8), estimate: 120),
      lms(4, kind: LmsItemKind.team, due: at(monday + 1, 12), estimate: 120),
    ]);
    final b = result.blocks.where((b) => b.taskId == 4).toList();
    expect(b, hasLength(1));
    expect(b.single.endAt.isAfter(at(monday + 1, 0)), isFalse);
    expect(b.single.startAt, at(monday, 15, 45));
  });

  test('다른 날에 자리가 있으면 날마다 빈 시간의 20%는 남긴다', () {
    // 수요일 23:59 마감(12시간 전은 수 11:59) 120분 일곱 개. 월·화 09:00–18:00과 수 09:00–11:59가 빈다.
    final result = plan([
      for (var id = 1; id <= 7; id++)
        lms(
          id,
          kind: LmsItemKind.team,
          due: at(monday + 2, 23, 59),
          estimate: 120,
        ),
    ]);
    expect(placedMinutes(result).values.fold<int>(0, (a, b) => a + b), 840);
    final byDay = <int, int>{};
    for (final b in result.blocks) {
      byDay[b.startAt.day] =
          (byDay[b.startAt.day] ?? 0) + b.endAt.difference(b.startAt).inMinutes;
    }
    expect(byDay[monday], lessThanOrEqualTo(540 * 0.8));
    expect(byDay[monday + 1], lessThanOrEqualTo(540 * 0.8));
  });

  test('목표를 넘겨야 할 때는 빈 시간에 견줘 덜 찬 날부터 놓는다', () {
    // A1–A3(화 08:00 마감)이 월요일 360분, K(수 08:00 마감)가 화요일 120분을 차지한다. J(수 11:00 마감)는 월요일
    // 남길 몫과 화요일 목표를 넘으므로 2단계로 가고, 더 덜 찬 화요일에 놓는다.
    final result = plan([
      for (var id = 1; id <= 3; id++)
        lms(id, kind: LmsItemKind.team, due: at(monday + 1, 8), estimate: 120),
      lms(4, kind: LmsItemKind.team, due: at(monday + 2, 8), estimate: 120),
      lms(5, kind: LmsItemKind.team, due: at(monday + 2, 11), estimate: 120),
    ]);
    expect(result.ranked, [1, 2, 3, 4, 5]);
    expect(
      result.blocks.where((b) => b.taskId == 4).single.startAt,
      at(monday + 1, 9),
    );
    expect(
      result.blocks.where((b) => b.taskId == 5).single.startAt.day,
      monday + 1,
    );
  });

  test('하루 목표 안이면 이른 날부터 놓는다', () {
    // X(월 23:59 마감)가 월요일 오전을 쓰고, 마감이 먼 Y는 월요일 목표 안이라 화요일이 아니라 월요일에 놓는다.
    final result = plan([
      lms(1, kind: LmsItemKind.team, due: at(monday, 23, 59), estimate: 120),
      lms(2, due: at(monday + 4, 23, 59), estimate: 60),
    ]);
    expect(
      result.blocks.where((b) => b.taskId == 2).single.startAt.day,
      monday,
    );
  });

  test('마감이 빠듯하면 하루 목표와 남길 몫을 넘겨 몰아 놓는다', () {
    final result = plan([
      for (var id = 1; id <= 4; id++)
        lms(id, kind: LmsItemKind.team, due: at(monday + 1, 9), estimate: 120),
    ]);
    // 화요일 09:00 마감(12시간 전은 월요일 21:00)이라 월요일 9시간에 8시간을 놓아야 한다.
    expect(placedMinutes(result).values.fold<int>(0, (a, b) => a + b), 480);
    expect(result.shortages, isEmpty);
  });

  test('시간 부족: 마감 전 빈 시간이 모자라면 들어가는 만큼 놓고 모자란 시간을 낸다', () {
    final result = plan([
      lms(1, kind: LmsItemKind.team, due: at(monday, 13), estimate: 240),
    ]);
    // 월요일 09:00–13:00(마감)에 15분 간격을 두고 놓을 수 있는 만큼.
    expect(result.shortages.single.taskId, 1);
    expect(result.shortages.single.missingMin + placedMinutes(result)[1]!, 240);
    expect(result.shortages.single.dueAt, at(monday, 13));
  });

  test('빈 시간 없음: 하루 창이 모두 막히면 그날에는 놓지 않는다', () {
    final schedule = scheduleOf(
      fixed: [
        FixedBlock(
          id: 1,
          name: '알바',
          weekdays: const [1],
          startMin: 540,
          endMin: 1080,
          bufferMin: 0,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
        ),
      ],
    );
    final result = plan([lms(1, due: at(monday, 20))], schedule: schedule);
    expect(result.blocks, isEmpty);
    expect(result.shortages.single.missingMin, 60);
  });

  test('15분씩 쪼개진 빈 시간에는 큰 일을 놓지 않고, 영상·퀴즈는 10분 조각으로 놓는다', () {
    // 09:00–18:00에 15분 비고 15분 막히기를 되풀이한다.
    final events = [
      for (var i = 0; i < 18; i++)
        Event(
          id: i + 1,
          title: '잘게 쪼갬',
          startAt: at(monday, 9, 15).add(Duration(minutes: 30 * i)),
          endAt: at(monday, 9, 30).add(Duration(minutes: 30 * i)),
          allDay: false,
          source: EventSource.manual,
        ),
    ];
    final schedule = scheduleOf(events: events);
    final result = plan([
      lms(1, due: at(monday, 20)),
      lms(2, kind: LmsItemKind.video, due: at(monday, 20), requiredMin: 20),
    ], schedule: schedule);
    expect(placedMinutes(result)[1], isNull);
    expect(result.shortages.map((s) => s.taskId), contains(1));
    expect(placedMinutes(result)[2], 20);
    expect([
      for (final b in result.blocks) b.endAt.difference(b.startAt).inMinutes,
    ], everyElement(lessThanOrEqualTo(15)));
  });

  test('점심(식사 보호)과 이동 시간, 피할 시간, 수업 앞뒤 여유, 자정을 넘는 고정 일정과 겹치지 않는다', () {
    final schedule = scheduleOf(
      slots: [
        slot(1, weekday: 1, startMin: 600, endMin: 675),
        slot(2, weekday: 2, startMin: 780, endMin: 855),
      ],
      fixed: [
        FixedBlock(
          id: 1,
          name: '야간 알바',
          weekdays: const [2],
          startMin: 1320,
          endMin: 1560,
          bufferMin: 10,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
        ),
      ],
    );
    final rules = [
      rule(
        RuleKind.workWindow,
        const RuleParams(startMin: 540, endMin: 1500),
        id: 50,
      ),
      rule(
        RuleKind.travel,
        const RuleParams(minutes: 30, position: TravelPosition.dayEdges),
      ),
      rule(
        RuleKind.blackout,
        const RuleParams(startMin: 1020, endMin: 1140),
        id: 101,
      ),
    ];
    final tasks = [
      for (var id = 1; id <= 8; id++)
        lms(
          id,
          kind: LmsItemKind.team,
          due: at(monday + 2, 23, 59),
          estimate: 120,
        ),
    ];
    final result = plan(tasks, schedule: schedule, rules: rules, lunch: true);
    expectSound(
      result,
      schedule: schedule,
      config: configOf(rules, lunch: true),
      now: at(monday, 8),
      tasks: tasks,
    );
    expect(result.blocks, isNotEmpty);
  });

  test('같은 날 마감이 여럿이면 여유도가 작은 것부터 놓고, 순번과 근거가 그 순서다', () {
    final result = plan([
      lms(1, due: at(monday, 23), estimate: 60),
      lms(2, due: at(monday, 21), estimate: 60),
      lms(3, due: at(monday, 23), estimate: 120),
      lms(4, due: at(monday + 5, 23), estimate: 60),
    ]);
    // 하루 창이 18:00에 끝나 세 마감 전 빈 시간은 같다. 그래서 큰 일(3)의 여유도가 가장 작고, 여유도가 같은
    // 2와 1은 마감이 이른 2가 먼저다. 마감이 먼 4가 마지막이다.
    expect(result.ranked, [3, 2, 1, 4]);
    final reasons = {for (final b in result.blocks) b.taskId: b.reason!};
    expect(
      [
        for (final id in [3, 2, 1, 4]) reasons[id]!.rank,
      ],
      [1, 2, 3, 4],
    );
    expect(reasons[2]!.dueAt, at(monday, 21));
    expect(reasons[3]!.slackMin, lessThan(reasons[2]!.slackMin));
    expect(reasons[2]!.slackMin, reasons[1]!.slackMin);
    // 가장 급한 일이 하루의 첫 자리를 갖는다.
    expect(result.blocks.first.taskId, 3);
  });

  test('지운 자리는 그 할 일에 다시 내지 않지만 다른 할 일에는 낸다', () {
    final schedule = scheduleOf(
      blocks: [
        block(
          1,
          1,
          at(monday, 9),
          at(monday, 10),
          status: PlanBlockStatus.dismissed,
          source: BlockSource.auto,
        ),
      ],
    );
    final mine = plan([
      lms(1, due: at(monday + 1, 23, 59)),
    ], schedule: schedule);
    expect(mine.blocks.single.startAt, at(monday, 10));
    final other = plan([
      lms(2, due: at(monday + 1, 23, 59)),
    ], schedule: schedule);
    expect(other.blocks.single.startAt, at(monday, 9));
  });

  test('규칙과 겹치는 확정 블록은 그대로 두고 그 시간은 비우지 않는다(옮기는 것은 사용자가 고름)', () {
    final schedule = scheduleOf(
      blocks: [block(1, 9, at(monday, 9), at(monday, 11))],
    );
    final rules = [
      rule(RuleKind.blackout, const RuleParams(startMin: 540, endMin: 600)),
    ];
    final tasks = [lms(1, due: at(monday + 1, 23, 59))];
    final result = plan(tasks, schedule: schedule, rules: rules);
    expect(result.blocks.any((b) => b.taskId == 9), isFalse);
    expect(result.blocks.single.startAt, at(monday, 11, 15));
  });

  test('밤 시간 쓰기를 고른 할 일만 그날부터 마감일까지 하루 창 끝을 늘린 빈 시간을 쓴다', () {
    final busyDay = [
      Event(
        id: 1,
        title: '행사',
        startAt: at(monday, 9),
        endAt: at(monday, 18),
        allDay: false,
        source: EventSource.manual,
      ),
    ];
    final schedule = scheduleOf(events: busyDay);
    final night = TaskEntry(
      task: task(
        1,
        kind: TaskKind.personal,
        due: at(monday + 1, 2),
        estimate: 60,
        nightFrom: '2026-11-16',
      ),
    );
    final other = TaskEntry(
      task: task(
        2,
        kind: TaskKind.personal,
        due: at(monday + 1, 2),
        estimate: 60,
      ),
    );
    final result = plan([night, other], schedule: schedule);
    // 하루 창 끝 18:00을 다음 날 01:00까지 늘린 1의 빈 시간만 있다(마감 02:00, 12시간 여유는 3단계로 씀).
    expect(placedMinutes(result), {1: 60});
    expect(result.blocks.single.startAt.isAfter(at(monday, 17, 59)), isTrue);
    expect(result.shortages.single.taskId, 2);
  });

  test('다른 일 미루기: 미룬 날 전에는 놓지 않는다', () {
    final result = plan([
      TaskEntry(
        task: task(
          1,
          kind: TaskKind.personal,
          due: at(monday + 5, 23, 59),
          estimate: 60,
          deferredUntil: '2026-11-19',
        ),
      ),
    ]);
    expect(result.blocks.single.startAt.day, monday + 3);
  });

  test('부분 목표를 골랐으면 그만큼만 놓는다', () {
    final result = plan([
      TaskEntry(
        task: task(
          1,
          kind: TaskKind.personal,
          due: at(monday + 5, 23, 59),
          estimate: 300,
          partialGoal: 90,
        ),
      ),
    ]);
    expect(placedMinutes(result), {1: 90});
    expect(result.shortages, isEmpty);
  });

  test('규칙을 끄면 쓰지 않고, 켜면 다시 따른다', () {
    final tasks = [lms(1, due: at(monday + 1, 23, 59))];
    final on = plan(
      tasks,
      rules: [
        rule(RuleKind.blackout, const RuleParams(startMin: 540, endMin: 720)),
      ],
    );
    final off = plan(
      tasks,
      rules: [
        rule(
          RuleKind.blackout,
          const RuleParams(startMin: 540, endMin: 720),
          active: false,
        ),
      ],
    );
    expect(on.blocks.single.startAt, at(monday, 12));
    expect(off.blocks.single.startAt, at(monday, 9));
  });

  test('지금 뒤에만 놓고, 시작은 5분 단위로 올린다', () {
    final result = plan([
      lms(1, due: at(monday + 1, 23, 59)),
    ], now: at(monday, 10, 7));
    expect(describe(result), ['1 16 10:10–11:10']);
  });

  test('관련 수업 바로 뒤·선호 시간대·쪼개지 않음·길이 맞음을 근거로 고른다', () {
    // 월요일 10:00–11:15 과목 1 수업. 그 뒤(여유 10분)부터 12:00까지 비는 자리는 수업 가까이다.
    final schedule = scheduleOf(
      slots: [slot(1, courseId: 1, weekday: 1, startMin: 600, endMin: 675)],
    );
    final near = plan(
      [lms(1, due: at(monday + 1, 23, 59), estimate: 30, courseId: 1)],
      schedule: schedule,
      now: at(monday, 10),
    );
    expect(near.blocks.single.startAt, at(monday, 11, 25));
    expect(near.blocks.single.reason!.factor, BlockFactor.nearClass);

    final preferred = plan(
      [lms(2, due: at(monday + 1, 23, 59), estimate: 30, courseId: 5)],
      schedule: schedule,
      now: at(monday, 10),
      rules: [
        rule(RuleKind.preferred, const RuleParams(startMin: 840, endMin: 960)),
      ],
    );
    expect(preferred.blocks.single.startAt, at(monday, 14));
    expect(preferred.blocks.single.reason!.factor, BlockFactor.preferred);

    final whole = plan([lms(3, due: at(monday + 3, 23, 59), estimate: 60)]);
    expect(whole.blocks.single.reason!.factor, BlockFactor.unsplit);
    expect(whole.blocks.single.reason!.gapMin, 540);

    // 한 번에 다 들어가는 빈 시간(13:00–15:00)을, 꼭 맞지만 다 들어가지 않는 빈 시간(09:00–10:00)보다 먼저
    // 고른다.
    Event busy(int id, int fromHour, int toHour) => Event(
      id: id,
      title: '일정 $id',
      startAt: at(monday, fromHour),
      endAt: at(monday, toHour),
      allDay: false,
      source: EventSource.manual,
    );
    final unsplit = plan([
      lms(4, due: at(monday + 1, 18), estimate: 90),
    ], schedule: scheduleOf(events: [busy(1, 10, 13), busy(2, 15, 18)]));
    expect(describe(unsplit), ['4 16 13:00–14:30']);
    expect(unsplit.blocks.single.reason!.factor, BlockFactor.unsplit);
  });

  test('같은 입력이면 순서가 달라도 같은 계획이다', () {
    final tasks = [
      for (var id = 1; id <= 8; id++)
        lms(
          id,
          kind: id.isEven ? LmsItemKind.team : LmsItemKind.assignment,
          due: at(monday + id % 5 + 1, 18),
        ),
    ];
    final first = plan(tasks);
    final second = plan(tasks.reversed.toList());
    expect(describe(second), describe(first));
    expect(second.ranked, first.ranked);
  });
}
