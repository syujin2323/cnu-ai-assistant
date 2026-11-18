// 블록 하나를 옮기거나 다시 놓을 자리 추천. docs/architecture.md '도메인 기본값과 배치 엔진' 4단계,
// docs/screens.md '옮기기 시트'·'02 홈'.
//
// - [suggestSlots]: 옮기기 시트('어디로 옮길까요?')의 다른 시간 몇 개.
// - [retrySlot]: 02 홈 피드백 카드에서 '못 했어요' 뒤 [다시 놓기]가 놓을 자리.
// - [briefingSlot]: 01 아침 브리핑에서 체크한 할 일을 놓을 오늘 자리.
//
// 둘 다 저장하지 않고 시트·카드를 열 때 계산하는 순수 함수이고, 같은 입력이면 늘 같은 답을 낸다. 빈 시간은 배치
// 엔진과 같은 `dayAvailability`로 구하되 옮기거나 다시 놓을 블록은 일정에서 빼고 본다(그 블록이 비킨 자리도 빈
// 시간이다). 앱이 고르는 자리라 배치 엔진처럼 지킨다: 지금 뒤(5분 단위로 올림), 영상 공개 뒤, 마감 전,
// 확정·완료 블록과 [Defaults.blockGapMin] 띄우기, 그날 지운 자리(그 할 일만) 빼기, 하루 최대 공부량(`daily_cap`,
// 그날 시작하는 확정·완료 블록 포함), '밤 시간 쓰기'를 고른 할 일은 하루 창 끝을 늘린 빈 시간. 고른 자리는
// 사용자가 확정하는 직접 정한 블록이 되므로 근거(`reason`)는 만들지 않는다.

import 'dart:math' as math;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/placement.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 옮기기 시트의 다른 시간 하나.
final class SlotOption {
  const SlotOption({
    required this.span,
    required this.gapMin,
    required this.factor,
  });

  /// 옮길 자리. 길이는 옮기는 블록의 길이이고, 그 빈 시간이 더 짧으면 그 빈 시간만큼이다.
  final TimeSpan span;

  /// 이 자리가 든 빈 시간의 길이(분). 블록 간격과 그날 지운 자리를 뺀 길이다.
  final int gapMin;

  /// 이 자리를 고른 가장 구체적인 이유([scoreSlot]). `unsplit`은 블록을 줄이지 않고 그대로 옮기고, `fit`은
  /// 빈 시간에 맞춰 줄인다.
  final BlockFactor factor;

  @override
  bool operator ==(Object other) =>
      other is SlotOption &&
      other.span == span &&
      other.gapMin == gapMin &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(span, gapMin, factor);

  @override
  String toString() => 'SlotOption($span, $gapMin, ${factor.name})';
}

