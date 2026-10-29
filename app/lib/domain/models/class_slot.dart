/// 캠퍼스.
enum Campus { daedeok, boun }

/// 시간표 칸을 누가 채웠는지. [auto]는 통합정보시스템에서 받아 채운 값이다.
enum SlotSource { manual, auto }

/// 시간표의 수업 한 칸. `class_slots` 표의 한 행.
///
/// 시각은 자정 기준 분이다. 자정을 넘으면 [endMin]에 1440을 더해 한 행으로 적으므로
/// `endMin > startMin`이 늘 성립한다.
class ClassSlot {
  const ClassSlot({
    required this.id,
    required this.courseId,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.place,
    required this.campus,
    required this.online,
    this.repeatRule,
    required this.source,
  });

  final int id;

  /// `courses.id`.
  final int courseId;

  /// 수업이 시작하는 달력일의 요일. 1(월)–7(일).
  final int weekday;

  /// 시작 시각(자정 기준 분, 0–1439).
  final int startMin;

  /// 끝 시각(자정 기준 분).
  final int endMin;

  /// 강의실.
  final String? place;

  final Campus campus;

  /// 실시간 비대면 수업이면 true. 이때 수업 앞뒤 버퍼는 0이다.
  final bool online;

  /// (R1) 반복 규칙 JSON. 구조는 R1에서 정한다.
  final String? repeatRule;

  final SlotSource source;
}
