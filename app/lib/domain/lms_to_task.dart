// LMS 항목을 할 일로 만드는 규칙. docs/architecture.md '폰 DB'의 동기화 문단.
//
// 동기화가 끝날 때마다 마지막 단계에서 부른다. `kind`가 자료가 아닌 LMS 항목마다 `lmsKey`가 같은 할 일(숨긴 할 일 포함)이
// 없으면 하나를 만들고(상태 `todo`), 있으면 제목·종류·마감·마감 시각 모름만 원본에서 다시 복사한다. 예상 시간·한 만큼·
// 상태·완료 시각 같은 사용자 값은 바꾸지 않고, 할 일의 과목은 `lms_items.courseId`를 읽으므로 넣지 않는다. 순수 함수라
// 같은 입력이면 늘 같은 결과이고, 바꿀 것이 없으면 빈 결과다. 쓰기는 동기화 저장소가 한 트랜잭션에서 한다.

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// LMS 항목에서 새로 만들 할 일.
final class LmsTaskDraft {
  const LmsTaskDraft({
    required this.lmsKey,
    required this.title,
    required this.kind,
    required this.dueAt,
    required this.dueTimeUnknown,
  });

  final String lmsKey;

  final String title;

  final TaskKind kind;

  final DateTime? dueAt;

  final bool dueTimeUnknown;

  @override
  bool operator ==(Object other) =>
      other is LmsTaskDraft &&
      other.lmsKey == lmsKey &&
      other.title == title &&
      other.kind == kind &&
      other.dueAt == dueAt &&
      other.dueTimeUnknown == dueTimeUnknown;

  @override
  int get hashCode => Object.hash(lmsKey, title, kind, dueAt, dueTimeUnknown);

  @override
  String toString() => 'LmsTaskDraft($lmsKey)';
}

/// 원본에서 다시 복사할 할 일의 네 열.
final class LmsTaskCopy {
  const LmsTaskCopy({
    required this.taskId,
    required this.title,
    required this.kind,
    required this.dueAt,
    required this.dueTimeUnknown,
  });

  final int taskId;

  final String title;

  final TaskKind kind;

  final DateTime? dueAt;

  final bool dueTimeUnknown;

  @override
  bool operator ==(Object other) =>
      other is LmsTaskCopy &&
      other.taskId == taskId &&
      other.title == title &&
      other.kind == kind &&
      other.dueAt == dueAt &&
      other.dueTimeUnknown == dueTimeUnknown;

  @override
  int get hashCode => Object.hash(taskId, title, kind, dueAt, dueTimeUnknown);

  @override
  String toString() => 'LmsTaskCopy(#$taskId)';
}

/// [tasksFromLmsItems]의 결과.
final class LmsTaskChanges {
  const LmsTaskChanges({this.inserts = const [], this.copies = const []});

  final List<LmsTaskDraft> inserts;

  final List<LmsTaskCopy> copies;

  bool get isEmpty => inserts.isEmpty && copies.isEmpty;
}

/// LMS 항목의 종류에 맞는 할 일 종류. 자료는 할 일로 만들지 않으므로 null이다.
TaskKind? taskKindOf(LmsItemKind kind) => switch (kind) {
  LmsItemKind.video => TaskKind.video,
  LmsItemKind.assignment => TaskKind.assignment,
  LmsItemKind.quiz => TaskKind.quiz,
  LmsItemKind.team => TaskKind.team,
  LmsItemKind.discussion => TaskKind.discussion,
  LmsItemKind.exam => TaskKind.exam,
  LmsItemKind.material => null,
};

/// LMS 항목 [items]와 지금 할 일 [tasks]로, 새로 만들 할 일과 다시 복사할 할 일을 구한다. [items]의 차례를 따른다.
LmsTaskChanges tasksFromLmsItems(
  Iterable<LmsItem> items,
  Iterable<Task> tasks,
) {
  final byKey = <String, Task>{for (final task in tasks) ?task.lmsKey: task};
  final inserts = <LmsTaskDraft>[];
  final copies = <LmsTaskCopy>[];
  final seen = <String>{};
  for (final item in items) {
    final kind = taskKindOf(item.kind);
    if (kind == null || !seen.add(item.remoteKey)) continue;
    final task = byKey[item.remoteKey];
    if (task == null) {
      inserts.add(
        LmsTaskDraft(
          lmsKey: item.remoteKey,
          title: item.title,
          kind: kind,
          dueAt: item.dueAt,
          dueTimeUnknown: item.dueTimeUnknown,
        ),
      );
    } else if (task.title != item.title ||
        task.kind != kind ||
        task.dueAt != item.dueAt ||
        task.dueTimeUnknown != item.dueTimeUnknown) {
      copies.add(
        LmsTaskCopy(
          taskId: task.id,
          title: item.title,
          kind: kind,
          dueAt: item.dueAt,
          dueTimeUnknown: item.dueTimeUnknown,
        ),
      );
    }
  }
  return LmsTaskChanges(inserts: inserts, copies: copies);
}
