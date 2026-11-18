// /v1/parse 응답을 06 AI 비서의 카드로 바꾼다. docs/screens.md '06 AI 비서'(카드, 되묻기),
// docs/architecture.md 'POST /v1/parse'(날짜·요일 일치와 되묻기 판단은 앱이 함).
//
// 응답의 항목마다 [parseQuestions]로 되물을 것을 고르고, 있으면 고를 것을 붙인 되묻기 카드([AskCard])를 하나씩
// 보인다. 고르면([afterPick]) 고른 날짜·시각을 채운 항목으로 다시 확인하고, 더 물을 것이 없으면 저장하는 카드
// ([EventCard]·[TaskCard])를 만든다. 문장 속 표현('주말', '다음 주')은 그대로 남으므로 이미 답한 것은
// [AskCard.answered]로 다시 묻지 않는다. 날짜는 요청의 today와 같은 한국 달력 날짜로 견준다(하루 경계는
// 적용하지 않음).
//
// 수업 변경은 과목의 2주 안 수업에서 그날 수업을 찾고(날짜가 없거나 그날 수업이 없으면 수업을 고르게 함),
// 바꾸기·지우기는 대상을 찾아(여럿이면 고르게 함) 지금과 바꾼 뒤를 보인다(`assistant_targets.dart`). 질문은
// 기간과 과목만 정해 두고 답은 화면이 폰 안 데이터로 그때그때 계산한다.
//
// AI가 카드 대신 질문만 돌려주면(한 문장에 의도 둘, 대상 모름) 그 질문을 안내 카드로 보인다. 그 답을 앞 문장과
// 함께 이어 받는 것은 K2(아니요 뒤 고쳐 말하기)와 같은 장치로 만든다(관리자 2026-11-19). 내 규칙 카드는 다음
// PR에서 붙이고, 그때까지는 안내 카드다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/parse_checks.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 규칙 모드(12 '말로 정하기')에서도 받는 의도. 프로토타입처럼 질문과 수업 변경은 그대로 답한다.
const _ruleModeIntents = {
  ParseIntent.setRule,
  ParseIntent.query,
  ParseIntent.classException,
};

/// 카드를 만들 때 함께 넘기는 것.
final class _Ctx {
  const _Ctx(this.now, this.nextId, this.snapshot);

  /// 지금(한국 시각).
  final DateTime now;
  final int Function() nextId;
  final AssistantSnapshot snapshot;

  DateTime get today => DateTime(now.year, now.month, now.day);
}

/// 응답 [result]로 보일 카드. [now]는 지금(한국 시각)이고 [nextId]가 카드마다 번호를 준다. [ruleMode]면
/// 12 내 규칙의 '말로 정하기'로 연 규칙 모드다. [snapshot]은 수업 변경·바꾸기·지우기가 찾을 폰 DB의 값이다.
List<AssistantMessage> replyCards(
  ParseResult result, {
  required DateTime now,
  required bool ruleMode,
  required int Function() nextId,
  AssistantSnapshot snapshot = const AssistantSnapshot(),
}) {
  final ctx = _Ctx(now, nextId, snapshot);
  if (result.needsClarification) {
    final question = result.clarification?.question.trim() ?? '';
    return [
      question.isEmpty
          ? InfoCard(nextId(), InfoKind.notUnderstood)
          : InfoCard(nextId(), InfoKind.serverQuestion, question: question),
    ];
  }
  final intent = result.intent;
  if (ruleMode && !_ruleModeIntents.contains(intent)) {
    return [InfoCard(nextId(), InfoKind.ruleOnly)];
  }
  switch (intent) {
    case ParseIntent.createEvent ||
        ParseIntent.createTask ||
        ParseIntent.classException ||
        ParseIntent.update ||
        ParseIntent.delete:
      if (result.items.isEmpty) {
        return [InfoCard(nextId(), InfoKind.notUnderstood)];
      }
      final cards = [
        for (final item in result.items)
          ..._resolve(intent, item, const {}, ctx),
      ];
      return _grouped(cards, (count) => '일정 $count개를 찾았어요. 하나씩 확인해 주세요.');
    case ParseIntent.query:
      return [_answerCard(result, ctx)];
    case ParseIntent.other:
      return [InfoCard(nextId(), InfoKind.notUnderstood)];
    case ParseIntent.setRule:
      return [InfoCard(nextId(), InfoKind.notYet)];
  }
}

