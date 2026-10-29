/// 할 일의 종류. [personal]을 뺀 값은 사캠 항목의 종류와 같다.
enum TaskKind {
  assignment,
  video,
  quiz,
  team,
  discussion,
  exam,
  material,
  personal,
}

/// 할 일의 상태. [hidden]은 사용자가 지운 사캠 할 일이다(행은 지우지 않는다).
enum TaskStatus { todo, done, hidden }

/// 할 일. `tasks` 표의 한 행.
///
/// 사캠 항목에서 만든 할 일은 [lmsKey]로 `lms_items`를 가리키고, 동기화는
/// [title]·[kind]·[dueAt]·[dueTimeUnknown]만 원본에서 다시 복사한다.
/// [estimateMin]·[spentMin]·[status]는 사용자 값이라 동기화가 바꾸지 않는다.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.kind,
    this.dueAt,
    required this.dueTimeUnknown,
    this.estimateMin,
    this.spentMin,
    required this.status,
    this.lmsKey,
  });

  final int id;

  final String title;

  final TaskKind kind;

  /// 마감. 날짜만 있으면 그날 23:59이고 [dueTimeUnknown]이 true다.
  final DateTime? dueAt;

  final bool dueTimeUnknown;

  /// 예상 작업 시간(분). 모르면 null.
  final int? estimateMin;

  /// 한 만큼(분). 블록을 완료하면 그 길이를 더한다.
  final int? spentMin;

  final TaskStatus status;

  /// `lms_items.remoteKey`. 직접 만든 할 일은 null.
  final String? lmsKey;
}
