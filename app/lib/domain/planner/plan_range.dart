// 배치 엔진: 앞으로 며칠의 제안 블록(`planRange`). docs/architecture.md '도메인 기본값과 배치 엔진' 2–4·6단계,
// docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)'.
//
// 같은 입력이면 늘 같은 계획을 낸다(순수 함수이고 순서를 모두 정해 둠). 빈 시간은 `free_slots.dart`의
// [dayAvailability]로 구하므로 확정·완료 블록은 이미 바쁜 시간이다. 입력의 제안 블록은 보지 않는다(다시 계산해
// 새로 놓고, 부르는 쪽이 결과로 바꿔 끼움). 지운 블록은 그날 그 할 일에 같은 자리를 다시 내지 않으려고만 본다.
//
// 1. 놓을 할 일과 시간([remainingWorkMin]): 끝냈거나 LMS가 제출·출석 인정을 알려 준 일, LMS에서 사라진 일,
//    마감이 없거나 지났거나 지평 밖인 일, 예상 시간을 모르는 토론·시험은 놓지 않는다. 여기서 아직 끝나지 않은
//    확정 블록의 남은 길이를 뺀 것이 놓을 시간이다.
// 2. 여유도 = 지금(영상은 공개)부터 마감 전까지의 빈 시간 합 − 놓을 시간. 작은 것부터 놓고, 같으면 마감이 이른
//    것, 놓을 시간이 큰 것, 할 일 id 순서다. 이 순번이 근거의 `rank`다.
// 3. 하루 목표(고르게 펼치기): 할 일마다 놓을 시간을 그 할 일이 놓일 수 있는 날들(마감 12시간 전까지)의 빈 시간에
//    비례해 나눠 날마다 더한다.
// 4. 놓기: 급한 할 일부터 조각을 하나씩 놓는다. 다 놓지 못하면 단계를 풀어 다시 본다.
//    - 1단계: 마감 12시간 전까지, 이른 날부터. 아직 아무것도 놓지 않은 날이거나, 조각을 더해도 그날 새로 놓은
//      양이 하루 목표 × (1 + [Defaults.planTargetOverRatio])에 가까워지는(조각의 절반까지만 넘는) 날이다. 앞으로
//      들어올 일정을 위해 빈 시간의 [Defaults.planReserveRatio]만큼은 남긴다. 조각을 줄여 맞추지 않는다(잘게
//      쪼개지 않게).
//    - 2단계: 목표와 남길 몫을 넘겨도 된다(마감 12시간 전까지). 빈 시간에 견줘 덜 찬 날부터 놓는다.
//    - 3단계: 마감 12시간 여유에도 놓는다(2단계처럼 덜 찬 날부터).
//    늘 지키는 것: 빈 시간 안, 지금 뒤(5분 단위로 올림), 영상 공개 뒤, 마감 전, 하루 최대 공부량(`daily_cap`,
//    그날의 확정·완료 블록 포함), 조각 길이(최소 [Defaults.minChunkMin], 영상·퀴즈 [Defaults.minLightChunkMin],
//    최대 `max_block`), 블록 사이 [Defaults.blockGapMin](새로 놓는 블록끼리와 확정·완료 블록과도), 그날 지운
//    자리(그 할 일만), 미룬 할 일은 미룬 날부터, '밤 시간 쓰기'를 고른 할 일은 그날부터 마감일까지 하루 창
//    끝을 늘린 빈 시간.
//    그날 안에서는 자리마다 점수([scoreSlot]: 쪼개지 않음·길이 맞음·관련 수업과 가까움·선호 시간대, 짧게
//    남는 빈 조각은 깎음)를 매겨 가장 높은 자리, 같으면 이른 자리에 놓는다. 근거의 `factor`는 그 자리의 가장
//    구체적인 이유다(관련 수업과 가까움 → 선호 시간대(조각의 절반 이상) → 쪼개지 않음 → 길이 맞음 순서).
// 5. 다 놓지 못한 할 일은 모자란 시간과 함께 [PlanResult.shortages]에 담는다(6단계 시간 부족).
// 수업 칸이 하나도 없으면(시간표를 아직 받지 못함) 아무것도 놓지 않는다.
//
// 점수·조각 길이·블록 간격·5분 단위는 옮기기 시트와 [다시 놓기]의 자리 추천(`suggest_slots.dart`)과 함께 쓰려고
// `placement.dart`에 둔다.