/// 되묻기 [card]의 [index]번째를 고른 뒤 이어서 보일 카드. 고른 항목마다 남은 것을 다시 확인한다.
List<AssistantMessage> afterPick(
  AskCard card,
  int index, {
  required DateTime now,
  required int Function() nextId,
  AssistantSnapshot snapshot = const AssistantSnapshot(),
}) {
  final ctx = _Ctx(now, nextId, snapshot);
  final option = card.options[index];
  final answered = {...card.answered, ..._answeredBy(card.topic)};
  final cards = [
    for (final item in option.items)
      ..._resolve(card.intent, item, answered, ctx),
  ];
  return _grouped(cards, (count) => '이틀 모두 넣을게요. 하나씩 확인해 주세요.');
}

/// 바꾸거나 지울 일정 [card]의 [index]번째를 고른 뒤의 카드.
AssistantMessage afterTargetPick(
  TargetPickCard card,
  int index, {
  required int Function() nextId,
}) => _changeCard(
  nextId(),
  card.candidates[index],
  card.item,
  delete: card.delete,
  say: null,
);

/// 일정 카드가 둘 이상이면 첫 카드 위 한 줄을 [say]로 바꾼다(카드마다 따로 넣음).
List<AssistantMessage> _grouped(
  List<AssistantMessage> cards,
  String Function(int count) say,
) {
  final events = cards.whereType<EventCard>().toList();
  if (events.length < 2) return cards;
  final first = events.first;
  return [
    for (final card in cards)
      if (card == first)
        EventCard(first.id, draft: first.draft, say: say(events.length))
      else
        card,
  ];
}

/// [topic]에 답하면 함께 답한 것으로 보는 것. 날짜를 고르면 문장 속 날짜 표현으로 다시 묻지 않는다.
Set<AskTopic> _answeredBy(AskTopic topic) => switch (topic) {
  AskTopic.date || AskTopic.taskDue => {
    topic,
    AskTopic.dayOnly,
    AskTopic.weekend,
    AskTopic.nextWeek,
    AskTopic.weekdayMismatch,
  },
  AskTopic.dayOnly => {AskTopic.dayOnly, AskTopic.weekdayMismatch},
  AskTopic.weekend => {
    AskTopic.weekend,
    AskTopic.nextWeek,
    AskTopic.weekdayMismatch,
  },
  AskTopic.nextWeek => {
    AskTopic.nextWeek,
    AskTopic.weekend,
    AskTopic.weekdayMismatch,
  },
  AskTopic.weekdayMismatch => {AskTopic.weekdayMismatch},
  AskTopic.meridiem => {AskTopic.meridiem},
  AskTopic.pastDate => {
    AskTopic.pastDate,
    AskTopic.dayOnly,
    AskTopic.weekend,
    AskTopic.nextWeek,
    AskTopic.weekdayMismatch,
  },
  AskTopic.pastTime => {AskTopic.pastTime, AskTopic.pastDate},
  AskTopic.session => {
    AskTopic.session,
    AskTopic.date,
    AskTopic.dayOnly,
    AskTopic.weekdayMismatch,
    AskTopic.pastDate,
  },
};

/// 묻는 차례. 날짜를 먼저 정해야 오전·오후와 지난 시각을 물을 수 있다.
const _askOrder = [
  AskTopic.taskDue,
  AskTopic.date,
  AskTopic.dayOnly,
  AskTopic.weekend,
  AskTopic.nextWeek,
  AskTopic.weekdayMismatch,
  AskTopic.meridiem,
  AskTopic.pastDate,
  AskTopic.pastTime,
];

AskTopic? _topicOf(ParseQuestionKind kind) => switch (kind) {
  ParseQuestionKind.missingDate => AskTopic.date,
  ParseQuestionKind.dayOnly => AskTopic.dayOnly,
  ParseQuestionKind.weekend => AskTopic.weekend,
  ParseQuestionKind.nextWeek => AskTopic.nextWeek,
  ParseQuestionKind.weekdayMismatch => AskTopic.weekdayMismatch,
  ParseQuestionKind.meridiem => AskTopic.meridiem,
  ParseQuestionKind.pastDate => AskTopic.pastDate,
  ParseQuestionKind.pastTime => AskTopic.pastTime,
  ParseQuestionKind.server || ParseQuestionKind.unsupportedRepeat => null,
};

