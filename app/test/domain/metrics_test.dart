// 사용 지표 계산 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'의 지표.
//
// 보고할 논리적 하루는 2026-11-18(수)이고 하루 경계는 04:00이다(그날은 11/18 04:00부터 11/19 04:00 앞까지).

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/metrics.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final day = DateTime(2026, 11, 18);

DateTime at(int date, int hour, [int minute = 0, int second = 0]) =>
    DateTime(2026, 11, date, hour, minute, second);

var _id = 0;

/// 할 일 하나. [submitted]면 LMS가 제출을 알려 준 할 일, [gone]이면 LMS에서 사라진 할 일이다.
TaskEntry entry({
  DateTime? due,
  TaskStatus status = TaskStatus.todo,
  DateTime? completedAt,
  bool submitted = false,
  bool gone = false,
}) {
  final id = ++_id;
  final lms = submitted || gone;
  return TaskEntry(
    task: Task(
      id: id,
      title: '할 일 $id',
      kind: TaskKind.assignment,
      dueAt: due,
      dueTimeUnknown: false,
      status: status,
      completedAt: completedAt,
      lmsKey: lms ? 'k$id' : null,
    ),
    lmsItem: lms
        ? LmsItem(
            id: id,
            remoteKey: 'k$id',
            courseId: 1,
            courseName: '과목',
            title: '할 일 $id',
            kind: LmsItemKind.assignment,
            dueTimeUnknown: false,
            submitted: submitted,
            firstSeenAt: at(1, 9),
            lastSeenAt: at(1, 9),
            missCount: gone ? Defaults.lmsGoneMissCount : 0,
            contentHash: 'k$id',
          )
        : null,
  );
}

SyncRun run(DateTime startedAt, SyncTrigger trigger, SyncResultKind result) =>
    SyncRun(
      id: ++_id,
      startedAt: startedAt,
      trigger: trigger,
      scope: SyncScope.list,
      result: result,
      changedCount: 0,
      elapsedMs: 100,
    );

MetricsReport report({
  Briefing? briefing,
  bool suggested = false,
  List<TaskEntry> tasks = const [],
  List<SyncRun> syncRuns = const [],
  DateTime? installedAt,
  DateTime? lmsLastConnectedAt,
}) => metricsReport(
  day: day,
  dayBoundaryMin: 240,
  briefing: briefing,
  suggested: suggested,
  tasks: tasks,
  syncRuns: syncRuns,
  installedAt: installedAt,
  lmsLastConnectedAt: lmsLastConnectedAt,
);

