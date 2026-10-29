/// 과목. `courses` 표의 한 행.
///
/// 사캠 과목 목록에서 받거나 사용자가 직접 만든다. 동기화는 학기 값이 가장 최근인
/// 과목과 [name]이 같고 [remoteId]가 null인 행이 있으면 그 행에 [remoteId]와
/// [semester]를 채워 합친다(docs/architecture.md '폰 DB').
class Course {
  const Course({
    required this.id,
    this.remoteId,
    this.semester,
    required this.name,
    this.alias,
    this.color,
    this.lastSeenAt,
  });

  final int id;

  /// 사캠 과목 ID. 직접 만든 과목은 null.
  final String? remoteId;

  /// 사캠 과목 목록 응답의 학기 값 그대로. 직접 만든 과목은 null.
  final String? semester;

  final String name;

  /// 사용자가 부르는 짧은 이름(예: 자구).
  final String? alias;

  /// 과목 색(ARGB 32비트 정수). 쓰는 방식은 아직 정하지 않았다.
  final int? color;

  /// 동기화에서 마지막으로 본 시각.
  final DateTime? lastSeenAt;
}