/// 항목 하나를 확인해 되묻기 카드나 저장하는 카드를 만든다.
List<AssistantMessage> _resolve(
  ParseIntent intent,
  ParseItem item,
  Set<AskTopic> answered,
  _Ctx ctx,
) {
  final change = intent == ParseIntent.update || intent == ParseIntent.delete;
  if (change && item.kind == ParseItemKind.task) {
    return [InfoCard(ctx.nextId(), InfoKind.taskChange)];
  }
  final isTask =
      !change &&
      intent != ParseIntent.classException &&
      (item.kind == ParseItemKind.task ||
          (item.kind == null && intent == ParseIntent.createTask));
  final itemIntent = switch (intent) {
    ParseIntent.classException ||
    ParseIntent.update ||
    ParseIntent.delete => intent,
    _ => isTask ? ParseIntent.createTask : ParseIntent.createEvent,
  };
  final exception = intent == ParseIntent.classException;
  final makeup = exception && item.exceptionType == ClassExceptionKind.makeup;
  if (exception && item.exceptionType == null) {
    return [InfoCard(ctx.nextId(), InfoKind.notUnderstood)];
  }
  if (makeup && (item.date == null || item.startMin == null)) {
    return [InfoCard(ctx.nextId(), InfoKind.makeupNeedsWhen)];
  }
  final kinds = parseQuestions(
    ParseResult(intent: itemIntent, items: [item]),
    now: ctx.now,
  ).map((question) => question.kind).toSet();
  if (kinds.contains(ParseQuestionKind.unsupportedRepeat) && !change) {
    return [InfoCard(ctx.nextId(), InfoKind.unsupportedRepeat)];
  }
  final topics = {
    for (final kind in kinds) ?_topicOf(kind),
    if (isTask && item.due == null) AskTopic.taskDue,
  }..removeAll(answered);
  // 수업 변경의 날짜는 2주 안의 수업에서 고르고(아래), 시각은 보강에만 있다.
  if (exception) {
    topics.remove(AskTopic.date);
    if (!makeup) topics.removeAll({AskTopic.meridiem, AskTopic.pastTime});
  }
  for (final topic in _askOrder) {
    if (!topics.contains(topic)) continue;
    // 오전·오후는 시작(할 일은 마감) 시각으로 묻는다. 끝만 있는 일정은 묻지 않는다.
    if (topic == AskTopic.meridiem &&
        (isTask ? item.dueTimeMin : item.startMin) == null) {
      continue;
    }
    if (topic == AskTopic.meridiem && _surelyAfternoon(item, isTask, ctx.now)) {
      return _resolve(itemIntent, _shifted(item, isTask, 12 * 60), {
        ...answered,
        AskTopic.meridiem,
      }, ctx);
    }
    return [
      _ask(
        ctx.nextId(),
        topic,
        item,
        isTask: isTask,
        intent: itemIntent,
        answered: answered,
        now: ctx.now,
      ),
    ];
  }
  if (exception) return [_exceptionCard(item, answered, ctx)];
  if (change) {
    return [_changeOrPick(item, delete: intent == ParseIntent.delete, ctx)];
  }
  return [
    isTask
        ? _taskCard(ctx.nextId(), item, now: ctx.now)
        : _eventCard(ctx.nextId(), item, now: ctx.now),
  ];
}

