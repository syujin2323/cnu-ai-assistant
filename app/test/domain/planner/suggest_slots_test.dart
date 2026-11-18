// 옮기기 시트의 다른 시간(suggestSlots), 02 홈 [다시 놓기]의 자리(retrySlot), 01 계획에서 체크한 할
// 일의 자리(briefingSlot) 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 4단계, docs/screens.md
// '옮기기 시트'·'02 홈'·'01 계획'.
//
// 기본값(임시값)이 바뀌어도 기대값이 그대로이도록 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로
// 둔다. 2026-11-16은 월요일이고, 지금은 그날 08:00이다(다시 놓기는 따로 정함).

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-[day] [hour]:[minute].
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const mon = 16;
const tue = 17;
const wed = 18;
const thu = 19;
const fri = 20;

Rule rule(RuleKind kind, RuleParams params, {required int id}) {
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

final baseRules = [
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
];

/// 하루 창을 [startMin]–[endMin]으로 바꾸는 규칙(기본 규칙보다 나중).
Rule window(int startMin, int endMin) => rule(
  RuleKind.workWindow,
  RuleParams(startMin: startMin, endMin: endMin),
  id: 200,
);

PlannerConfig configOf([List<Rule> rules = const []]) =>
    PlannerConfig.from([...baseRules, ...rules]);

ClassSlot slot(
  int id, {
  required int courseId,
  required int weekday,
  required int startMin,
  required int endMin,
}) => ClassSlot(
  id: id,
  courseId: courseId,
  weekday: weekday,
  startMin: startMin,
  endMin: endMin,
  place: '공학관 201',
  campus: Campus.daedeok,
  online: false,
  source: SlotSource.manual,
);

/// 평일 빈 시간을 막지 않는 일요일 수업.
final sundayClass = slot(
  900,
  courseId: 9,
  weekday: DateTime.sunday,
  startMin: 540,
  endMin: 600,
);

TaskEntry entry(
  int id, {
  TaskKind kind = TaskKind.assignment,
  DateTime? due,
  String? nightFrom,
}) => TaskEntry(
  task: Task(
    id: id,
    title: '할 일 $id',
    kind: kind,
    dueAt: due,
    dueTimeUnknown: false,
    status: TaskStatus.todo,
    nightWindowFrom: nightFrom,
  ),
);

/// LMS 할 일과 그 원본.
TaskEntry lms(
  int id, {
  LmsItemKind kind = LmsItemKind.assignment,
  required DateTime due,
  int courseId = 1,
  DateTime? openAt,
}) {
  final key = 'k:$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: '할 일 $id',
      kind: TaskKind.values.byName(kind.name),
      dueAt: due,
      dueTimeUnknown: false,
      status: TaskStatus.todo,
      lmsKey: key,
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
      firstSeenAt: at(1, 9),
      lastSeenAt: at(1, 9),
      missCount: 0,
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
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.manual,
);

Event event(int id, DateTime start, DateTime end) => Event(
  id: id,
  title: '일정 $id',
  startAt: start,
  endAt: end,
  allDay: false,
  source: EventSource.manual,
);

Schedule scheduleOf({
  List<ClassSlot>? slots,
  List<Event> events = const [],
  List<PlanBlock> blocks = const [],
}) => Schedule(
  classSlots: slots ?? [sundayClass],
  events: events,
  planBlocks: blocks,
);

/// [moving]을 옮길 다른 시간. 일정에는 [moving]도 넣는다.
List<SlotOption> options(
  PlanBlock moving,
  TaskEntry task, {
  List<ClassSlot>? slots,
  List<Event> events = const [],
  List<PlanBlock> others = const [],
  List<Rule> rules = const [],
  DateTime? now,
  int days = Defaults.planHorizonDays,
  int count = Defaults.alternativeSlotCount,
}) => suggestSlots(
  now: now ?? at(mon, 8),
  block: moving,
  entry: task,
  schedule: scheduleOf(
    slots: slots,
    events: events,
    blocks: [moving, ...others],
  ),
  config: configOf(rules),
  dayBoundaryMin: Defaults.dayBoundaryMin,
  days: days,
  count: count,
);

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 다른 시간을 '날 시작–끝 이유' 꼴로.
List<String> describe(List<SlotOption> list) => [
  for (final o in list)
    '${o.span.start.day} ${_hhmm(o.span.start)}–${_hhmm(o.span.end)} '
        '${o.factor.name}',
];

/// [moving]을 다시 놓을 자리. 일정에는 [moving]도 넣는다.
TimeSpan? retry(
  PlanBlock moving,
  TaskEntry task, {
  required DateTime now,
  List<Event> events = const [],
  List<PlanBlock> others = const [],
  List<Rule> rules = const [],
}) => retrySlot(
  now: now,
  block: moving,
  entry: task,
  schedule: scheduleOf(events: events, blocks: [moving, ...others]),
  config: configOf(rules),
  dayBoundaryMin: Defaults.dayBoundaryMin,
);

void main() {
  group('suggestSlots', () {
    test('빈 날에는 블록이 있던 자리의 앞뒤와 내일을 점수 순서로 낸다', () {
      final result = options(
        block(10, 1, at(mon, 10), at(mon, 11)),
        entry(1, due: at(wed, 18)),
      );
      expect(describe(result), [
        '16 09:00–10:00 unsplit',
        '16 11:00–12:00 unsplit',
        '17 09:00–10:00 unsplit',
      ]);
      // 블록이 있던 자리와 겹치는 다른 시간은 내지 않는다.
      for (final o in result) {
        expect(o.span.intersection(TimeSpan(at(mon, 10), at(mon, 11))), isNull);
      }
      expect([for (final o in result) o.gapMin], [60, 420, 540]);
    });

    test('같은 두 시간 칸에서는 점수가 높은(같으면 이른) 하나만 고른다', () {
      // 월요일 빈 시간은 08:00–09:00과 09:15–10:15(같은 08–10시 칸)이고 둘 다 꼭 맞는다.
      final result = options(
        block(10, 1, at(tue, 8), at(tue, 9)),
        entry(1, due: at(fri, 12)),
        rules: [window(480, 720)],
        events: [
          event(1, at(mon, 9), at(mon, 9, 15)),
          event(2, at(mon, 10, 15), at(mon, 12)),
        ],
        now: at(mon, 7),
      );
      expect(describe(result), [
        '16 08:00–09:00 unsplit',
        '17 09:00–10:00 unsplit',
        '18 08:00–09:00 unsplit',
      ]);
    });

    test('이미 제안한 자리와 확정·완료 블록은 15분 띄우고, 그 할 일의 지운 자리는 그대로 뺀다', () {
      final result = options(
        block(10, 1, at(tue, 9), at(tue, 10)),
        entry(1, due: at(fri, 18)),
        others: [
          block(
            11,
            2,
            at(mon, 10),
            at(mon, 11),
            status: PlanBlockStatus.suggested,
          ),
          block(12, 3, at(mon, 13), at(mon, 14)),
          block(
            13,
            1,
            at(mon, 15),
            at(mon, 16),
            status: PlanBlockStatus.dismissed,
          ),
          // 다른 할 일의 지운 자리는 막지 않는다.
          block(
            14,
            4,
            at(mon, 16, 30),
            at(mon, 17),
            status: PlanBlockStatus.dismissed,
          ),
        ],
      );
      expect(describe(result), [
        '16 11:15–12:15 unsplit',
        '16 16:00–17:00 unsplit',
        '17 10:00–11:00 unsplit',
      ]);
      expect([for (final o in result) o.gapMin], [90, 120, 480]);
    });

    test('완료 블록도 15분 띄우고, 놓친 블록은 시간을 막지 않는다', () {
      final result = options(
        block(10, 1, at(tue, 9), at(tue, 10)),
        entry(1, due: at(mon, 18)),
        rules: [window(540, 720)],
        others: [
          block(11, 2, at(mon, 9), at(mon, 10), status: PlanBlockStatus.done),
          block(
            12,
            3,
            at(mon, 11),
            at(mon, 12),
            status: PlanBlockStatus.missed,
          ),
        ],
      );
      expect(describe(result), ['16 10:15–11:15 unsplit']);
    });

    test('마감 전에 끝나는 자리만 내고 마감 뒤의 날은 보지 않는다', () {
      final result = options(
        block(10, 1, at(mon, 10), at(mon, 11)),
        entry(1, due: at(mon, 13)),
      );
      expect(describe(result), [
        '16 09:00–10:00 unsplit',
        '16 11:00–12:00 unsplit',
      ]);
      // 마감 전 빈 시간이 30분이면 줄여서, 20분이면 내지 않는다.
      expect(
        describe(
          options(
            block(10, 1, at(mon, 10), at(mon, 11)),
            entry(1, due: at(mon, 9, 30)),
          ),
        ),
        ['16 09:00–09:30 fit'],
      );
      expect(
        options(
          block(10, 1, at(mon, 10), at(mon, 11)),
          entry(1, due: at(mon, 9, 20)),
        ),
        isEmpty,
      );
    });

    test('마감이 없으면 배치 지평 안에서 고르고, 빈 시간마다 자리는 하나다', () {
      final result = options(
        block(10, 1, at(mon, 10), at(mon, 11)),
        entry(1),
        days: 2,
        count: 5,
      );
      expect(describe(result), [
        '16 09:00–10:00 unsplit',
        '16 11:00–12:00 unsplit',
        '17 09:00–10:00 unsplit',
      ]);
    });

    test('빈 시간이 짧으면 최소 조각까지 줄이고 그보다 짧은 빈 시간은 내지 않는다', () {
      final moving = block(10, 1, at(tue, 9), at(tue, 10));
      expect(
        describe(
          options(
            moving,
            entry(1, due: at(fri, 18)),
            rules: [window(540, 570)],
            days: 1,
          ),
        ),
        ['16 09:00–09:30 fit'],
      );
      // 20분은 과제의 최소 조각(25분)보다 짧고, 퀴즈·영상(10분)에는 들어간다.
      expect(
        options(
          moving,
          entry(1, due: at(fri, 18)),
          rules: [window(540, 560)],
          days: 1,
        ),
        isEmpty,
      );
      for (final kind in [TaskKind.quiz, TaskKind.video]) {
        expect(
          describe(
            options(
              moving,
              entry(1, kind: kind, due: at(fri, 18)),
              rules: [window(540, 560)],
              days: 1,
            ),
          ),
          ['16 09:00–09:20 fit'],
          reason: '$kind',
        );
      }
      // 블록이 최소 조각보다 짧으면 그 길이 그대로 옮긴다.
      expect(
        describe(
          options(
            block(10, 1, at(tue, 9), at(tue, 9, 20)),
            entry(1, due: at(fri, 18)),
            rules: [window(540, 560)],
            days: 1,
          ),
        ),
        ['16 09:00–09:20 unsplit'],
      );
    });

    test('하루 최대 공부량이 남은 만큼으로 줄이고, 다 찬 날은 건너뛴다', () {
      final moving = block(10, 1, at(tue, 9), at(tue, 10));
      // 그날 공부량은 그날 시작하는 확정(90분)·완료(30분) 블록이고, 다음 날 블록은 넣지 않는다.
      final others = [
        block(11, 2, at(mon, 13), at(mon, 14, 30)),
        block(
          12,
          3,
          at(mon, 17, 30),
          at(mon, 18),
          status: PlanBlockStatus.done,
        ),
        block(13, 4, at(tue, 13), at(tue, 14, 30)),
      ];
      Rule cap(int minutes) =>
          rule(RuleKind.dailyCap, RuleParams(minutes: minutes), id: 201);
      List<String> monday(int capMin) => describe(
        options(
          moving,
          entry(1, due: at(fri, 18)),
          others: others,
          rules: [cap(capMin)],
          days: 1,
        ),
      );
      expect(monday(150), ['16 14:45–15:15 fit', '16 09:00–09:30 fit']);
      expect(monday(140), isEmpty);
      expect(monday(600), ['16 14:45–15:45 unsplit', '16 09:00–10:00 unsplit']);
      // 옮기는 블록 자신은 그날 공부량에 넣지 않는다.
      expect(
        describe(
          options(
            block(10, 1, at(mon, 16), at(mon, 17)),
            entry(1, due: at(mon, 18)),
            rules: [cap(60), window(540, 660)],
          ),
        ),
        ['16 09:00–10:00 unsplit'],
      );
    });

    test('그 과목 수업과 가까운 자리를 먼저 고르고 이유로 낸다', () {
      final mondayClass = slot(
        1,
        courseId: 1,
        weekday: DateTime.monday,
        startMin: 780,
        endMin: 840,
      );
      final result = options(
        block(10, 1, at(tue, 9), at(tue, 10)),
        lms(1, due: at(fri, 18)),
        slots: [sundayClass, mondayClass],
      );
      expect(describe(result), [
        '16 11:50–12:50 nearClass',
        '16 14:10–15:10 nearClass',
        '17 10:00–11:00 unsplit',
      ]);
      // 다른 과목의 할 일에는 가깝다고 보지 않는다.
      expect(
        describe(
          options(
            block(10, 1, at(tue, 9), at(tue, 10)),
            lms(1, due: at(fri, 18), courseId: 2),
            slots: [sundayClass, mondayClass],
          ),
        ),
        [
          '16 09:00–10:00 unsplit',
          '16 14:10–15:10 unsplit',
          '17 10:00–11:00 unsplit',
        ],
      );
    });

    test('선호 시간대 시작에도 놓아 보고, 같은 자리라면 가까운 날을 먼저 낸다', () {
      final preferred = rule(
        RuleKind.preferred,
        const RuleParams(startMin: 900, endMin: 960),
        id: 202,
      );
      final result = options(
        block(10, 1, at(tue, 9), at(tue, 10)),
        entry(1, due: at(fri, 18)),
        rules: [preferred],
      );
      expect(describe(result), [
        '16 15:00–16:00 preferred',
        '17 15:00–16:00 preferred',
        '18 15:00–16:00 preferred',
      ]);
      // 선호 시간대 시작에 놓으면 빈 시간을 넘는 자리는 고르지 않는다.
      expect(
        describe(
          options(
            block(10, 1, at(tue, 9), at(tue, 10)),
            entry(1, due: at(fri, 18)),
            rules: [preferred, window(540, 930)],
            days: 1,
          ),
        ),
        ['16 14:30–15:30 preferred'],
      );
    });

    test('공개 전 영상은 공개 뒤의 자리만 낸다', () {
      final result = options(
        block(10, 1, at(tue, 14), at(tue, 14, 30)),
        lms(1, kind: LmsItemKind.video, due: at(fri, 18), openAt: at(tue, 13)),
      );
      expect(describe(result), [
        '17 13:00–13:30 unsplit',
        '17 14:30–15:00 unsplit',
        '18 09:00–09:30 unsplit',
      ]);
    });

    test('밤 시간 쓰기를 고른 할 일은 그날부터 마감일까지 늘린 하루 창에서 고른다', () {
      final moving = block(10, 1, at(tue, 9), at(tue, 10));
      final daytime = [event(1, at(mon, 9), at(mon, 18))];
      expect(
        describe(
          options(
            moving,
            entry(1, due: at(tue, 23), nightFrom: '2026-11-16'),
            events: daytime,
          ),
        ),
        ['16 18:00–19:00 unsplit', '17 10:00–11:00 unsplit'],
      );
      expect(
        describe(options(moving, entry(1, due: at(tue, 23)), events: daytime)),
        ['17 10:00–11:00 unsplit'],
      );
    });

    test('지금 뒤(5분 단위로 올림)만 보고 오늘이 끝나면 내일부터 본다', () {
      final result = options(
        block(10, 1, at(tue, 9), at(tue, 10)),
        entry(1, due: at(tue, 18)),
        now: at(mon, 16, 52),
      );
      expect(describe(result), [
        '16 16:55–17:55 unsplit',
        '17 10:00–11:00 unsplit',
      ]);
      // 하루 경계(04:00) 전 새벽은 전날의 연장이다.
      expect(
        describe(
          options(
            block(10, 1, at(tue, 9), at(tue, 10)),
            entry(1, due: at(tue, 18)),
            now: at(tue, 2),
            count: 1,
          ),
        ),
        ['17 10:00–11:00 unsplit'],
      );
    });

    test('count개까지 내고 days일만 본다', () {
      final moving = block(10, 1, at(mon, 10), at(mon, 11));
      expect(describe(options(moving, entry(1, due: at(fri, 18)), count: 1)), [
        '16 09:00–10:00 unsplit',
      ]);
      expect(describe(options(moving, entry(1, due: at(fri, 18)), days: 1)), [
        '16 09:00–10:00 unsplit',
        '16 11:00–12:00 unsplit',
      ]);
      expect(options(moving, entry(1, due: at(fri, 18)), count: 0), isEmpty);
    });

    test('길이가 0인 블록은 빈 목록이고, days가 1보다 작으면 ArgumentError다', () {
      expect(
        options(block(10, 1, at(mon, 10), at(mon, 10)), entry(1)),
        isEmpty,
      );
      expect(
        () =>
            options(block(10, 1, at(mon, 10), at(mon, 11)), entry(1), days: 0),
        throwsArgumentError,
      );
    });

    test('같은 입력이면 같은 답을 낸다', () {
      List<String> run() => describe(
        options(
          block(10, 1, at(mon, 10), at(mon, 11)),
          entry(1, due: at(fri, 18)),
          others: [
            block(
              11,
              2,
              at(mon, 13),
              at(mon, 14),
              status: PlanBlockStatus.suggested,
            ),
          ],
        ),
      );
      expect(run(), run());
    });
  });

  group('retrySlot', () {
    final missed = block(
      10,
      1,
      at(mon, 9),
      at(mon, 10),
      status: PlanBlockStatus.missed,
    );

    test('오늘 지금 뒤 가장 이른 자리를 5분 단위로 고른다', () {
      expect(
        retry(missed, entry(1, due: at(fri, 18)), now: at(mon, 11, 2)),
        TimeSpan(at(mon, 11, 5), at(mon, 12, 5)),
      );
    });

    test('길이는 블록 길이를 25분–2시간으로 맞춘 것이다', () {
      expect(
        retry(
          block(
            10,
            1,
            at(mon, 9),
            at(mon, 9, 10),
            status: PlanBlockStatus.missed,
          ),
          entry(1, due: at(fri, 18)),
          now: at(mon, 11),
        ),
        TimeSpan(at(mon, 11), at(mon, 11, 25)),
      );
      expect(
        retry(
          block(10, 1, at(mon, 9), at(mon, 12), status: PlanBlockStatus.missed),
          entry(1, due: at(fri, 18)),
          now: at(mon, 12),
        ),
        TimeSpan(at(mon, 12), at(mon, 14)),
      );
    });

    test('확정·완료 블록과 15분 띄우고 제안 블록은 보지 않는다', () {
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 11, 2),
          others: [
            block(11, 2, at(mon, 12), at(mon, 13)),
            block(
              12,
              3,
              at(mon, 13, 15),
              at(mon, 14, 15),
              status: PlanBlockStatus.suggested,
            ),
          ],
        ),
        TimeSpan(at(mon, 13, 15), at(mon, 14, 15)),
      );
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 11, 2),
          others: [
            block(
              11,
              2,
              at(mon, 11, 30),
              at(mon, 12),
              status: PlanBlockStatus.done,
            ),
          ],
        ),
        TimeSpan(at(mon, 12, 15), at(mon, 13, 15)),
      );
    });

    test('그 할 일의 지운 자리는 빼고, 다시 놓는 블록 자신은 시간을 막지 않는다', () {
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 11),
          others: [
            block(
              11,
              1,
              at(mon, 11),
              at(mon, 12, 30),
              status: PlanBlockStatus.dismissed,
            ),
          ],
        ),
        TimeSpan(at(mon, 12, 30), at(mon, 13, 30)),
      );
      // 아직 확정인 채로 답을 받은 블록이어도 그 블록의 간격은 보지 않는다.
      expect(
        retry(
          block(10, 1, at(mon, 10), at(mon, 11)),
          entry(1, due: at(fri, 18)),
          now: at(mon, 11, 2),
        ),
        TimeSpan(at(mon, 11, 5), at(mon, 12, 5)),
      );
    });

    test('오늘 자리가 없으면 내일 가장 이른 자리이고, 마감 전에 끝나야 한다', () {
      expect(
        retry(missed, entry(1, due: at(fri, 18)), now: at(mon, 17, 30)),
        TimeSpan(at(tue, 9), at(tue, 10)),
      );
      expect(
        retry(missed, entry(1, due: at(tue, 9, 30)), now: at(mon, 17, 30)),
        isNull,
      );
      expect(
        retry(missed, entry(1, due: at(mon, 20)), now: at(mon, 17, 30)),
        isNull,
      );
      expect(
        retry(missed, entry(1, due: at(mon, 12, 5)), now: at(mon, 11, 2)),
        TimeSpan(at(mon, 11, 5), at(mon, 12, 5)),
      );
      expect(
        retry(missed, entry(1, due: at(mon, 12)), now: at(mon, 11, 2)),
        isNull,
      );
      // 내일 다음 날은 보지 않는다.
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 17, 30),
          events: [event(1, at(tue, 9), at(tue, 18))],
        ),
        isNull,
      );
    });

    test('하루 최대 공부량을 넘는 날은 건너뛴다', () {
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 11),
          others: [block(11, 2, at(mon, 13), at(mon, 14, 30))],
          rules: [
            rule(RuleKind.dailyCap, const RuleParams(minutes: 120), id: 201),
          ],
        ),
        TimeSpan(at(tue, 9), at(tue, 10)),
      );
      expect(
        retry(
          missed,
          entry(1, due: at(fri, 18)),
          now: at(mon, 11),
          others: [block(11, 2, at(mon, 13), at(mon, 14))],
          rules: [
            rule(RuleKind.dailyCap, const RuleParams(minutes: 120), id: 201),
          ],
        ),
        TimeSpan(at(mon, 11), at(mon, 12)),
      );
    });

    test('밤 시간 쓰기와 영상 공개 시각을 따른다', () {
      expect(
        retry(
          missed,
          entry(1, due: at(tue, 23), nightFrom: '2026-11-16'),
          now: at(mon, 17, 30),
        ),
        TimeSpan(at(mon, 17, 30), at(mon, 18, 30)),
      );
      expect(
        retry(
          block(
            10,
            1,
            at(mon, 9),
            at(mon, 9, 30),
            status: PlanBlockStatus.missed,
          ),
          lms(
            1,
            kind: LmsItemKind.video,
            due: at(fri, 18),
            openAt: at(mon, 15),
          ),
          now: at(mon, 11),
        ),
        TimeSpan(at(mon, 15), at(mon, 15, 30)),
      );
    });
  });

  group('briefingSlot', () {
    PlanBlock auto(int id, int taskId, DateTime start, DateTime end) =>
        PlanBlock(
          id: id,
          taskId: taskId,
          startAt: start,
          endAt: end,
          status: PlanBlockStatus.confirmed,
          source: BlockSource.auto,
        );

    SlotOption? find(
      TaskEntry task, {
      int minutes = 60,
      TimeSpan? preferred,
      List<Event> events = const [],
      List<PlanBlock> blocks = const [],
      Set<int> replaced = const {},
      List<TimeSpan> taken = const [],
      DateTime? now,
    }) => briefingSlot(
      now: now ?? at(mon, 8),
      entry: task,
      minutes: minutes,
      preferred: preferred,
      schedule: scheduleOf(events: events, blocks: blocks),
      replaced: replaced,
      taken: taken,
      config: configOf(),
      dayBoundaryMin: Defaults.dayBoundaryMin,
    );

    test('제안 시각이 비었으면 그 자리이고, 빈 시간 길이와 이유를 낸다', () {
      final found = find(
        entry(1, due: at(fri, 18)),
        preferred: TimeSpan(at(mon, 10), at(mon, 11)),
      );
      expect(found!.span, TimeSpan(at(mon, 10), at(mon, 11)));
      expect(found.gapMin, 540);
      expect(found.factor, BlockFactor.unsplit);
    });

    test('제안 시각이 막혔으면 지금 뒤 한 번에 들어가는 가장 이른 자리이고, 남은 확정 블록과 15분 띄운다', () {
      final found = find(
        entry(1, due: at(fri, 18)),
        preferred: TimeSpan(at(mon, 9, 30), at(mon, 10, 30)),
        blocks: [block(10, 2, at(mon, 9), at(mon, 10))],
      );
      expect(found!.span, TimeSpan(at(mon, 10, 15), at(mon, 11, 15)));
      expect(found.gapMin, 465);
    });

    test('확정하면 지울 블록의 자리는 비어 있고, 완료 블록은 막는다', () {
      expect(
        find(
          entry(1, due: at(fri, 18)),
          preferred: TimeSpan(at(mon, 9), at(mon, 10)),
          blocks: [auto(10, 1, at(mon, 9), at(mon, 10))],
          replaced: {10},
        )!.span,
        TimeSpan(at(mon, 9), at(mon, 10)),
      );
      expect(
        find(
          entry(1, due: at(fri, 18)),
          blocks: [
            block(11, 2, at(mon, 9), at(mon, 10), status: PlanBlockStatus.done),
          ],
        )!.span,
        TimeSpan(at(mon, 10, 15), at(mon, 11, 15)),
      );
    });

    test('이 브리핑에서 이미 체크한 자리와 15분 띄우고, 제안 블록은 막지 않는다', () {
      expect(
        find(
          entry(1, due: at(fri, 18)),
          taken: [TimeSpan(at(mon, 9), at(mon, 10))],
        )!.span,
        TimeSpan(at(mon, 10, 15), at(mon, 11, 15)),
      );
      expect(
        find(
          entry(1, due: at(fri, 18)),
          blocks: [
            block(
              12,
              2,
              at(mon, 9),
              at(mon, 10),
              status: PlanBlockStatus.suggested,
            ),
          ],
        )!.span,
        TimeSpan(at(mon, 9), at(mon, 10)),
      );
    });

    test('그 할 일의 지운 자리는 빼고(띄우지 않음), 지금 뒤 5분 단위로 올린다', () {
      expect(
        find(
          entry(1, due: at(fri, 18)),
          blocks: [
            block(
              13,
              1,
              at(mon, 9),
              at(mon, 10),
              status: PlanBlockStatus.dismissed,
            ),
          ],
        )!.span,
        TimeSpan(at(mon, 10), at(mon, 11)),
      );
      expect(
        find(entry(1, due: at(fri, 18)), now: at(mon, 9, 2))!.span,
        TimeSpan(at(mon, 9, 5), at(mon, 10, 5)),
      );
    });

    test('길이는 2시간까지이고, 한 번에 들어가는 자리가 없으면 최소 조각 이상 들어가는 만큼이다', () {
      expect(
        find(entry(1, due: at(fri, 18)), minutes: 180)!.span,
        TimeSpan(at(mon, 9), at(mon, 11)),
      );
      final partial = find(
        entry(1, due: at(fri, 18)),
        events: [
          event(1, at(mon, 9), at(mon, 10)),
          event(2, at(mon, 10, 40), at(mon, 18)),
        ],
      );
      expect(partial!.span, TimeSpan(at(mon, 10), at(mon, 10, 40)));
      expect(partial.factor, BlockFactor.fit);
    });

    test('최소 조각(25분, 영상·퀴즈 10분)도 들어가지 않으면 null이다', () {
      final events = [
        event(1, at(mon, 9), at(mon, 10)),
        event(2, at(mon, 10, 20), at(mon, 18)),
      ];
      expect(find(entry(1, due: at(fri, 18)), events: events), isNull);
      expect(
        find(
          entry(1, kind: TaskKind.quiz, due: at(fri, 18)),
          events: events,
        )!.span,
        TimeSpan(at(mon, 10), at(mon, 10, 20)),
      );
    });

    test('마감 전에 끝나야 하고, 그날 시작 전에 마감이 지났으면 null이다', () {
      expect(
        find(entry(1, due: at(mon, 10)))!.span,
        TimeSpan(at(mon, 9), at(mon, 10)),
      );
      expect(find(entry(1, due: at(mon, 3))), isNull);
    });

    test('길이가 0 이하면 ArgumentError다', () {
      expect(
        () => find(entry(1, due: at(fri, 18)), minutes: 0),
        throwsArgumentError,
      );
    });
  });
}
