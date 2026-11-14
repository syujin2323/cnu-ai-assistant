// LMS 항목을 할 일로 만드는 규칙 테스트. docs/architecture.md '폰 DB'의 동기화 문단.
//
// 자료가 아닌 항목마다 할 일이 없으면 만들고, 있으면(숨긴 할 일 포함) 제목·종류·마감·마감 시각 모름만 바뀐 때 다시 복사하며,
// 사용자 값은 건드리지 않는지 본다. 값은 모두 합성 값이다.

import 'package:cnu_ai_assistant/domain/lms_to_task.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

final _seen = DateTime(2026, 11, 15, 9);

LmsItem _item(
  String key, {
  LmsItemKind kind = LmsItemKind.assignment,
  String title = '과제',
  DateTime? dueAt,
  bool dueTimeUnknown = false,
}) => LmsItem(
  id: key.hashCode,
  remoteKey: key,
  courseId: 1,
  courseName: '과목A',
  title: title,
  kind: kind,
  dueAt: dueAt,
  dueTimeUnknown: dueTimeUnknown,
  firstSeenAt: _seen,
  lastSeenAt: _seen,
  missCount: 0,
  contentHash: 'h',
);

Task _task(
  int id,
  String? key, {
  TaskKind kind = TaskKind.assignment,
  String title = '과제',
  DateTime? dueAt,
  bool dueTimeUnknown = false,
  TaskStatus status = TaskStatus.todo,
}) => Task(
  id: id,
  title: title,
  kind: kind,
  dueAt: dueAt,
  dueTimeUnknown: dueTimeUnknown,
  status: status,
  lmsKey: key,
  estimateMin: 90,
);

void main() {
  final due = DateTime(2026, 11, 20, 23, 59);

  test('할 일이 없는 항목은 종류에 맞는 할 일로 만든다(자료는 빼고, 항목 차례대로)', () {
    final changes = tasksFromLmsItems([
      _item('a', kind: LmsItemKind.video, title: '영상', dueAt: due),
      _item('m', kind: LmsItemKind.material),
      _item('b', kind: LmsItemKind.exam, dueTimeUnknown: true),
    ], const []);
    expect(changes.inserts, [
      LmsTaskDraft(
        lmsKey: 'a',
        title: '영상',
        kind: TaskKind.video,
        dueAt: due,
        dueTimeUnknown: false,
      ),
      const LmsTaskDraft(
        lmsKey: 'b',
        title: '과제',
        kind: TaskKind.exam,
        dueAt: null,
        dueTimeUnknown: true,
      ),
    ]);
    expect(changes.copies, isEmpty);
  });

  test('있는 할 일(숨긴 할 일 포함)은 네 열이 바뀐 때만 다시 복사하고 새로 만들지 않는다', () {
    final changes = tasksFromLmsItems(
      [
        _item('same', dueAt: due),
        _item('title', title: '새 제목', dueAt: due),
        _item('kind', kind: LmsItemKind.quiz),
        _item('due', dueAt: due.add(const Duration(days: 1))),
        _item('unknown', dueAt: due, dueTimeUnknown: true),
        _item('hidden', title: '바뀜'),
      ],
      [
        _task(1, 'same', dueAt: due),
        _task(2, 'title', dueAt: due),
        _task(3, 'kind'),
        _task(4, 'due', dueAt: due),
        _task(5, 'unknown', dueAt: due),
        _task(6, 'hidden', status: TaskStatus.hidden),
        _task(7, null),
      ],
    );
    expect(changes.inserts, isEmpty);
    expect(changes.copies, [
      LmsTaskCopy(
        taskId: 2,
        title: '새 제목',
        kind: TaskKind.assignment,
        dueAt: due,
        dueTimeUnknown: false,
      ),
      const LmsTaskCopy(
        taskId: 3,
        title: '과제',
        kind: TaskKind.quiz,
        dueAt: null,
        dueTimeUnknown: false,
      ),
      LmsTaskCopy(
        taskId: 4,
        title: '과제',
        kind: TaskKind.assignment,
        dueAt: due.add(const Duration(days: 1)),
        dueTimeUnknown: false,
      ),
      LmsTaskCopy(
        taskId: 5,
        title: '과제',
        kind: TaskKind.assignment,
        dueAt: due,
        dueTimeUnknown: true,
      ),
      const LmsTaskCopy(
        taskId: 6,
        title: '바뀜',
        kind: TaskKind.assignment,
        dueAt: null,
        dueTimeUnknown: false,
      ),
    ]);
  });

  test('마감이 없어지면 마감 없음으로 다시 복사한다', () {
    final changes = tasksFromLmsItems(
      [_item('a')],
      [_task(1, 'a', dueAt: due)],
    );
    expect(changes.copies.single.dueAt, isNull);
  });

  test('같은 원본 키가 두 번 오면 처음 것만 쓰고, 바꿀 것이 없으면 빈 결과다', () {
    final changes = tasksFromLmsItems([
      _item('a', title: '처음'),
      _item('a', title: '나중'),
    ], const []);
    expect(changes.inserts.single.title, '처음');
    final none = tasksFromLmsItems([_item('a')], [_task(1, 'a')]);
    expect(none.isEmpty, isTrue);
    expect(tasksFromLmsItems(const [], const []).isEmpty, isTrue);
  });

  test('taskKindOf는 자료만 null이고 나머지는 같은 이름의 종류다', () {
    for (final kind in LmsItemKind.values) {
      final taskKind = taskKindOf(kind);
      if (kind == LmsItemKind.material) {
        expect(taskKind, isNull);
      } else {
        expect(taskKind?.name, kind.name);
      }
    }
  });
}