/// 수업 변경 카드. 보강은 그 과목의 수업 칸 하나에 그 날짜·시각으로 넣고, 그 밖에는 2주 안의 그날 수업을
/// 바꾼다. 날짜가 없거나 그날 그 과목 수업이 없으면 수업을 고르게 한다(이번 주에 하나뿐이면 그 수업).
AssistantMessage _exceptionCard(
  ParseItem item,
  Set<AskTopic> answered,
  _Ctx ctx,
) {
  final kind = item.exceptionType!;
  final course = _textOrNull(item.course);
  if (course == null) return InfoCard(ctx.nextId(), InfoKind.noClass);
  if (kind == ClassExceptionKind.makeup) {
    final slot = anySlotOf(course, ctx.snapshot);
    if (slot == null) return InfoCard(ctx.nextId(), InfoKind.noClass);
    final start = item.startMin!;
    final length = slot.endMin - slot.startMin;
    final draft = ExceptionDraft(
      kind: kind,
      slotId: slot.id,
      courseName: course,
      date: item.date!,
      startMin: start,
      endMin: _endFor(start, item.endMin, length),
      originalPlace: slot.place,
      place: _textOrNull(item.place),
    );
    return ExceptionCard(
      ctx.nextId(),
      draft: draft,
      say: '${withJosa(course, Josa.eunNeun)} 그날만 보강을 넣을게요.',
    );
  }
  final sessions = sessionsOf(course, ctx.snapshot, today: ctx.today);
  if (sessions.isEmpty) return InfoCard(ctx.nextId(), InfoKind.noClass);
  final place = _textOrNull(item.place);
  if (kind == ClassExceptionKind.placeChange && place == null) {
    return InfoCard(ctx.nextId(), InfoKind.placeNeeded);
  }
  final date = item.date;
  ClassSession? hit;
  if (date != null) {
    hit = sessions
        .where(
          (session) =>
              _sameDate(session.date, date) &&
              (item.startMin == null || session.startMin == item.startMin),
        )
        .firstOrNull;
  } else if (!answered.contains(AskTopic.session)) {
    final week = sessions
        .where((session) => session.date.isBefore(_addDays(ctx.today, 7)))
        .toList();
    if (week.length == 1) hit = week.single;
  }
  if (hit == null) {
    return AskCard(
      ctx.nextId(),
      topic: AskTopic.session,
      question: date == null
          ? '어느 날 $course 수업인가요?'
          : '${_monthDay(date)} ${weekdayText(date.weekday)}요일에는 '
                '$course 수업이 없어요',
      sub: date == null ? '이번 주와 다음 주 수업이에요' : '어느 수업인가요?',
      options: [
        for (final session in sessions.take(4))
          AskOption(
            label:
                '${monthDayText(session.date, today: ctx.today)} '
                '${timeRangeText(session.startMin, session.endMin)}',
            sub: session.place,
            items: [
              _copy(item, date: session.date, startMin: session.startMin),
            ],
          ),
      ],
      intent: ParseIntent.classException,
      answered: answered,
    );
  }
  final draft = ExceptionDraft(
    kind: kind,
    slotId: hit.slot.id,
    courseName: course,
    date: hit.date,
    startMin: hit.startMin,
    endMin: hit.endMin,
    originalPlace: hit.place,
    place: kind == ClassExceptionKind.cancelled ? null : place,
  );
  return ExceptionCard(
    ctx.nextId(),
    draft: draft,
    say:
        '${_weekPrefix(hit.date, ctx.today)}${weekdayText(hit.date.weekday)}요일 '
        '$course 수업만 ${withJosa(exceptionKindName(kind), Josa.euroRo)} 바꿀게요.',
  );
}

/// 수업 변경의 이름('휴강', '보강', '시험', '강의실 변경').
String exceptionKindName(ClassExceptionKind kind) => switch (kind) {
  ClassExceptionKind.cancelled => '휴강',
  ClassExceptionKind.makeup => '보강',
  ClassExceptionKind.exam => '시험',
  ClassExceptionKind.placeChange => '강의실 변경',
};

/// '이번 주 '·'다음 주 ', 그 뒤는 '{M월 D일} '.
String _weekPrefix(DateTime date, DateTime today) {
  final weeks = _mondayOf(date).difference(_mondayOf(today)).inDays ~/ 7;
  return switch (weeks) {
    0 => '이번 주 ',
    1 => '다음 주 ',
    _ => '${_monthDay(date)} ',
  };
}

