import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 화면과 배치 엔진이 보는 할 일 한 줄: 할 일, 그 LMS 원본(LMS 할 일이면), 과목.
///
/// 저장된 상태와 LMS가 알려 준 것을 함께 봐야 끝냈는지·사라졌는지를 알 수 있어서 한 값으로 묶는다
/// (docs/architecture.md '폰 DB'의 동기화, docs/screens.md '03 할 일').
final class TaskEntry {
  const TaskEntry({required this.task, this.lmsItem, this.course});

  final Task task;

  /// [Task.lmsKey]가 가리키는 LMS 원본. 직접 넣은 할 일이거나 원본을 찾지 못하면 null.
  final LmsItem? lmsItem;

  /// 할 일의 과목([Task.courseIdWith]의 과목). 개인 할 일이거나 과목을 찾지 못하면 null.
  final Course? course;

  /// 끝낸 일. 사용자가 끝냈거나([TaskStatus.done]) LMS가 제출·출석 인정을 알려 줬다(`tasks.status`가
  /// `todo`여도).
  bool get isDone =>
      task.status == TaskStatus.done ||
      lmsItem?.submitted == true ||
      lmsItem?.officiallyDone == true;

  /// LMS에서 사라진 일(연속 미발견이 [Defaults.lmsGoneMissCount] 이상). 연결된 블록은 흐리게 그린다.
  bool get isGone => (lmsItem?.missCount ?? 0) >= Defaults.lmsGoneMissCount;

  /// 03 할 일에 남은 일: 숨기지 않았고, 끝내지 않았고, LMS에서 사라지지 않았다.
  bool get isRemaining =>
      task.status != TaskStatus.hidden && !isDone && !isGone;
}
