// 할 일 모델 테스트. docs/architecture.md '폰 DB'의 tasks와 '도메인 기본값과 배치 엔진' 2단계(예상 시간).
//
// 할 일의 과목은 과목을 정해 만든 할 일이면 그 할 일의 과목, LMS 할 일이면 그 LMS 항목의 과목이다.

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 14, 9);

  LmsItem item(String remoteKey, int courseId) => LmsItem(
    id: 1,
    remoteKey: remoteKey,
    courseId: courseId,
    courseName: '과목A',
    title: '과제1',
    kind: LmsItemKind.assignment,
    dueTimeUnknown: false,
    firstSeenAt: at,
    lastSeenAt: at,
    missCount: 0,
    contentHash: 'hash1',
  );

  Task task({
    String? lmsKey,
    int? courseId,
    TaskKind kind = TaskKind.assignment,
  }) => Task(
    id: 1,
    title: '과제1',
    kind: kind,
    dueTimeUnknown: false,
    status: TaskStatus.todo,
    lmsKey: lmsKey,
    courseId: courseId,
  );

  group('courseIdWith', () {
    test('과목을 정해 만든 할 일은 그 과목이고, 개인 할 일은 null이다', () {
      expect(task(courseId: 7).courseIdWith(null), 7);
      expect(task(kind: TaskKind.personal).courseIdWith(null), isNull);
    });

    test('LMS 할 일은 그 LMS 항목의 과목이고, 항목을 못 찾았으면 null이다', () {
      const key = '1:7:assignment:1';
      expect(task(lmsKey: key).courseIdWith(item(key, 7)), 7);
      expect(task(lmsKey: key).courseIdWith(null), isNull);
    });

    test('LMS 할 일에 과목이 들어 있어도 LMS 항목의 과목을 쓴다', () {
      const key = '1:7:assignment:1';
      expect(task(lmsKey: key, courseId: 9).courseIdWith(item(key, 7)), 7);
      expect(task(lmsKey: key, courseId: 9).courseIdWith(null), isNull);
    });

    test('그 할 일이 가리키지 않는 LMS 항목을 넘기면 debug에서 알린다', () {
      expect(
        () => task(lmsKey: '1:7:assignment:1').courseIdWith(item('다른 키', 7)),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => task(courseId: 7).courseIdWith(item('1:7:assignment:1', 7)),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