/// 바꾸기·지우기: 대상을 찾아 하나면 그 카드, 여럿이면 고르는 카드다.
AssistantMessage _changeOrPick(
  ParseItem item,
  _Ctx ctx, {
  required bool delete,
}) {
  final candidates = findTargets(item.target, item.targetDate, ctx.snapshot);
  if (candidates.isEmpty) {
    return InfoCard(
      ctx.nextId(),
      InfoKind.targetNotFound,
      question: _textOrNull(item.target),
    );
  }
  if (!delete &&
      candidates.every((target) => changedAfter(target, item) == null)) {
    return InfoCard(
      ctx.nextId(),
      InfoKind.changeNeedsHow,
      question: _textOrNull(item.target),
    );
  }
  if (candidates.length > 1) {
    final target = _textOrNull(item.target) ?? '';
    return TargetPickCard(
      ctx.nextId(),
      delete: delete,
      item: item,
      candidates: candidates,
      say: '「$target」 일정이 ${candidates.length}개 있어요.',
    );
  }
  return _changeCard(
    ctx.nextId(),
    candidates.single,
    item,
    delete: delete,
    say: delete ? '지우기 전에 확인해 주세요.' : '바꾸기 전에 확인해 주세요.',
  );
}

AssistantMessage _changeCard(
  int id,
  ChangeTarget target,
  ParseItem item, {
  required bool delete,
  required String? say,
}) {
  if (delete) return ChangeCard(id, delete: true, target: target, say: say);
  final after = changedAfter(target, item);
  if (after == null) {
    return InfoCard(
      id,
      InfoKind.changeNeedsHow,
      question: _textOrNull(item.target),
    );
  }
  return ChangeCard(id, delete: false, target: target, after: after, say: say);
}

/// 질문 답 카드. 기간을 말하지 않았으면 마감은 오늘부터 이번 주 일요일까지, 하루 계획·빈 시간은 오늘이다.
AssistantMessage _answerCard(ParseResult result, _Ctx ctx) {
  final type = result.queryType;
  if (type == null) return InfoCard(ctx.nextId(), InfoKind.notUnderstood);
  final from = result.queryFrom ?? ctx.today;
  var to =
      result.queryTo ??
      (type == ParseQueryType.deadlinesThisWeek
          ? _addDays(_mondayOf(ctx.today), 6)
          : from);
  if (to.isBefore(from)) to = from;
  return AnswerCard(
    ctx.nextId(),
    type: type,
    from: from,
    to: type == ParseQueryType.deadlinesThisWeek ? to : from,
    courseName: _textOrNull(result.queryCourse),
    say: switch (type) {
      ParseQueryType.deadlinesThisWeek => '폰에 저장된 마감으로 정리했어요.',
      ParseQueryType.todayPlan => '홈에 보이는 계획을 그대로 정리했어요.',
      ParseQueryType.freeTime => '시간표와 일정을 빼고 남은 시간을 찾았어요.',
    },
  );
}

/// 새 시작 [start]의 끝. 끝을 말했으면 그 끝(이르면 자정을 넘음), 아니면 [length]만큼 뒤다.
int _endFor(int start, int? end, int length) {
  if (end == null) return start + length;
  final value = end > start ? end : end + 1440;
  return value - start >= 1440 ? start + length : value;
}

/// 오늘 일정인데 오전으로 보면 이미 끝났으면(할 일은 마감이 지났으면) 오후가 틀림없다(프로토타입처럼 묻지
/// 않고 오후로 본다).
bool _surelyAfternoon(ParseItem item, bool isTask, DateTime now) {
  final day = isTask ? item.due : item.date;
  if (day == null || !_sameDate(day, now)) return false;
  final nowMin = now.hour * 60 + now.minute;
  if (isTask) {
    final due = item.dueTimeMin;
    return due != null && due % 720 <= nowMin;
  }
  final start = item.startMin;
  if (start == null) return false;
  final morningStart = start % 720;
  final morningEnd = morningStart + _lengthOf(item);
  return morningEnd <= nowMin;
}

/// 오전 기준 시각을 [delta]만큼 옮긴 항목(오전이면 0, 오후면 720). 시작과 끝을 함께 옮긴다.
ParseItem _shifted(ParseItem item, bool isTask, int delta) {
  if (isTask) {
    final due = item.dueTimeMin;
    return _copy(item, dueTimeMin: due == null ? null : due % 720 + delta);
  }
  final start = item.startMin;
  if (start == null) return item;
  final newStart = start % 720 + delta;
  return _copy(item, startMin: newStart, endMin: newStart + _lengthOf(item));
}

