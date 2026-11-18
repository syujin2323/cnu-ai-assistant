// 01 아침 브리핑이 보일 것과 확정 값 테스트. docs/screens.md '01 아침 브리핑'.
//
// 지금은 2026-11-16(월) 08:00이고, 어제는 11-15(일)이다.

import 'package:cnu_ai_assistant/domain/briefing.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-[day] [hour]:[minute].
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const sun = 15;
const mon = 16;

final now = at(mon, 8);
final config = PlannerConfig.from(const []);

TaskEntry entry(
  int id, {
  TaskKind kind = TaskKind.assignment,
  TaskStatus status = TaskStatus.todo,
  int? estimateMin,
  int? spentMin,
  bool gone = false,
}) {
  final key = 'k:$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: '할 일 $id',
      kind: kind,
      dueAt: at(20, 18),
      dueTimeUnknown: false,
      status: status,
      estimateMin: estimateMin,
      spentMin: spentMin,
      lmsKey: gone ? key : null,
    ),
    lmsItem: gone
        ? LmsItem(
            id: id,
            remoteKey: key,
            courseId: 1,
            courseName: '과목',
            title: '할 일 $id',
            kind: LmsItemKind.assignment,
            dueTimeUnknown: false,
            firstSeenAt: at(1, 9),
            lastSeenAt: at(1, 9),
            missCount: Defaults.lmsGoneMissCount,
            contentHash: key,
          )
        : null,
  );
}

PlanBlock block(
  int id,
  int taskId,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
  BlockSource source = BlockSource.auto,
  bool fromBriefing = false,
  BlockReason? reason,
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: source,
  fromBriefing: fromBriefing,
  reason: reason,
);

BriefingContent content({
  List<PlanBlock> today = const [],
  List<PlanBlock> yesterday = const [],
  required List<TaskEntry> tasks,
  List<int> ranked = const [],
  int limit = 10,
}) => briefingContent(
  now: now,
  today: today,
  yesterday: yesterday,
  tasks: tasks,
  ranked: ranked,
  config: config,
  limit: limit,
);