/// [block]을 옮길 다른 시간을 좋은 순서로 [count]개까지 돌려준다. 없으면 빈 목록이다.
///
/// [now]는 지금(한국 시각), [entry]는 그 블록의 할 일, [schedule]은 오늘(논리적 하루)부터 [days]일의 일정
/// (`ScheduleRepository.read`)이다.
///
/// - 오늘부터 [days]일(배치 지평) 안이고 마감 전에 끝나는 빈 시간에서 고른다. 이미 제안한 자리(모든 할 일의
///   제안 블록)와 확정·완료 블록은 [Defaults.blockGapMin]을 띄워 빼고, 그 할 일의 지운 자리와 [block]이 있던
///   자리는 그대로 뺀다.
/// - 길이는 [block]의 길이이고, 빈 시간이 더 짧으면 할 일의 최소 조각([minChunkMinFor])까지 줄인다. 하루 최대
///   공부량이 남은 만큼으로도 줄인다.
/// - 빈 시간마다 가장 좋은 자리 하나를 [scoreSlot]으로 고르고(시작·끝에 붙이기, 선호 시간대 시작), 오늘에서
///   하루 멀어질 때마다 [PlanWeights.laterDay]를 깎아 점수가 높은 순서(같으면 이른 순서)로 늘어놓는다. 같은
///   두 시간 칸(달력 날짜와 짝수 시 시작 두 시간)에서는 하나만 고른다.
///
/// [days]가 1보다 작으면 [ArgumentError]다.
List<SlotOption> suggestSlots({
  required DateTime now,
  required PlanBlock block,
  required TaskEntry entry,
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
  int days = Defaults.planHorizonDays,
  int count = Defaults.alternativeSlotCount,
}) {
  if (days < 1) throw ArgumentError.value(days, 'days');
  final blockMin = block.endAt.difference(block.startAt).inMinutes;
  if (blockMin <= 0 || count < 1) return const [];
  final target = _Target(
    entry,
    excluded: {block.id},
    schedule: schedule,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
  );
  final minLen = math.min(blockMin, minChunkMinFor(entry.task.kind));
  final blocked = [
    ...withBlockGap([
      for (final other in target.others)
        if (other.status == PlanBlockStatus.suggested ||
            other.status == PlanBlockStatus.confirmed ||
            other.status == PlanBlockStatus.done)
          TimeSpan(other.startAt, other.endAt),
    ]),
    ...target.dismissed,
    TimeSpan(block.startAt, block.endAt),
  ];

  final options = <_Ranked>[];
  for (var i = 0; i < days; i++) {
    final day = target.day(i, config: config);
    if (day == null) break;
    final room = day.roomUnderCap(blockMin);
    if (room < minLen) continue;
    final lessons = day.lessons;
    final preferred = preferredSpans(
      day.date,
      config: config,
      dayBoundaryMin: dayBoundaryMin,
    );
    for (final free in day.free) {
      for (final segment in subtractSpans(free, blocked)) {
        final best = _bestIn(
          segment,
          maxMinutes: room,
          minMinutes: minLen,
          blockMin: blockMin,
          lessons: lessons,
          preferred: preferred,
        );
        if (best == null) continue;
        options.add(
          _Ranked(best.option, best.score - PlanWeights.laterDay * i),
        );
      }
    }
  }
  options.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : a.option.span.start.compareTo(b.option.span.start);
  });
  final cells = <DateTime>{};
  final picked = <SlotOption>[];
  for (final ranked in options) {
    final start = ranked.option.span.start;
    final cell = DateTime(
      start.year,
      start.month,
      start.day,
      start.hour - start.hour % 2,
    );
    if (!cells.add(cell)) continue;
    picked.add(ranked.option);
    if (picked.length == count) break;
  }
  return picked;
}