/// 일정의 길이(분). 끝이 없으면 60분(임시, docs/architecture.md 'POST /v1/parse'), 끝이 시작보다 이르면 자정을
/// 넘는 것으로 본다.
int _lengthOf(ParseItem item) {
  final start = item.startMin;
  final end = item.endMin;
  if (start == null || end == null) return _defaultLengthMin;
  final length = end > start ? end - start : end + 1440 - start;
  return length >= 1440 ? _defaultLengthMin : length;
}

/// 끝을 말하지 않은 일정의 길이(임시).
const _defaultLengthMin = 60;

AskCard _ask(
  int id,
  AskTopic topic,
  ParseItem item, {
  required bool isTask,
  required ParseIntent intent,
  required Set<AskTopic> answered,
  required DateTime now,
}) {
  final today = _dateOf(now);
  final title = _titleOf(item, isTask);
  final day = isTask ? item.due : item.date;
  AskOption onDay(DateTime date, {String? sub}) => AskOption(
    label: monthDayText(date, today: today),
    sub: sub ?? relativeDayText(date, today: today),
    items: [isTask ? _copy(item, due: date) : _copy(item, date: date)],
  );
  final next5 = [for (var i = 0; i < 5; i++) _addDays(today, i)];
  switch (topic) {
    case AskTopic.date:
      return AskCard(
        id,
        topic: topic,
        question: '「$title」 언제인가요?',
        sub: '날짜를 말하지 않았어요',
        options: [for (final date in next5) onDay(date)],
        intent: intent,
        answered: answered,
      );
    case AskTopic.taskDue:
      return AskCard(
        id,
        topic: topic,
        question: '「$title」 마감이 언제인가요?',
        sub: '마감을 말하지 않았어요',
        options: [
          for (final date in next5) onDay(date),
          AskOption(label: '마감 없음', sub: '자동으로 놓지 않아요', items: [item]),
        ],
        intent: intent,
        answered: answered,
      );
    case AskTopic.dayOnly:
      final dayOfMonth = day!.day;
      final candidates = <DateTime>[];
      for (var month = 0; candidates.length < 2 && month < 4; month++) {
        final date = DateTime(today.year, today.month + month, dayOfMonth);
        if (date.day == dayOfMonth && !date.isBefore(today)) {
          candidates.add(date);
        }
      }
      return AskCard(
        id,
        topic: topic,
        question: '$dayOfMonth일이 언제인가요?',
        sub: '몇 월인지 말하지 않았어요',
        options: [for (final date in candidates) onDay(date)],
        intent: intent,
        answered: answered,
      );
    case AskTopic.weekend:
      final saturday = _addDays(_mondayOf(day!), 5);
      final sunday = _addDays(saturday, 1);
      final weeks =
          _mondayOf(saturday).difference(_mondayOf(today)).inDays ~/ 7;
      return AskCard(
        id,
        topic: topic,
        question: switch (weeks) {
          0 => '이번 주말 언제인가요?',
          1 => '다음 주말 언제인가요?',
          _ => '${_monthDay(saturday)} 주말 언제인가요?',
        },
        sub: '하루만 고르거나 이틀 모두 넣을 수 있어요',
        options: [
          onDay(saturday, sub: '토요일'),
          onDay(sunday, sub: '일요일'),
          AskOption(
            label: '토·일 이틀 모두',
            sub: '${_monthDay(saturday)}–${sunday.day}일',
            items: [
              _copy(item, date: saturday),
              _copy(item, date: sunday),
            ],
          ),
        ],
        intent: intent,
        answered: answered,
      );
    case AskTopic.nextWeek:
      final monday = _mondayOf(day!);
      return AskCard(
        id,
        topic: topic,
        question: '다음 주 무슨 요일인가요?',
        options: [
          for (var i = 0; i < 7; i++)
            if (!_addDays(monday, i).isBefore(today))
              onDay(_addDays(monday, i)),
        ],
        intent: intent,
        answered: answered,
      );
    case AskTopic.weekdayMismatch:
      final said = item.weekday!;
      final byWeekday = _addDays(day!, said - day.weekday);
      return AskCard(
        id,
        topic: topic,
        question:
            '${_monthDay(day)}은 ${weekdayText(day.weekday)}요일이에요. 어느 날인가요?',
        sub: '날짜와 요일이 서로 달라요',
        options: [
          onDay(day, sub: '날짜 기준'),
          onDay(byWeekday, sub: '${weekdayText(said)}요일 기준'),
        ],
        intent: intent,
        answered: answered,
      );
    case AskTopic.meridiem:
      final time = (isTask ? item.dueTimeMin : item.startMin)!;
      final hour = time ~/ 60 % 12 == 0 ? 12 : time ~/ 60 % 12;
      AskOption at(int delta) {
        final shifted = _shifted(item, isTask, delta);
        final start = (isTask ? shifted.dueTimeMin : shifted.startMin)!;
        return AskOption(
          label: clockText(start),
          sub: isTask
              ? '마감 ${hhmmText(start)}'
              : timeRangeText(start, start + _lengthOf(item)),
          items: [shifted],
        );
      }
      return AskCard(
        id,
        topic: topic,
        question: '$hour시가 오전인가요, 오후인가요?',
        sub: '「$title」 · ${_whenOfItem(item, isTask, today)}',
        options: [at(0), at(12 * 60)],
        intent: intent,
        answered: answered,
      );
    case AskTopic.pastDate:
      var sameWeekday = day!;
      while (sameWeekday.isBefore(today)) {
        sameWeekday = _addDays(sameWeekday, 7);
      }
      final tomorrow = _addDays(today, 1);
      return AskCard(
        id,
        topic: topic,
        question: '${_monthDay(day)}은 이미 지났어요. 언제인가요?',
        options: [
          if (sameWeekday != today && sameWeekday != tomorrow)
            onDay(sameWeekday, sub: '같은 요일'),
          onDay(today),
          onDay(tomorrow),
        ],
        intent: intent,
        answered: answered,
      );
    case AskTopic.session:
      // 수업 고르기는 수업 변경 카드를 만들 때 2주 안의 수업으로 만든다(_exceptionCard).
      throw StateError('session asks come from the class exception flow');
    case AskTopic.pastTime:
      final time = (isTask ? item.dueTimeMin : item.startMin)!;
      final nowMin = now.hour * 60 + now.minute;
      final later = _addDays(day!, isTask ? 1 : 7);
      return AskCard(
        id,
        topic: topic,
        question:
            '오늘 ${withJosa(clockText(time), Josa.eunNeun)} 이미 지났어요. 언제인가요?',
        sub: '지금은 ${withJosa(clockText(nowMin), Josa.ieyoYeyo)}',
        options: [
          onDay(later, sub: isTask ? '내일 같은 시각' : '다음 주 같은 요일'),
          AskOption(
            label: '오늘 그대로',
            sub: isTask ? '이미 지난 마감으로 넣어요' : '지난 일정으로 넣어요',
            items: [item],
          ),
        ],
        intent: intent,
        answered: answered,
      );
  }
}

