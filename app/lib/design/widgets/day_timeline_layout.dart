// 세로 하루 시간표의 자리 계산. docs/screens.md '02 홈'의 오늘 시간표·'09 일간'의 시간표.
//
// 최종 프로토타입의 규칙을 따른다(값은 임시).
// - 한 시간은 [TimelineMetrics.hourHeight]pt이고, 시각을 위치로 바꾼다. 카드는 시작 순서로 놓고, 앞 카드와
//   겹치면 그 아래로 민다(나란히 놓지 않음).
// - 카드 최소 높이는 할 일·수업·일정 [TimelineMetrics.cardMin], 이동·점심·빈 시간 [TimelineMetrics.softMin]이다.
//   빈 시간 카드는 그보다 낮아지면 그리지 않는다. 카드 높이에 따라 모양이 셋이다([TimelineCardMode]).
// - 이동은 15분 미만을 그리지 않고, '이동·점심 시간 표시'를 끄면 이동·점심을 그리지 않는다(자리는 그대로 비워
//   둠. 빈 시간 카드가 그 시간을 차지하지 않음).
// - 빈 시간 카드는 배치 엔진과 같은 빈 시간([DayAvailability.free])에서 [TimelineMetrics.freeMin]분 이상인
//   것만이고, 오늘은 지금 뒤만 센다.
// - 오늘은 끝난 항목을 접는다([TimelineLayout.pastCount], '지난 일정 N개 보기'). 펼치면 그날의 첫 항목(없으면
//   08시)부터 보인다. 시작 시각 줄은 지금과 첫 남은 항목 가운데 이른 시각의 시(時)부터, 끝은 하루 창 끝과 마지막
//   항목 가운데 늦은 쪽(최대 다음 날 01시)까지다.
// - 지금 선은 오늘이고 보이는 범위 안일 때만이며, 지금 선이 가리는 시 글자는 숨긴다.

import 'dart:math' as math;

import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';

/// 시간표의 크기 값(임시, 최종 프로토타입).
abstract final class TimelineMetrics {
  /// 한 시간의 높이(pt).
  static const double hourHeight = 60;

  /// 할 일·수업·일정 카드의 최소 높이.
  static const double cardMin = 44;

  /// 이동·점심·빈 시간 카드의 최소 높이.
  static const double softMin = 30;

  /// 카드 사이 간격.
  static const double gap = 4;

  /// 이 높이 이상이면 [TimelineCardMode.tall].
  static const double tallMin = 92;

  /// 이 높이 이상이면 [TimelineCardMode.mid].
  static const double midMin = 60;

  /// 빈 시간 카드로 보이는 최소 길이(분).
  static const int freeMin = 45;

  /// 이 길이(분)보다 짧은 이동은 그리지 않는다.
  static const int travelMin = 15;

  /// 지금 선이 시 글자를 가리는 거리(pt).
  static const double nowCover = 19;

  /// 시간표 아래 여백.
  static const double bottomPad = 14;

  /// 09 일간에서 빈 시간 카드의 가장 큰 높이. 그 아래 남은 빈 시간에는 'HH:MM에 놓기' 칸을 둔다.
  static const double freeCardMax = 112;

  /// 카드 아래 남은 높이가 이보다 클 때만 'HH:MM에 놓기' 칸을 둔다.
  static const double slotRoom = 40;
}

/// 카드의 모양. 높이로 정한다.
enum TimelineCardMode {
  /// 제목 한 줄과 오른쪽 시각.
  short,

  /// 제목과 한 줄의 덧붙임(종류·장소·시각).
  mid,

  /// 제목, 덧붙임, 줄 아래 시각.
  tall,
}

/// 시간표에 놓인 것 하나.
sealed class TimelineEntry {
  const TimelineEntry({required this.top, required this.height});

  final double top;
  final double height;
}

/// 항목 카드(수업·일정·고정 일정·할 일 블록).
final class TimelineCard extends TimelineEntry {
  const TimelineCard(
    this.item, {
    required super.top,
    required super.height,
    required this.mode,
    required this.past,
    required this.current,
  });

  final DayItem item;
  final TimelineCardMode mode;

  /// 이미 끝났다(지금 하는 것이 아님).
  final bool past;

  /// 지금 하는 중이다(진행 막대와 남은 분).
  final bool current;
}

/// 이동·점심 카드(흐린 작은 카드).
final class TimelineSoft extends TimelineEntry {
  const TimelineSoft(this.item, {required super.top, required super.height});

  /// [TravelItem]이나 [MealItem].
  final DayItem item;
}

/// 빈 시간 카드.
final class TimelineFree extends TimelineEntry {
  const TimelineFree(this.span, {required super.top, required super.height});

  /// 보이는 빈 시간(오늘은 지금 뒤).
  final TimeSpan span;
}