import 'dart:math' as math;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
import 'package:cnu_ai_assistant/domain/planner/placement.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 시간이 모자란 할 일.
final class Shortage {
  const Shortage({
    required this.taskId,
    required this.missingMin,
    required this.dueAt,
  });

  /// `tasks.id`.
  final int taskId;

  /// 마감 전 빈 시간에 다 놓지 못한 시간(분).
  final int missingMin;

  final DateTime dueAt;

  @override
  bool operator ==(Object other) =>
      other is Shortage &&
      other.taskId == taskId &&
      other.missingMin == missingMin &&
      other.dueAt == dueAt;

  @override
  int get hashCode => Object.hash(taskId, missingMin, dueAt);

  @override
  String toString() => 'Shortage($taskId, $missingMin, $dueAt)';
}

/// [planRange]의 결과. 목록은 바꿀 수 없다.
final class PlanResult {
  PlanResult({
    required List<BlockDraft> blocks,
    required List<Shortage> shortages,
    required List<int> ranked,
  }) : blocks = List.unmodifiable(blocks),
       shortages = List.unmodifiable(shortages),
       ranked = List.unmodifiable(ranked);

  static final empty = PlanResult(blocks: [], shortages: [], ranked: []);

  /// 새 제안 블록(시작 순서, 같으면 할 일 id 순서). 모두 `source` auto이고 근거가 있다.
  final List<BlockDraft> blocks;

  /// 시간이 모자란 할 일(급한 순서).
  final List<Shortage> shortages;

  /// 놓을 시간이 있는 할 일의 id를 급한 순서(근거의 `rank` 순서)로. 01 아침 브리핑의 '급한 순'에 쓴다.
  final List<int> ranked;
}

/// [entry]의 남은 작업 시간(분, 아직 끝나지 않은 확정 블록은 빼지 않음). 자동으로 놓지 않는 할 일(예상 시간을
/// 모르는 토론·시험, LMS 자료)이면 null이다.
///
/// 영상은 출석 인정 시간 전체이고, 없으면 영상 길이, 둘 다 없으면 [Defaults.unknownVideoMin]이다. 그 밖에는 예상
/// 시간(할 일의 값 → 그 과목·종류의 `estimate` 규칙 → [Defaults.estimateMinByKind])에서 한 만큼(`spentMin`)을
/// 뺀다. '부분 목표'를 골랐으면 그만큼까지만이다.
int? remainingWorkMin(TaskEntry entry, PlannerConfig config) {
  final task = entry.task;
  final int remaining;
  if (task.kind == TaskKind.video) {
    final item = entry.lmsItem;
    remaining = item?.requiredMin ?? item?.videoMin ?? Defaults.unknownVideoMin;
  } else {
    final estimate =
        task.estimateMin ??
        config.estimateMin(
          courseId: task.courseIdWith(entry.lmsItem),
          kind: task.kind,
        ) ??
        Defaults.estimateMinByKind[task.kind];
    if (estimate == null) return null;
    remaining = estimate - (task.spentMin ?? 0);
  }
  final goal = task.partialGoalMin;
  return goal == null ? remaining : math.min(remaining, goal);
}