/// 일정 카드. 반복 일정인데 요일이나 시각이 없으면 저장할 수 없어 안내 카드다.
AssistantMessage _eventCard(int id, ParseItem item, {required DateTime now}) {
  final title = _titleOf(item, false);
  final today = _dateOf(now);
  final repeat = item.repeat;
  final start = item.startMin;
  final end = start == null ? null : start + _lengthOf(item);
  if (repeat != null) {
    final weekdays = {...repeat.weekdays}.toList()..sort();
    if (weekdays.isEmpty || start == null) {
      return InfoCard(id, InfoKind.repeatIncomplete);
    }
    final draft = EventDraft(
      title: title,
      weekdays: weekdays,
      startMin: start,
      endMin: end,
      place: _textOrNull(item.place),
      prep: _textOrNull(item.prep),
      fixedKind: item.fixedBlockKind,
      reminderMinutes: item.reminderMinutes,
    );
    return EventCard(
      id,
      draft: draft,
      say:
          '${repeatText(weekdays)} ${withJosa(title, Josa.euroRo)} 정리했어요. '
          '맞으면 캘린더에 넣을게요.',
    );
  }
  final date = item.date!;
  final draft = EventDraft(
    title: title,
    date: date,
    startMin: start,
    endMin: end,
    place: _textOrNull(item.place),
    prep: _textOrNull(item.prep),
    reminderMinutes: item.reminderMinutes,
  );
  return EventCard(
    id,
    draft: draft,
    say: start == null
        ? '시간을 말하지 않아서 시간 미정으로 정리했어요. 시간을 고르거나 그대로 넣을 수 있어요.'
        : '${monthDayText(date, today: today)} ${hhmmText(start)} '
              '${withJosa(title, Josa.euroRo)} 정리했어요.',
  );
}

