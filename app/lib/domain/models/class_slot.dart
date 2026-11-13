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
    this.importedWeekday,
    this.importedStartMin,
    this.importedEndMin,
    this.importedPlace,
    this.placeEdited = false,
    this.onlineEdited = false,
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

  /// 통합정보시스템에서 불러온 원래 요일. 직접 넣은 수업이면 null이다. 13 시간표·고정 일정의
  /// '새로 고침'은 새로 불러온 값을 이 값과 견주어 학교 쪽에서 바뀐 것만 묻는다(docs/lms.md '시간표').
  final int? importedWeekday;

  /// 불러온 원래 시작 시각(자정 기준 분). [importedWeekday]·[importedEndMin]과 함께 있거나 함께 없다.
  final int? importedStartMin;

  /// 불러온 원래 끝 시각(자정 기준 분).
  final int? importedEndMin;

  /// 불러온 원래 강의실. 불러온 수업이어도 강의실이 없으면 null이다.
  final String? importedPlace;

  /// 사용자가 장소([place])를 고쳤는지. 새로 고침은 고친 장소를 덮어쓰지 않는다.
  final bool placeEdited;

  /// 사용자가 실시간 온라인([online])을 고쳤는지. 새로 고침은 고친 값을 덮어쓰지 않는다.
  final bool onlineEdited;
}