void main() {
  group('briefingContent 어제 못 한 일', () {
    test('어제 확정했거나 놓친 블록 가운데 할 일이 남은 것을 시작 순서로 낸다', () {
      final result = content(
        yesterday: [
          block(1, 1, at(sun, 15), at(sun, 16)),
          block(2, 2, at(sun, 10), at(sun, 11), status: PlanBlockStatus.missed),
          block(3, 3, at(sun, 12), at(sun, 13), status: PlanBlockStatus.done),
          block(
            4,
            4,
            at(sun, 13),
            at(sun, 14),
            status: PlanBlockStatus.suggested,
          ),
          block(
            5,
            1,
            at(sun, 17),
            at(sun, 18),
            status: PlanBlockStatus.dismissed,
          ),
          block(6, 5, at(sun, 9), at(sun, 10), status: PlanBlockStatus.missed),
          block(7, 6, at(sun, 9), at(sun, 10)),
          block(8, 7, at(sun, 9), at(sun, 10)),
        ],
        tasks: [
          entry(1),
          entry(2),
          entry(3),
          entry(4),
          entry(5, status: TaskStatus.done),
          entry(6, gone: true),
          entry(7, status: TaskStatus.hidden),
        ],
      );

      expect([for (final m in result.missed) m.block.id], [2, 1]);
      expect(result.missed.first.minutes, 60);
      expect(result.missed.first.entry.task.id, 2);
    });

    test('전에 브리핑에서 오늘로 다시 놓은 블록은 그 할 일의 어제 줄 하나에만 짝짓는다', () {
      final placed = block(20, 1, at(mon, 10), at(mon, 11), fromBriefing: true);
      final result = content(
        yesterday: [
          block(2, 1, at(sun, 15), at(sun, 16), status: PlanBlockStatus.missed),
          block(1, 1, at(sun, 10), at(sun, 11), status: PlanBlockStatus.missed),
        ],
        today: [placed],
        tasks: [entry(1)],
      );
      expect([for (final m in result.missed) m.placed?.id], [20, null]);
      expect([for (final m in result.missed) m.block.id], [1, 2]);
    });
  });

  group('briefingContent 오늘 할 일', () {
    test('① 잠긴 줄 → ② 전 브리핑 확정 → ③ 제안 → ④ 급한 순서로 채우고, 같은 할 일은 한 번만', () {
      final result = content(
        today: [
          // ① 직접 놓은 확정 블록, 시작한 자동 확정 블록, 완료 블록.
          block(1, 10, at(mon, 14), at(mon, 15), source: BlockSource.manual),
          block(2, 11, at(mon, 7), at(mon, 9)),
          block(3, 12, at(mon, 6), at(mon, 7), status: PlanBlockStatus.done),
          // ② 전에 브리핑에서 확정한 블록(시작 전).
          block(4, 13, at(mon, 10), at(mon, 11), fromBriefing: true),
          // ③ 제안과 브리핑 밖에서 확정한 시작 전 자동 확정 블록.
          block(
            5,
            14,
            at(mon, 15, 30),
            at(mon, 16),
            status: PlanBlockStatus.suggested,
          ),
          block(6, 15, at(mon, 12), at(mon, 13)),
          // 이미 잠긴 할 일의 제안은 다시 넣지 않는다.
          block(
            7,
            10,
            at(mon, 16),
            at(mon, 17),
            status: PlanBlockStatus.suggested,
          ),
        ],
        tasks: [for (var id = 10; id <= 17; id++) entry(id)],
        ranked: [16, 14, 17],
      );

      expect(
        [for (final t in result.tasks) (t.taskId, t.kind)],
        [
          (12, BriefingTaskKind.locked),
          (11, BriefingTaskKind.locked),
          (10, BriefingTaskKind.locked),
          (13, BriefingTaskKind.confirmed),
          (15, BriefingTaskKind.suggested),
          (14, BriefingTaskKind.suggested),
          (16, BriefingTaskKind.urgent),
          (17, BriefingTaskKind.urgent),
        ],
      );
      expect(
        [for (final t in result.tasks) t.minutes],
        [null, null, null, 60, 60, 30, 60, 60],
      );
      expect(result.tasks[3].span, TimeSpan(at(mon, 10), at(mon, 11)));
      expect(result.tasks.last.span, isNull);
      // 확정하면 지울 블록: 시작 전 자동 확정(6)과 전 브리핑 확정(4). 직접 놓은 것·시작한 것은 남는다.
      expect([for (final b in result.replaced) b.id], [4, 6]);
      expect(result.replacedIds, {4, 6});
      expect([for (final b in result.previous) b.id], [4]);
      expect(result.remainingCount, 8);
    });

    test('전 브리핑 확정은 출처가 직접(manual)이어도 바꿔 끼울 블록이고 ②다', () {
      final result = content(
        today: [
          block(
            1,
            1,
            at(mon, 10),
            at(mon, 11),
            source: BlockSource.manual,
            fromBriefing: true,
          ),
        ],
        tasks: [entry(1)],
      );
      expect(result.replacedIds, {1});
      expect(
        [for (final t in result.tasks) (t.taskId, t.kind)],
        [(1, BriefingTaskKind.confirmed)],
      );
    });

    test('어제 못 한 일에 있는 할 일, 시작한 제안, 끝낸 할 일은 넣지 않는다', () {
      final result = content(
        yesterday: [
          block(1, 1, at(sun, 10), at(sun, 11), status: PlanBlockStatus.missed),
        ],
        today: [
          block(
            2,
            1,
            at(mon, 10),
            at(mon, 11),
            status: PlanBlockStatus.suggested,
          ),
          block(
            3,
            2,
            at(mon, 7),
            at(mon, 9),
            status: PlanBlockStatus.suggested,
          ),
          block(
            4,
            3,
            at(mon, 12),
            at(mon, 13),
            status: PlanBlockStatus.suggested,
          ),
        ],
        tasks: [
          entry(1),
          entry(2),
          entry(3, status: TaskStatus.done),
        ],
        ranked: [1, 3],
      );
      expect([for (final t in result.tasks) t.taskId], isEmpty);
      expect(result.remainingCount, 2);
    });

    test('④의 길이는 남은 작업 시간을 2시간까지로 줄인 것이고, 놓을 시간이 없는 할 일은 넘긴다', () {
      final result = content(
        tasks: [
          entry(1, estimateMin: 300),
          entry(2, estimateMin: 45),
          entry(3, kind: TaskKind.discussion),
          entry(4, estimateMin: 60, spentMin: 60),
        ],
        ranked: [3, 4, 1, 2],
      );
      expect(
        [for (final t in result.tasks) (t.taskId, t.minutes)],
        [(1, Defaults.maxBlockMin), (2, 45)],
      );
    });

    test('오늘 할 일은 limit개까지다', () {
      final result = content(
        tasks: [for (var id = 1; id <= 8; id++) entry(id)],
        ranked: [for (var id = 1; id <= 8; id++) id],
        limit: Defaults.briefingTodayTaskMax,
      );
      expect([for (final t in result.tasks) t.taskId], [1, 2, 3, 4, 5]);
    });
  });

  group('sortBriefingTasks', () {
    BriefingTask row(int id, BriefingTaskKind kind, [int? hour]) =>
        BriefingTask(
          entry: entry(id),
          kind: kind,
          block: hour == null
              ? null
              : block(id, id, at(mon, hour), at(mon, hour + 1)),
          minutes: 60,
        );
    final rows = [
      row(1, BriefingTaskKind.locked, 15),
      row(2, BriefingTaskKind.suggested, 10),
      row(3, BriefingTaskKind.urgent),
      row(4, BriefingTaskKind.suggested, 10),
      row(5, BriefingTaskKind.urgent),
    ];

    test('추천순은 채운 순서 그대로다', () {
      expect(
        [
          for (final t in sortBriefingTasks(rows, BriefingSort.recommended))
            t.taskId,
        ],
        [1, 2, 3, 4, 5],
      );
    });

    test('시간순은 시각 순서(같으면 채운 순서)이고, 시각이 없는 줄은 뒤에 채운 순서로 둔다', () {
      expect(
        [for (final t in sortBriefingTasks(rows, BriefingSort.time)) t.taskId],
        [2, 4, 1, 3, 5],
      );
      // 화면은 체크한 줄에 놓을 자리의 시각을 준다.
      expect(
        [
          for (final t in sortBriefingTasks(
            rows,
            BriefingSort.time,
            startOf: (task) => task.taskId == 5 ? at(mon, 9) : task.span?.start,
          ))
            t.taskId,
        ],
        [5, 2, 4, 1, 3],
      );
    });
  });

  group('briefingDraft', () {
    final reason = BlockReason(
      slackMin: 300,
      dueAt: at(19, 18),
      gapMin: 90,
      rank: 2,
      factor: BlockFactor.fit,
    );

    test('제안 자리 그대로면 그 근거와 출처를 쓴다', () {
      final suggestion = block(
        1,
        1,
        at(mon, 10),
        at(mon, 11),
        status: PlanBlockStatus.suggested,
        reason: reason,
      );
      final draft = briefingDraft(
        entry: entry(1),
        slot: SlotOption(
          span: TimeSpan(at(mon, 10), at(mon, 11)),
          gapMin: 120,
          factor: BlockFactor.unsplit,
        ),
        suggestion: suggestion,
        base: reason,
      );
      expect(
        (draft.taskId, draft.startAt, draft.endAt, draft.source, draft.reason),
        (1, at(mon, 10), at(mon, 11), BlockSource.auto, reason),
      );
    });

    test('다른 자리면 자동 블록이고, 근거는 엔진의 여유도·순번과 이 자리의 빈 시간·이유다', () {
      final draft = briefingDraft(
        entry: entry(1),
        slot: SlotOption(
          span: TimeSpan(at(mon, 13), at(mon, 14)),
          gapMin: 75,
          factor: BlockFactor.nearClass,
        ),
        suggestion: block(1, 1, at(mon, 10), at(mon, 11)),
        base: reason,
      );
      expect(draft.source, BlockSource.auto);
      final made = draft.reason!;
      expect(
        (made.slackMin, made.dueAt, made.gapMin, made.rank, made.factor),
        (300, at(20, 18), 75, 2, BlockFactor.nearClass),
      );
    });

    test('마감이 없거나 엔진 근거가 없으면 직접 정한 블록처럼 근거 없이 둔다', () {
      final slot = SlotOption(
        span: TimeSpan(at(mon, 13), at(mon, 14)),
        gapMin: 75,
        factor: BlockFactor.fit,
      );
      final noDue = TaskEntry(
        task: Task(
          id: 9,
          title: '마감 없는 일',
          kind: TaskKind.personal,
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
      for (final draft in [
        briefingDraft(entry: noDue, slot: slot, base: reason),
        briefingDraft(entry: entry(1), slot: slot),
      ]) {
        expect((draft.source, draft.reason), (BlockSource.manual, null));
        expect((draft.startAt, draft.endAt), (at(mon, 13), at(mon, 14)));
      }
    });
  });

  group('briefingAction', () {
    BlockDraft draft(int taskId, int hour) => BlockDraft(
      taskId: taskId,
      startAt: at(mon, hour),
      endAt: at(mon, hour + 1),
    );
    PlanBlock before(int taskId, int hour) => block(
      taskId,
      taskId,
      at(mon, hour),
      at(mon, hour + 1),
      fromBriefing: true,
    );

    test('체크가 전 브리핑 확정과 같으면(둘 다 없을 때 포함) 오늘 시작하기다', () {
      expect(
        briefingAction(picks: const [], previous: const []),
        BriefingActionKind.start,
      );
      expect(
        briefingAction(
          picks: [draft(2, 13), draft(1, 10)],
          previous: [before(1, 10), before(2, 13)],
        ),
        BriefingActionKind.start,
      );
    });

    test('하나라도 다르면(할 일이나 시각) 확정하기이고, 전 확정을 모두 풀면 빼기다', () {
      expect(
        briefingAction(picks: [draft(1, 11)], previous: [before(1, 10)]),
        BriefingActionKind.confirm,
      );
      expect(
        briefingAction(
          picks: [draft(1, 10), draft(2, 13)],
          previous: [before(1, 10)],
        ),
        BriefingActionKind.confirm,
      );
      expect(
        briefingAction(picks: [draft(1, 10)], previous: const []),
        BriefingActionKind.confirm,
      );
      expect(
        briefingAction(picks: const [], previous: [before(1, 10)]),
        BriefingActionKind.clear,
      );
    });
  });

  test('briefingLoadMin은 체크한 것과 확정하면 남는 오늘의 확정·완료 블록을 더한다', () {
    final total = briefingLoadMin(
      picks: [BlockDraft(taskId: 1, startAt: at(mon, 10), endAt: at(mon, 11))],
      today: [
        block(1, 2, at(mon, 13), at(mon, 13, 30), source: BlockSource.manual),
        block(2, 3, at(mon, 7), at(mon, 7, 45), status: PlanBlockStatus.done),
        block(3, 4, at(mon, 15), at(mon, 16)),
        block(
          4,
          5,
          at(mon, 16),
          at(mon, 17),
          status: PlanBlockStatus.suggested,
        ),
      ],
      replaced: {3},
    );
    expect(total, 60 + 30 + 45);
  });
}
