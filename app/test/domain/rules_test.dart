import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // [id]가 클수록 나중에 저장한 규칙으로 둔다([updatedAt]을 주면 그 값을 쓴다).
  Rule rule(
    RuleKind kind,
    RuleParams params, {
    int id = 1,
    List<int>? weekdays,
    bool active = true,
    DateTime? updatedAt,
  }) {
    final at = updatedAt ?? DateTime(2026, 10, 1).add(Duration(minutes: id));
    return Rule(
      id: id,
      kind: kind,
      params: params,
      weekdays: weekdays,
      active: active,
      source: EntrySource.manual,
      createdAt: at,
      updatedAt: at,
    );
  }

  List<RuleIssue> issues(
    RuleKind kind,
    RuleParams params, {
    List<int>? weekdays,
  }) => validateRule(kind, params, weekdays: weekdays);

  RuleIssue issue(String field, RuleIssueKind kind) => RuleIssue(field, kind);

  group('validateRule', () {
    test('종류마다 필요한 값만 있으면 통과한다', () {
      final valid = <RuleKind, RuleParams>{
        RuleKind.travel: const RuleParams(
          minutes: 60,
          position: TravelPosition.dayEdges,
        ),
        RuleKind.classBuffer: const RuleParams(minutes: 0),
        RuleKind.workWindow: const RuleParams(startMin: 540, endMin: 1320),
        RuleKind.blackout: const RuleParams(startMin: 1080, endMin: 1200),
        RuleKind.preferred: const RuleParams(startMin: 600, endMin: 720),
        RuleKind.maxBlock: const RuleParams(minutes: 90),
        RuleKind.dailyCap: const RuleParams(minutes: 240),
        RuleKind.meal: const RuleParams(
          startMin: 1080,
          endMin: 1200,
          minutes: 60,
        ),
        RuleKind.estimate: const RuleParams(
          taskKind: TaskKind.assignment,
          minutes: 120,
        ),
        RuleKind.notify: const RuleParams(briefingMin: 450),
      };
      expect(valid.keys, unorderedEquals(RuleKind.values));
      for (final MapEntry(key: kind, value: params) in valid.entries) {
        expect(issues(kind, params), isEmpty, reason: kind.name);
      }
    });

    test('필요한 값이 없으면 missing이다', () {
      expect(issues(RuleKind.travel, const RuleParams(minutes: 60)), [
        issue('position', RuleIssueKind.missing),
      ]);
      expect(
        issues(RuleKind.meal, const RuleParams(startMin: 1080, endMin: 1200)),
        [issue('minutes', RuleIssueKind.missing)],
      );
    });

    test('그 종류가 쓰지 않는 값과 요일은 notAllowed다', () {
      expect(
        issues(
          RuleKind.classBuffer,
          const RuleParams(minutes: 10, startMin: 0),
        ),
        [issue('startMin', RuleIssueKind.notAllowed)],
      );
      expect(
        issues(RuleKind.maxBlock, const RuleParams(minutes: 60), weekdays: [1]),
        [issue('weekdays', RuleIssueKind.notAllowed)],
      );
    });

    test('estimate는 과목이나 종류가 하나는 있어야 한다', () {
      expect(issues(RuleKind.estimate, const RuleParams(minutes: 60)), [
        issue('courseId', RuleIssueKind.missing),
      ]);
      expect(
        issues(RuleKind.estimate, const RuleParams(courseId: 3, minutes: 60)),
        isEmpty,
      );
    });

    test('notify는 값이 하나는 있어야 하고 조용한 시간은 시작과 끝을 함께 둔다', () {
      expect(issues(RuleKind.notify, const RuleParams()), [
        issue('briefingMin', RuleIssueKind.missing),
      ]);
      expect(issues(RuleKind.notify, const RuleParams(quietStartMin: 0)), [
        issue('quietEndMin', RuleIssueKind.missing),
      ]);
      expect(
        issues(
          RuleKind.notify,
          const RuleParams(quietStartMin: 1380, quietEndMin: 1860),
        ),
        isEmpty,
      );
    });

    test('분은 종류마다 범위가 다르다', () {
      void expectMinutes(RuleKind kind, int ok, int bad) {
        expect(issues(kind, RuleParams(minutes: ok)), isEmpty, reason: '$ok');
        expect(issues(kind, RuleParams(minutes: bad)), [
          issue('minutes', RuleIssueKind.outOfRange),
        ], reason: '$bad');
      }

      expectMinutes(RuleKind.classBuffer, RuleLimits.minutes.low, -1);
      expectMinutes(RuleKind.classBuffer, RuleLimits.minutes.high, 241);
      expectMinutes(RuleKind.dailyCap, RuleLimits.dailyCap.low, 29);
      expectMinutes(RuleKind.dailyCap, RuleLimits.dailyCap.high, 721);
      expectMinutes(RuleKind.maxBlock, RuleLimits.maxBlock.low, 24);
      expectMinutes(RuleKind.maxBlock, RuleLimits.maxBlock.high, 241);
    });

    test('시각은 하루 안에서 시작하고 끝이 늦되 하루를 넘지 않는다', () {
      List<RuleIssue> blackout(int start, int end) =>
          issues(RuleKind.blackout, RuleParams(startMin: start, endMin: end));

      expect(blackout(1320, 1560), isEmpty, reason: '자정을 넘는 22:00–02:00');
      expect(blackout(0, 1439), isEmpty);
      expect(blackout(1440, 1500), [
        issue('startMin', RuleIssueKind.outOfRange),
      ]);
      expect(blackout(-1, 60), [issue('startMin', RuleIssueKind.outOfRange)]);
      expect(blackout(600, 600), [issue('endMin', RuleIssueKind.badOrder)]);
      expect(blackout(600, 540), [issue('endMin', RuleIssueKind.badOrder)]);
      expect(blackout(600, 600 + 1440), [
        issue('endMin', RuleIssueKind.badOrder),
      ]);
    });

    test('식사 시간은 그 시간대보다 길 수 없다', () {
      expect(
        issues(
          RuleKind.meal,
          const RuleParams(startMin: 1080, endMin: 1110, minutes: 40),
        ),
        [issue('minutes', RuleIssueKind.outOfRange)],
      );
    });

    test('브리핑 시각과 알림 상한의 범위', () {
      expect(issues(RuleKind.notify, const RuleParams(briefingMin: 1440)), [
        issue('briefingMin', RuleIssueKind.outOfRange),
      ]);
      expect(
        issues(
          RuleKind.notify,
          const RuleParams(notifyCap: RuleLimits.notifyCap.high + 1),
        ),
        [issue('notifyCap', RuleIssueKind.outOfRange)],
      );
    });

    test('요일은 1–7이고 비거나 겹치면 안 된다', () {
      const params = RuleParams(startMin: 600, endMin: 660);
      expect(issues(RuleKind.blackout, params, weekdays: [1, 3]), isEmpty);
      for (final bad in [
        <int>[],
        [0],
        [8],
        [2, 2],
      ]) {
        expect(issues(RuleKind.blackout, params, weekdays: bad), [
          issue('weekdays', RuleIssueKind.outOfRange),
        ], reason: '$bad');
      }
    });
  });

  group('PlannerConfig.from', () {
    const defaultWindow = MinuteRange(
      Defaults.dayWindowStartMin,
      Defaults.dayWindowEndMin,
    );
    const defaultMealWindow = MinuteRange(
      Defaults.mealWindowStartMin,
      Defaults.mealWindowEndMin,
    );

    test('규칙이 없으면 모든 요일이 기본값이다', () {
      final config = PlannerConfig.from(const []);
      expect(config.classBufferMin, Defaults.classBufferMin);
      expect(config.maxBlockMin, Defaults.maxBlockMin);
      expect(config.meals.map((meal) => meal.window), [defaultMealWindow]);
      expect(config.meals.single.minutes, Defaults.mealMin);
      for (var weekday = 1; weekday <= 7; weekday++) {
        final day = config.forWeekday(weekday);
        expect(day.workWindow, defaultWindow);
        expect(day.travel, isNull);
        expect(day.blackouts, isEmpty);
        expect(day.preferred, isEmpty);
        expect(day.dailyCapMin, isNull);
      }
      expect(config.estimateMin(courseId: 1, kind: TaskKind.quiz), isNull);
    });

    test('꺼진 규칙과 값 검사를 통과하지 못한 규칙은 쓰지 않는다', () {
      final config = PlannerConfig.from([
        rule(RuleKind.maxBlock, const RuleParams(minutes: 60), active: false),
        rule(RuleKind.classBuffer, const RuleParams(minutes: 999)),
      ]);
      expect(config.maxBlockMin, Defaults.maxBlockMin);
      expect(config.classBufferMin, Defaults.classBufferMin);
    });

    test('요일이 일부만 겹치면 그 요일에는 나중에 저장한 규칙을 쓴다', () {
      final everyDay = rule(
        RuleKind.workWindow,
        const RuleParams(startMin: 540, endMin: 1320),
        id: 1,
      );
      final monday = rule(
        RuleKind.workWindow,
        const RuleParams(startMin: 600, endMin: 1200),
        id: 2,
        weekdays: [DateTime.monday],
      );
      for (final rules in [
        [everyDay, monday],
        [monday, everyDay],
      ]) {
        final config = PlannerConfig.from(rules);
        expect(
          config.forWeekday(DateTime.monday).workWindow,
          const MinuteRange(600, 1200),
        );
        expect(
          config.forWeekday(DateTime.tuesday).workWindow,
          const MinuteRange(540, 1320),
        );
      }
    });

    test('저장 시각이 같으면 id가 큰 규칙을 쓴다', () {
      final at = DateTime(2026, 10, 1);
      final config = PlannerConfig.from([
        rule(
          RuleKind.dailyCap,
          const RuleParams(minutes: 300),
          id: 7,
          updatedAt: at,
        ),
        rule(
          RuleKind.dailyCap,
          const RuleParams(minutes: 200),
          id: 3,
          updatedAt: at,
        ),
      ]);
      expect(config.forWeekday(DateTime.friday).dailyCapMin, 300);
    });

    test('하나만 두는 종류는 나중에 저장한 값을 쓴다', () {
      final config = PlannerConfig.from([
        rule(RuleKind.classBuffer, const RuleParams(minutes: 20), id: 2),
        rule(RuleKind.classBuffer, const RuleParams(minutes: 5), id: 1),
        rule(RuleKind.maxBlock, const RuleParams(minutes: 50), id: 3),
      ]);
      expect(config.classBufferMin, 20);
      expect(config.maxBlockMin, 50);
    });

    test('이동 시간은 그 요일에만 걸린다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.travel,
          const RuleParams(minutes: 60, position: TravelPosition.everyClass),
          weekdays: [DateTime.tuesday, DateTime.thursday],
        ),
      ]);
      final tuesday = config.forWeekday(DateTime.tuesday).travel!;
      expect(tuesday.minutes, 60);
      expect(tuesday.position, TravelPosition.everyClass);
      expect(config.forWeekday(DateTime.wednesday).travel, isNull);
    });

    test('피할 시간과 선호 시간대는 모두 모아 시작 순서로 둔다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.blackout,
          const RuleParams(startMin: 1200, endMin: 1260),
          id: 1,
        ),
        rule(
          RuleKind.blackout,
          const RuleParams(startMin: 600, endMin: 660),
          id: 2,
          weekdays: [DateTime.monday],
        ),
        rule(
          RuleKind.preferred,
          const RuleParams(startMin: 540, endMin: 720),
          id: 3,
        ),
      ]);
      expect(config.forWeekday(DateTime.monday).blackouts, const [
        MinuteRange(600, 660),
        MinuteRange(1200, 1260),
      ]);
      expect(config.forWeekday(DateTime.sunday).blackouts, const [
        MinuteRange(1200, 1260),
      ]);
      expect(config.forWeekday(DateTime.sunday).preferred, const [
        MinuteRange(540, 720),
      ]);
    });

    test('기본 식사 시간대와 겹치는 식사 규칙은 기본값을 바꾼다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.meal,
          const RuleParams(startMin: 720, endMin: 780, minutes: 30),
        ),
      ]);
      expect(config.meals.map((meal) => meal.window), [
        const MinuteRange(720, 780),
      ]);
      expect(config.meals.single.minutes, 30);
    });

    test('기본 식사 시간대와 겹치지 않는 식사 규칙은 기본값에 더한다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.meal,
          const RuleParams(startMin: 1080, endMin: 1200, minutes: 60),
        ),
      ]);
      expect(config.meals.map((meal) => meal.window), [
        defaultMealWindow,
        const MinuteRange(1080, 1200),
      ]);
    });

    test('예상 시간은 과목·종류, 과목, 종류 순서로 찾는다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.estimate,
          const RuleParams(taskKind: TaskKind.assignment, minutes: 60),
          id: 1,
        ),
        rule(
          RuleKind.estimate,
          const RuleParams(courseId: 7, minutes: 90),
          id: 2,
        ),
        rule(
          RuleKind.estimate,
          const RuleParams(
            courseId: 7,
            taskKind: TaskKind.assignment,
            minutes: 180,
          ),
          id: 3,
        ),
      ]);
      expect(config.estimateMin(courseId: 7, kind: TaskKind.assignment), 180);
      expect(config.estimateMin(courseId: 7, kind: TaskKind.quiz), 90);
      expect(config.estimateMin(courseId: 8, kind: TaskKind.assignment), 60);
      expect(config.estimateMin(courseId: null, kind: TaskKind.assignment), 60);
      expect(config.estimateMin(courseId: 8, kind: TaskKind.quiz), isNull);
    });

    test('요일은 1–7만 받는다', () {
      final config = PlannerConfig.from(const []);
      expect(() => config.forWeekday(0), throwsRangeError);
      expect(() => config.forWeekday(8), throwsRangeError);
    });
  });

  group('NotifyConfig.from', () {
    test('규칙이 없으면 기본값이다', () {
      final config = NotifyConfig.from(const []);
      expect(config.briefingMin, Defaults.briefingMin);
      expect(config.notifyCap, Defaults.notifyCap);
      expect(
        config.quietHours,
        const MinuteRange(Defaults.quietStartMin, Defaults.quietEndMin),
      );
    });

    test('값마다 그 값을 가진 가장 최근 규칙을 쓴다', () {
      final config = NotifyConfig.from([
        rule(
          RuleKind.notify,
          const RuleParams(
            briefingMin: 420,
            quietStartMin: 0,
            quietEndMin: 420,
          ),
          id: 1,
        ),
        rule(
          RuleKind.notify,
          const RuleParams(briefingMin: 540, notifyCap: 3),
          id: 2,
        ),
      ]);
      expect(config.briefingMin, 540);
      expect(config.notifyCap, 3);
      expect(config.quietHours, const MinuteRange(0, 420));
    });

    test('notify가 아닌 규칙은 보지 않는다', () {
      final config = NotifyConfig.from([
        rule(RuleKind.maxBlock, const RuleParams(minutes: 60)),
      ]);
      expect(config.notifyCap, Defaults.notifyCap);
    });
  });
}
