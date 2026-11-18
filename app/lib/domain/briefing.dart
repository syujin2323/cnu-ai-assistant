// 01 계획이 보일 것과 체크한 것을 확정할 때 쓸 값. docs/screens.md '01 계획',
// docs/architecture.md '계획 화면'.
//
// 브리핑은 AI 없이 폰의 코드가 계산한다. 같은 입력이면 늘 같은 답을 내는 순수 함수다.
//
// - [briefingContent]: 어제 못 한 일과 오늘 할 일(5개까지, 임시)을 고른다.
// - [sortBriefingTasks]: 오늘 할 일을 [추천순 | 시간순]으로 늘어놓는다.
// - [briefingDraft]: 체크한 할 일을 [briefingSlot]이 고른 자리에 넣을 블록 초안(근거 포함).
// - [briefingAction]: 아래 고정 버튼('오늘 시작하기'·'N개 확정하기'·'확정한 할 일 빼기').
// - [briefingLoadMin]: 하루 최대 공부량과 견줄 오늘의 합계.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 오늘 할 일 한 줄이 들어온 까닭. 이 순서로 채운다.
enum BriefingTaskKind {
  /// ① 오늘 시작했거나 직접 놓은 확정·완료 블록이 있다. 잠긴 줄이고 체크를 바꿀 수 없다.
  locked,

  /// ② 전에 브리핑에서 확정했다. 다시 열면 체크된 채로 보인다.
  confirmed,

  /// ③ 오늘 제안이 있다. 브리핑 밖에서 확정한 시작 전 자동 확정 블록도 여기다('추천', 체크 없음).
  suggested,

  /// ④ 놓을 시간이 있는 할 일을 급한 순서로.
  urgent,
}

/// 오늘 할 일 한 줄.
final class BriefingTask {
  const BriefingTask({
    required this.entry,
    required this.kind,
    this.block,
    this.minutes,
  });

  final TaskEntry entry;
  final BriefingTaskKind kind;

  /// 줄의 블록: 잠긴 줄은 그 블록(여럿이면 가장 이른 것), ②는 전에 브리핑에서 확정한 블록, ③은 제안(또는 브리핑
  /// 밖에서 확정한 자동 확정 블록). ④는 null이다.
  final PlanBlock? block;

  /// 체크하면 놓을 길이(분). 잠긴 줄은 null이다.
  final int? minutes;

  int get taskId => entry.task.id;

  /// 줄에 보일 시각. ②·③은 그 블록의 자리, 잠긴 줄은 그 블록, ④는 null이다.
  TimeSpan? get span =>
      block == null ? null : TimeSpan(block!.startAt, block!.endAt);
}

/// 어제 못 한 일 한 줄.
final class BriefingMissed {
  const BriefingMissed({required this.block, required this.entry, this.placed});

  /// 어제 확정했거나 놓친 블록.
  final PlanBlock block;
  final TaskEntry entry;

  /// 전에 브리핑에서 이 할 일을 오늘로 다시 놓은 블록(다시 열면 체크된 채로 보임). 없으면 null이다.
  final PlanBlock? placed;

  int get minutes => block.endAt.difference(block.startAt).inMinutes;
}

/// 01 계획의 '어제 못 한 일'과 '오늘 할 일'.
final class BriefingContent {
  BriefingContent({
    required List<BriefingMissed> missed,
    required List<BriefingTask> tasks,
    required this.remainingCount,
    required List<PlanBlock> replaced,
  }) : missed = List.unmodifiable(missed),
       tasks = List.unmodifiable(tasks),
       replaced = List.unmodifiable(replaced);

  final List<BriefingMissed> missed;

  /// 채운 순서(①–④)의 오늘 할 일.
  final List<BriefingTask> tasks;

  /// '할 일 전체 보기 · N개'의 N(03 할 일에 남은 할 일 수).
  final int remainingCount;

  /// 확정하면 지울 오늘 블록: 시작 전인 자동 확정 블록과 전에 브리핑에서 확정한 블록(시작 전).
  final List<PlanBlock> replaced;

  /// [replaced]의 id.
  Set<int> get replacedIds => {for (final block in replaced) block.id};

  /// [replaced] 가운데 전에 브리핑에서 확정한 것. 버튼은 체크가 이것과 같은지 본다.
  List<PlanBlock> get previous => [
    for (final block in replaced)
      if (block.fromBriefing) block,
  ];
}

