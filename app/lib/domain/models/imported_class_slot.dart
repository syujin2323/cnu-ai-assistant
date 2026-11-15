// 통합정보시스템에서 불러온 수업 칸. docs/lms.md '시간표 (통합정보시스템)'.

/// 통합정보시스템에서 불러온 수업 칸 하나(요일·시각·강의실).
final class ImportedClassSlot {
  const ImportedClassSlot({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.place,
  });

  /// 요일 1(월)–7(일).
  final int weekday;

  /// 시작·끝(자정 기준 분).
  final int startMin;
  final int endMin;

  /// 강의실. 없으면 null이다.
  final String? place;

  /// 요일·시작·끝이 [other]와 같은지(강의실은 보지 않음).
  bool sameTime(ImportedClassSlot other) =>
      weekday == other.weekday &&
      startMin == other.startMin &&
      endMin == other.endMin;

  @override
  bool operator ==(Object other) =>
      other is ImportedClassSlot && sameTime(other) && other.place == place;

  @override
  int get hashCode => Object.hash(weekday, startMin, endMin, place);
}
