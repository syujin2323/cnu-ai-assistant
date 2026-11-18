// 06 AI 비서의 내 규칙 카드. docs/screens.md '06 AI 비서'의 카드 4, docs/architecture.md '내 규칙'(말로 정하기·빈 값
// 채우기·하나만 두는 종류와 대신하는 규칙).
//
// /v1/parse의 `rules[]` 항목마다 오전·오후와 이동 시간의 자리를 되묻고, 말하지 않은 값을 채운 뒤([completeRule])
// 값을 검사해([validateRule]) 미리보기 카드를 만든다. 채우기가 제안한 값이 있으면 카드 위 한 줄로 그 값이 맞는지
// 묻고, 카드의 [저장]이 그 답이다. 그 밖의 빈 값과 범위를 벗어난 값은 되묻는 문장([ruleIssueQuestion])을 보이고
// 저장하지 않는다(다시 말하면 새로 받음). 정할 수 없는 조건(`unsupportedRule`, 알림)은 '아직 그런 조건은 정할
// 수 없어요'로 답한다. 지우기(`remove`)는 같은 종류의 켜진 규칙 가운데 말한 요일·시각·과목·종류로 대상을 좁혀
// 하나면 확인받고 여럿이면 고르게 한다. 문구는 디자인 전 임시 문구다(최종 프로토타입 06의 문구를 따름).

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/parse_checks.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 정할 수 없는 조건을 받았을 때 보이는 예시(종류 이름과 문장). 누르면 그 문장을 입력창에 넣는다. 알림은 지금
/// 정하지 않으므로 넣지 않는다. 문장은 docs/screens.md '12 내 규칙' 표의 '말로 할 때 예'다.
const List<(RuleKind, String)> ruleExamples = [
  (RuleKind.travel, '학교에서 집까지 40분 걸려'),
  (RuleKind.classBuffer, '수업 앞뒤 여유 15분'),
  (RuleKind.workWindow, '밤 11시 이후엔 공부 안 할래'),
  (RuleKind.blackout, '화요일 저녁 7시부터 9시는 비워 줘'),
  (RuleKind.preferred, '오전에 공부가 잘 돼'),
  (RuleKind.maxBlock, '한 번에 1시간 반까지만'),
  (RuleKind.dailyCap, '하루 공부는 4시간까지만'),
  (RuleKind.meal, '점심은 12시부터 1시 사이에 먹어'),
  (RuleKind.estimate, '과제는 보통 3시간 걸려'),
];

/// 내 규칙 응답([ParseIntent.setRule])의 카드. [now]는 지금(한국 시각), [snapshot]은 과목·내 규칙이다.
List<AssistantMessage> ruleReplyCards(
  ParseResult result, {
  required DateTime now,
  required int Function() nextId,
  required AssistantSnapshot snapshot,
}) {
  if (result.unsupportedRule case final kind?) {
    return [InfoCard(nextId(), InfoKind.ruleUnsupported, unsupported: kind)];
  }
  if (result.rules.isEmpty) {
    return [
      InfoCard(
        nextId(),
        InfoKind.ruleUnsupported,
        unsupported: UnsupportedRuleKind.other,
      ),
    ];
  }
  final cards = [
    for (final rule in result.rules)
      _resolveRule(rule, const {}, now, nextId, snapshot),
  ];
  final rules = cards.whereType<RuleCard>().toList();
  if (rules.length < 2 || rules.first.say != null) return cards;
  final first = rules.first;
  return [
    for (final card in cards)
      if (card == first)
        RuleCard(
          first.id,
          draft: first.draft,
          replaced: first.replaced,
          say: '규칙 ${rules.length}개를 찾았어요. 하나씩 확인해 주세요.',
        )
      else
        card,
  ];
}