/// 02 홈 피드백 카드에서 [block]을 '못 했어요'라고 답한 뒤 [다시 놓기]가 놓을 자리. 없으면 null이다.
///
/// 길이는 [block]의 길이를 [Defaults.minChunkMin]–[Defaults.maxBlockMin](25분–2시간, 임시)으로 맞춘 것이다.
/// 오늘(논리적 하루) 지금 뒤 가장 이른 자리(5분 단위)를, 없으면 내일 가장 이른 자리를 고르고, 마감 전에
/// 끝나야 한다. 확정·완료 블록과는 [Defaults.blockGapMin]을 띄우고 그 할 일의 지운 자리는 빼며, 하루 최대
/// 공부량을 넘는 날은 건너뛴다. 제안 블록은 보지 않는다(다시 놓으면 다음 재계산이 제안을 새로 놓는다).
/// [schedule]은 오늘과 내일의 일정이다.
TimeSpan? retrySlot({
  required DateTime now,
  required PlanBlock block,
  required TaskEntry entry,
  required Schedule schedule,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) {
  final minutes = block.endAt
      .difference(block.startAt)
      .inMinutes
      .clamp(Defaults.minChunkMin, Defaults.maxBlockMin);
  final target = _Target(
    entry,
    excluded: {block.id},
    schedule: schedule,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
  );
  final blocked = [
    ...withBlockGap([
      for (final other in target.others)
        if (other.status == PlanBlockStatus.confirmed ||
            other.status == PlanBlockStatus.done)
          TimeSpan(other.startAt, other.endAt),
    ]),
    ...target.dismissed,
  ];
  // 오늘, 그다음 내일.
  for (var i = 0; i < 2; i++) {
    final day = target.day(i, config: config);
    if (day == null) return null;
    if (day.roomUnderCap(minutes) < minutes) continue;
    for (final free in day.free) {
      for (final segment in subtractSpans(free, blocked)) {
        final from = roundUpToFive(segment.start);
        final end = from.add(Duration(minutes: minutes));
        if (!end.isAfter(segment.end)) return TimeSpan(from, end);
      }
    }
  }
  return null;
}

/// 01 아침 브리핑에서 [entry]를 체크했을 때 놓을 오늘(논리적 하루) 자리. 없으면 null이다(docs/screens.md
/// '01 아침 브리핑').
///
/// [preferred](오늘 제안 시각)가 비었으면 그 자리, 아니면 지금 뒤 [minutes]가 한 번에 들어가는 가장 이른 자리
/// ([Defaults.maxBlockMin]까지, 5분 단위), 그다음 그 할 일의 최소 조각(25분, 영상·퀴즈 10분) 이상 들어가는 가장
/// 이른 자리(들어가는 만큼)다. [replaced]는 확정하면 지울 블록(오늘 시작 전인 자동 확정 블록과 전에 브리핑에서
/// 확정한 블록)이라 자리를 막지 않고, [taken]은 이 브리핑에서 이미 체크한 다른 것의 자리다. 남은 확정·완료
/// 블록과 [taken]은 [Defaults.blockGapMin]을 띄우고, 그 할 일의 지운 자리는 빼며, 마감 전·영상 공개 뒤·지금
/// 뒤만 본다. 하루 최대 공부량은 막지 않는다(넘으면 화면이 합계로 알림). [schedule]은 오늘의 일정이다.
///
/// 고른 자리의 이유는 배치 엔진과 같은 점수로 매기고([scoreSlot]), 근거를 새로 계산할 때 쓴다.
SlotOption? briefingSlot({
  required DateTime now,
  required TaskEntry entry,
  required int minutes,
  TimeSpan? preferred,
  required Schedule schedule,
  required Set<int> replaced,
  required List<TimeSpan> taken,
  required PlannerConfig config,
  required int dayBoundaryMin,
}) {
  if (minutes <= 0) throw ArgumentError.value(minutes, 'minutes');
  final target = _Target(
    entry,
    excluded: replaced,
    schedule: schedule,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
  );
  final day = target.day(0, config: config);
  if (day == null) return null;
  final blocked = [
    ...withBlockGap([
      for (final other in target.others)
        if (other.status == PlanBlockStatus.confirmed ||
            other.status == PlanBlockStatus.done)
          TimeSpan(other.startAt, other.endAt),
      ...taken,
    ]),
    ...target.dismissed,
  ];
  final segments = [
    for (final free in day.free) ...subtractSpans(free, blocked),
  ];
  final preferredSpansToday = preferredSpans(
    day.date,
    config: config,
    dayBoundaryMin: dayBoundaryMin,
  );
  SlotOption pick(TimeSpan segment, TimeSpan slot) {
    final scored = scoreSlot(
      segment: segment,
      slot: slot,
      whole: slot.minutes >= minutes,
      lessons: day.lessons,
      preferred: preferredSpansToday,
    );
    return SlotOption(
      span: slot,
      gapMin: segment.minutes,
      factor: scored.factor,
    );
  }

  if (preferred != null) {
    for (final segment in segments) {
      if (!preferred.start.isBefore(segment.start) &&
          !preferred.end.isAfter(segment.end)) {
        return pick(segment, preferred);
      }
    }
  }
  final whole = math.min(minutes, Defaults.maxBlockMin);
  for (final segment in segments) {
    final from = roundUpToFive(segment.start);
    final end = from.add(Duration(minutes: whole));
    if (!end.isAfter(segment.end)) return pick(segment, TimeSpan(from, end));
  }
  final least = minChunkMinFor(entry.task.kind);
  for (final segment in segments) {
    final from = roundUpToFive(segment.start);
    final until = roundDownToFive(segment.end);
    final room = until.difference(from).inMinutes;
    if (room < least) continue;
    return pick(
      segment,
      TimeSpan(from, from.add(Duration(minutes: math.min(whole, room)))),
    );
  }
  return null;
}

/// 자리를 찾을 블록과 그 할 일.
final class _Target {
  _Target._({
    required this.entry,
    required this.dayBoundaryMin,
    required this.today,
    required this.earliest,
    required this.dueDate,
    required this.others,
    required this.dismissed,
    required this.rest,
  });

  /// [excluded]는 일정에서 빼고 볼 블록(옮기거나 다시 놓을 블록, 브리핑이 바꿔 끼울 블록)의 id다.
  factory _Target(
    TaskEntry entry, {
    required Set<int> excluded,
    required Schedule schedule,
    required DateTime now,
    required int dayBoundaryMin,
  }) {
    final start = roundUpToFive(now);
    final openAt = entry.lmsItem?.openAt;
    final dueAt = entry.task.dueAt;
    final others = [
      for (final other in schedule.planBlocks)
        if (!excluded.contains(other.id)) other,
    ];
    return _Target._(
      entry: entry,
      dayBoundaryMin: dayBoundaryMin,
      today: logicalDate(now, dayBoundaryMin: dayBoundaryMin),
      earliest: openAt != null && openAt.isAfter(start)
          ? roundUpToFive(openAt)
          : start,
      dueDate: dueAt == null
          ? null
          : logicalDate(dueAt, dayBoundaryMin: dayBoundaryMin),
      others: others,
      dismissed: [
        for (final other in others)
          if (other.taskId == entry.task.id &&
              other.status == PlanBlockStatus.dismissed)
            TimeSpan(other.startAt, other.endAt),
      ],
      rest: Schedule(
        classSlots: schedule.classSlots,
        classExceptions: schedule.classExceptions,
        fixedBlocks: schedule.fixedBlocks,
        events: schedule.events,
        planBlocks: others,
      ),
    );
  }

  final TaskEntry entry;
  final int dayBoundaryMin;

  /// 오늘(논리적 하루)의 날짜.
  final DateTime today;

  /// 가장 이르게 놓을 수 있는 때(지금, 공개 전 영상은 공개 시각. 5분 단위로 올림).
  final DateTime earliest;

  /// 마감이 든 논리적 하루의 날짜. 마감이 없으면 null이다.
  final DateTime? dueDate;

  /// 뺀 블록을 뺀 블록.
  final List<PlanBlock> others;

  /// 이 할 일의 지운 블록 자리.
  final List<TimeSpan> dismissed;

  /// 뺀 블록을 뺀 일정.
  final Schedule rest;

  /// 오늘부터 [offset]일 뒤의 하루. 그날 시작 전에 마감이 지났으면 null이다.
  _Day? day(int offset, {required PlannerConfig config}) {
    final date = DateTime(today.year, today.month, today.day + offset);
    final start = logicalDayStart(date, dayBoundaryMin: dayBoundaryMin);
    final dueAt = entry.task.dueAt;
    if (dueAt != null && !dueAt.isAfter(start)) return null;
    final end = logicalDayEnd(date, dayBoundaryMin: dayBoundaryMin);
    final from = earliest.isAfter(start) ? earliest : start;
    final until = dueAt != null && dueAt.isBefore(end) ? dueAt : end;
    final availability = dayAvailability(
      date,
      schedule: rest,
      config: config,
      dayBoundaryMin: dayBoundaryMin,
      nightWindow: usesNightWindowOn(
        date,
        nightFrom: entry.task.nightWindowFrom,
        dueDate: dueDate,
      ),
    );
    final courseId = entry.task.courseIdWith(entry.lmsItem);
    var load = 0;
    for (final other in others) {
      if ((other.status == PlanBlockStatus.confirmed ||
              other.status == PlanBlockStatus.done) &&
          !other.startAt.isBefore(start) &&
          other.startAt.isBefore(end)) {
        load += other.endAt.difference(other.startAt).inMinutes;
      }
    }
    final window = TimeSpan(from, until);
    return _Day(
      date,
      free: window.end.isAfter(window.start)
          ? [for (final free in availability.free) ?free.intersection(window)]
          : const [],
      lessons: courseId == null
          ? const []
          : classesByCourse(availability, rest.classSlots)[courseId] ??
                const [],
      cap: config.forWeekday(date.weekday).dailyCapMin,
      load: load,
    );
  }
}

/// 자리를 찾는 하루 하나.
final class _Day {
  const _Day(
    this.date, {
    required this.free,
    required this.lessons,
    required this.cap,
    required this.load,
  });

  /// 논리적 하루의 날짜.
  final DateTime date;

  /// 지금(또는 공개 시각) 뒤, 마감 전의 빈 구간.
  final List<TimeSpan> free;

  /// 그날 그 할 일 과목의 수업.
  final List<TimeSpan> lessons;

  /// 하루 최대 공부량(분). 규칙이 없으면 null이다.
  final int? cap;

  /// 그날 시작하는 확정·완료 블록(옮기는 블록 제외)의 분.
  final int load;

  /// [minutes] 가운데 하루 최대 공부량 안에 들어가는 분.
  int roomUnderCap(int minutes) {
    final capMin = cap;
    return capMin == null ? minutes : math.min(minutes, capMin - load);
  }
}

/// 빈 시간 [segment]에서 가장 좋은 자리. 길이는 [blockMin]과 [maxMinutes]와 빈 시간 가운데 가장 짧은 것이고,
/// [minMinutes]보다 짧으면 null이다.
({SlotOption option, double score})? _bestIn(
  TimeSpan segment, {
  required int maxMinutes,
  required int minMinutes,
  required int blockMin,
  required List<TimeSpan> lessons,
  required List<TimeSpan> preferred,
}) {
  final from = roundUpToFive(segment.start);
  if (!segment.end.isAfter(from)) return null;
  final minutes = math.min(maxMinutes, segment.end.difference(from).inMinutes);
  if (minutes < minMinutes) return null;
  final duration = Duration(minutes: minutes);
  final starts = <DateTime>{
    from,
    roundDownToFive(segment.end.subtract(duration)),
    for (final span in preferred)
      if (span.end.isAfter(from) && span.start.isBefore(segment.end))
        _later(from, roundUpToFive(span.start)),
  };
  ({SlotOption option, double score})? best;
  for (final at in starts) {
    final slot = TimeSpan(at, at.add(duration));
    if (at.isBefore(from) || slot.end.isAfter(segment.end)) continue;
    final scored = scoreSlot(
      segment: segment,
      slot: slot,
      whole: minutes == blockMin,
      lessons: lessons,
      preferred: preferred,
    );
    final current = best;
    if (current == null ||
        scored.score > current.score ||
        (scored.score == current.score &&
            at.isBefore(current.option.span.start))) {
      best = (
        option: SlotOption(
          span: slot,
          gapMin: segment.minutes,
          factor: scored.factor,
        ),
        score: scored.score,
      );
    }
  }
  return best;
}

/// 점수를 매긴 다른 시간.
final class _Ranked {
  const _Ranked(this.option, this.score);

  final SlotOption option;
  final double score;
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
