import 'package:cnu_ai_assistant/domain/models/lms_item.dart';

/// 할 일의 종류. [personal]을 뺀 값은 LMS 항목의 종류와 같다.
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

/// 할 일의 상태. [hidden]은 사용자가 지운 LMS 할 일이다(행은 지우지 않는다).
enum TaskStatus { todo, done, hidden }

/// 할 일. `tasks` 표의 한 행.
///
/// LMS 항목에서 만든 할 일은 [lmsKey]로 `lms_items`를 가리키고, 동기화는
/// [title]·[kind]·[dueAt]·[dueTimeUnknown]만 원본에서 다시 복사한다.
/// [estimateMin]·[spentMin]·[status]는 사용자 값이라 동기화가 바꾸지 않는다. 할 일의 과목은
/// [courseIdWith]로 구한다.
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
    this.courseId,
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

  /// 06 AI 비서·직접 추가 폼에서 과목을 정해 만든 할 일의 과목(`courses.id`). LMS 할 일은 null로 두고
  /// 과목은 그 LMS 항목에서 읽는다(동기화가 쓰는 열을 늘리지 않음). 개인 할 일도 null이다.
  final int? courseId;

  /// 이 할 일의 과목 id. LMS 할 일은 [lmsKey]로 찾은 [lmsItem]의 과목이고(못 찾았으면 null), 그 밖에는
  /// [courseId]다. 예상 시간 규칙(`PlannerConfig.estimateMin`)과 03 할 일 줄의 과목이 이것을 쓴다.
  int? courseIdWith(LmsItem? lmsItem) {
    assert(
      lmsItem == null || lmsItem.remoteKey == lmsKey,
      'lmsItem must be the LMS item this task points to',
    );
    return lmsKey == null ? courseId : lmsItem?.courseId;
  }
}