/// 09 일간 빈 시간 카드 아래의 'HH:MM에 놓기' 칸. [span]은 그 시(時)부터 그 빈 시간 끝까지다.
final class TimelineSlot extends TimelineEntry {
  const TimelineSlot(this.span, {required super.top, required super.height});

  final TimeSpan span;
}

/// 시 글자 하나.
final class TimelineHour {
  const TimelineHour({
    required this.hour,
    required this.top,
    required this.visible,
  });

  /// 0–23시(다음 날 01시는 1).
  final int hour;
  final double top;

  /// 지금 선에 가려 숨기면 false.
  final bool visible;
}

/// 시간표 하나의 자리 계산 결과.
final class TimelineLayout {
  const TimelineLayout({
    required this.entries,
    required this.hours,
    required this.height,
    required this.nowTop,
    required this.pastCount,
    required this.empty,
  });

  /// 그릴 것(위에서부터).
  final List<TimelineEntry> entries;
  final List<TimelineHour> hours;

  /// 시간표 전체 높이.
  final double height;

  /// 지금 선의 위치. 그리지 않으면 null이다.
  final double? nowTop;

  /// 접은 지난 항목 수('지난 일정 N개 보기'). 펼쳤거나 오늘이 아니면 0이다.
  final int pastCount;

  /// 수업·일정·고정 일정이 하나도 없다(빈 시간을 눌러 놓으라고 안내).
  final bool empty;
}