/// 내 규칙 되묻기 [card]의 [index]번째를 고른 뒤의 카드.
List<AssistantMessage> ruleCardsAfterPick(
  AskCard card,
  int index, {
  required DateTime now,
  required int Function() nextId,
  required AssistantSnapshot snapshot,
}) {
  final answered = {...card.answered, card.topic};
  return [
    for (final rule in card.options[index].rules)
      _resolveRule(rule, answered, now, nextId, snapshot),
  ];
}

/// 지울 규칙이 여럿일 때 [card]의 [index]번째를 고른 뒤의 카드.
RuleRemoveCard afterRulePick(
  RulePickCard card,
  int index, {
  required int Function() nextId,
}) {
  final rule = card.rules[index];
  return RuleRemoveCard(
    nextId(),
    rule: rule,
    courseName: card.courseNames[rule.params.courseId],
  );
}

/// 규칙 카드 제목 아래 한 줄: '{종류} · {늘|매일|월·수요일}'. 하나만 두는 종류와 예상 시간은 요일이 없어 '늘'이다.
String ruleScopeText(RuleKind kind, List<int>? weekdays) {
  final scope = kind.singleRow || kind == RuleKind.estimate
      ? '늘'
      : weekdays == null
      ? '매일'
      : '${weekdays.map(weekdayText).join('·')}요일';
  return '${ruleKindName(kind)} · $scope';
}

/// 저장하면 바뀌거나 꺼지는 지금 규칙을 알리는 줄. 하나만 두는 종류는 '지금 값 「10분」을 이 값으로 바꿔요',
/// 그 밖에는 '지금 켜진 「09:00–23:00」 규칙은 꺼져요'(둘 이상이면 '같은 자리의 이전 규칙 N개는 꺼요')이고,
/// 바뀌는 규칙이 없으면 null이다.
String? ruleReplacedText(RuleCard card) {
  final replaced = card.replaced;
  if (replaced.isEmpty) return null;
  final kind = card.draft.kind;
  if (replaced.length > 1 && !kind.singleRow) {
    return ruleTurnOffSentence(replaced.length);
  }
  final old = replaced.first;
  final short = ruleShortValue(
    kind,
    old.params,
    weekdays: old.weekdays,
    courseName: card.draft.courseName,
  );
  if (short == null) return null;
  return kind.singleRow
      ? '지금 값 ${withJosa('「$short」', Josa.eulReul)} 이 값으로 바꿔요'
      : '지금 켜진 「$short」 규칙은 꺼져요';
}

AssistantMessage _resolveRule(
  ParsedRule rule,
  Set<AskTopic> answered,
  DateTime now,
  int Function() nextId,
  AssistantSnapshot snapshot,
) {
  if (rule.remove) return _removeCard(rule, nextId, snapshot);
  if (!ruleKindSavable(rule.kind)) {
    return InfoCard(
      nextId(),
      InfoKind.ruleUnsupported,
      unsupported: UnsupportedRuleKind.notification,
    );
  }
  if (!answered.contains(AskTopic.meridiem) && _needsMeridiem(rule, now)) {
    return _meridiemAsk(nextId(), rule, answered);
  }
  final course = _textOrNull(rule.course);
  int? courseId;
  if (course != null) {
    courseId = snapshot.courses
        .where((candidate) => candidate.name == course)
        .firstOrNull
        ?.id;
    if (courseId == null) {
      return InfoCard(
        nextId(),
        InfoKind.ruleQuestion,
        question: '어느 과목인가요? 시간표에 있는 과목 이름으로 말해 주세요',
      );
    }
  }
  final weekdays = canonicalWeekdays(rule.weekdays);
  final completion = completeRule(
    rule.kind,
    RuleParams(
      minutes: rule.minutes,
      position: rule.position,
      startMin: rule.startMin,
      endMin: rule.endMin,
      courseId: courseId,
      taskKind: rule.taskKind,
      briefingMin: rule.briefingMin,
      notifyCap: rule.notifyCap,
      quietStartMin: rule.quietStartMin,
      quietEndMin: rule.quietEndMin,
    ),
    current: PlannerConfig.from(snapshot.rules),
    weekdays: weekdays,
  );
  final merged = paramsToStore(rule.kind, completion.params, snapshot.rules);
  final issues = validateRule(rule.kind, merged, weekdays: weekdays);
  if (issues.isNotEmpty) {
    final issue = issues.first;
    // 자리를 고르면 늘 채워지므로 다시 묻지 않는다.
    if (issue == const RuleIssue('position', RuleIssueKind.missing)) {
      return _positionAsk(nextId(), rule, answered);
    }
    return InfoCard(
      nextId(),
      InfoKind.ruleQuestion,
      question: ruleIssueQuestion(rule.kind, issue),
    );
  }
  return RuleCard(
    nextId(),
    draft: RuleDraft(
      kind: rule.kind,
      params: completion.params,
      merged: merged,
      weekdays: weekdays,
      courseName: course,
    ),
    replaced: [
      for (final old in rulesReplacedBy(
        rule.kind,
        completion.params,
        weekdays,
        snapshot.rules,
      ))
        if (old.active) old,
    ],
    say: ruleProposalQuestion(rule.kind, completion, weekdays: weekdays),
  );
}