void main() {
  group('metricsReport', () {
    test('브리핑을 보고 확정했으면 확정까지의 초와 수정 횟수를 담는다', () {
      final result = report(
        briefing: Briefing(
          id: 1,
          date: '2026-11-18',
          createdAt: at(18, 8, 30),
          openedAt: at(18, 8, 30),
          confirmedAt: at(18, 8, 31, 15),
          editCount: 3,
        ),
        suggested: true,
      );

      expect(result.date, '2026-11-18');
      expect(result.briefingOpened, isTrue);
      expect(result.todaySuggested, isTrue);
      expect(result.planConfirmed, isTrue);
      expect(result.confirmSeconds, 75);
      expect(result.editsBeforeConfirm, 3);
    });

    test('브리핑 기록이 없거나 확정하지 않았으면 확정 쪽은 비운다', () {
      final none = report();
      expect(none.briefingOpened, isFalse);
      expect(none.planConfirmed, isFalse);
      expect(none.confirmSeconds, isNull);
      expect(none.editsBeforeConfirm, 0);
      expect(none.todaySuggested, isFalse);

      final seen = report(
        briefing: Briefing(
          id: 1,
          date: '2026-11-18',
          createdAt: at(18, 9),
          openedAt: at(18, 9),
          editCount: 2,
        ),
      );
      expect(seen.briefingOpened, isTrue);
      expect(seen.planConfirmed, isFalse);
      expect(seen.confirmSeconds, isNull);
      expect(seen.editsBeforeConfirm, 2);
    });

    test('확정까지의 초와 수정 횟수는 서버의 범위로 자른다', () {
      final result = report(
        briefing: Briefing(
          id: 1,
          date: '2026-11-18',
          createdAt: at(18, 4),
          openedAt: at(18, 4),
          confirmedAt: at(20, 9),
          editCount: 5000,
        ),
      );
      expect(result.confirmSeconds, metricsSecondsMax);
      expect(result.editsBeforeConfirm, metricsCountMax);
    });

    test('놓친 마감은 그 논리적 하루에 마감이 있고 끝내지 않았거나 마감 뒤에 끝낸 할 일이다', () {
      final result = report(
        tasks: [
          // 셈: 끝내지 않음, 마감 뒤에 끝냄, 하루 경계 전 새벽(달력은 다음 날) 마감.
          entry(due: at(18, 23, 59)),
          entry(
            due: at(18, 18),
            status: TaskStatus.done,
            completedAt: at(18, 19),
          ),
          entry(due: at(19, 2)),
          // 세지 않음: 제때 끝냄, LMS 제출, 숨김, LMS에서 사라짐, 그날 밖, 마감 없음.
          entry(
            due: at(18, 18),
            status: TaskStatus.done,
            completedAt: at(18, 17),
          ),
          entry(due: at(18, 12), submitted: true),
          entry(due: at(18, 12), status: TaskStatus.hidden),
          entry(due: at(18, 12), gone: true),
          entry(due: at(19, 5)),
          entry(due: at(18, 3, 59)),
          entry(),
        ],
      );
      expect(result.missedDeadlines, 3);
    });

    test('동기화는 그 논리적 하루에 LMS를 부른 것을 계기마다 세고, 정상·빈 결과·일부를 성공으로 센다', () {
      final result = report(
        syncRuns: [
          run(at(18, 9), SyncTrigger.open, SyncResultKind.normal),
          run(at(18, 12), SyncTrigger.open, SyncResultKind.networkFailure),
          run(at(18, 15), SyncTrigger.periodic, SyncResultKind.empty),
          run(at(19, 2), SyncTrigger.background, SyncResultKind.partial),
          run(at(18, 20), SyncTrigger.manual, SyncResultKind.skipped),
          run(at(18, 21), SyncTrigger.manual, SyncResultKind.parseFailure),
          // 그날 밖.
          run(at(18, 3), SyncTrigger.login, SyncResultKind.normal),
          run(at(19, 4), SyncTrigger.login, SyncResultKind.normal),
        ],
      );
      expect(result.syncAttempts, {
        SyncTrigger.open: 2,
        SyncTrigger.periodic: 1,
        SyncTrigger.background: 1,
        SyncTrigger.manual: 1,
      });
      expect(result.syncSuccesses, {
        SyncTrigger.open: 1,
        SyncTrigger.periodic: 1,
        SyncTrigger.background: 1,
      });
    });

    test('설치 후 날 수와 마지막 LMS 로그인 뒤 날 수는 논리적 하루로 센다', () {
      final result = report(
        // 11/12 02:00은 하루 경계 전이라 11/11의 논리적 하루다.
        installedAt: at(12, 2),
        lmsLastConnectedAt: at(14, 10),
      );
      expect(result.installAgeDays, 7);
      expect(result.daysSinceLmsLogin, 4);

      expect(report(installedAt: at(18, 23)).installAgeDays, 0);
      expect(report().daysSinceLmsLogin, isNull);
      // 그날보다 뒤에 다시 로그인했으면 그날 기준의 값을 알 수 없어 0이다.
      expect(report(lmsLastConnectedAt: at(19, 9)).daysSinceLmsLogin, 0);
    });

    test('JSON은 서버의 키를 모두 담고 계기는 다섯 개 모두 적는다', () {
      final json = report(
        briefing: Briefing(
          id: 1,
          date: '2026-11-18',
          createdAt: at(18, 9),
          openedAt: at(18, 9),
        ),
        syncRuns: [run(at(18, 9), SyncTrigger.open, SyncResultKind.normal)],
        installedAt: at(17, 10),
      ).toJson();

      expect(json, {
        'date': '2026-11-18',
        'briefingOpened': 1,
        'todaySuggested': 0,
        'planConfirmed': 0,
        'confirmSeconds': null,
        'editsBeforeConfirm': 0,
        'missedDeadlines': 0,
        'syncAttempts': {
          'login': 0,
          'open': 1,
          'periodic': 0,
          'background': 0,
          'manual': 0,
        },
        'syncSuccesses': {
          'login': 0,
          'open': 1,
          'periodic': 0,
          'background': 0,
          'manual': 0,
        },
        'installAgeDays': 1,
        'daysSinceLmsLogin': null,
      });
    });
  });

  group('metricsDaysToSend', () {
    final today = DateTime(2026, 11, 19);

    test('앱을 쓴 지난 날 가운데 마지막으로 보낸 날 뒤, 6일 전부터를 오래된 순서로 고른다', () {
      expect(
        metricsDaysToSend(
          today: today,
          lastSentOn: '2026-11-13',
          activeDays: [
            '2026-11-18',
            '2026-11-10',
            '2026-11-13',
            '2026-11-17',
            '2026-11-19',
            '어제',
          ],
          installDay: DateTime(2026, 11, 1),
        ),
        [DateTime(2026, 11, 17), DateTime(2026, 11, 18)],
      );
    });

    test('보낸 적이 없으면 6일 전부터 고르되 설치한 날보다 앞은 고르지 않는다', () {
      final active = ['2026-11-12', '2026-11-13', '2026-11-15'];
      expect(
        metricsDaysToSend(
          today: today,
          lastSentOn: null,
          activeDays: active,
          installDay: null,
        ),
        [DateTime(2026, 11, 13), DateTime(2026, 11, 15)],
      );
      expect(
        metricsDaysToSend(
          today: today,
          lastSentOn: null,
          activeDays: active,
          installDay: DateTime(2026, 11, 14),
        ),
        [DateTime(2026, 11, 15)],
      );
    });

    test('오늘과 마지막으로 보낸 날까지는 고르지 않는다', () {
      expect(
        metricsDaysToSend(
          today: today,
          lastSentOn: '2026-11-18',
          activeDays: ['2026-11-18', '2026-11-19'],
          installDay: null,
        ),
        isEmpty,
      );
    });
  });
}