/// 01 계획에 보일 것을 고른다.
///
/// [today]·[yesterday]는 오늘·어제(논리적 하루)의 블록이고, [ranked]는 배치 엔진이 낸 급한 순서의 할 일 id다.
/// - 어제 못 한 일: 어제 확정했거나 놓친 블록 가운데 할 일이 남은 것(끝냈거나 숨겼거나 LMS에서 사라진 일 제외).
///   블록마다 한 줄이고 시작 순서다.
/// - 오늘 할 일: 남은 할 일을 ①–④ 순서로 [limit]개까지 채운다(어제 못 한 일에 있는 할 일은 넣지 않음).
///   같은 순서 안에서는 ①·②·③은 블록 시작 순서, ④는 [ranked] 순서다. ③의 길이는 그 블록의 길이, ④는 남은
///   작업 시간을 [Defaults.maxBlockMin]까지로 줄인 것이다.
BriefingContent briefingContent({
  required DateTime now,
  required List<PlanBlock> today,
  required List<PlanBlock> yesterday,
  required List<TaskEntry> tasks,
  required List<int> ranked,
  required PlannerConfig config,
  int limit = Defaults.briefingTodayTaskMax,
}) {
  final remaining = {
    for (final entry in tasks)
      if (entry.isRemaining) entry.task.id: entry,
  };
  final todaySorted = [...today]..sort(_byStart);

  // 확정하면 바꿔 끼울 블록: 시작 전이고, 자동 확정이거나 전에 브리핑에서 확정한 것.
  final replaced = [
    for (final block in todaySorted)
      if (block.status == PlanBlockStatus.confirmed &&
          block.startAt.isAfter(now) &&
          (block.source == BlockSource.auto || block.fromBriefing))
        block,
  ];
  final replacedIds = {for (final block in replaced) block.id};

  final missed = <BriefingMissed>[];
  final missedTasks = <int>{};
  // 전에 브리핑에서 다시 놓은 블록은 그 할 일의 어제 줄 하나에만 짝짓는다(시작 순서대로).
  final unplaced = [
    for (final block in replaced)
      if (block.fromBriefing) block,
  ];
  for (final block in [...yesterday]..sort(_byStart)) {
    if (block.status != PlanBlockStatus.confirmed &&
        block.status != PlanBlockStatus.missed) {
      continue;
    }
    final entry = remaining[block.taskId];
    if (entry == null) continue;
    missedTasks.add(block.taskId);
    final placed = unplaced
        .where((other) => other.taskId == block.taskId)
        .firstOrNull;
    if (placed != null) unplaced.remove(placed);
    missed.add(BriefingMissed(block: block, entry: entry, placed: placed));
  }

  final picked = <BriefingTask>[];
  final seen = <int>{...missedTasks};
  void add(BriefingTask task) {
    if (picked.length >= limit || !seen.add(task.taskId)) return;
    picked.add(task);
  }

  // ① 오늘 시작했거나 직접 놓은 확정·완료 블록.
  for (final block in todaySorted) {
    final entry = remaining[block.taskId];
    if (entry == null) continue;
    final kept =
        (block.status == PlanBlockStatus.confirmed ||
            block.status == PlanBlockStatus.done) &&
        !replacedIds.contains(block.id);
    if (kept) {
      add(
        BriefingTask(entry: entry, kind: BriefingTaskKind.locked, block: block),
      );
    }
  }
  // ② 전에 브리핑에서 확정한 블록.
  for (final block in replaced) {
    final entry = remaining[block.taskId];
    if (entry == null || !block.fromBriefing) continue;
    add(
      BriefingTask(
        entry: entry,
        kind: BriefingTaskKind.confirmed,
        block: block,
        minutes: block.endAt.difference(block.startAt).inMinutes,
      ),
    );
  }
  // ③ 오늘 제안과, 브리핑 밖에서 확정한 시작 전 자동 확정 블록.
  for (final block in todaySorted) {
    final entry = remaining[block.taskId];
    if (entry == null) continue;
    final suggested =
        (block.status == PlanBlockStatus.suggested &&
            block.startAt.isAfter(now)) ||
        (replacedIds.contains(block.id) && !block.fromBriefing);
    if (!suggested) continue;
    add(
      BriefingTask(
        entry: entry,
        kind: BriefingTaskKind.suggested,
        block: block,
        minutes: block.endAt.difference(block.startAt).inMinutes,
      ),
    );
  }
  // ④ 급한 순서.
  for (final taskId in ranked) {
    final entry = remaining[taskId];
    if (entry == null) continue;
    final work = remainingWorkMin(entry, config);
    if (work == null || work <= 0) continue;
    add(
      BriefingTask(
        entry: entry,
        kind: BriefingTaskKind.urgent,
        minutes: work < Defaults.maxBlockMin ? work : Defaults.maxBlockMin,
      ),
    );
  }

  return BriefingContent(
    missed: missed,
    tasks: picked,
    remainingCount: remaining.length,
    replaced: replaced,
  );
}

/// 오늘 할 일의 정렬.
enum BriefingSort {
  /// 추천순: 채운 순서(①–④).
  recommended,

  /// 시간순: 시각이 있는 줄을 시각 순서로, 없는 줄은 그 뒤에 채운 순서로.
  time,
}

