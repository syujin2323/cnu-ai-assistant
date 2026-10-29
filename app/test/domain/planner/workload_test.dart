import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/planner/workload.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 지금은 2026-10-12(월) 10:00이다.
  final now = DateTime(2026, 10, 12, 10);
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  Task task({
    int id = 1,
    TaskKind kind = TaskKind.assignment,
    DateTime? dueAt,
    int? estimateMin,
    int? spentMin,
  }) => Task(
    id: id,
    title: '과제',
    kind: kind,
    dueAt: dueAt,
    dueTimeUnknown: false,
    estimateMin: estimateMin,
    spentMin: spentMin,
    status: TaskStatus.todo,
  );

  LmsItem item({
    int courseId = 7,
    LmsItemKind kind = LmsItemKind.video,
    DateTime? openAt,
    int? videoMin,
    int? requiredMin,
    int? watchedMin,
  }) => LmsItem(
    id: 1,
    remoteKey: 's:7:video:1',
    courseId: courseId,
    courseName: '과목A',
    title: '1주차 영상',
    kind: kind,
    dueTimeUnknown: false,
    openAt: openAt,
    videoMin: videoMin,
    requiredMin: requiredMin,
    watchedMin: watchedMin,
    firstSeenAt: now,
    lastSeenAt: now,
    missCount: 0,
    contentHash: 'hash',
  );

  PlanBlock block(
    DateTime start,
    DateTime end,
    PlanBlockStatus status, {
    int taskId = 1,
  }) => PlanBlock(
    id: start.hour,
    taskId: taskId,
    startAt: start,
    endAt: end,
    status: status,
    source: BlockSource.auto,
  );

  Workload workload(
    Task task, {
    LmsItem? item,
    List<Rule> rules = const [],
    List<PlanBlock> blocks = const [],
  }) => workloadOf(
    task,
    item: item,
    config: PlannerConfig.from(rules),
    blocks: blocks,
    now: now,
  );

  group('남은 작업 시간', () {
    test('영상은 사캠 진도(인정 시간 − 시청 시간)를 쓰고 한 만큼은 빼지 않는다', () {
      final result = workload(
        task(kind: TaskKind.video, spentMin: 25, estimateMin: 90),
        item: item(videoMin: 60, requiredMin: 50, watchedMin: 20),
      );
      expect(result.remainingMin, 30);
      expect(result.source, EstimateSource.lmsProgress);
    });

    test('시청 시간이 인정 시간보다 많으면 0이다', () {
      final result = workload(
        task(kind: TaskKind.video),
        item: item(requiredMin: 50, watchedMin: 70),
      );
      expect(result.remainingMin, 0);
      expect(result.toPlaceMin, 0);
    });

    test('진도 필드가 없는 영상은 영상 길이에서 한 만큼을 뺀다', () {
      final result = workload(
        task(kind: TaskKind.video, spentMin: 15),
        item: item(videoMin: 45, requiredMin: 50),
      );
      expect(result.remainingMin, 30);
      expect(result.source, EstimateSource.videoLength);
    });

    test('진도가 없으면 사용자 입력이 영상 길이보다 우선한다', () {
      final result = workload(
        task(kind: TaskKind.video, estimateMin: 80),
        item: item(videoMin: 45),
      );
      expect(result.remainingMin, 80);
      expect(result.source, EstimateSource.user);
    });

    test('과제는 사용자 예상 시간에서 한 만큼을 뺀다', () {
      final result = workload(task(estimateMin: 120, spentMin: 50));
      expect(result.remainingMin, 70);
      expect(result.source, EstimateSource.user);
    });

    test('한 만큼이 예상 시간보다 많으면 0이다', () {
      expect(workload(task(estimateMin: 60, spentMin: 90)).remainingMin, 0);
    });

    test('예상 시간을 모르면 그 과목·종류의 estimate 규칙을 쓴다', () {
      final rule = Rule(
        id: 1,
        kind: RuleKind.estimate,
        params: const RuleParams(courseId: 7, minutes: 150),
        active: true,
        source: EntrySource.manual,
        createdAt: now,
        updatedAt: now,
      );
      final result = workload(
        task(),
        item: item(kind: LmsItemKind.assignment),
        rules: [rule],
      );
      expect(result.remainingMin, 150);
      expect(result.source, EstimateSource.rule);
    });

    test('규칙도 없으면 종류별 기본값을 쓴다', () {
      final result = workload(task(kind: TaskKind.quiz));
      expect(result.remainingMin, Defaults.taskEstimateMin[TaskKind.quiz]);
      expect(result.source, EstimateSource.kindDefault);
    });

    test('모든 종류에 기본값이 있다', () {
      expect(Defaults.taskEstimateMin.keys, unorderedEquals(TaskKind.values));
    });
  });

  group('배치할 시간', () {
    test('아직 끝나지 않은 확정 블록만 빼고, 진행 중이면 남은 부분만 뺀다', () {
      final result = workload(
        task(estimateMin: 240),
        blocks: [
          // 진행 중: 09:30–10:30 가운데 남은 30분.
          block(at(12, 9, 30), at(12, 10, 30), PlanBlockStatus.confirmed),
          // 앞으로: 60분.
          block(at(13, 14), at(13, 15), PlanBlockStatus.confirmed),
          // 이미 끝난 확정 블록, 제안·완료 블록, 다른 할 일의 블록은 빼지 않는다.
          block(at(12, 8), at(12, 9), PlanBlockStatus.confirmed),
          block(at(13, 16), at(13, 17), PlanBlockStatus.suggested),
          block(at(12, 11), at(12, 12), PlanBlockStatus.done),
          block(at(13, 18), at(13, 19), PlanBlockStatus.confirmed, taskId: 2),
        ],
      );
      expect(result.remainingMin, 240);
      expect(result.toPlaceMin, 150);
    });

    test('확정 블록이 남은 시간보다 길면 0이다', () {
      final result = workload(
        task(estimateMin: 30),
        blocks: [block(at(13, 14), at(13, 16), PlanBlockStatus.confirmed)],
      );
      expect(result.toPlaceMin, 0);
    });
  });

  group('여유도', () {
    // 월요일 09:00–12:00, 13:00–15:00, 화요일 09:00–11:00이 빈다.
    final free = [
      TimeSpan(at(12, 9), at(12, 12)),
      TimeSpan(at(12, 13), at(12, 15)),
      TimeSpan(at(13, 9), at(13, 11)),
    ];

    const sixtyMin = Workload(
      remainingMin: 60,
      toPlaceMin: 60,
      source: EstimateSource.user,
    );

    test('지금부터 마감 전까지의 빈 시간 합에서 배치할 시간을 뺀다', () {
      // 10:00–12:00(120) + 13:00–15:00(120) + 화 09:00–10:00(60) = 300.
      final slack = slackMin(
        task(dueAt: at(13, 10)),
        workload: sixtyMin,
        free: free,
        now: now,
      );
      expect(slack, 240);
    });

    test('공개 전 영상은 공개 시각부터 센다', () {
      final slack = slackMin(
        task(kind: TaskKind.video, dueAt: at(13, 23, 59)),
        item: item(openAt: at(12, 14)),
        workload: sixtyMin,
        free: free,
        now: now,
      );
      // 14:00–15:00(60) + 화 09:00–11:00(120) = 180.
      expect(slack, 120);
    });

    test('시간이 모자라면 음수다', () {
      final slack = slackMin(
        task(dueAt: at(12, 11)),
        workload: const Workload(
          remainingMin: 120,
          toPlaceMin: 120,
          source: EstimateSource.user,
        ),
        free: free,
        now: now,
      );
      expect(slack, -60);
    });

    test('마감이 없으면 null이다', () {
      expect(
        slackMin(task(), workload: sixtyMin, free: free, now: now),
        isNull,
      );
    });
  });

  test('freeMinutesBetween은 구간 밖을 잘라 더한다', () {
    final free = [
      TimeSpan(at(12, 9), at(12, 12)),
      TimeSpan(at(12, 13), at(12, 15)),
    ];
    expect(freeMinutesBetween(free, at(12, 11), at(12, 14)), 120);
    expect(freeMinutesBetween(free, at(12, 15), at(12, 18)), 0);
    expect(freeMinutesBetween(free, at(12, 14), at(12, 10)), 0);
  });
}
