// 수업 칸·고정 일정 값 검사 테스트. docs/architecture.md '폰 DB'의 공통 규칙.
//
// 폰 DB의 CHECK와 같은 값을 거절하는지는 test/data/db/database_test.dart의 'CHECK' 묶음이 본다.

import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('수업 칸', () {
    List<TimetableIssue> check(int weekday, int startMin, int endMin) =>
        checkClassSlot(weekday: weekday, startMin: startMin, endMin: endMin);

    test('요일 1–7, 시작 0–1439, 끝이 시작보다 늦고 하루보다 짧으면 통과한다', () {
      expect(check(1, 540, 600), isEmpty);
      expect(check(7, 0, 1), isEmpty);
      // 자정을 넘으면 끝에 1440을 더한다(22:00–02:00).
      expect(check(5, 1320, 1560), isEmpty);
      // 가장 긴 구간은 하루보다 1분 짧다.
      expect(check(3, 1439, 1439 + 1439), isEmpty);
    });

    test('요일이 1–7 밖이면 weekday다', () {
      expect(check(0, 540, 600), [TimetableIssue.weekday]);
      expect(check(8, 540, 600), [TimetableIssue.weekday]);
    });

    test('시작이 하루 밖이면 startMin이고 끝은 따로 보지 않는다', () {
      expect(check(1, -1, 60), [TimetableIssue.startMin]);
      expect(check(1, 1440, 1500), [TimetableIssue.startMin]);
    });

    test('끝이 시작보다 늦지 않거나 하루 이상 떨어지면 endMin이다', () {
      expect(check(1, 600, 600), [TimetableIssue.endMin]);
      expect(check(1, 600, 500), [TimetableIssue.endMin]);
      expect(check(1, 600, 600 + 1440), [TimetableIssue.endMin]);
    });

    test('여러 값이 틀리면 모두 알린다', () {
      expect(check(9, 600, 600), [
        TimetableIssue.weekday,
        TimetableIssue.endMin,
      ]);
    });
  });

  group('고정 일정', () {
    List<TimetableIssue> check({
      List<int> weekdays = const [1, 3, 5],
      int startMin = 720,
      int endMin = 780,
      int bufferMin = 10,
    }) => checkFixedBlock(
      weekdays: weekdays,
      startMin: startMin,
      endMin: endMin,
      bufferMin: bufferMin,
    );

    test('요일이 있고 겹치지 않으며 시각과 앞뒤 여유가 범위 안이면 통과한다', () {
      expect(check(), isEmpty);
      expect(check(weekdays: [7, 1]), isEmpty);
      expect(check(startMin: 1320, endMin: 1560), isEmpty);
      expect(check(bufferMin: TimetableLimits.bufferMin.low), isEmpty);
      expect(check(bufferMin: TimetableLimits.bufferMin.high), isEmpty);
    });

    test('요일이 없거나 1–7 밖이거나 겹치면 weekday다', () {
      expect(check(weekdays: []), [TimetableIssue.weekday]);
      expect(check(weekdays: [0]), [TimetableIssue.weekday]);
      expect(check(weekdays: [1, 8]), [TimetableIssue.weekday]);
      expect(check(weekdays: [2, 2]), [TimetableIssue.weekday]);
    });

    test('시각은 수업 칸과 같은 규칙이다', () {
      expect(check(startMin: 1440, endMin: 1500), [TimetableIssue.startMin]);
      expect(check(startMin: 720, endMin: 720), [TimetableIssue.endMin]);
      expect(check(startMin: 720, endMin: 2160), [TimetableIssue.endMin]);
    });

    test('앞뒤 여유가 0–60분 밖이면 bufferMin이다', () {
      expect(check(bufferMin: -1), [TimetableIssue.bufferMin]);
      expect(check(bufferMin: 61), [TimetableIssue.bufferMin]);
    });
  });
}
