// 06 AI 비서 내 규칙 카드 테스트. docs/screens.md '06 AI 비서'의 카드 4, docs/architecture.md '내 규칙'(말로
// 정하기·빈 값 채우기·하나만 두는 종류와 대신하는 규칙).
//
// 지금은 2026-11-19(목) 10:30이다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_rules.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19, 10, 30);

const _ds = Course(id: 1, name: '데이터구조');

Rule _rule(
  int id,
  RuleKind kind,
  RuleParams params, {
  List<int>? weekdays,
  bool active = true,
  int updatedDay = 1,
}) => Rule(
  id: id,
  kind: kind,
  params: params,
  weekdays: weekdays,
  active: active,
  source: EntrySource.manual,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, updatedDay),
);

ParsedRule _parsed(
  RuleKind kind, {
  bool remove = false,
  int? minutes,
  TravelPosition? position,
  int? start,
  int? end,
  String? timeExpression,
  List<int>? weekdays,
  String? course,
  TaskKind? taskKind,
  int? briefingMin,
}) => ParsedRule(
  kind: kind,
  remove: remove,
  minutes: minutes,
  position: position,
  startMin: start,
  endMin: end,
  timeExpression: timeExpression,
  weekdays: weekdays,
  course: course,
  taskKind: taskKind,
  briefingMin: briefingMin,
);

List<AssistantMessage> _reply(
  List<ParsedRule> rules, {
  List<Rule> saved = const [],
  UnsupportedRuleKind? unsupported,
}) {
  var id = 0;
  return replyCards(
    ParseResult(
      intent: ParseIntent.setRule,
      rules: rules,
      unsupportedRule: unsupported,
    ),
    now: _now,
    ruleMode: true,
    nextId: () => ++id,
    snapshot: AssistantSnapshot(courses: const [_ds], rules: saved),
  );
}

List<AssistantMessage> _pick(
  AssistantMessage card,
  int index, {
  List<Rule> saved = const [],
}) {
  var id = 99;
  return afterPick(
    card as AskCard,
    index,
    now: _now,
    nextId: () => ++id,
    snapshot: AssistantSnapshot(courses: const [_ds], rules: saved),
  );
}