/// 오전·오후를 말하지 않은 8–11시가 있는지(`parseQuestions`의 규칙).
bool _needsMeridiem(ParsedRule rule, DateTime now) => parseQuestions(
  ParseResult(intent: ParseIntent.setRule, rules: [rule]),
  now: now,
).any((question) => question.kind == ParseQuestionKind.meridiem);

AskCard _meridiemAsk(int id, ParsedRule rule, Set<AskTopic> answered) {
  final time =
      rule.startMin ?? rule.endMin ?? rule.quietStartMin ?? rule.quietEndMin!;
  final hour = time ~/ 60 % 12 == 0 ? 12 : time ~/ 60 % 12;
  AskOption at(int delta) {
    final shifted = delta == 0 ? rule : _afternoon(rule);
    return AskOption(label: _timesText(shifted), rules: [shifted]);
  }

  return AskCard(
    id,
    topic: AskTopic.meridiem,
    question: '$hour시가 오전인가요, 오후인가요?',
    sub: ruleKindName(rule.kind),
    options: [at(0), at(12 * 60)],
    intent: ParseIntent.setRule,
    answered: answered,
  );
}

AskCard _positionAsk(int id, ParsedRule rule, Set<AskTopic> answered) {
  ParsedRule at(TravelPosition position) => ParsedRule(
    kind: rule.kind,
    remove: rule.remove,
    minutes: rule.minutes,
    position: position,
    startMin: rule.startMin,
    endMin: rule.endMin,
    timeExpression: rule.timeExpression,
    weekdays: rule.weekdays,
    course: rule.course,
    taskKind: rule.taskKind,
    briefingMin: rule.briefingMin,
    notifyCap: rule.notifyCap,
    quietStartMin: rule.quietStartMin,
    quietEndMin: rule.quietEndMin,
  );
  final minutes = rule.minutes;
  return AskCard(
    id,
    topic: AskTopic.rulePosition,
    question: ruleIssueQuestion(
      RuleKind.travel,
      const RuleIssue('position', RuleIssueKind.missing),
    ),
    sub: minutes == null
        ? ruleKindName(rule.kind)
        : '${ruleKindName(rule.kind)} ${durationText(minutes)}',
    options: [
      AskOption(
        label: '매 수업 앞뒤',
        sub: '대면 수업마다 앞뒤로 비워요',
        rules: [at(TravelPosition.everyClass)],
      ),
      AskOption(
        label: '하루 첫 수업 전·마지막 수업 뒤',
        sub: '대면 수업이 있는 날 두 번만 비워요',
        rules: [at(TravelPosition.dayEdges)],
      ),
    ],
    intent: ParseIntent.setRule,
    answered: answered,
  );
}

