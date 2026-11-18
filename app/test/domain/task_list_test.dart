// 03 할 일 목록 계산의 테스트. docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-16(월) 10:00.
final now = DateTime(2026, 11, 16, 10);

DateTime at(int month, int day, [int hour = 23, int minute = 59]) =>
    DateTime(2026, month, day, hour, minute);

final config = PlannerConfig.from(const []);

/// 개인 할 일.
TaskEntry personal(
  int id, {
  DateTime? due,
  String? title,
  TaskKind kind = TaskKind.personal,
  EntrySource source = EntrySource.manual,
  Course? course,
  int? estimateMin,
  int? spentMin,
  String? deferredUntil,
  TaskStatus status = TaskStatus.todo,
}) => TaskEntry(
  task: Task(
    id: id,
    title: title ?? '개인 $id',
    kind: kind,
    dueAt: due,
    dueTimeUnknown: false,
    estimateMin: estimateMin,
    spentMin: spentMin,
    status: status,
    courseId: course?.id,
    source: source,
    deferredUntil: deferredUntil,
  ),
  course: course,
);

/// LMS 할 일. [courseName]이 null이면 원본도 과목도 없는 할 일이다.
TaskEntry lms(
  int id, {
  DateTime? due,
  TaskKind kind = TaskKind.assignment,
  String? courseName = '자료구조',
  DateTime? openAt,
  int? videoMin,
  int? requiredMin,
  bool? submitted,
  int missCount = 0,
  int? estimateMin,
  TaskStatus status = TaskStatus.todo,
}) {
  final key = 'lms-$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: 'LMS $id',
      kind: kind,
      dueAt: due,
      dueTimeUnknown: false,
      estimateMin: estimateMin,
      status: status,
      lmsKey: key,
    ),
    lmsItem: courseName == null
        ? null
        : LmsItem(
            id: id,
            remoteKey: key,
            courseId: courseName.hashCode,
            courseName: courseName,
            title: 'LMS $id',
            kind: LmsItemKind.values.byName(kind.name),
            dueAt: due,
            dueTimeUnknown: false,
            openAt: openAt,
            videoMin: videoMin,
            requiredMin: requiredMin,
            submitted: submitted,
            firstSeenAt: at(11, 1, 9),
            lastSeenAt: at(11, 16, 9),
            missCount: missCount,
            contentHash: key,
          ),
  );
}

PlanBlock block(
  int id,
  int taskId,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.auto,
);

LmsItemChange dueChange(int id, DateTime before, {DateTime? changedAt}) =>
    LmsItemChange(
      id: id,
      remoteKey: 'lms-$id',
      field: LmsItemChangeField.dueAt,
      oldValue: encodeDateTime(before),
      newValue: null,
      changedAt: changedAt ?? at(11, 15, 9),
    );

TaskListContent content(
  List<TaskEntry> entries, {
  List<PlanBlock> blocks = const [],
  List<Shortage> shortages = const [],
  Map<String, LmsItemChange> dueChanges = const {},
  bool hasClassSlots = true,
  bool weekly = false,
  bool lmsOnly = false,
  TaskListSort sort = TaskListSort.due,
  DateTime? when,
  Set<int> unchecked = const {},
}) => taskListContent(
  entries: entries,
  blocks: blocks,
  shortages: shortages,
  dueChanges: dueChanges,
  config: config,
  hasClassSlots: hasClassSlots,
  now: when ?? now,
  dayBoundaryMin: Defaults.dayBoundaryMin,
  weekly: weekly,
  lmsOnly: lmsOnly,
  sort: sort,
  uncheckedCourseIds: unchecked,
);

List<int> ids(TaskListContent list) => [
  for (final group in list.groups)
    for (final row in group.rows) row.taskId,
];

TaskRow rowOf(TaskListContent list, int id) => list.groups
    .expand((group) => group.rows)
    .firstWhere((row) => row.taskId == id);