/// [tasks](채운 순서)를 [sort]대로 늘어놓는다. 시간순의 시각은 [startOf]가 주고(화면은 체크한 줄에 놓을 자리를
/// 줌), 주지 않으면 줄의 블록 시각이다. 시각이 같거나 없으면 채운 순서다.
List<BriefingTask> sortBriefingTasks(
  List<BriefingTask> tasks,
  BriefingSort sort, {
  DateTime? Function(BriefingTask task)? startOf,
}) {
  if (sort == BriefingSort.recommended) return [...tasks];
  final timeOf = startOf ?? (BriefingTask task) => task.span?.start;
  final rows = [
    for (var i = 0; i < tasks.length; i++) (i, tasks[i], timeOf(tasks[i])),
  ];
  rows.sort((a, b) {
    final (ia, _, ta) = a;
    final (ib, _, tb) = b;
    if (ta != null && tb != null) {
      final byTime = ta.compareTo(tb);
      if (byTime != 0) return byTime;
    } else if (ta != null) {
      return -1;
    } else if (tb != null) {
      return 1;
    }
    return ia.compareTo(ib);
  });
  return [for (final (_, task, _) in rows) task];
}

/// 체크한 할 일을 [slot]에 넣을 블록 초안(브리핑에서 확정한 블록이 됨).
///
/// [suggestion]의 자리 그대로면 그 근거와 출처를 그대로 쓴다. 다른 자리면 출처는 `auto`이고 근거를 새로
/// 계산한다: 여유도와 급한 순번은 [base](배치 엔진이 그 할 일에 낸 근거)에서, 빈 시간 길이와 고른 이유는
/// [slot]에서 가져온다. 마감이 없거나 [base]가 없으면(엔진이 그 할 일을 놓지 못함) 직접 정한 블록처럼
/// `manual`·근거 없음이다.
BlockDraft briefingDraft({
  required TaskEntry entry,
  required SlotOption slot,
  PlanBlock? suggestion,
  BlockReason? base,
}) {
  final taskId = entry.task.id;
  if (suggestion != null &&
      suggestion.startAt == slot.span.start &&
      suggestion.endAt == slot.span.end) {
    return BlockDraft(
      taskId: taskId,
      startAt: slot.span.start,
      endAt: slot.span.end,
      source: suggestion.source,
      reason: suggestion.reason,
    );
  }
  final dueAt = entry.task.dueAt;
  if (dueAt == null || base == null) {
    return BlockDraft(
      taskId: taskId,
      startAt: slot.span.start,
      endAt: slot.span.end,
      source: BlockSource.manual,
    );
  }
  return BlockDraft(
    taskId: taskId,
    startAt: slot.span.start,
    endAt: slot.span.end,
    source: BlockSource.auto,
    reason: BlockReason(
      slackMin: base.slackMin,
      dueAt: dueAt,
      gapMin: slot.gapMin,
      rank: base.rank,
      factor: slot.factor,
    ),
  );
}

/// 아래 고정 버튼.
enum BriefingActionKind {
  /// '오늘 시작하기': 체크가 전에 브리핑에서 확정한 것과 같다(둘 다 없을 때 포함). 아무것도 쓰지 않는다.
  start,

  /// 'N개 확정하기': 체크가 전과 다르다.
  confirm,

  /// '확정한 할 일 빼기': 전에 확정한 것을 모두 풀었다.
  clear,
}

/// 체크한 것([picks])과 전에 브리핑에서 확정한 블록([previous])으로 버튼을 정한다. 할 일과 시작·끝이 모두
/// 같아야 같은 것이다.
BriefingActionKind briefingAction({
  required Iterable<BlockDraft> picks,
  required Iterable<PlanBlock> previous,
}) {
  final chosen = {
    for (final pick in picks) (pick.taskId, pick.startAt, pick.endAt),
  };
  final before = {
    for (final block in previous) (block.taskId, block.startAt, block.endAt),
  };
  if (chosen.length == before.length && chosen.containsAll(before)) {
    return BriefingActionKind.start;
  }
  return chosen.isEmpty ? BriefingActionKind.clear : BriefingActionKind.confirm;
}

/// 하루 최대 공부량과 견줄 오늘의 합계(분): 체크한 것과, 확정하면 남는 오늘의 확정·완료 블록.
int briefingLoadMin({
  required Iterable<BlockDraft> picks,
  required List<PlanBlock> today,
  required Set<int> replaced,
}) {
  var total = 0;
  for (final pick in picks) {
    total += pick.endAt.difference(pick.startAt).inMinutes;
  }
  for (final block in today) {
    if ((block.status == PlanBlockStatus.confirmed ||
            block.status == PlanBlockStatus.done) &&
        !replaced.contains(block.id)) {
      total += block.endAt.difference(block.startAt).inMinutes;
    }
  }
  return total;
}

int _byStart(PlanBlock a, PlanBlock b) {
  final byStart = a.startAt.compareTo(b.startAt);
  return byStart != 0 ? byStart : a.id.compareTo(b.id);
}