void main() {
  group('정하기', () {
    test('값이 다 있으면 미리보기 카드이고, 요일은 정렬하고 일곱 요일이면 매일이다', () {
      final card =
          _reply([
                _parsed(
                  RuleKind.blackout,
                  start: 19 * 60,
                  end: 21 * 60,
                  timeExpression: '저녁 7시부터 9시',
                  weekdays: [4, 2],
                ),
              ]).single
              as RuleCard;
      expect(card.draft.kind, RuleKind.blackout);
      expect(card.draft.params.startMin, 19 * 60);
      expect(card.draft.params.endMin, 21 * 60);
      expect(card.draft.weekdays, [2, 4]);
      expect(card.say, isNull);
      expect(card.replaced, isEmpty);
      expect(
        ruleScopeText(card.draft.kind, card.draft.weekdays),
        '피할 시간 · 화·목요일',
      );

      final everyDay =
          _reply([
                _parsed(
                  RuleKind.dailyCap,
                  minutes: 240,
                  weekdays: [1, 2, 3, 4, 5, 6, 7],
                ),
              ]).single
              as RuleCard;
      expect(everyDay.draft.weekdays, isNull);
      expect(
        ruleScopeText(everyDay.draft.kind, everyDay.draft.weekdays),
        '하루 최대 공부량 · 매일',
      );
      expect(ruleScopeText(RuleKind.maxBlock, null), '한 번에 할 최대 시간 · 늘');
      expect(ruleScopeText(RuleKind.estimate, null), '예상 시간 · 늘');
    });

    test('끝이 시작보다 이르면 자정을 넘는 구간이다', () {
      final card =
          _reply([
                _parsed(
                  RuleKind.blackout,
                  start: 23 * 60,
                  end: 60,
                  timeExpression: '밤 11시부터 새벽 1시',
                ),
              ]).single
              as RuleCard;
      expect(
        (card.draft.params.startMin, card.draft.params.endMin),
        (1380, 1500),
      );
    });

    test('공부 가능한 시간대의 빈 끝은 지금 하루 창으로 채워 카드 위 한 줄로 확인받는다', () {
      final card =
          _reply([
                _parsed(
                  RuleKind.workWindow,
                  end: 23 * 60,
                  timeExpression: '밤 11시 이후',
                ),
              ]).single
              as RuleCard;
      expect(card.draft.params.startMin, 8 * 60);
      expect(card.say, '오전 8시부터 오후 11시까지만 할 일을 놓을까요?');
    });

    test('과목은 과목 id로 바꾸고, 모르는 과목이면 되묻는다', () {
      final card =
          _reply([
                _parsed(
                  RuleKind.estimate,
                  minutes: 180,
                  course: ' 데이터구조 ',
                  taskKind: TaskKind.assignment,
                ),
              ]).single
              as RuleCard;
      expect(card.draft.params.courseId, 1);
      expect(card.draft.courseName, '데이터구조');

      final unknown =
          _reply([
                _parsed(
                  RuleKind.estimate,
                  minutes: 180,
                  course: '운영체제',
                  taskKind: TaskKind.assignment,
                ),
              ]).single
              as InfoCard;
      expect(unknown.kind, InfoKind.ruleQuestion);
      expect(unknown.question, '어느 과목인가요? 시간표에 있는 과목 이름으로 말해 주세요');
    });

    test('빈 값이나 범위를 벗어난 값은 되묻는 문장을 보이고 저장하지 않는다', () {
      final missing = _reply([_parsed(RuleKind.dailyCap)]).single as InfoCard;
      expect(missing.kind, InfoKind.ruleQuestion);
      expect(missing.question, isNotEmpty);
      final tooLong =
          _reply([_parsed(RuleKind.maxBlock, minutes: 600)]).single as InfoCard;
      expect(tooLong.kind, InfoKind.ruleQuestion);
    });

    test('하나만 두는 종류는 지금 행과 합친 값으로 보이고, 지금 값을 바꾼다고 알린다', () {
      final saved = [
        _rule(1, RuleKind.classBuffer, const RuleParams(minutes: 10)),
      ];
      final card =
          _reply([
                _parsed(RuleKind.classBuffer, minutes: 15),
              ], saved: saved).single
              as RuleCard;
      expect(card.draft.merged.minutes, 15);
      expect(card.replaced.single.id, 1);
      expect(ruleReplacedText(card), '지금 값 「10분」을 이 값으로 바꿔요');
    });

    test('하나만 두는 종류는 행이 여럿이어도 가장 최근 행의 값을 바꾼다고 알리고, 꺼진 행은 알리지 않는다', () {
      final two = [
        _rule(
          1,
          RuleKind.maxBlock,
          const RuleParams(minutes: 60),
          updatedDay: 2,
        ),
        _rule(
          2,
          RuleKind.maxBlock,
          const RuleParams(minutes: 90),
          updatedDay: 5,
        ),
      ];
      final card =
          _reply([_parsed(RuleKind.maxBlock, minutes: 120)], saved: two).single
              as RuleCard;
      expect(card.replaced, hasLength(2));
      expect(ruleReplacedText(card), '지금 값 「1시간 30분」을 이 값으로 바꿔요');

      final off =
          _reply(
                [_parsed(RuleKind.classBuffer, minutes: 15)],
                saved: [
                  _rule(
                    1,
                    RuleKind.classBuffer,
                    const RuleParams(minutes: 10),
                    active: false,
                  ),
                ],
              ).single
              as RuleCard;
      expect(off.replaced, isEmpty);
      expect(ruleReplacedText(off), isNull);
    });

    test('같은 요일의 이전 규칙을 대신하면 꺼진다고 알리고, 꺼진 규칙은 알리지 않는다', () {
      final saved = [
        _rule(
          1,
          RuleKind.workWindow,
          const RuleParams(startMin: 540, endMin: 1380),
        ),
        _rule(
          2,
          RuleKind.workWindow,
          const RuleParams(startMin: 600, endMin: 1320),
          active: false,
        ),
      ];
      final card =
          _reply([
                _parsed(
                  RuleKind.workWindow,
                  start: 7 * 60,
                  end: 22 * 60,
                  timeExpression: '오전 7시부터 밤 10시',
                ),
              ], saved: saved).single
              as RuleCard;
      expect([for (final rule in card.replaced) rule.id], [1]);
      expect(ruleReplacedText(card), '지금 켜진 「09:00–23:00」 규칙은 꺼져요');
    });

    test('여러 개를 대신하면 개수로 알린다', () {
      final card = RuleCard(
        1,
        draft: const RuleDraft(
          kind: RuleKind.workWindow,
          params: RuleParams(startMin: 420, endMin: 1320),
          merged: RuleParams(startMin: 420, endMin: 1320),
        ),
        replaced: [
          _rule(
            1,
            RuleKind.workWindow,
            const RuleParams(startMin: 540, endMin: 1380),
          ),
          _rule(
            2,
            RuleKind.workWindow,
            const RuleParams(startMin: 600, endMin: 1380),
          ),
        ],
      );
      expect(ruleReplacedText(card), '같은 자리의 이전 규칙 2개는 꺼요');
      expect(ruleReplacedText(RuleCard(1, draft: card.draft)), isNull);
    });

    test('규칙이 둘 이상이면 첫 카드 위에 개수를 적는다', () {
      final cards = _reply([
        _parsed(RuleKind.dailyCap, minutes: 240),
        _parsed(RuleKind.maxBlock, minutes: 90),
      ]);
      expect((cards.first as RuleCard).say, '규칙 2개를 찾았어요. 하나씩 확인해 주세요.');
      expect((cards.last as RuleCard).say, isNull);
    });
  });

  group('되묻기', () {
    test('8–11시에 오전·오후가 없으면 묻고, 오후를 고르면 낮 12시 전 시각을 12시간 옮긴다', () {
      final ask =
          _reply([
                _parsed(
                  RuleKind.blackout,
                  start: 9 * 60,
                  end: 11 * 60,
                  timeExpression: '9시부터 11시',
                ),
              ]).single
              as AskCard;
      expect(ask.topic, AskTopic.meridiem);
      expect(ask.intent, ParseIntent.setRule);
      expect(ask.question, '9시가 오전인가요, 오후인가요?');
      expect(ask.sub, '피할 시간');
      expect(
        [for (final option in ask.options) option.label],
        ['오전 9시부터 오전 11시까지', '오후 9시부터 오후 11시까지'],
      );

      final pm = _pick(ask, 1).single as RuleCard;
      expect(
        (pm.draft.params.startMin, pm.draft.params.endMin),
        (21 * 60, 23 * 60),
      );
      final am = _pick(ask, 0).single as RuleCard;
      expect(am.draft.params.startMin, 9 * 60);
    });

    test('오후를 고르면 끝의 12시는 밤 12시다', () {
      final ask =
          _reply([
                _parsed(
                  RuleKind.blackout,
                  start: 11 * 60,
                  end: 12 * 60,
                  timeExpression: '11시부터 12시',
                ),
              ]).single
              as AskCard;
      expect(
        [for (final option in ask.options) option.label],
        ['오전 11시부터 오후 12시까지', '오후 11시부터 밤 12시까지'],
      );
      final pm = _pick(ask, 1).single as RuleCard;
      expect(
        (pm.draft.params.startMin, pm.draft.params.endMin),
        (23 * 60, 24 * 60),
      );
      final am = _pick(ask, 0).single as RuleCard;
      expect(
        (am.draft.params.startMin, am.draft.params.endMin),
        (11 * 60, 12 * 60),
      );
    });

    test('시작만 말했으면 시작 시각부터로 묻는다', () {
      final ask =
          _reply([
                _parsed(
                  RuleKind.workWindow,
                  start: 9 * 60,
                  timeExpression: '9시부터',
                ),
              ]).single
              as AskCard;
      expect(
        [for (final option in ask.options) option.label],
        ['오전 9시부터', '오후 9시부터'],
      );
    });

    test('끝만 말했으면 끝 시각으로 묻는다', () {
      final ask =
          _reply([
                _parsed(
                  RuleKind.workWindow,
                  end: 11 * 60,
                  timeExpression: '11시 이후엔',
                ),
              ]).single
              as AskCard;
      expect(ask.question, '11시가 오전인가요, 오후인가요?');
      expect(ask.options.last.label, '오후 11시까지');
    });

    test('이동 시간의 자리가 없으면 묻고, 고르면 그 자리로 미리보기 카드다', () {
      final ask =
          _reply([_parsed(RuleKind.travel, minutes: 40)]).single as AskCard;
      expect(ask.topic, AskTopic.rulePosition);
      expect(ask.question, '매 수업 앞뒤인가요, 하루 첫 수업 전과 마지막 수업 뒤인가요?');
      expect(ask.sub, '이동 시간 40분');
      expect(
        [for (final option in ask.options) option.label],
        ['매 수업 앞뒤', '하루 첫 수업 전·마지막 수업 뒤'],
      );
      final card = _pick(ask, 1).single as RuleCard;
      expect(card.draft.params.position, TravelPosition.dayEdges);
      expect(card.draft.params.minutes, 40);
    });

    test('이동 시간의 분도 없으면 분부터 되묻는다', () {
      final info = _reply([_parsed(RuleKind.travel)]).single as InfoCard;
      expect(info.kind, InfoKind.ruleQuestion);
    });
  });

  group('정할 수 없는 조건', () {
    test('정할 수 없는 조건이나 규칙 항목이 없으면 안내한다', () {
      for (final kind in UnsupportedRuleKind.values) {
        final info = _reply(const [], unsupported: kind).single as InfoCard;
        expect(info.kind, InfoKind.ruleUnsupported);
        expect(info.unsupported, kind);
      }
      final empty = _reply(const []).single as InfoCard;
      expect(empty.unsupported, UnsupportedRuleKind.other);
    });

    test('알림 규칙은 저장하지 않고 알림 조건으로 안내한다', () {
      final info =
          _reply([_parsed(RuleKind.notify, briefingMin: 7 * 60)]).single
              as InfoCard;
      expect(info.kind, InfoKind.ruleUnsupported);
      expect(info.unsupported, UnsupportedRuleKind.notification);
    });

    test('예시는 알림을 뺀 아홉 종류다', () {
      expect(ruleExamples, hasLength(9));
      expect(
        ruleExamples.map((example) => example.$1),
        isNot(contains(RuleKind.notify)),
      );
    });
  });

  group('지우기', () {
    final saved = [
      _rule(
        1,
        RuleKind.blackout,
        const RuleParams(startMin: 1140, endMin: 1260),
        weekdays: [2],
        updatedDay: 3,
      ),
      _rule(
        2,
        RuleKind.blackout,
        const RuleParams(startMin: 1320, endMin: 1380),
        updatedDay: 5,
      ),
      _rule(
        3,
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
        active: false,
      ),
      _rule(4, RuleKind.estimate, const RuleParams(courseId: 1, minutes: 180)),
    ];

    test('켜진 규칙이 없으면 안내한다', () {
      final info =
          _reply([
                _parsed(RuleKind.dailyCap, remove: true),
              ], saved: saved).single
              as InfoCard;
      expect(info.kind, InfoKind.noRuleToRemove);
      expect(info.question, '하루 최대 공부량');
    });

    test('하나면 지우기 카드이고, 여럿이면 최근 것부터 고르게 한다', () {
      final one =
          _reply([
                _parsed(RuleKind.estimate, remove: true),
              ], saved: saved).single
              as RuleRemoveCard;
      expect(one.rule.id, 4);
      expect(one.courseName, '데이터구조');
      expect(one.say, '지우기 전에 확인해 주세요.');

      final pick =
          _reply([
                _parsed(RuleKind.blackout, remove: true),
              ], saved: saved).single
              as RulePickCard;
      expect([for (final rule in pick.rules) rule.id], [2, 1]);
      expect(pick.say, '켜진 피할 시간 규칙이 2개 있어요.');
      var id = 99;
      final card = afterRulePick(pick, 1, nextId: () => ++id);
      expect(card.id, 100);
      expect(card.rule.id, 1);
      expect(pick.pick(1).picked, 1);
    });

    test('말한 요일·시각으로 좁히고, 맞는 것이 없으면 그 값으로는 좁히지 않는다', () {
      final byDay =
          _reply([
                _parsed(RuleKind.blackout, remove: true, weekdays: [2]),
              ], saved: saved).single
              as RuleRemoveCard;
      expect(byDay.rule.id, 1);
      final byStart =
          _reply([
                _parsed(
                  RuleKind.blackout,
                  remove: true,
                  start: 1320,
                  timeExpression: '밤 10시',
                ),
              ], saved: saved).single
              as RuleRemoveCard;
      expect(byStart.rule.id, 2);
      final noMatch =
          _reply([
                _parsed(RuleKind.blackout, remove: true, weekdays: [5]),
              ], saved: saved).single
              as RulePickCard;
      expect(noMatch.rules, hasLength(2));
    });

    test('예상 시간은 과목과 종류로 좁힌다', () {
      final more = [
        ...saved,
        _rule(
          5,
          RuleKind.estimate,
          const RuleParams(taskKind: TaskKind.quiz, minutes: 30),
          updatedDay: 9,
        ),
      ];
      final byCourse =
          _reply([
                _parsed(RuleKind.estimate, remove: true, course: '데이터구조'),
              ], saved: more).single
              as RuleRemoveCard;
      expect(byCourse.rule.id, 4);
      final byKind =
          _reply([
                _parsed(
                  RuleKind.estimate,
                  remove: true,
                  taskKind: TaskKind.quiz,
                ),
              ], saved: more).single
              as RuleRemoveCard;
      expect(byKind.rule.id, 5);
    });

    test('읽을 수 없는 규칙은 지울 대상으로 보지 않는다', () {
      final info =
          _reply(
                [_parsed(RuleKind.maxBlock, remove: true)],
                saved: [
                  _rule(
                    9,
                    RuleKind.maxBlock,
                    const UnreadableRuleParams('{broken'),
                  ),
                ],
              ).single
              as InfoCard;
      expect(info.kind, InfoKind.noRuleToRemove);
    });
  });
}
