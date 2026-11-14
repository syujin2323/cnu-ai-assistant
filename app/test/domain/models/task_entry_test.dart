import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 15, 9);

  Task task({TaskStatus status = TaskStatus.todo, String? lmsKey}) => Task(
    id: 1,
    title: '과제1',
    kind: TaskKind.assignment,
    dueTimeUnknown: false,
    status: status,
    lmsKey: lmsKey,
  );

  LmsItem item({bool? submitted, bool? officiallyDone, int missCount = 0}) =>
      LmsItem(
        id: 1,
        remoteKey: 'a:b:assignment:1',
        courseId: 1,
        courseName: '과목A',
        title: '과제1',
        kind: LmsItemKind.assignment,
        dueTimeUnknown: false,
        submitted: submitted,
        officiallyDone: officiallyDone,
        firstSeenAt: at,
        lastSeenAt: at,
        missCount: missCount,
        contentHash: 'h',
      );

  test('남은 일은 숨기지 않았고 끝내지 않았고 LMS에서 사라지지 않은 일이다', () {
    expect(TaskEntry(task: task()).isRemaining, isTrue);
    expect(TaskEntry(task: task(status: TaskStatus.done)).isRemaining, isFalse);
    expect(
      TaskEntry(task: task(status: TaskStatus.hidden)).isRemaining,
      isFalse,
    );
  });

  test('LMS가 제출·출석 인정을 알려 주면 상태가 todo여도 끝낸 일이다', () {
    const key = 'a:b:assignment:1';
    expect(
      TaskEntry(
        task: task(lmsKey: key),
        lmsItem: item(submitted: true),
      ).isDone,
      isTrue,
    );
    expect(
      TaskEntry(
        task: task(lmsKey: key),
        lmsItem: item(officiallyDone: true),
      ).isDone,
      isTrue,
    );
    expect(
      TaskEntry(
        task: task(lmsKey: key),
        lmsItem: item(submitted: false, officiallyDone: false),
      ).isDone,
      isFalse,
    );
  });

  test('연속 미발견이 기준 횟수가 되면 LMS에서 사라진 일이고 남은 일이 아니다', () {
    const key = 'a:b:assignment:1';
    final almost = TaskEntry(
      task: task(lmsKey: key),
      lmsItem: item(missCount: Defaults.lmsGoneMissCount - 1),
    );
    final gone = TaskEntry(
      task: task(lmsKey: key),
      lmsItem: item(missCount: Defaults.lmsGoneMissCount),
    );
    expect(almost.isGone, isFalse);
    expect(almost.isRemaining, isTrue);
    expect(gone.isGone, isTrue);
    expect(gone.isRemaining, isFalse);
  });
}