/// 논리적 하루 [from]부터 [days]일 동안의 제안 블록을 계산한다. [now]는 지금(한국 시각)이고 지난 시간에는
/// 놓지 않는다. [schedule]은 그 기간의 일정이다(`ScheduleRepository.read`). [tasks]는 할 일 목록이다
/// (`TaskRepository.read`, 숨긴 할 일은 빠져 있음). [days]가 1보다 작으면 [ArgumentError]다.
PlanResult planRange({
  required DateTime now,
  required DateTime from,
  int days = Defaults.planHorizonDays,
  required Schedule schedule,
  required List<TaskEntry> tasks,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) {
  if (days < 1) throw ArgumentError.value(days, 'days');
  if (schedule.classSlots.isEmpty) return PlanResult.empty;
  final start = roundUpToFive(now);
  final planDays = <_Day>[
    for (var i = 0; i < days; i++)
      _Day(
        DateTime(from.year, from.month, from.day + i),
        schedule: schedule,
        config: config,
        dayBoundaryMin: dayBoundaryMin,
        start: start,
      ),
  ].where((day) => day.logical.end.isAfter(start)).toList();
  if (planDays.isEmpty) return PlanResult.empty;
  final horizonEnd = planDays.last.logical.end;

  final jobs = <_Job>[
    for (final entry in tasks)
      ?_Job.of(
        entry,
        schedule: schedule,
        config: config,
        dayBoundaryMin: dayBoundaryMin,
        start: start,
        horizonEnd: horizonEnd,
      ),
  ];
  for (final job in jobs) {
    final free = planDays.fold<int>(
      0,
      (sum, day) => sum + day.freeMinutesFor(job, until: job.dueAt),
    );
    job.slack = free - job.toPlace;
  }
  jobs.sort((a, b) {
    for (final order in [
      a.slack.compareTo(b.slack),
      a.dueAt.compareTo(b.dueAt),
      b.toPlace.compareTo(a.toPlace),
      a.taskId.compareTo(b.taskId),
    ]) {
      if (order != 0) return order;
    }
    return 0;
  });
  for (var i = 0; i < jobs.length; i++) {
    jobs[i].rank = i + 1;
  }

  // 하루 목표: 할 일마다 놓을 시간을 놓일 수 있는 날들의 빈 시간에 비례해 나눈다.
  for (final job in jobs) {
    final shares = [
      for (final day in planDays) day.freeMinutesFor(job, until: job.softEnd),
    ];
    final total = shares.fold<int>(0, (sum, minutes) => sum + minutes);
    if (total == 0) continue;
    for (var i = 0; i < planDays.length; i++) {
      planDays[i].target += job.toPlace * shares[i] / total;
    }
  }

  final blocks = <BlockDraft>[];
  for (final job in jobs) {
    for (final tier in _Tier.values) {
      while (job.remaining > 0) {
        BlockDraft? placed;
        for (final day in _dayOrder(planDays, tier)) {
          placed = day.placeOne(job, tier, config: config);
          if (placed != null) break;
        }
        if (placed == null) break;
        blocks.add(placed);
      }
      if (job.remaining <= 0) break;
    }
  }
  blocks.sort((a, b) {
    final byStart = a.startAt.compareTo(b.startAt);
    return byStart != 0 ? byStart : a.taskId.compareTo(b.taskId);
  });
  return PlanResult(
    blocks: blocks,
    shortages: [
      for (final job in jobs)
        if (job.remaining > 0)
          Shortage(
            taskId: job.taskId,
            missingMin: job.remaining,
            dueAt: job.dueAt,
          ),
    ],
    ranked: [for (final job in jobs) job.taskId],
  );
}

/// [tier] 단계에서 날을 보는 순서. 1단계는 이른 날부터, 2·3단계는 빈 시간에 견줘 새로 놓은 양이 적은 날부터(같으면
/// 이른 날)다.
List<_Day> _dayOrder(List<_Day> days, _Tier tier) {
  if (tier == _Tier.spread) return days;
  double fill(_Day day) => day.freeMin == 0 ? 1 : day.newLoad / day.freeMin;
  return [...days]..sort((a, b) {
    final byFill = fill(a).compareTo(fill(b));
    return byFill != 0 ? byFill : a.date.compareTo(b.date);
  });
}

/// 놓기 단계. 앞 단계에서 다 놓지 못한 할 일만 다음 단계로 간다.
enum _Tier {
  /// 마감 12시간 전까지, 하루 목표와 남길 몫 안.
  spread,

  /// 마감 12시간 전까지, 목표·남길 몫을 넘겨도 됨.
  crowd,

  /// 마감 12시간 여유에도.
  slack,
}

/// 놓을 할 일 하나.
final class _Job {
  _Job._({
    required this.entry,
    required this.dueAt,
    required this.dueDate,
    required this.earliest,
    required this.toPlace,
    required this.minChunk,
    required this.courseId,
    required this.nightFrom,
    required this.deferredUntil,
    required this.dismissed,
  }) : remaining = toPlace,
       softEnd = dueAt.subtract(
         const Duration(minutes: Defaults.deadlineSlackMin),
       );

  /// 놓을 할 일이면 만들고, 아니면 null이다(이 파일 머리말 1번).
  static _Job? of(
    TaskEntry entry, {
    required Schedule schedule,
    required PlannerConfig config,
    required int dayBoundaryMin,
    required DateTime start,
    required DateTime horizonEnd,
  }) {
    final task = entry.task;
    final dueAt = task.dueAt;
    if (!entry.isRemaining || dueAt == null) return null;
    if (!dueAt.isAfter(start) || dueAt.isAfter(horizonEnd)) return null;
    final work = remainingWorkMin(entry, config);
    if (work == null) return null;
    final confirmed = schedule.planBlocks
        .where(
          (block) =>
              block.taskId == task.id &&
              block.status == PlanBlockStatus.confirmed &&
              block.endAt.isAfter(start),
        )
        .fold<int>(
          0,
          (sum, block) =>
              sum +
              block.endAt
                  .difference(
                    block.startAt.isAfter(start) ? block.startAt : start,
                  )
                  .inMinutes,
        );
    final toPlace = work - confirmed;
    if (toPlace <= 0) return null;
    final openAt = entry.lmsItem?.openAt;
    final earliest = openAt != null && openAt.isAfter(start)
        ? roundUpToFive(openAt)
        : start;
    if (!earliest.isBefore(dueAt)) return null;
    return _Job._(
      entry: entry,
      dueAt: dueAt,
      dueDate: logicalDate(dueAt, dayBoundaryMin: dayBoundaryMin),
      earliest: earliest,
      toPlace: toPlace,
      minChunk: minChunkMinFor(task.kind),
      courseId: task.courseIdWith(entry.lmsItem),
      nightFrom: task.nightWindowFrom,
      deferredUntil: task.deferredUntil,
      dismissed: [
        for (final block in schedule.planBlocks)
          if (block.taskId == task.id &&
              block.status == PlanBlockStatus.dismissed)
            TimeSpan(block.startAt, block.endAt),
      ],
    );
  }

  final TaskEntry entry;
  final DateTime dueAt;

  /// 마감이 든 논리적 하루의 날짜.
  final DateTime dueDate;

  /// 가장 이르게 놓을 수 있는 때(지금, 영상은 공개 시각).
  final DateTime earliest;

  /// 마감 12시간 여유를 뺀 때. 1·2단계는 블록이 이때까지 끝나게 놓는다.
  final DateTime softEnd;

  final int toPlace;
  final int minChunk;
  final int? courseId;

  /// '밤 시간 쓰기'를 고른 날(`YYYY-MM-DD`).
  final String? nightFrom;

  /// '다른 일 미루기'로 다시 놓는 날(`YYYY-MM-DD`).
  final String? deferredUntil;

  /// 이 할 일의 지운 블록 자리.
  final List<TimeSpan> dismissed;

  int remaining;
  int slack = 0;
  int rank = 0;

  int get taskId => entry.task.id;

  /// [date]에 놓아도 되는지(미룬 할 일은 미룬 날부터).
  bool allowedOn(DateTime date) =>
      deferredUntil == null || isoDate(date).compareTo(deferredUntil!) >= 0;

  /// [date]에 하루 창 끝을 늘린 빈 시간을 쓰는지('밤 시간 쓰기'를 고른 날부터 마감일까지).
  bool usesNightOn(DateTime date) =>
      usesNightWindowOn(date, nightFrom: nightFrom, dueDate: dueDate);
}

/// 논리적 하루 하나와 그날 놓은 것.
final class _Day {
  _Day(
    this.date, {
    required this.schedule,
    required this.config,
    required this.dayBoundaryMin,
    required this.start,
  }) : logical = TimeSpan(
         logicalDayStart(date, dayBoundaryMin: dayBoundaryMin),
         logicalDayEnd(date, dayBoundaryMin: dayBoundaryMin),
       ),
       normal = dayAvailability(
         date,
         schedule: schedule,
         config: config,
         dayBoundaryMin: dayBoundaryMin,
       ) {
    rules = config.forWeekday(date.weekday);
    preferred = preferredSpans(
      date,
      config: config,
      dayBoundaryMin: dayBoundaryMin,
    );
    for (final block in schedule.planBlocks) {
      if (block.status != PlanBlockStatus.confirmed &&
          block.status != PlanBlockStatus.done) {
        continue;
      }
      final span = TimeSpan(block.startAt, block.endAt);
      if (span.intersection(logical) == null) continue;
      study.add(span);
      if (logical.contains(block.startAt)) existingLoad += span.minutes;
    }
    freeMin = _sum(_after(normal.free, start));
    classes = classesByCourse(normal, schedule.classSlots);
  }

  /// 논리적 하루의 날짜.
  final DateTime date;
  final Schedule schedule;
  final PlannerConfig config;
  final int dayBoundaryMin;

  /// 지금(5분 단위로 올림). 이보다 이르게는 놓지 않는다.
  final DateTime start;

  /// 논리적 하루(하루 경계부터 다음 경계 전까지).
  final TimeSpan logical;

  /// 보통 빈 시간.
  final DayAvailability normal;

  /// 하루 창 끝을 늘린 빈 시간('밤 시간 쓰기'). 쓰는 할 일이 있을 때만 계산한다.
  late final DayAvailability night = dayAvailability(
    date,
    schedule: schedule,
    config: config,
    dayBoundaryMin: dayBoundaryMin,
    nightWindow: true,
  );

  late final DayPlanRules rules;
  late final List<TimeSpan> preferred;

  /// 그날의 확정·완료 블록. 새 블록은 이것과도 [Defaults.blockGapMin]을 띄운다.
  final List<TimeSpan> study = [];

  /// 과목 id → 그날 그 과목 수업.
  late final Map<int, List<TimeSpan>> classes;

  /// 그날 시작하는 확정·완료 블록의 분. 하루 최대 공부량에 넣는다.
  int existingLoad = 0;

  /// 지금 뒤의 보통 빈 시간(분).
  late final int freeMin;

  /// 하루 목표(분). 새로 놓는 양을 고르게 펼치는 기준이다.
  double target = 0;

  /// 그날 새로 놓은 블록.
  final List<TimeSpan> placed = [];

  int get newLoad => _sum(placed);

  /// [job]이 이날 [until] 전까지 쓸 수 있는 빈 시간(분). 여유도와 하루 목표에 쓴다(블록 사이 간격은 보지 않음).
  int freeMinutesFor(_Job job, {required DateTime until}) {
    if (!job.allowedOn(date)) return 0;
    final window = TimeSpan(_later(job.earliest, logical.start), until);
    if (!window.end.isAfter(window.start)) return 0;
    return _sum(
      _clip(job.usesNightOn(date) ? night.free : normal.free, window),
    );
  }

  /// [job]의 조각 하나를 [tier] 단계의 조건으로 이날 가장 좋은 자리에 놓고 돌려준다. 놓을 자리가 없으면 null이다.
  BlockDraft? placeOne(_Job job, _Tier tier, {required PlannerConfig config}) {
    if (!job.allowedOn(date)) return null;
    var maxLen = config.maxBlockMin;
    final cap = rules.dailyCapMin;
    if (cap != null) maxLen = math.min(maxLen, cap - existingLoad - newLoad);
    if (maxLen < math.min(job.minChunk, job.remaining)) return null;

    final latest = tier == _Tier.slack ? job.dueAt : job.softEnd;
    final window = TimeSpan(_later(job.earliest, logical.start), latest);
    if (!window.end.isAfter(window.start)) return null;
    final blocked = [
      ...withBlockGap([...placed, ...study]),
      ...job.dismissed,
    ];
    _Candidate? best;
    for (final free in _clip(
      job.usesNightOn(date) ? night.free : normal.free,
      window,
    )) {
      for (final segment in subtractSpans(free, blocked)) {
        final from = roundUpToFive(segment.start);
        final segmentMin = segment.end.difference(from).inMinutes;
        final chunk = _chunkLength(
          job.remaining,
          math.min(maxLen, segmentMin),
          job.minChunk,
        );
        if (chunk == null) continue;
        final duration = Duration(minutes: chunk);
        final starts = <DateTime>{
          from,
          roundDownToFive(segment.end.subtract(duration)),
          for (final span in preferred)
            if (span.end.isAfter(from) && span.start.isBefore(segment.end))
              _later(from, roundUpToFive(span.start)),
        };
        for (final at in starts) {
          if (at.isBefore(from) || at.add(duration).isAfter(segment.end)) {
            continue;
          }
          final candidate = _score(job, segment, at, chunk);
          if (best == null ||
              candidate.score > best.score ||
              (candidate.score == best.score && at.isBefore(best.start))) {
            best = candidate;
          }
        }
      }
    }
    if (best == null) return null;
    if (tier == _Tier.spread) {
      // 아직 아무것도 놓지 않은 날은 첫 조각을 받는다(혼자인 일은 가장 이른 날에). 그 밖에는 하루 목표에
      // 가까워지는 조각만 받는다(조각의 절반까지만 넘음). 앞으로 들어올 일정의 몫은 늘 남긴다. 조각을 줄여
      // 맞추지 않고 다른 날을 본다.
      final goal = target * (1 + Defaults.planTargetOverRatio);
      final keep = freeMin * (1 - Defaults.planReserveRatio);
      if ((newLoad > 0 && newLoad + best.minutes / 2 > goal) ||
          newLoad + best.minutes > keep) {
        return null;
      }
    }
    final span = TimeSpan(
      best.start,
      best.start.add(Duration(minutes: best.minutes)),
    );
    placed.add(span);
    job.remaining -= best.minutes;
    return BlockDraft(
      taskId: job.taskId,
      startAt: span.start,
      endAt: span.end,
      reason: BlockReason(
        slackMin: job.slack,
        dueAt: job.dueAt,
        gapMin: best.segmentMin,
        rank: job.rank,
        factor: best.factor,
      ),
    );
  }

  _Candidate _score(_Job job, TimeSpan segment, DateTime at, int chunk) {
    final courseId = job.courseId;
    final scored = scoreSlot(
      segment: segment,
      slot: TimeSpan(at, at.add(Duration(minutes: chunk))),
      whole: chunk == job.remaining,
      lessons: courseId == null ? const [] : classes[courseId] ?? const [],
      preferred: preferred,
    );
    return _Candidate(
      start: at,
      minutes: chunk,
      segmentMin: segment.minutes,
      score: scored.score,
      factor: scored.factor,
    );
  }
}

/// 한 자리 후보.
final class _Candidate {
  const _Candidate({
    required this.start,
    required this.minutes,
    required this.segmentMin,
    required this.score,
    required this.factor,
  });

  final DateTime start;
  final int minutes;

  /// 그 자리가 든 빈 구간의 길이(분, 근거의 `gapMin`).
  final int segmentMin;
  final double score;
  final BlockFactor factor;
}

/// [remaining]에서 이번에 놓을 조각 길이. [maxLen]까지이고 [minChunk]보다 짧으면 안 된다(남은 것 전부라면
/// 짧아도 됨). 남는 것이 [minChunk]보다 짧아지지 않게 줄인다. 놓을 수 없으면 null이다.
int? _chunkLength(int remaining, int maxLen, int minChunk) {
  var chunk = math.min(remaining, maxLen);
  final rest = remaining - chunk;
  if (rest > 0 && rest < minChunk) chunk = remaining - minChunk;
  if (chunk <= 0) return null;
  if (chunk < minChunk && chunk != remaining) return null;
  return chunk;
}

/// [spans]를 [window] 안으로 자른다.
List<TimeSpan> _clip(Iterable<TimeSpan> spans, TimeSpan window) => [
  for (final span in spans) ?span.intersection(window),
];

/// [spans]에서 [at] 뒤의 부분만.
List<TimeSpan> _after(Iterable<TimeSpan> spans, DateTime at) => [
  for (final span in spans)
    if (span.end.isAfter(at)) TimeSpan(_later(span.start, at), span.end),
];

int _sum(Iterable<TimeSpan> spans) =>
    spans.fold<int>(0, (sum, span) => sum + span.minutes);

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
