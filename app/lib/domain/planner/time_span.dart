// 배치 엔진의 중간 값: 시각 구간과 구간 연산. docs/architecture.md '폴더 구조'(`domain/planner/`의 작은 값 클래스).
//
// 빈 시간 계산(`free_slots.dart`)이 쓰는 연산을 공개해, 앞으로 02 홈의 끌어 놓기 판정, 11 주간의 제안 빼기, 옮기기
// 시트의 후보 찾기도 같은 연산을 쓰게 한다.

/// [start]부터 [end] 전까지의 구간. 둘 다 앱의 시각(한국 시각 벽시계 값, `domain/clock.dart`)이다. 빈 시간
/// 계산이 돌려주는 빈 구간은 늘 [end]가 [start]보다 늦고, 일정·블록으로 만든 바쁜 구간은 길이가 0 이하일 수
/// 있으며 계산에서 버린다.
final class TimeSpan {
  const TimeSpan(this.start, this.end);

  final DateTime start;

  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  /// [at]이 이 구간 안에 있는지. [start]는 들고 [end]는 들지 않는다.
  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);

  /// [other]와 겹치는 부분. 겹치지 않거나 맞닿기만 하면 null이다.
  TimeSpan? intersection(TimeSpan other) {
    final from = start.isAfter(other.start) ? start : other.start;
    final to = end.isBefore(other.end) ? end : other.end;
    return to.isAfter(from) ? TimeSpan(from, to) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is TimeSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeSpan($start, $end)';
}

/// [window]에서 [busy]를 빼고 남은 구간을 시작 순서로 돌려준다. 길이가 0이거나 거꾸로 된 바쁜 구간은
/// 무시하고, [busy]는 순서가 없어도 된다.
List<TimeSpan> subtractSpans(TimeSpan window, Iterable<TimeSpan> busy) {
  final sorted = busy.where((span) => span.end.isAfter(span.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final free = <TimeSpan>[];
  var cursor = window.start;
  for (final span in sorted) {
    if (!span.start.isBefore(window.end)) break;
    if (!span.end.isAfter(cursor)) continue;
    if (span.start.isAfter(cursor)) free.add(TimeSpan(cursor, span.start));
    cursor = span.end;
  }
  if (cursor.isBefore(window.end)) free.add(TimeSpan(cursor, window.end));
  return free;
}

/// [spans]를 시작 순서로 늘어놓고 겹치거나 맞닿은 구간을 하나로 합친다.
List<TimeSpan> mergeSpans(Iterable<TimeSpan> spans) {
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <TimeSpan>[];
  for (final span in sorted) {
    final last = merged.lastOrNull;
    if (last == null || span.start.isAfter(last.end)) {
      merged.add(span);
    } else if (span.end.isAfter(last.end)) {
      merged[merged.length - 1] = TimeSpan(last.start, span.end);
    }
  }
  return merged;
}

/// [spans]에서 [cut]과 겹치는 부분을 잘라 낸다. [cut]이 구간 가운데에 걸리면 그 구간은 둘로 나뉜다. 길이가
/// 0 이하인 [cut]은 아무것도 자르지 않는다.
List<TimeSpan> cutSpans(Iterable<TimeSpan> spans, TimeSpan cut) {
  if (!cut.end.isAfter(cut.start)) return [...spans];
  return [
    for (final span in spans) ...[
      if (span.start.isBefore(cut.start))
        TimeSpan(
          span.start,
          span.end.isBefore(cut.start) ? span.end : cut.start,
        ),
      if (span.end.isAfter(cut.end))
        TimeSpan(span.start.isAfter(cut.end) ? span.start : cut.end, span.end),
    ],
  ];
}

/// [spans]에서 [at] 전 부분을 잘라 낸다. [at]까지 끝나는 구간은 버리고, [at]에 걸친 구간은 [at]부터 남긴다.
/// 오늘 남은 빈 시간처럼 지금 이후만 볼 때 쓴다.
List<TimeSpan> spansFrom(Iterable<TimeSpan> spans, DateTime at) => [
  for (final span in spans)
    if (span.end.isAfter(at))
      span.start.isBefore(at) ? TimeSpan(at, span.end) : span,
];