/// 논리적 하루 [day]의 시간표 자리를 계산한다. [items]는 `dayItems`, [free]는 그날의 빈 시간이다.
/// [windowEndMin]은 하루 창 끝(그날 0시 기준 분, 자정을 넘으면 1440 이상)이다. [today]면 [now]로 지난 항목을
/// 접고([showPast]면 펼침) 지금 선을 그린다. 시간표는 논리적 하루 전체를 보인다: 하루 경계([dayBoundaryMin],
/// 기본 04:00)부터 다음 날 하루 경계까지다(지난 항목을 접었으면 위는 지금 시각이나 남은 첫 항목부터).
TimelineLayout layoutDayTimeline({
  required DateTime day,
  required List<DayItem> items,
  required List<TimeSpan> free,
  required DateTime now,
  required bool today,
  required int windowEndMin,
  int dayBoundaryMin = 240,
  bool showPast = false,
  bool showTravelMeal = true,
  bool slots = false,
}) {
  final base = DateTime(day.year, day.month, day.day);
  int minuteOf(DateTime at) => at.difference(base).inMinutes;
  final nowMin = minuteOf(now);

  final kept = [
    for (final item in items)
      if (item is! TravelItem || item.span.minutes >= TimelineMetrics.travelMin)
        item,
  ];
  final visible = [
    for (final item in kept)
      if (showTravelMeal || (item is! TravelItem && item is! MealItem)) item,
  ];
  final collapse = today && !showPast;
  final boundaryHour = dayBoundaryMin ~/ 60;
  final firstLive = visible
      .where((item) => !today || minuteOf(item.span.end) > nowMin)
      .firstOrNull;
  var startHour = collapse
      ? math.min(
          (nowMin / 60).floor(),
          firstLive == null
              ? 22
              : (minuteOf(firstLive.span.start) / 60).floor(),
        )
      : math.min(
          boundaryHour,
          visible.isEmpty
              ? boundaryHour
              : (minuteOf(visible.first.span.start) / 60).floor(),
        );
  final lastEnd = kept.fold<int>(
    0,
    (latest, item) => math.max(latest, minuteOf(item.span.end)),
  );
  final endHour = math.max(
    math.max((windowEndMin / 60).ceil(), boundaryHour + 24),
    (lastEnd / 60).ceil(),
  );
  if (startHour >= endHour) startHour = endHour - 1;
  final top0 = startHour * 60;
  double toY(int minute) => (minute - top0) / 60 * TimelineMetrics.hourHeight;

  // 그릴 것: 항목과 빈 시간 카드를 시작 순서로.
  final stream = <({int start, int end, DayItem? item, TimeSpan? free})>[
    for (final item in visible)
      (
        start: minuteOf(item.span.start),
        end: minuteOf(item.span.end),
        item: item,
        free: null,
      ),
    for (final span in free)
      if (!today || span.end.isAfter(now))
        if (_from(span, today ? now : null) case final shown
            when shown.minutes >= TimelineMetrics.freeMin)
          (
            start: minuteOf(shown.start),
            end: minuteOf(shown.end),
            item: null,
            free: shown,
          ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final entries = <TimelineEntry>[];
  var lastBottom = -99.0;
  var pastCount = 0;
  for (final (index, entry) in stream.indexed) {
    final item = entry.item;
    if (collapse && entry.end <= nowMin) {
      if (item != null && item is! TravelItem && item is! MealItem) {
        pastCount++;
      }
      continue;
    }
    if (entry.free != null) {
      final top = math.max(
        toY(entry.start) + 3,
        lastBottom + TimelineMetrics.gap,
      );
      final full = toY(entry.end) - 3 - top;
      if (full < TimelineMetrics.softMin) continue;
      final height = slots ? math.min(full, TimelineMetrics.freeCardMax) : full;
      lastBottom = top + height;
      entries.add(TimelineFree(entry.free!, top: top, height: height));
      if (slots && full - height > TimelineMetrics.slotRoom) {
        // 카드 아래(6pt 띄움) 처음 오는 정시부터, 30분 넘게 남은 시마다 하나씩. 빈 시간 안에서 시작하는 다른
        // 카드(시간을 막지 않는 휴강 수업 등)는 줄인 카드 바로 아래로 오므로, 그 카드가 시작하는 시각까지만 둔다.
        var limit = entry.end;
        for (final later in stream.skip(index + 1)) {
          if (later.start >= entry.end) break;
          if (later.free == null) {
            limit = later.start;
            break;
          }
        }
        final below =
            top0 + (top + height + 6) / TimelineMetrics.hourHeight * 60;
        for (
          var hour = (below / 60).ceil() * 60;
          hour + 30 <= limit;
          hour += 60
        ) {
          final end = math.min(hour + 60, limit);
          entries.add(
            TimelineSlot(
              TimeSpan(base.add(Duration(minutes: hour)), entry.free!.end),
              top: toY(hour) + 3,
              height: toY(end) - toY(hour) - 6,
            ),
          );
        }
      }
      continue;
    }
    final top = math.max(toY(entry.start), lastBottom + TimelineMetrics.gap);
    if (item is TravelItem || item is MealItem) {
      final height = math.max(
        toY(entry.end) - top - TimelineMetrics.gap,
        TimelineMetrics.softMin,
      );
      lastBottom = top + height;
      entries.add(TimelineSoft(item!, top: top, height: height));
      continue;
    }
    final height = math.max(
      toY(entry.end) - top - TimelineMetrics.gap,
      TimelineMetrics.cardMin,
    );
    lastBottom = top + height;
    final current =
        today && entry.start <= nowMin && nowMin < entry.end && _real(item!);
    entries.add(
      TimelineCard(
        item!,
        top: top,
        height: height,
        mode: height >= TimelineMetrics.tallMin
            ? TimelineCardMode.tall
            : height >= TimelineMetrics.midMin
            ? TimelineCardMode.mid
            : TimelineCardMode.short,
        past: today && entry.end <= nowMin,
        current: current,
      ),
    );
  }
  // 지금 하는 것이 여럿이면 할 일 블록 → 수업 → 일정 순서로 하나만.
  final currents = entries.whereType<TimelineCard>().where((c) => c.current);
  if (currents.length > 1) {
    final keep = currents.reduce(
      (a, b) => _priority(a) <= _priority(b) ? a : b,
    );
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry is TimelineCard && entry.current && !identical(entry, keep)) {
        entries[i] = TimelineCard(
          entry.item,
          top: entry.top,
          height: entry.height,
          mode: entry.mode,
          past: entry.past,
          current: false,
        );
      }
    }
  }

  final nowVisible = today && nowMin >= top0 && nowMin <= endHour * 60;
  final nowTop = nowVisible ? toY(nowMin) : null;
  return TimelineLayout(
    entries: entries,
    hours: [
      for (var hour = startHour; hour <= endHour; hour++)
        TimelineHour(
          hour: hour % 24,
          top: (hour - startHour) * TimelineMetrics.hourHeight,
          visible:
              nowTop == null ||
              ((hour - startHour) * TimelineMetrics.hourHeight - nowTop)
                      .abs() >=
                  TimelineMetrics.nowCover,
        ),
    ],
    height:
        (endHour - startHour) * TimelineMetrics.hourHeight +
        TimelineMetrics.bottomPad,
    nowTop: nowTop,
    pastCount: pastCount,
    empty: !visible.any(
      (item) =>
          (item is ClassItem && !item.cancelled) ||
          item is EventItem ||
          item is FixedItem,
    ),
  );
}

/// [span]에서 [after] 뒤의 부분(없으면 그대로).
TimeSpan _from(TimeSpan span, DateTime? after) =>
    after != null && after.isAfter(span.start)
    ? TimeSpan(after, span.end)
    : span;

/// 지금 하는 것으로 볼 항목: 끝내지 않은 할 일 블록, 휴강하지 않은 수업, 일정, 고정 일정.
bool _real(DayItem item) => switch (item) {
  BlockItem(:final block) =>
    block.status != PlanBlockStatus.done &&
        block.status != PlanBlockStatus.missed,
  ClassItem(:final cancelled) => !cancelled,
  EventItem() || FixedItem() => true,
  TravelItem() || MealItem() => false,
};

int _priority(TimelineCard card) => switch (card.item) {
  BlockItem() => 0,
  ClassItem() => 1,
  _ => 2,
};
