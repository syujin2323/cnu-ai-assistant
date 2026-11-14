// 내 규칙의 값 검사와 설정 테스트. docs/architecture.md '내 규칙'.
//
// 경계값은 [RuleLimits]의 양끝과 그 바깥(`low - 1`, `high + 1`)으로 적어, 범위를 바꿔도 경계를 놓치지
// 않게 한다.

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
    String? sentence,
  }) {
    final at = updatedAt ?? DateTime(2026, 10, 1).add(Duration(minutes: id));
    return Rule(
      id: id,
      kind: kind,
      params: params,
      weekdays: weekdays,
      active: active,
      source: EntrySource.manual,
      sentence: sentence,
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

    test('쓰지 않는 값은 notAllowed만 내고 범위·짝은 검사하지 않는다', () {
      // 범위 밖이어도 outOfRange를 함께 내지 않는다.
      expect(
        issues(
          RuleKind.classBuffer,
          const RuleParams(minutes: 10, startMin: 2000, notifyCap: 99),
        ),
        [
          issue('startMin', RuleIssueKind.notAllowed),
          issue('notifyCap', RuleIssueKind.notAllowed),
        ],
      );
      // 조용한 시간의 짝은 notify에서만 본다.
      expect(
        issues(
          RuleKind.travel,
          const RuleParams(
            minutes: 30,
            position: TravelPosition.dayEdges,
            quietStartMin: 1380,
          ),
        ),
        [issue('quietStartMin', RuleIssueKind.notAllowed)],
      );
    });

    test('요일은 travel·work_window·blackout·preferred·daily_cap만 쓴다', () {
      const withWeekdays = {
        RuleKind.travel,
        RuleKind.workWindow,
        RuleKind.blackout,
        RuleKind.preferred,
        RuleKind.dailyCap,
      };
      final params = <RuleKind, RuleParams>{
        RuleKind.travel: const RuleParams(
          minutes: 60,
          position: TravelPosition.everyClass,
        ),
        RuleKind.classBuffer: const RuleParams(minutes: 10),
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
        RuleKind.estimate: const RuleParams(courseId: 1, minutes: 60),
        RuleKind.notify: const RuleParams(briefingMin: 480),
      };
      expect(params.keys, unorderedEquals(RuleKind.values));
      for (final MapEntry(key: kind, value: value) in params.entries) {
        expect(
          issues(kind, value, weekdays: [DateTime.monday]),
          withWeekdays.contains(kind)
              ? isEmpty
              : [issue('weekdays', RuleIssueKind.notAllowed)],
          reason: kind.name,
        );
      }
    });

    test('estimate는 과목이나 종류가 하나는 있어야 한다(missingOneOf)', () {
      expect(issues(RuleKind.estimate, const RuleParams(minutes: 60)), [
        issue('courseId|taskKind', RuleIssueKind.missingOneOf),
      ]);
      expect(
        issues(RuleKind.estimate, const RuleParams(courseId: 3, minutes: 60)),
        isEmpty,
      );
      expect(
        issues(
          RuleKind.estimate,
          const RuleParams(taskKind: TaskKind.quiz, minutes: 60),
        ),
        isEmpty,
      );
    });

    test('notify는 값이 하나는 있어야 하고 조용한 시간은 시작과 끝을 함께 둔다', () {
      expect(issues(RuleKind.notify, const RuleParams()), [
        issue(
          'briefingMin|notifyCap|quietStartMin|quietEndMin',
          RuleIssueKind.missingOneOf,
        ),
      ]);
      expect(issues(RuleKind.notify, const RuleParams(quietStartMin: 0)), [
        issue('quietEndMin', RuleIssueKind.missing),
      ]);
      expect(issues(RuleKind.notify, const RuleParams(quietEndMin: 420)), [
        issue('quietStartMin', RuleIssueKind.missing),
      ]);
      expect(
        issues(
          RuleKind.notify,
          const RuleParams(quietStartMin: 1380, quietEndMin: 1860),
        ),
        isEmpty,
      );
    });

    test('missingOneOf의 후보는 RuleField 순서로 잇는다', () {
      final names = RuleField.values.map((field) => field.name).toList();
      for (final RuleIssue(:field) in [
        ...issues(RuleKind.estimate, const RuleParams(minutes: 60)),
        ...issues(RuleKind.notify, const RuleParams()),
      ]) {
        final indexes = field.split('|').map(names.indexOf).toList();
        expect(indexes, everyElement(isNonNegative), reason: field);
        expect(indexes, orderedEquals([...indexes]..sort()), reason: field);
      }
    });

    test('분은 종류마다 범위가 다르다', () {
      RuleParams paramsFor(RuleKind kind, int minutes) => switch (kind) {
        RuleKind.travel => RuleParams(
          minutes: minutes,
          position: TravelPosition.dayEdges,
        ),
        // 시간대는 분의 상한보다 넓게 둬 식사 길이 검사에 걸리지 않게 한다.
        RuleKind.meal => RuleParams(
          startMin: 600,
          endMin: 900,
          minutes: minutes,
        ),
        RuleKind.estimate => RuleParams(
          taskKind: TaskKind.assignment,
          minutes: minutes,
        ),
        _ => RuleParams(minutes: minutes),
      };

      void expectLimit(RuleKind kind, ({int low, int high}) limit) {
        for (final ok in [limit.low, limit.high]) {
          expect(
            issues(kind, paramsFor(kind, ok)),
            isEmpty,
            reason: '${kind.name} $ok',
          );
        }
        for (final bad in [limit.low - 1, limit.high + 1]) {
          expect(issues(kind, paramsFor(kind, bad)), [
            issue('minutes', RuleIssueKind.outOfRange),
          ], reason: '${kind.name} $bad');
        }
      }

      expectLimit(RuleKind.classBuffer, RuleLimits.minutes);
      expectLimit(RuleKind.travel, RuleLimits.minutes);
      expectLimit(RuleKind.meal, RuleLimits.minutes);
      expectLimit(RuleKind.estimate, RuleLimits.minutes);
      expectLimit(RuleKind.dailyCap, RuleLimits.dailyCap);
      expectLimit(RuleKind.maxBlock, RuleLimits.maxBlock);
    });

    test('max_block 하한은 배치 최소 조각과 같다', () {
      expect(RuleLimits.maxBlock.low, Defaults.minChunkMin);
    });

    test('범위 상수는 docs/architecture.md \'내 규칙\'의 값 범위와 같다(임시값)', () {
      expect(RuleLimits.minutes, (low: 0, high: 240));
      expect(RuleLimits.dailyCap, (low: 30, high: 720));
      expect(RuleLimits.maxBlock.high, 240);
      expect(RuleLimits.notifyCap, (low: 0, high: 20));
      expect(RuleLimits.briefing, (low: 360, high: 720));
      expect(RuleLimits.briefingStepMin, 30);
    });

    test('시각은 하루 안에서 시작하고 끝이 늦되 하루를 넘지 않는다', () {
      List<RuleIssue> blackout(int start, int end) =>
          issues(RuleKind.blackout, RuleParams(startMin: start, endMin: end));

      expect(blackout(1320, 1560), isEmpty, reason: '자정을 넘는 22:00–02:00');
      expect(blackout(0, 1439), isEmpty);
      expect(blackout(600, 600 + 1439), isEmpty, reason: '가장 늦은 끝');
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

    test('조용한 시간도 하루 안에서 시작하고 끝이 늦어야 한다', () {
      List<RuleIssue> quiet(int start, int end) => issues(
        RuleKind.notify,
        RuleParams(quietStartMin: start, quietEndMin: end),
      );

      expect(quiet(1410, 1860), isEmpty, reason: '자정을 넘는 23:30–07:00');
      expect(quiet(600, 600), [issue('quietEndMin', RuleIssueKind.badOrder)]);
      expect(quiet(600, 540), [issue('quietEndMin', RuleIssueKind.badOrder)]);
      expect(quiet(1440, 1500), [
        issue('quietStartMin', RuleIssueKind.outOfRange),
      ]);
    });

    test('식사 시간은 그 시간대보다 길 수 없다', () {
      List<RuleIssue> meal(int start, int end, int minutes) => issues(
        RuleKind.meal,
        RuleParams(startMin: start, endMin: end, minutes: minutes),
      );

      expect(meal(1080, 1110, 30), isEmpty);
      expect(meal(1080, 1110, 40), [
        issue('minutes', RuleIssueKind.outOfRange),
      ]);
      // 자정을 넘는 23:00–01:00(120분).
      expect(meal(1380, 1500, 120), isEmpty);
      expect(meal(1380, 1500, 121), [
        issue('minutes', RuleIssueKind.outOfRange),
      ]);
    });

    test('식사 길이는 시간대와 분이 맞을 때만 본다', () {
      // 끝이 시작보다 이르면 badOrder만 낸다.
      expect(
        issues(
          RuleKind.meal,
          const RuleParams(startMin: 1200, endMin: 1080, minutes: 40),
        ),
        [issue('endMin', RuleIssueKind.badOrder)],
      );
      // 분이 범위 밖이면 outOfRange를 한 번만 낸다.
      expect(
        issues(
          RuleKind.meal,
          RuleParams(
            startMin: 1080,
            endMin: 1110,
            minutes: RuleLimits.minutes.high + 1,
          ),
        ),
        [issue('minutes', RuleIssueKind.outOfRange)],
      );
    });

    test('브리핑 시각은 06:00–12:00의 30분 단위만 받는다', () {
      List<RuleIssue> briefing(int minute) =>
          issues(RuleKind.notify, RuleParams(briefingMin: minute));
      const bad = [RuleIssue('briefingMin', RuleIssueKind.outOfRange)];

      expect(briefing(RuleLimits.briefing.low), isEmpty);
      expect(briefing(RuleLimits.briefing.high), isEmpty);
      expect(briefing(RuleLimits.briefing.low - 1), bad);
      expect(briefing(RuleLimits.briefing.high + 1), bad);
      // 단위는 맞지만 범위 밖(05:30, 12:30).
      expect(
        briefing(RuleLimits.briefing.low - RuleLimits.briefingStepMin),
        bad,
      );
      expect(
        briefing(RuleLimits.briefing.high + RuleLimits.briefingStepMin),
        bad,
      );
      expect(
        briefing(RuleLimits.briefing.low + RuleLimits.briefingStepMin ~/ 2),
        bad,
        reason: '단위가 맞지 않음(06:15)',
      );
      expect(briefing(1440), bad);
    });

    test('브리핑 시각 칩은 06:00부터 12:00까지 30분마다 13개이고 기본값을 담는다', () {
      final choices = RuleLimits.briefingChoices;
      expect(choices, hasLength(13));
      expect(choices.first, RuleLimits.briefing.low);
      expect(choices.last, RuleLimits.briefing.high);
      for (var i = 1; i < choices.length; i++) {
        expect(choices[i] - choices[i - 1], RuleLimits.briefingStepMin);
      }
      for (final minute in choices) {
        expect(
          issues(RuleKind.notify, RuleParams(briefingMin: minute)),
          isEmpty,
          reason: '$minute',
        );
      }
      expect(choices, contains(Defaults.briefingMin));
      expect(() => choices.add(780), throwsUnsupportedError);
    });

    test('알림 상한의 범위', () {
      for (final bad in [
        RuleLimits.notifyCap.low - 1,
        RuleLimits.notifyCap.high + 1,
      ]) {
        expect(issues(RuleKind.notify, RuleParams(notifyCap: bad)), [
          issue('notifyCap', RuleIssueKind.outOfRange),
        ], reason: '$bad');
      }
      for (final ok in [RuleLimits.notifyCap.low, RuleLimits.notifyCap.high]) {
        expect(
          issues(RuleKind.notify, RuleParams(notifyCap: ok)),
          isEmpty,
          reason: '$ok',
        );
      }
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

    test('기본값은 모두 검사를 통과한다', () {
      final defaults = <(RuleKind, RuleParams)>[
        (
          RuleKind.classBuffer,
          const RuleParams(minutes: Defaults.classBufferMin),
        ),
        (
          RuleKind.workWindow,
          const RuleParams(
            startMin: Defaults.dayWindowStartMin,
            endMin: Defaults.dayWindowEndMin,
          ),
        ),
        (RuleKind.maxBlock, const RuleParams(minutes: Defaults.maxBlockMin)),
        (
          RuleKind.meal,
          const RuleParams(
            startMin: Defaults.mealWindowStartMin,
            endMin: Defaults.mealWindowEndMin,
            minutes: Defaults.mealMin,
          ),
        ),
        (
          RuleKind.notify,
          const RuleParams(
            briefingMin: Defaults.briefingMin,
            notifyCap: Defaults.notifyCap,
            quietStartMin: Defaults.quietStartMin,
            quietEndMin: Defaults.quietEndMin,
          ),
        ),
        for (final MapEntry(key: kind, value: minutes)
            in Defaults.estimateMinByKind.entries)
          (RuleKind.estimate, RuleParams(taskKind: kind, minutes: minutes)),
      ];
      for (final (kind, params) in defaults) {
        expect(issues(kind, params), isEmpty, reason: '$kind $params');
      }
    });

    test('알림 재설계 전에는 notify에서 브리핑 시각만 저장한다', () {
      expect(savableNotifyFields, {RuleField.briefingMin});
      // validateRule은 범위만 보므로 하루 상한·조용한 시간은 통과하지만, 저장할 수 없는 자리로 따로 알린다.
      const capAndQuiet = RuleParams(
        briefingMin: Defaults.briefingMin,
        notifyCap: 3,
        quietStartMin: 1380,
        quietEndMin: 1860,
      );
      expect(issues(RuleKind.notify, capAndQuiet), isEmpty);
      expect(unsavableFields(RuleKind.notify, capAndQuiet), [
        RuleField.notifyCap,
        RuleField.quietStartMin,
        RuleField.quietEndMin,
      ]);
      expect(
        unsavableFields(
          RuleKind.notify,
          const RuleParams(briefingMin: Defaults.briefingMin),
        ),
        isEmpty,
      );
      expect(
        unsavableFields(RuleKind.dailyCap, const RuleParams(minutes: 120)),
        isEmpty,
      );
      expect(
        issues(
          RuleKind.notify,
          const RuleParams(briefingMin: Defaults.briefingMin),
        ),
        isEmpty,
      );
    });

    test('RuleField는 RuleParams의 값마다 있는지 본다', () {
      const params = RuleParams(
        minutes: 1,
        position: TravelPosition.dayEdges,
        startMin: 2,
        endMin: 3,
        courseId: 4,
        taskKind: TaskKind.quiz,
        briefingMin: 5,
        notifyCap: 6,
        quietStartMin: 7,
        quietEndMin: 8,
      );
      for (final field in RuleField.values) {
        expect(
          field.isSetIn(params),
          field != RuleField.weekdays,
          reason: field.name,
        );
        expect(field.isSetIn(const RuleParams()), isFalse, reason: field.name);
      }
      // 이름은 params의 JSON 키와 같다.
      expect(params.toJson().keys.toList(), [
        for (final field in RuleField.values)
          if (field != RuleField.weekdays) field.name,
      ]);
    });
  });

  group('PlannerConfig.from', () {
    const defaultWindow = MinuteRange(
      Defaults.dayWindowStartMin,
      Defaults.dayWindowEndMin,
    );
    const defaultMeal = MealGuard(
      window: MinuteRange(
        Defaults.mealWindowStartMin,
        Defaults.mealWindowEndMin,
      ),
      minutes: Defaults.mealMin,
    );
    const defaultDay = DayPlanRules(
      workWindow: defaultWindow,
      travel: null,
      blackouts: [],
      preferred: [],
      dailyCapMin: null,
    );

    test('규칙이 없으면 모든 요일이 기본값이다', () {
      final config = PlannerConfig.from(const []);
      expect(config.classBufferMin, Defaults.classBufferMin);
      expect(config.maxBlockMin, Defaults.maxBlockMin);
      expect(config.meals, [defaultMeal]);
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(config.forWeekday(weekday), defaultDay, reason: '$weekday');
      }
      expect(config.estimateMin(courseId: 1, kind: TaskKind.quiz), isNull);
    });

    test('꺼진 규칙과 값 검사를 통과하지 못한 규칙은 쓰지 않는다', () {
      final config = PlannerConfig.from([
        rule(RuleKind.maxBlock, const RuleParams(minutes: 60), active: false),
        rule(RuleKind.classBuffer, const RuleParams(minutes: 999)),
        rule(
          RuleKind.workWindow,
          const RuleParams(startMin: 600, endMin: 1200),
          active: false,
        ),
        rule(
          RuleKind.blackout,
          const RuleParams(startMin: 600, endMin: 540),
          id: 2,
        ),
        rule(
          RuleKind.travel,
          const RuleParams(minutes: 999, position: TravelPosition.dayEdges),
          id: 3,
        ),
      ]);
      expect(config.maxBlockMin, Defaults.maxBlockMin);
      expect(config.classBufferMin, Defaults.classBufferMin);
      for (var weekday = 1; weekday <= 7; weekday++) {
        expect(config.forWeekday(weekday), defaultDay, reason: '$weekday');
      }
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
      expect(
        config.forWeekday(DateTime.tuesday).travel,
        const TravelTime(minutes: 60, position: TravelPosition.everyClass),
      );
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
      expect(config.meals, const [
        MealGuard(window: MinuteRange(720, 780), minutes: 30),
      ]);
    });

    test('기본 식사 시간대와 겹치지 않는 식사 규칙은 기본값에 더한다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.meal,
          const RuleParams(startMin: 1080, endMin: 1200, minutes: 60),
        ),
      ]);
      expect(config.meals, const [
        defaultMeal,
        MealGuard(window: MinuteRange(1080, 1200), minutes: 60),
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

    test('설정의 목록은 바꿀 수 없다', () {
      final config = PlannerConfig.from([
        rule(
          RuleKind.blackout,
          const RuleParams(startMin: 600, endMin: 660),
          id: 1,
        ),
        rule(
          RuleKind.preferred,
          const RuleParams(startMin: 540, endMin: 720),
          id: 2,
        ),
      ]);
      final monday = config.forWeekday(DateTime.monday);
      expect(() => config.meals.add(defaultMeal), throwsUnsupportedError);
      expect(
        () => monday.blackouts.add(const MinuteRange(0, 60)),
        throwsUnsupportedError,
      );
      expect(
        () => monday.preferred.add(const MinuteRange(0, 60)),
        throwsUnsupportedError,
      );
      // 다른 계산이 같은 설정을 다시 읽어도 그대로다.
      expect(config.meals, [defaultMeal]);
      expect(config.forWeekday(DateTime.monday).blackouts, const [
        MinuteRange(600, 660),
      ]);
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

    test('꺼진 행과 값 검사를 통과하지 못한 행은 쓰지 않는다', () {
      final config = NotifyConfig.from([
        rule(RuleKind.notify, const RuleParams(briefingMin: 420), id: 1),
        rule(
          RuleKind.notify,
          const RuleParams(briefingMin: 600),
          id: 2,
          active: false,
        ),
        // 단위가 맞지 않는 브리핑 시각이 든 행은 행 전체를 버린다(같은 행의 상한도).
        rule(
          RuleKind.notify,
          const RuleParams(briefingMin: 615, notifyCap: 3),
          id: 3,
        ),
      ]);
      expect(config.briefingMin, 420);
      expect(config.notifyCap, Defaults.notifyCap);
    });

    test('저장 시각이 같으면 id가 큰 행을 쓴다', () {
      final at = DateTime(2026, 10, 1);
      for (final (firstId, secondId) in [(3, 7), (7, 3)]) {
        final config = NotifyConfig.from([
          rule(
            RuleKind.notify,
            const RuleParams(briefingMin: 420),
            id: firstId,
            updatedAt: at,
          ),
          rule(
            RuleKind.notify,
            const RuleParams(briefingMin: 540),
            id: secondId,
            updatedAt: at,
          ),
        ]);
        expect(
          config.briefingMin,
          secondId > firstId ? 540 : 420,
          reason: '$firstId, $secondId',
        );
      }
    });

    test('notify가 아닌 규칙은 보지 않는다', () {
      final config = NotifyConfig.from([
        rule(RuleKind.maxBlock, const RuleParams(minutes: 60)),
      ]);
      expect(config.notifyCap, Defaults.notifyCap);
    });
  });

  group('값 클래스', () {
    test('MealGuard·TravelTime·DayPlanRules는 값이 같으면 같다', () {
      const meal = MealGuard(window: MinuteRange(690, 810), minutes: 40);
      expect(meal, const MealGuard(window: MinuteRange(690, 810), minutes: 40));
      expect(
        meal.hashCode,
        const MealGuard(window: MinuteRange(690, 810), minutes: 40).hashCode,
      );
      expect(
        meal,
        isNot(const MealGuard(window: MinuteRange(690, 810), minutes: 30)),
      );
      expect(
        meal,
        isNot(const MealGuard(window: MinuteRange(700, 810), minutes: 40)),
      );

      const travel = TravelTime(minutes: 40, position: TravelPosition.dayEdges);
      expect(
        travel,
        const TravelTime(minutes: 40, position: TravelPosition.dayEdges),
      );
      expect(
        travel,
        isNot(
          const TravelTime(minutes: 40, position: TravelPosition.everyClass),
        ),
      );
      expect(
        travel,
        isNot(const TravelTime(minutes: 30, position: TravelPosition.dayEdges)),
      );

      DayPlanRules day({
        MinuteRange window = const MinuteRange(480, 1380),
        TravelTime? travel,
        List<MinuteRange> blackouts = const [MinuteRange(600, 660)],
        List<MinuteRange> preferred = const [],
        int? dailyCapMin = 240,
      }) => DayPlanRules(
        workWindow: window,
        travel: travel,
        blackouts: blackouts,
        preferred: preferred,
        dailyCapMin: dailyCapMin,
      );
      expect(day(), day(blackouts: [const MinuteRange(600, 660)]));
      expect(
        day().hashCode,
        day(blackouts: [const MinuteRange(600, 660)]).hashCode,
      );
      for (final other in [
        day(window: const MinuteRange(540, 1380)),
        day(travel: travel),
        day(blackouts: const []),
        day(blackouts: const [MinuteRange(600, 700)]),
        day(preferred: const [MinuteRange(600, 660)]),
        day(dailyCapMin: null),
      ]) {
        expect(day(), isNot(other), reason: '$other');
      }
    });

    test('toString은 값을 보이고 Rule은 사용자 문장을 넣지 않는다', () {
      expect(
        const MealGuard(window: MinuteRange(690, 810), minutes: 40).toString(),
        'MealGuard(MinuteRange(690, 810), minutes: 40)',
      );
      expect(
        const TravelTime(
          minutes: 40,
          position: TravelPosition.dayEdges,
        ).toString(),
        'TravelTime(40, dayEdges)',
      );
      expect(
        const RuleParams(
          minutes: 40,
          position: TravelPosition.dayEdges,
        ).toString(),
        'RuleParams({minutes: 40, position: day_edges})',
      );
      final text = rule(
        RuleKind.travel,
        const RuleParams(minutes: 40, position: TravelPosition.dayEdges),
        sentence: '통학은 40분 걸려',
      ).toString();
      expect(text, contains('kind: travel'));
      expect(text, contains('minutes: 40'));
      expect(text, isNot(contains('통학')));
    });
  });

  group('저장 정책', () {
    test('종류마다의 정책은 docs/architecture.md \'내 규칙\'의 표와 같다', () {
      expect(
        {
          for (final kind in RuleKind.values)
            if (kind.singleRow) kind,
        },
        {RuleKind.classBuffer, RuleKind.maxBlock, RuleKind.notify},
      );
      expect(
        {
          for (final kind in RuleKind.values)
            if (kind.replacesSameWeekdays) kind,
        },
        {RuleKind.workWindow, RuleKind.dailyCap, RuleKind.travel},
      );
      expect(
        {
          for (final kind in RuleKind.values)
            if (kind.allowsWeekdays) kind,
        },
        {
          RuleKind.travel,
          RuleKind.workWindow,
          RuleKind.blackout,
          RuleKind.preferred,
          RuleKind.dailyCap,
        },
      );
      // 요일 집합으로 대신하는 종류는 요일을 쓰고, 하나만 두는 종류는 요일을 쓰지 않는다.
      for (final kind in RuleKind.values) {
        if (kind.replacesSameWeekdays) {
          expect(kind.allowsWeekdays, isTrue, reason: kind.name);
        }
        if (kind.singleRow) {
          expect(kind.allowsWeekdays, isFalse, reason: kind.name);
        }
      }
    });

    test('canonicalWeekdays는 정렬하고 겹침을 빼며 일곱 요일이면 null이다', () {
      expect(canonicalWeekdays(null), isNull);
      expect(canonicalWeekdays([3, 1]), [1, 3]);
      expect(canonicalWeekdays([5, 5, 2]), [2, 5]);
      expect(canonicalWeekdays([1, 2, 3, 4, 5, 6, 7]), isNull);
      expect(canonicalWeekdays([7, 6, 5, 4, 3, 2, 1]), isNull);
      expect(canonicalWeekdays([1, 2, 3, 4, 5, 6]), [1, 2, 3, 4, 5, 6]);
      expect(canonicalWeekdays([0, 1, 2, 3, 4, 5, 6]), hasLength(7));
      expect(() => canonicalWeekdays([3, 1])!.add(5), throwsUnsupportedError);
    });

    test('하나만 두는 종류는 그 종류의 행 전부(꺼진 행도)를 나중 것부터 대신한다', () {
      final old = rule(
        RuleKind.notify,
        const RuleParams(briefingMin: 420),
        id: 1,
      );
      final off = rule(
        RuleKind.notify,
        const RuleParams(briefingMin: 450),
        id: 2,
        active: false,
      );
      final other = rule(
        RuleKind.maxBlock,
        const RuleParams(minutes: 60),
        id: 3,
      );
      expect(
        rulesReplacedBy(
          RuleKind.notify,
          const RuleParams(briefingMin: 480),
          null,
          [old, off, other],
        ),
        [off, old],
      );
    });

    test('같은 요일을 대신하는 종류는 요일 집합이 같은 켜진 행만 대신한다', () {
      const params = RuleParams(minutes: 40, position: TravelPosition.dayEdges);
      final everyDay = rule(RuleKind.travel, params, id: 1);
      final allDays = rule(
        RuleKind.travel,
        params,
        id: 2,
        weekdays: [7, 6, 5, 4, 3, 2, 1],
      );
      final monWed = rule(RuleKind.travel, params, id: 3, weekdays: [3, 1]);
      final monWedOff = rule(
        RuleKind.travel,
        params,
        id: 4,
        weekdays: [1, 3],
        active: false,
      );
      final monday = rule(RuleKind.travel, params, id: 5, weekdays: [1]);
      final existing = [everyDay, allDays, monWed, monWedOff, monday];

      expect(rulesReplacedBy(RuleKind.travel, params, null, existing), [
        allDays,
        everyDay,
      ]);
      expect(
        rulesReplacedBy(RuleKind.travel, params, [
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        ], existing),
        [allDays, everyDay],
      );
      expect(rulesReplacedBy(RuleKind.travel, params, [1, 3], existing), [
        monWed,
      ]);
      expect(rulesReplacedBy(RuleKind.travel, params, [2], existing), isEmpty);
    });

    test('예상 시간은 과목·종류가 같은 켜진 행만 대신한다', () {
      final quiz = rule(
        RuleKind.estimate,
        const RuleParams(courseId: 1, taskKind: TaskKind.quiz, minutes: 30),
        id: 1,
      );
      final course = rule(
        RuleKind.estimate,
        const RuleParams(courseId: 1, minutes: 60),
        id: 2,
      );
      final otherCourse = rule(
        RuleKind.estimate,
        const RuleParams(courseId: 2, taskKind: TaskKind.quiz, minutes: 30),
        id: 3,
      );
      final off = rule(
        RuleKind.estimate,
        const RuleParams(courseId: 1, taskKind: TaskKind.quiz, minutes: 45),
        id: 4,
        active: false,
      );
      expect(
        rulesReplacedBy(
          RuleKind.estimate,
          const RuleParams(courseId: 1, taskKind: TaskKind.quiz, minutes: 40),
          null,
          [quiz, course, otherCourse, off],
        ),
        [quiz],
      );
    });

    test('피할 시간·선호 시간대·식사는 여러 개 두므로 대신하지 않는다', () {
      for (final (kind, params) in [
        (RuleKind.blackout, const RuleParams(startMin: 600, endMin: 660)),
        (RuleKind.preferred, const RuleParams(startMin: 600, endMin: 660)),
        (
          RuleKind.meal,
          const RuleParams(startMin: 1080, endMin: 1200, minutes: 40),
        ),
      ]) {
        expect(
          rulesReplacedBy(kind, params, null, [rule(kind, params)]),
          isEmpty,
          reason: kind.name,
        );
      }
    });

    test('저장할 값은 하나만 두는 종류면 가장 최근 행(꺼진 행도)에 합친 것이다', () {
      final older = rule(
        RuleKind.notify,
        const RuleParams(briefingMin: 420),
        id: 1,
      );
      final latestOff = rule(
        RuleKind.notify,
        const RuleParams(briefingMin: 450, notifyCap: 3),
        id: 2,
        active: false,
      );
      expect(
        paramsToStore(RuleKind.notify, const RuleParams(briefingMin: 540), [
          older,
          latestOff,
        ]),
        const RuleParams(briefingMin: 540, notifyCap: 3),
      );
      expect(
        paramsToStore(RuleKind.notify, const RuleParams(briefingMin: 540), []),
        const RuleParams(briefingMin: 540),
      );
      // 여러 개 두는 종류는 들어온 값 그대로다.
      const blackout = RuleParams(startMin: 600, endMin: 660);
      expect(
        paramsToStore(RuleKind.blackout, blackout, [
          rule(RuleKind.blackout, const RuleParams(startMin: 0, endMin: 60)),
        ]),
        blackout,
      );
    });

    test('통학 칩은 이동 시간 규칙(하루 첫 수업 전·마지막 수업 뒤)으로 저장할 수 있다', () {
      expect(Defaults.commuteChoices, contains(Defaults.commuteMin));
      for (final minutes in Defaults.commuteChoices) {
        expect(
          issues(
            RuleKind.travel,
            RuleParams(minutes: minutes, position: TravelPosition.dayEdges),
          ),
          isEmpty,
          reason: '$minutes',
        );
      }
    });
  });
}