TaskCard _taskCard(int id, ParseItem item, {required DateTime now}) {
  final title = _titleOf(item, true);
  final course = _textOrNull(item.course);
  final courseName = item.category == ParseCategory.course ? course : null;
  final said = item.estimatedMinutes;
  final draft = TaskDraft(
    title: title,
    courseName: courseName,
    kind: courseName == null ? TaskKind.personal : courseTaskKindOf(title),
    dueDate: item.due,
    dueTimeMin: item.dueTimeMin,
    saidEstimateMin: said != null && said > 0 ? said : null,
  );
  final due = draft.dueDate;
  return TaskCard(
    id,
    draft: draft,
    say: due == null
        ? '마감 없는 할 일로 정리했어요.'
        : '${monthDayText(due, today: _dateOf(now))} '
              '${hhmmText(draft.dueTimeMin ?? 23 * 60 + 59)} 마감인 할 일로 정리했어요.',
  );
}

/// 과목 할 일 제목에서 고른 종류 칩의 처음 값. 제목에 퀴즈·팀플·시험·토론이 보이면 그것, 아니면 과제다
/// (docs/screens.md '06 AI 비서'의 카드 2: 처음 값 과제). /v1/parse에는 할 일 종류가 없다
/// (docs/decisions.md 2026-11-14 '과목을 정해 만든 할 일은 과목을 저장하고 종류는 카드에서 고른다').
TaskKind courseTaskKindOf(String title) {
  if (title.contains('퀴즈')) return TaskKind.quiz;
  if (RegExp(r'팀플|팀\s*과제|팀\s*프로젝트|조별').hasMatch(title)) {
    return TaskKind.team;
  }
  if (RegExp(r'시험|중간고사|기말고사|쪽지').hasMatch(title)) return TaskKind.exam;
  if (title.contains('토론')) return TaskKind.discussion;
  return TaskKind.assignment;
}

/// 과목 할 일의 종류 칩(처음 값 과제, '개인'은 없음). 영상·자료는 LMS에서만 온다.
const courseTaskKinds = [
  TaskKind.assignment,
  TaskKind.quiz,
  TaskKind.team,
  TaskKind.discussion,
  TaskKind.exam,
];

String _whenOfItem(ParseItem item, bool isTask, DateTime today) {
  final repeat = item.repeat;
  if (!isTask && repeat != null) {
    return repeatText({...repeat.weekdays}.toList()..sort());
  }
  final day = isTask ? item.due : item.date;
  return day == null ? '날짜 미정' : monthDayText(day, today: today);
}

String _titleOf(ParseItem item, bool isTask) =>
    _textOrNull(item.title) ?? (isTask ? '할 일' : '일정');

String? _textOrNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

/// '10월 13일'.
String _monthDay(DateTime date) => '${date.month}월 ${date.day}일';

DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime _mondayOf(DateTime date) => _addDays(date, 1 - date.weekday);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [item]의 날짜·시각만 바꾼 것. 날짜를 바꾸면 문장 속 요일은 지운다(고른 날짜가 정답이므로).
ParseItem _copy(
  ParseItem item, {
  DateTime? date,
  DateTime? due,
  int? startMin,
  int? endMin,
  int? dueTimeMin,
}) {
  final newDay = date != null || due != null;
  return ParseItem(
    title: item.title,
    kind: item.kind,
    category: item.category,
    course: item.course,
    date: date ?? item.date,
    weekday: newDay ? null : item.weekday,
    dateExpression: item.dateExpression,
    timeExpression: item.timeExpression,
    startMin: startMin ?? item.startMin,
    endMin: endMin ?? item.endMin,
    repeat: item.repeat,
    fixedBlockKind: item.fixedBlockKind,
    due: due ?? item.due,
    dueTimeMin: dueTimeMin ?? item.dueTimeMin,
    estimatedMinutes: item.estimatedMinutes,
    reminderMinutes: item.reminderMinutes,
    place: item.place,
    prep: item.prep,
    shiftMinutes: item.shiftMinutes,
    target: item.target,
    targetDate: item.targetDate,
    exceptionType: item.exceptionType,
  );
}
