// 배치 엔진의 중간 값: 시각 구간. docs/architecture.md '폴더 구조'(`domain/planner/`의 작은 값 클래스).

/// [start]부터 [end] 전까지의 구간. 둘 다 기기 로컬 시각이다. 빈 시간 계산이 돌려주는 빈 구간은 늘 [end]가
/// [start]보다 늦고, 일정·블록으로 만든 바쁜 구간은 길이가 0 이하일 수 있으며 계산에서 버린다.
final class TimeSpan {
  const TimeSpan(this.start, this.end);

  final DateTime start;

  final DateTime end;

  int get minutes => end.difference(start).inMinutes;

  @override
  bool operator ==(Object other) =>
      other is TimeSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeSpan($start, $end)';
}