/// 오후를 고른 규칙. 낮 12시 전의 시각은 12시간 뒤로 옮기고, 끝의 12시는 밤 12시(자정)로 본다('11시부터 12시'의
/// 오후는 23:00–24:00).
ParsedRule _afternoon(ParsedRule rule) {
  int? later(int? minute) =>
      minute != null && minute < 12 * 60 ? minute + 12 * 60 : minute;
  int? laterEnd(int? minute) => minute == 12 * 60 ? 0 : later(minute);
  return ParsedRule(
    kind: rule.kind,
    remove: rule.remove,
    minutes: rule.minutes,
    position: rule.position,
    startMin: later(rule.startMin),
    endMin: laterEnd(rule.endMin),
    timeExpression: rule.timeExpression,
    weekdays: rule.weekdays,
    course: rule.course,
    taskKind: rule.taskKind,
    briefingMin: rule.briefingMin,
    notifyCap: rule.notifyCap,
    quietStartMin: later(rule.quietStartMin),
    quietEndMin: laterEnd(rule.quietEndMin),
  );
}

/// 되묻기의 고를 것 '오전 9시부터 오전 11시까지', '오후 11시까지'.
String _timesText(ParsedRule rule) {
  final start = rule.startMin ?? rule.quietStartMin;
  final end = rule.endMin ?? rule.quietEndMin;
  if (start != null && end != null) {
    return '${clockText(start)}부터 ${clockText(end)}까지';
  }
  return start != null ? '${clockText(start)}부터' : '${clockText(end!)}까지';
}

AssistantMessage _removeCard(
  ParsedRule rule,
  int Function() nextId,
  AssistantSnapshot snapshot,
) {
  final active = [
    for (final candidate in snapshot.rules)
      if (candidate.kind == rule.kind &&
          candidate.active &&
          !candidate.isUnreadable)
        candidate,
  ];
  if (active.isEmpty) {
    return InfoCard(
      nextId(),
      InfoKind.noRuleToRemove,
      question: ruleKindName(rule.kind),
    );
  }
  final courseNames = {
    for (final course in snapshot.courses) course.id: course.name,
  };
  final courseId = switch (_textOrNull(rule.course)) {
    final name? =>
      snapshot.courses.where((course) => course.name == name).firstOrNull?.id,
    null => null,
  };
  final days = canonicalWeekdays(rule.weekdays);
  var candidates = active;
  // 말한 값마다 좁히되, 맞는 규칙이 없으면 그 값으로는 좁히지 않는다.
  void narrow(bool Function(Rule rule) keep) {
    final kept = candidates.where(keep).toList();
    if (kept.isNotEmpty) candidates = kept;
  }

  if (days != null) {
    narrow(
      (candidate) => _sameDays(canonicalWeekdays(candidate.weekdays), days),
    );
  }
  if (rule.startMin case final start?) {
    narrow((candidate) => candidate.params.startMin == start);
  }
  if (courseId != null) {
    narrow((candidate) => candidate.params.courseId == courseId);
  }
  if (rule.taskKind case final taskKind?) {
    narrow((candidate) => candidate.params.taskKind == taskKind);
  }
  candidates.sort((a, b) {
    final byTime = b.updatedAt.compareTo(a.updatedAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
  if (candidates.length == 1) {
    final only = candidates.single;
    return RuleRemoveCard(
      nextId(),
      rule: only,
      courseName: courseNames[only.params.courseId],
      say: '지우기 전에 확인해 주세요.',
    );
  }
  return RulePickCard(
    nextId(),
    kind: rule.kind,
    rules: candidates,
    courseNames: courseNames,
    say: '켜진 ${ruleKindName(rule.kind)} 규칙이 ${candidates.length}개 있어요.',
  );
}

bool _sameDays(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String? _textOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
