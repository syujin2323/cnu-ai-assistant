// 06 AI 비서 카드 문구·예상 시간·다시 계산한 제안 테스트. docs/screens.md '06 AI 비서'(카드 1·2·3·5),
// docs/architecture.md '도메인 기본값과 배치 엔진'(예상 시간의 순서).

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 19);
final _now = DateTime(2026, 11, 19, 10, 30);

BlockDraft _block(int taskId, DateTime start, {int minutes = 60}) => BlockDraft(
  taskId: taskId,
  startAt: start,
  endAt: start.add(Duration(minutes: minutes)),
  source: BlockSource.auto,
);

PlanResult _plan(List<BlockDraft> blocks, {List<int> short = const []}) =>
    PlanResult(
      blocks: blocks,
      shortages: [
        for (final id in short)
          Shortage(taskId: id, missingMin: 30, dueAt: DateTime(2026, 11, 20)),
      ],
      ranked: const [],
    );

Rule _estimateRule({int? courseId, TaskKind? kind, required int minutes}) =>
    Rule(
      id: 1,
      kind: RuleKind.estimate,
      params: RuleParams(courseId: courseId, taskKind: kind, minutes: minutes),
      active: true,
      source: EntrySource.manual,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  test('반복 요일은 매일·평일마다·주말마다·매주 요일로 쓴다', () {
    expect(repeatText([1, 2, 3, 4, 5, 6, 7]), '매일');
    expect(repeatText([1, 2, 3, 4, 5]), '평일마다');
    expect(repeatText([6, 7]), '주말마다');
    expect(repeatText([1, 3]), '매주 월·수');
    expect(repeatText([7]), '매주 일');
  });

  test('날짜 말은 오늘·내일·모레, 요일, N일 뒤·전이다', () {
    String at(int day) =>
        relativeDayText(DateTime(2026, 11, day), today: _today);
    expect(
      [at(19), at(20), at(21), at(22), at(25), at(26), at(18), at(12)],
      ['오늘', '내일', '모레', '일요일', '수요일', '7일 뒤', '1일 전', '7일 전'],
    );
  });

  test('일정이 언제인지와 시간 범위', () {
    final once = EventDraft(
      title: '스터디',
      date: DateTime(2026, 11, 20),
      startMin: 15 * 60,
      endMin: 16 * 60 + 30,
    );
    expect(eventWhenText(once, today: _today), '11월 20일 (금) 15:00');
    expect(eventSpanText(once), '15:00–16:30 · 1시간 30분');

    final unknown = EventDraft(title: '모임', date: DateTime(2026, 11, 20));
    expect(eventWhenText(unknown, today: _today), '11월 20일 (금) · 시간 미정');
    expect(eventSpanText(unknown), '시간 미정');

    const weekly = EventDraft(
      title: '알바',
      weekdays: [6, 7],
      startMin: 22 * 60,
      endMin: 26 * 60,
    );
    expect(eventWhenText(weekly, today: _today), '주말마다 22:00');
    expect(eventSpanText(weekly), '22:00–02:00 · 4시간');
  });

  group('예상 시간', () {
    const draft = TaskDraft(title: '과제', kind: TaskKind.assignment);

    test('고른 값 → 말한 값 → 규칙 → 종류별 기본값 순서다', () {
      final config = PlannerConfig.from([
        _estimateRule(courseId: 3, kind: TaskKind.assignment, minutes: 150),
      ]);
      expect(taskEstimateOf(draft, courseId: 3, config: config), (
        minutes: 150,
        source: EstimateSource.rule,
      ));
      expect(taskEstimateOf(draft, courseId: 4, config: config), (
        minutes: Defaults.estimateMinByKind[TaskKind.assignment],
        source: EstimateSource.kindDefault,
      ));
      // 규칙을 아직 읽지 못했으면 규칙을 보지 않는다.
      expect(
        taskEstimateOf(draft, courseId: 3, config: null).source,
        EstimateSource.kindDefault,
      );
      const said = TaskDraft(
        title: '과제',
        kind: TaskKind.assignment,
        saidEstimateMin: 200,
      );
      expect(taskEstimateOf(said, courseId: 3, config: config), (
        minutes: 200,
        source: EstimateSource.said,
      ));
      expect(
        taskEstimateOf(said.withEstimate(45), courseId: 3, config: config),
        (minutes: 45, source: EstimateSource.picked),
      );
    });

    test('토론·시험은 기본값이 없어 고르기 전에는 없다', () {
      for (final kind in [TaskKind.exam, TaskKind.discussion]) {
        expect(
          taskEstimateOf(
            TaskDraft(title: '시험', courseName: '선형대수', kind: kind),
            courseId: null,
            config: PlannerConfig.from(const []),
          ),
          (minutes: null, source: EstimateSource.none),
        );
      }
    });

    test('칩은 30분·1시간·2시간·3시간에 지금 값을 더하고, 안내는 출처를 말한다', () {
      expect(estimateChoices(null), [30, 60, 120, 180]);
      expect(estimateChoices(60), [30, 60, 120, 180]);
      expect(estimateChoices(90), [30, 60, 90, 120, 180]);
      expect(estimateChoices(300), [30, 60, 120, 180, 300]);
      expect(estimateNote(EstimateSource.picked, TaskKind.quiz), isNull);
      expect(estimateNote(EstimateSource.said, TaskKind.quiz), '말한 시간으로 잡았어요');
      expect(
        estimateNote(EstimateSource.rule, TaskKind.quiz),
        '내 규칙의 예상 시간으로 잡았어요',
      );
      expect(
        estimateNote(EstimateSource.kindDefault, TaskKind.quiz),
        '처음이라 퀴즈 기본값으로 잡았어요. 맞게 골라 주세요',
      );
      expect(
        estimateNote(EstimateSource.none, TaskKind.exam),
        '예상 시간을 고르면 빈 시간에 놓아요',
      );
    });

    test('저장하는 예상 시간은 고른 값이나 말한 값뿐이다', () {
      expect(draft.estimateToStore, isNull);
      expect(
        const TaskDraft(
          title: '과제',
          kind: TaskKind.assignment,
          saidEstimateMin: 90,
        ).estimateToStore,
        90,
      );
      expect(draft.withEstimate(30).estimateToStore, 30);
    });
  });

  group('다시 계산한 제안', () {
    test('일정을 넣기 전에 있던 제안 가운데 사라진 것을 센다', () {
      final keep = _block(1, DateTime(2026, 11, 19, 13));
      final moved = _block(2, DateTime(2026, 11, 19, 15));
      final before = _plan([keep, moved]);
      expect(eventPlanNote(before, _plan([keep, moved])), isNull);
      expect(
        eventPlanNote(
          before,
          _plan([keep, _block(2, DateTime(2026, 11, 19, 17))]),
        ),
        '겹치던 제안 1개를 다른 빈 시간으로 옮겼어요',
      );
      expect(eventPlanNote(null, _plan([keep])), isNull);
      expect(eventPlanNote(before, null), isNull);
    });

    test('수업 변경·바꾸기 뒤에는 새로 놓인 제안을, 없으면 빠진 제안을 센다', () {
      final keep = _block(1, DateTime(2026, 11, 19, 13));
      final other = _block(2, DateTime(2026, 11, 19, 15));
      final before = _plan([keep, other]);
      expect(replanNote(before, _plan([keep, other])), isNull);
      expect(
        replanNote(
          before,
          _plan([
            keep,
            _block(2, DateTime(2026, 11, 19, 17)),
            _block(3, DateTime(2026, 11, 20, 9)),
          ]),
        ),
        '제안 2개를 다시 놓았어요',
      );
      expect(replanNote(before, _plan([keep])), '제안 1개를 뺐어요');
      expect(replanNote(_plan(const []), _plan([keep])), '제안 1개를 다시 놓았어요');
      expect(replanNote(null, _plan([keep])), isNull);
      expect(replanNote(before, null), isNull);
    });

    test('할 일을 넣은 뒤 놓인 자리를 적는다', () {
      final draft = TaskDraft(
        title: '과제',
        kind: TaskKind.assignment,
        dueDate: DateTime(2026, 11, 21),
      );
      String? note(
        PlanResult? plan, {
        TaskDraft? task,
        int? estimate = 60,
        bool hasTimetable = true,
      }) => taskPlanNote(
        draft: task ?? draft,
        taskId: 7,
        estimate: estimate,
        plan: plan,
        hasTimetable: hasTimetable,
        now: _now,
        dayBoundaryMin: Defaults.dayBoundaryMin,
      );
      expect(
        note(
          _plan([
            _block(7, DateTime(2026, 11, 20, 13)),
            _block(7, DateTime(2026, 11, 19, 15), minutes: 50),
            _block(8, DateTime(2026, 11, 19, 11)),
          ]),
        ),
        '2번에 나눠 놓았어요. 먼저 오늘 15:00–15:50에 놓았어요 · 확정 전 제안이에요',
      );
      expect(
        note(_plan([_block(7, DateTime(2026, 11, 20, 23, 30))])),
        '먼저 내일 23:30–00:30에 놓았어요 · 확정 전 제안이에요',
      );
      expect(
        note(_plan(const [], short: [7])),
        '마감 전 빈 시간이 모자라요 · 홈에서 방법을 골라 주세요',
      );
      expect(note(_plan(const [])), '마감 전에 놓을 빈 시간을 찾지 못했어요');
      expect(
        note(_plan(const []), hasTimetable: false),
        '시간표가 없어 아직 자동으로 놓지 않아요',
      );
      expect(note(null), isNull);
      expect(note(_plan(const []), estimate: null), '예상 시간을 몰라 자동으로 놓지 않아요');
      expect(
        note(
          _plan(const []),
          task: const TaskDraft(title: '과제', kind: TaskKind.assignment),
        ),
        '마감이 없어 자동으로 놓지 않아요',
      );
      expect(
        note(
          _plan(const []),
          task: TaskDraft(
            title: '과제',
            kind: TaskKind.assignment,
            dueDate: DateTime(2026, 12, 20),
          ),
        ),
        '마감 14일 전부터 빈 시간에 놓아요',
      );
    });
  });

  group('바꾸기 카드의 시각', () {
    Event event(DateTime start, DateTime end, {bool allDay = false}) => Event(
      id: 1,
      title: '스터디',
      startAt: start,
      endAt: end,
      allDay: allDay,
      source: EventSource.manual,
    );

    test('일정은 날짜와 시간 범위, 종일이면 종일이다', () {
      expect(
        targetWhenText(
          EventTarget(
            event(DateTime(2026, 11, 20, 15), DateTime(2026, 11, 20, 16, 30)),
          ),
          today: _today,
        ),
        '11월 20일 (금) 15:00–16:30',
      );
      expect(
        targetWhenText(
          EventTarget(
            event(DateTime(2026, 11, 21), DateTime(2026, 11, 22), allDay: true),
          ),
          today: _today,
        ),
        '11월 21일 (토) · 종일',
      );
      // 자정을 넘으면 실제 시각, 하루를 넘으면 하루 안의 끝까지, 길이가 없으면 시작만 적는다.
      expect(
        targetWhenText(
          EventTarget(
            event(DateTime(2026, 11, 20, 23), DateTime(2026, 11, 21, 1)),
          ),
          today: _today,
        ),
        '11월 20일 (금) 23:00–01:00',
      );
      expect(
        targetWhenText(
          EventTarget(
            event(DateTime(2026, 11, 20, 9), DateTime(2026, 11, 22, 9)),
          ),
          today: _today,
        ),
        '11월 20일 (금) 09:00–08:59',
      );
      expect(
        targetWhenText(
          EventTarget(
            event(DateTime(2026, 11, 20, 9), DateTime(2026, 11, 20, 9)),
          ),
          today: _today,
        ),
        '11월 20일 (금) 09:00',
      );
    });

    test('고정 일정은 반복 요일과 시간 범위다', () {
      expect(
        targetWhenText(
          const FixedTarget(
            FixedBlock(
              id: 5,
              name: '알바',
              weekdays: [DateTime.saturday, DateTime.sunday],
              startMin: 840,
              endMin: 1020,
              bufferMin: 0,
              kind: FixedBlockKind.work,
              source: EntrySource.manual,
            ),
          ),
          today: _today,
        ),
        '주말마다 14:00–17:00',
      );
    });

    test('바꾼 뒤도 같은 꼴이다', () {
      expect(
        afterWhenText(
          EventAfter(
            startAt: DateTime(2026, 11, 23, 10),
            endAt: DateTime(2026, 11, 23, 11),
            allDay: false,
          ),
          today: _today,
        ),
        '11월 23일 (월) 10:00–11:00',
      );
      expect(
        afterWhenText(
          EventAfter(
            startAt: DateTime(2026, 11, 28),
            endAt: DateTime(2026, 11, 29),
            allDay: true,
          ),
          today: _today,
        ),
        '11월 28일 (토) · 종일',
      );
      expect(
        afterWhenText(
          const FixedAfter(
            weekdays: [DateTime.monday, DateTime.wednesday],
            startMin: 1320,
            endMin: 1500,
          ),
          today: _today,
        ),
        '매주 월·수 22:00–01:00',
      );
    });
  });
}
