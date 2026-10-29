/// 사캠 항목의 종류.
enum LmsItemKind { video, assignment, quiz, team, discussion, exam, material }

/// 사캠에서 받은 항목의 원본. `lms_items` 표의 한 행.
///
/// 동기화만 이 표를 바꾼다. 사용자의 계획은 `plan_blocks → tasks → lms_items` 순서로
/// 참조만 한다. 빠진 값(진도 없음 등)은 0이 아니라 null로 둔다.
class LmsItem {
  const LmsItem({
    required this.id,
    required this.remoteKey,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.kind,
    this.dueAt,
    required this.dueTimeUnknown,
    this.openAt,
    this.videoMin,
    this.requiredMin,
    this.watchedMin,
    this.officiallyDone,
    this.submitted,
    this.link,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.missCount,
    this.goneAt,
    required this.contentHash,
  });

  final int id;

  /// 학기·과목·종류·항목 ID를 `:`로 이은 원본 키. 표 안에서 겹치지 않는다.
  final String remoteKey;

  /// `courses.id`.
  final int courseId;

  final String courseName;

  final String title;

  final LmsItemKind kind;

  /// 마감. 날짜만 있으면 그날 23:59이고 [dueTimeUnknown]이 true다.
  final DateTime? dueAt;

  final bool dueTimeUnknown;

  /// 공개 시각. 미래면 배치 대상에서 뺀다.
  final DateTime? openAt;

  /// 영상 길이(분).
  final int? videoMin;

  /// 인정 시간(분).
  final int? requiredMin;

  /// 시청 시간(분).
  final int? watchedMin;

  /// 사캠의 공식 완료 여부.
  final bool? officiallyDone;

  /// 제출 여부.
  final bool? submitted;

  /// 항목 페이지 주소.
  final String? link;

  final DateTime firstSeenAt;

  final DateTime lastSeenAt;

  /// 연속으로 보이지 않은 동기화 수. 다시 보이면 0이다.
  final int missCount;

  /// 사캠에서 사라졌다고 본 시각.
  final DateTime? goneAt;

  /// 바뀌었는지 비교하는 해시.
  final String contentHash;
}