void main() {
  group('탭과 숫자', () {
    final entries = [
      lms(1, due: at(11, 17)),
      lms(2, due: at(11, 30)),
      lms(3, due: at(11, 14)),
      personal(4, due: at(11, 18)),
      personal(5),
      lms(6, due: at(11, 17), status: TaskStatus.done),
      lms(7, due: at(11, 17), submitted: true),
      lms(8, due: at(11, 17), missCount: Defaults.lmsGoneMissCount),
      personal(9, due: at(11, 17), status: TaskStatus.hidden),
    ];

    test('주간은 7일 안 마감과 지난 마감, 전체는 남은 할 일 전부다', () {
      final weekly = content(entries, weekly: true);
      expect(ids(weekly), [3, 1, 4]);
      expect(weekly.weeklyCount, 3);
      expect(weekly.allCount, 5);
      final all = content(entries);
      expect(ids(all), [3, 1, 4, 2, 5]);
      expect(all.empty, isNull);
    });

    test("'LMS만'은 숫자에서 개인 할 일을 빼고 그 줄은 접는다", () {
      final list = content(entries, lmsOnly: true);
      expect(list.weeklyCount, 2);
      expect(list.allCount, 3);
      expect(ids(list), [3, 1, 4, 2, 5]);
      expect(rowOf(list, 4).folded, isTrue);
      expect(rowOf(list, 5).folded, isTrue);
      expect(rowOf(list, 1).folded, isFalse);
      expect(
        content(entries).groups.expand((g) => g.rows).any((r) => r.folded),
        isFalse,
      );
    });
  });

  group('정렬과 묶음', () {
    test('마감순은 지난 마감부터, 같은 마감이면 영상이 뒤, 마감 없는 일은 마감 없음 묶음이다', () {
      final list = content([
        personal(1),
        lms(2, due: at(11, 18), kind: TaskKind.video),
        lms(3, due: at(11, 18)),
        lms(4, due: at(11, 10)),
        lms(5),
      ]);
      expect(list.groups.map((g) => g.kind), [
        TaskGroupKind.due,
        TaskGroupKind.noDue,
      ]);
      expect(list.groups.first.title, isNull);
      expect(list.groups.first.rows.map((r) => r.taskId), [4, 3, 2]);
      expect(list.groups.last.title, '마감 없음');
      expect(list.groups.last.rows.map((r) => r.taskId), [1, 5]);
    });

    test('주간 탭에는 마감 없음 묶음이 없다', () {
      final list = content([
        personal(1),
        lms(2, due: at(11, 18)),
      ], weekly: true);
      expect(list.groups.map((g) => g.kind), [TaskGroupKind.due]);
    });

    test('과목별은 급한 과목부터 묶고 개인은 늘 마지막이다', () {
      final os = Course(id: 9, name: '운영체제');
      final list = content([
        personal(1, due: at(11, 15)),
        lms(2, due: at(11, 20), courseName: '선형대수'),
        lms(3, due: at(11, 17)),
        lms(4, due: at(11, 25), courseName: '선형대수'),
        personal(5, due: at(11, 19), kind: TaskKind.quiz, course: os),
        lms(6, due: at(11, 21), courseName: null),
      ], sort: TaskListSort.course);
      expect(
        [for (final g in list.groups) (g.kind, g.title, g.rows.length)],
        [
          (TaskGroupKind.course, '자료구조', 1),
          (TaskGroupKind.course, '운영체제', 1),
          (TaskGroupKind.course, '선형대수', 2),
          (TaskGroupKind.course, 'LMS', 1),
          (TaskGroupKind.personal, '개인', 1),
        ],
      );
    });

    test('과목별에서도 마감 없는 일은 묶음 안 맨 뒤이고 묶음 차례를 앞당기지 않는다', () {
      final list = content([
        lms(1),
        lms(2, due: at(11, 20), courseName: '선형대수'),
        lms(3, due: at(11, 22)),
        lms(4, courseName: '운영체제'),
      ], sort: TaskListSort.course);
      expect([for (final g in list.groups) g.title], ['선형대수', '자료구조', '운영체제']);
      expect(list.groups[1].rows.map((r) => r.taskId), [3, 1]);
    });

    test("'LMS만'이면 개인 묶음의 수는 0이다", () {
      final list = content(
        [personal(1, due: at(11, 17)), lms(2, due: at(11, 18))],
        sort: TaskListSort.course,
        lmsOnly: true,
      );
      expect(list.groups.last.kind, TaskGroupKind.personal);
      expect(list.groups.last.shownCount, 0);
      expect(list.groups.first.shownCount, 1);
    });
  });

  group('요약 줄', () {
    test('주간은 7일 뒤 날짜와 그 안 마감의 남은 시간이다', () {
      final list = content([
        lms(1, due: at(11, 17)),
        lms(2, due: at(11, 19), kind: TaskKind.quiz),
        lms(3, due: at(11, 14)),
      ], weekly: true);
      expect(list.summary, '11월 23일 (월)까지 · 남은 일 약 2시간');
      expect(content(const [], weekly: true).summary, '11월 23일 (월)까지');
    });

    test('전체는 7일 안 마감 수이고, 지난 마감과 오늘 이미 지난 마감은 세지 않는다', () {
      final list = content([
        lms(1, due: at(11, 23)),
        lms(2, due: at(11, 16, 9)),
        lms(3, due: at(11, 30)),
        personal(4, due: at(11, 18), estimateMin: 20),
      ]);
      expect(list.summary, '7일 안 마감 2개 · 남은 일 약 1시간');
      expect(content([lms(1, due: at(11, 30))]).summary, '7일 안 마감은 없어요');
    });

    test("'LMS만'이면 LMS 할 일 수를 앞에 붙이고 LMS 할 일로만 센다", () {
      final list = content([
        lms(1, due: at(11, 17), kind: TaskKind.quiz),
        personal(2, due: at(11, 18)),
      ], lmsOnly: true);
      expect(list.summary, 'LMS 할 일 1개 · 7일 안 마감 1개 · 남은 일 1시간 미만');
    });
  });

  group('빈 화면', () {
    test('남은 할 일이 없으면 nothing이다', () {
      expect(content(const []).empty, TaskListEmpty.nothing);
      expect(content(const [], weekly: true).empty, TaskListEmpty.nothing);
    });

    test('주간이 비었는데 전체에 있으면 notThisWeek와 전체 수다', () {
      final list = content([
        lms(1, due: at(11, 30)),
        personal(2),
      ], weekly: true);
      expect(list.empty, TaskListEmpty.notThisWeek);
      expect(list.otherCount, 2);
    });

    test("'LMS만'인데 이 탭에 개인 할 일만 있으면 noLmsTasks와 그 수다", () {
      final list = content(
        [personal(1, due: at(11, 17)), personal(2, due: at(11, 18))],
        weekly: true,
        lmsOnly: true,
      );
      expect(list.empty, TaskListEmpty.noLmsTasks);
      expect(list.otherCount, 2);
      expect(ids(list), [1, 2]);
    });

    test("'LMS만'이고 이 탭에 아무것도 없으면 LMS 할 일이 다른 탭에 있을 때만 notThisWeek다", () {
      final elsewhere = content(
        [lms(1, due: at(11, 30)), personal(2)],
        weekly: true,
        lmsOnly: true,
      );
      expect(elsewhere.empty, TaskListEmpty.notThisWeek);
      expect(elsewhere.otherCount, 1);
      final none = content([personal(1)], weekly: true, lmsOnly: true);
      expect(none.empty, TaskListEmpty.nothing);
    });
  });

  group('줄', () {
    test('머리: 개인, AI 비서로 추가, 과목과 종류, 과목별 정렬에서는 과목을 뺀다', () {
      final ds = Course(id: 3, name: '데이터베이스');
      final entries = [
        personal(1, due: at(11, 17)),
        personal(2, due: at(11, 17), source: EntrySource.ai),
        lms(3, due: at(11, 17), kind: TaskKind.quiz),
        personal(
          4,
          due: at(11, 17),
          kind: TaskKind.team,
          course: ds,
          source: EntrySource.ai,
        ),
        lms(5, due: at(11, 17), courseName: null),
      ];
      final byDue = content(entries);
      expect(
        [
          for (final id in [1, 2, 3, 4, 5]) rowOf(byDue, id).kicker,
        ],
        ['개인', '개인 · AI 비서로 추가', '자료구조 · 퀴즈', '데이터베이스 · 팀플', 'LMS 할 일'],
      );
      final byCourse = content(entries, sort: TaskListSort.course);
      expect(
        [
          for (final id in [1, 2, 3, 4, 5]) rowOf(byCourse, id).kicker,
        ],
        ['직접 추가', 'AI 비서로 추가', '퀴즈', '팀플', '과제'],
      );
    });

    test('마감 문구와 붉은 표시는 오늘·내일만이다(지난 마감은 붉게 쓰지 않음)', () {
      final list = content([
        lms(1, due: at(11, 17)),
        lms(2, due: at(11, 18)),
        lms(3, due: at(11, 25)),
        lms(4, due: at(11, 15)),
      ]);
      expect(rowOf(list, 1).due, '내일 23:59 마감');
      expect(rowOf(list, 1).dueUrgent, isTrue);
      expect(rowOf(list, 2).dueUrgent, isFalse);
      expect(rowOf(list, 3).due, '11월 25일 (수) 23:59 마감');
      expect(rowOf(list, 4).due, '어제 23:59 마감');
      expect(rowOf(list, 4).dueUrgent, isFalse);
    });

    test('지난 마감은 안내만 두고 계획 줄을 두지 않는다', () {
      final list = content([
        lms(1, due: at(11, 15)),
        personal(2, due: at(11, 16, 9)),
      ]);
      expect(rowOf(list, 1).note?.kind, TaskNoteKind.overdue);
      expect(rowOf(list, 1).note?.text, '마감이 지났어요 · LMS에서 확인해 주세요');
      expect(rowOf(list, 1).plan, isNull);
      expect(rowOf(list, 2).note?.text, '마감이 지났어요 · 끝냈다면 체크해 주세요');
    });

    test('공개 전 LMS 할 일은 열리는 때를 안내하고 영상 길이와 계획 줄을 두지 않는다', () {
      final list = content([
        lms(
          1,
          due: at(11, 20),
          kind: TaskKind.video,
          openAt: at(11, 17, 9, 0),
          videoMin: 40,
        ),
        lms(
          2,
          due: at(11, 20),
          kind: TaskKind.video,
          openAt: at(11, 16, 9, 0),
          videoMin: 40,
        ),
      ]);
      final closed = rowOf(list, 1);
      expect(closed.note?.kind, TaskNoteKind.opens);
      expect(closed.note?.text, '내일 09:00에 열려요');
      expect(closed.video, isNull);
      expect(closed.plan, isNull);
      expect(rowOf(list, 2).note, isNull);
      expect(rowOf(list, 2).video, '영상 40분');
    });

    test('영상 길이는 출석 인정 시간을 먼저 쓰고 모르면 그렇게 적는다', () {
      final list = content([
        lms(
          1,
          due: at(11, 20),
          kind: TaskKind.video,
          requiredMin: 50,
          videoMin: 60,
        ),
        lms(
          2,
          due: at(11, 20),
          kind: TaskKind.video,
          requiredMin: 50,
          videoMin: 50,
        ),
        lms(3, due: at(11, 20), kind: TaskKind.video, requiredMin: 50),
        lms(4, due: at(11, 20), kind: TaskKind.video),
        lms(5, due: at(11, 20)),
      ]);
      expect(rowOf(list, 1).video, '출석 인정 50분 · 영상 60분');
      expect(rowOf(list, 2).video, '출석 인정 50분');
      expect(rowOf(list, 3).video, '출석 인정 50분');
      expect(rowOf(list, 4).video, '영상 길이는 아직 몰라요');
      expect(rowOf(list, 5).video, isNull);
    });

    test('마감 변경은 날짜가 바뀐 LMS 할 일에 7일 동안 보인다', () {
      final entries = [
        lms(1, due: at(11, 20)),
        lms(2, due: at(11, 20)),
        lms(3, due: at(11, 20)),
        lms(4, due: at(11, 20)),
        lms(5, due: at(11, 21)),
        lms(6, due: at(11, 20)),
      ];
      final list = content(
        entries,
        dueChanges: {
          'lms-1': dueChange(1, at(11, 18)),
          'lms-2': dueChange(2, at(11, 21)),
          'lms-3': dueChange(3, at(11, 20, 9, 0)),
          'lms-4': dueChange(4, at(11, 18), changedAt: at(11, 8, 9, 0)),
          // 24:00 마감(다음 날 00:00)은 전날 마감과 같은 날이다.
          'lms-5': dueChange(5, DateTime(2026, 11, 22)),
          'lms-6': dueChange(6, at(11, 15)),
        },
      );
      expect(rowOf(list, 1).dueChange, '마감이 이틀 늦춰졌어요');
      expect(rowOf(list, 2).dueChange, '마감이 하루 당겨졌어요');
      expect(rowOf(list, 3).dueChange, isNull);
      expect(rowOf(list, 4).dueChange, isNull);
      expect(rowOf(list, 5).dueChange, isNull);
      expect(rowOf(list, 6).dueChange, '마감이 5일 늦춰졌어요');
    });
  });

  group('계획 줄', () {
    test('확정 블록이 지금이면 하는 중이고 끝이 자정이면 24:00이다', () {
      final list = content(
        [lms(1, due: at(11, 18)), lms(2, due: at(11, 18))],
        blocks: [
          block(1, 1, at(11, 16, 9, 30), at(11, 16, 11, 0)),
          block(2, 2, at(11, 16, 9, 0), DateTime(2026, 11, 17)),
        ],
      );
      expect(rowOf(list, 1).plan?.kind, TaskPlanKind.now);
      expect(rowOf(list, 1).plan?.text, '지금 하는 중 · 11:00까지');
      expect(rowOf(list, 2).plan?.text, '지금 하는 중 · 24:00까지');
    });

    test('다음 블록의 날·시각과 횟수, 제안과 확정을 쓴다', () {
      final list = content(
        [lms(1, due: at(11, 20)), lms(2, due: at(11, 20))],
        blocks: [
          block(
            1,
            1,
            at(11, 17, 14, 0),
            at(11, 17, 15, 0),
            status: PlanBlockStatus.suggested,
          ),
          block(2, 2, at(11, 18, 9, 0), at(11, 18, 10, 0)),
          block(3, 2, at(11, 16, 13, 0), at(11, 16, 14, 0)),
          block(
            4,
            2,
            at(11, 19, 9, 0),
            at(11, 19, 10, 0),
            status: PlanBlockStatus.suggested,
          ),
        ],
      );
      expect(rowOf(list, 1).plan?.kind, TaskPlanKind.suggested);
      expect(rowOf(list, 1).plan?.text, '내일 14:00 · 제안');
      expect(rowOf(list, 2).plan?.kind, TaskPlanKind.confirmed);
      expect(rowOf(list, 2).plan?.text, '오늘 13:00부터 3번 · 확정');
    });

    test('끝난 블록, 지운·놓친·완료 블록, 다른 할 일의 블록은 보지 않는다', () {
      final list = content(
        [lms(1, due: at(11, 20))],
        blocks: [
          block(1, 1, at(11, 16, 8, 0), at(11, 16, 9, 0)),
          block(
            2,
            1,
            at(11, 17, 9, 0),
            at(11, 17, 10, 0),
            status: PlanBlockStatus.dismissed,
          ),
          block(
            3,
            1,
            at(11, 17, 11, 0),
            at(11, 17, 12, 0),
            status: PlanBlockStatus.done,
          ),
          block(
            4,
            1,
            at(11, 17, 13, 0),
            at(11, 17, 14, 0),
            status: PlanBlockStatus.missed,
          ),
          block(5, 2, at(11, 17, 15, 0), at(11, 17, 16, 0)),
        ],
      );
      expect(rowOf(list, 1).plan?.kind, TaskPlanKind.none);
      expect(rowOf(list, 1).plan?.text, '아직 놓을 시간이 없어요');
    });

    test('시간이 모자라면 붉게 쓰고 모자란 시간을 붙인다', () {
      final list = content(
        [lms(1, due: at(11, 18)), lms(2, due: at(11, 18))],
        blocks: [block(1, 1, at(11, 17, 9, 0), at(11, 17, 10, 0))],
        shortages: [
          Shortage(taskId: 1, missingMin: 90, dueAt: at(11, 18)),
          Shortage(taskId: 2, missingMin: 60, dueAt: at(11, 18)),
        ],
      );
      expect(rowOf(list, 1).plan?.text, '내일 09:00 · 확정 · 1시간 30분 모자라요');
      expect(rowOf(list, 1).plan?.alert, isTrue);
      expect(rowOf(list, 2).plan?.text, '마감 전 빈 시간이 모자라요');
      expect(rowOf(list, 2).plan?.alert, isTrue);
    });

    test('놓인 블록이 없으면 그 까닭을 쓴다', () {
      final list = content([
        lms(1, due: at(11, 20), kind: TaskKind.discussion),
        personal(2, due: at(11, 20), estimateMin: 60, spentMin: 60),
        personal(3),
        personal(4, due: at(11, 20), deferredUntil: '2026-11-18'),
        personal(5, due: at(11, 20), deferredUntil: '2026-11-16'),
        lms(6, due: at(11, 30)),
        lms(7, due: at(12, 10)),
        lms(8, due: DateTime(2026, 11, 30, 4)),
        lms(9, due: DateTime(2026, 12, 1, 4)),
      ]);
      expect(rowOf(list, 1).plan?.text, '예상 시간을 정하면 빈 시간에 놓아요');
      expect(rowOf(list, 2).plan?.kind, TaskPlanKind.confirmed);
      expect(rowOf(list, 2).plan?.text, '예상 시간만큼 했어요 · 끝냈다면 체크해 주세요');
      expect(rowOf(list, 3).plan?.text, '마감이 없어 직접 고른 시간에만 놓아요');
      expect(rowOf(list, 4).plan?.text, '이번 계획에서 뺐어요');
      expect(rowOf(list, 5).plan?.text, '아직 놓을 시간이 없어요');
      expect(rowOf(list, 6).plan?.text, '내일부터 빈 시간에 놓아요');
      expect(rowOf(list, 7).plan?.text, '11월 27일 (금)부터 빈 시간에 놓아요');
      // 하루 경계 시각의 마감은 그 전날의 하루 끝이라 배치 지평 안이다.
      expect(rowOf(list, 8).plan?.text, '아직 놓을 시간이 없어요');
      // 지평 밖이어도 그 전날의 하루 끝으로 세어, 하루 일찍 지평에 든다.
      expect(rowOf(list, 9).plan?.text, '내일부터 빈 시간에 놓아요');
    });

    test('예상 시간을 넣은 토론은 놓을 수 있는 할 일이다', () {
      final list = content([
        lms(1, due: at(11, 20), kind: TaskKind.discussion, estimateMin: 40),
      ]);
      expect(rowOf(list, 1).plan?.text, '아직 놓을 시간이 없어요');
    });

    test('시간표가 없으면 블록이 없는 할 일에 그 까닭을 쓴다', () {
      final list = content(
        [
          lms(1, due: at(11, 20)),
          lms(2, due: at(12, 10)),
          lms(3, due: at(11, 20)),
        ],
        blocks: [block(1, 3, at(11, 17, 9, 0), at(11, 17, 10, 0))],
        hasClassSlots: false,
      );
      expect(rowOf(list, 1).plan?.text, '시간표를 받으면 빈 시간에 놓아요');
      expect(rowOf(list, 2).plan?.text, '11월 27일 (금)부터 빈 시간에 놓아요');
      expect(rowOf(list, 3).plan?.text, '내일 09:00 · 확정');
    });
  });

  group('확인 못 함과 안내 칸', () {
    final os = '운영체제'.hashCode;
    final entries = [
      lms(1, due: at(11, 17)),
      lms(2, due: at(11, 18), courseName: '운영체제'),
      lms(3, due: at(11, 19), courseName: '운영체제'),
      personal(4, due: at(11, 18)),
    ];

    test('마감순에서는 받지 못한 과목의 LMS 할 일 줄에 표시한다', () {
      final list = content(entries, unchecked: {os});

      expect(
        [
          for (final id in [1, 2, 3, 4]) rowOf(list, id).unchecked,
        ],
        [false, true, true, false],
      );
      expect(list.groups.every((group) => !group.unchecked), isTrue);
      expect(
        content(entries).groups.single.rows.any((r) => r.unchecked),
        isFalse,
      );
    });

    test('과목별에서는 줄 대신 그 과목 묶음 머리에 표시한다', () {
      final list = content(entries, unchecked: {os}, sort: TaskListSort.course);

      expect(
        {for (final g in list.groups) g.title: g.unchecked},
        {'자료구조': false, '운영체제': true, '개인': false},
      );
      expect(
        list.groups.expand((g) => g.rows).any((r) => r.unchecked),
        isFalse,
      );
    });

    test('연동 멈춤과 로그인 전은 늘 알린다', () {
      final paused = taskListNotice(status: LmsStatusKind.paused, now: now)!;
      expect(paused.kind, TaskListNoticeKind.paused);
      expect(paused.title, 'LMS 연동을 잠시 멈췄어요');
      expect(paused.sub, '받아 둔 할 일은 그대로 있어요. 직접 추가는 계속 쓸 수 있어요');

      final before = taskListNotice(
        status: LmsStatusKind.beforeLogin,
        unchecked: const ['운영체제'],
        now: now,
      )!;
      expect(before.kind, TaskListNoticeKind.beforeLogin);
      expect(before.title, 'LMS에 로그인하면 마감을 모아 와요');
      expect(before.sub, '학번과 비밀번호로 로그인해요. 그전에는 할 일을 직접 넣어요');
    });

    test('일부 과목 실패는 연동됨일 때 과목 이름과 받은 때를 알린다', () {
      TaskListNotice? notice(List<String> names, {LmsStatusKind? status}) =>
          taskListNotice(
            status: status ?? LmsStatusKind.synced,
            unchecked: names,
            checkedAt: now.subtract(const Duration(minutes: 12)),
            now: now,
          );

      expect(notice(const ['운영체제'])!.title, '운영체제는 확인하지 못했어요');
      expect(
        notice(const ['운영체제'])!.sub,
        '다른 과목은 12분 전에 새로 받았어요. 확인하지 못한 과목은 전에 받은 할 일을 보여 드려요',
      );
      expect(notice(const ['자료구조', '운영체제'])!.title, '자료구조·운영체제는 확인하지 못했어요');
      expect(
        notice(const ['자료구조', '운영체제', '선형대수'])!.title,
        '자료구조 외 2과목은 확인하지 못했어요',
      );
      expect(notice(const ['선형대수'])!.title, '선형대수는 확인하지 못했어요');
      expect(notice(const ['데이터베이스'])!.kind, TaskListNoticeKind.unchecked);
      expect(
        taskListNotice(
          status: LmsStatusKind.synced,
          unchecked: const ['운영체제'],
          now: now,
        )!.sub,
        startsWith('다른 과목은 새로 받았어요.'),
      );
      expect(notice(const []), isNull);
      expect(notice(const ['운영체제'], status: LmsStatusKind.offline), isNull);
      expect(
        notice(const ['운영체제'], status: LmsStatusKind.reloginNeeded),
        isNull,
      );
      expect(taskListNotice(status: null, now: now), isNull);
    });
  });
}
