// /v1/parse 응답의 날짜·시각 확인과 되묻기 판단. docs/architecture.md 'POST /v1/parse'(날짜·요일 일치, 되묻기
// 판단은 앱의 domain/이 함)와 docs/screens.md '06 AI 비서'의 되묻기.
//
// AI는 날짜·시각을 계산해 오지만 맞는지는 여기 코드가 본다. [parseQuestions]는 되물을 까닭만 고르고, 질문
// 문구는 06 화면이 정한다. [withAfternoonDefault]는 오전·오후를 말하지 않은 1–7시를 오후로 고친다.

import 'package:cnu_ai_assistant/domain/models/parse_result.dart';

/// 되물을 까닭.
enum ParseQuestionKind {
  /// 서버(AI)가 되물었다. 질문은 [ParseResult.clarification]에 있다.
  server,

  /// 8–11시인데 오전·오후를 말하지 않았다.
  meridiem,

  /// 한 번뿐인 일정이나 수업 변경에 날짜가 없다.
  missingDate,

  /// 'N일'처럼 날만 말해 달을 알 수 없다.
  dayOnly,

  /// '주말'처럼 하루를 가리키지 않았다(한 번뿐인 일정).
  weekend,

  /// '다음 주'만 말하고 요일을 말하지 않았다(한 번뿐인 일정).
  nextWeek,

  /// 날짜(할 일은 마감)와 문장 속 요일이 어긋난다.
  weekdayMismatch,

  /// 지난 날짜다.
  pastDate,

  /// 오늘인데 지난 시각이다.
  pastTime,

  /// 매주가 아닌 반복(격주·매달 등)이라 고정 일정으로 저장할 수 없다.
  unsupportedRepeat,
}

/// 되물을 것 하나. 항목이나 규칙에 걸린 것이면 그 순번을 담는다.
final class ParseQuestion {
  const ParseQuestion(this.kind, {this.itemIndex, this.ruleIndex});

  final ParseQuestionKind kind;
  final int? itemIndex;
  final int? ruleIndex;

  @override
  bool operator ==(Object other) =>
      other is ParseQuestion &&
      other.kind == kind &&
      other.itemIndex == itemIndex &&
      other.ruleIndex == ruleIndex;

  @override
  int get hashCode => Object.hash(kind, itemIndex, ruleIndex);

  @override
  String toString() =>
      'ParseQuestion($kind, item: $itemIndex, rule: $ruleIndex)';
}

/// [result]에서 되물을 것을 고른다. [now]는 지금(한국 시각)이고 날짜는 달력 날짜로 견준다(요청의 today와
/// 같음). 서버가 되물었으면 그것 하나만 돌려준다. 되물을 것이 없으면 빈 목록이다.
List<ParseQuestion> parseQuestions(
  ParseResult result, {
  required DateTime now,
}) {
  if (result.needsClarification) {
    return const [ParseQuestion(ParseQuestionKind.server)];
  }
  final today = DateTime(now.year, now.month, now.day);
  final nowMin = now.hour * 60 + now.minute;
  final questions = <ParseQuestion>[];
  for (final (index, item) in result.items.indexed) {
    for (final kind in _itemQuestions(result.intent, item, today, nowMin)) {
      questions.add(ParseQuestion(kind, itemIndex: index));
    }
  }
  if (result.intent == ParseIntent.setRule) {
    for (final (index, rule) in result.rules.indexed) {
      if (_needsMeridiem(rule.timeExpression, [
        rule.startMin ?? rule.endMin,
        rule.quietStartMin ?? rule.quietEndMin,
      ])) {
        questions.add(
          ParseQuestion(ParseQuestionKind.meridiem, ruleIndex: index),
        );
      }
    }
  }
  return questions;
}

List<ParseQuestionKind> _itemQuestions(
  ParseIntent intent,
  ParseItem item,
  DateTime today,
  int nowMin,
) {
  final isTask = item.kind == ParseItemKind.task;
  final isOneOffEvent =
      intent == ParseIntent.createEvent && item.repeat == null;
  final day = isTask ? item.due : item.date;
  final time = isTask ? item.dueTimeMin : item.startMin;
  final expression = item.dateExpression;
  final kinds = <ParseQuestionKind>[];
  switch (intent) {
    case ParseIntent.delete ||
        ParseIntent.query ||
        ParseIntent.setRule ||
        ParseIntent.other:
      return kinds;
    case ParseIntent.createEvent ||
        ParseIntent.createTask ||
        ParseIntent.update ||
        ParseIntent.classException:
      break;
  }
  if (_needsMeridiem(item.timeExpression, [
    item.startMin ?? item.endMin,
    item.dueTimeMin,
  ])) {
    kinds.add(ParseQuestionKind.meridiem);
  }
  final needsDate = isOneOffEvent || intent == ParseIntent.classException;
  if (needsDate && item.date == null) {
    kinds.add(ParseQuestionKind.missingDate);
  }
  if (expression != null && day != null) {
    if (_saysDayOnly(expression)) kinds.add(ParseQuestionKind.dayOnly);
    if (!isTask && item.repeat == null) {
      if (expression.contains('주말')) kinds.add(ParseQuestionKind.weekend);
      if (_saysNextWeekOnly(expression)) {
        kinds.add(ParseQuestionKind.nextWeek);
      }
    }
  }
  if (day != null && item.weekday != null && day.weekday != item.weekday) {
    kinds.add(ParseQuestionKind.weekdayMismatch);
  }
  if (day != null && day.isBefore(today)) {
    kinds.add(ParseQuestionKind.pastDate);
  } else if (day != null && day == today && time != null && time < nowMin) {
    kinds.add(ParseQuestionKind.pastTime);
  }
  if (item.repeat != null && item.repeat!.freq != ParseRepeatFreq.weekly) {
    kinds.add(ParseQuestionKind.unsupportedRepeat);
  }
  return kinds;
}

/// [result]에서 오전·오후를 말하지 않은 1–7시(01:00–07:59)를 오후로 고친다(docs/screens.md '06 AI 비서'의
/// 되묻기: 1–7시는 오후). 끝 시각도 같다. 그 밖의 값은 그대로 둔다.
ParseResult withAfternoonDefault(ParseResult result) => ParseResult(
  intent: result.intent,
  needsClarification: result.needsClarification,
  clarification: result.clarification,
  queryType: result.queryType,
  queryFrom: result.queryFrom,
  queryTo: result.queryTo,
  queryCourse: result.queryCourse,
  unsupportedRule: result.unsupportedRule,
  items: [for (final item in result.items) _itemWithAfternoon(item)],
  rules: [for (final rule in result.rules) _ruleWithAfternoon(rule)],
);

ParseItem _itemWithAfternoon(ParseItem item) {
  if (!_lacksMeridiem(item.timeExpression)) return item;
  return ParseItem(
    title: item.title,
    kind: item.kind,
    category: item.category,
    course: item.course,
    date: item.date,
    weekday: item.weekday,
    dateExpression: item.dateExpression,
    timeExpression: item.timeExpression,
    startMin: _afternoon(item.startMin),
    endMin: _afternoon(item.endMin),
    repeat: item.repeat,
    fixedBlockKind: item.fixedBlockKind,
    due: item.due,
    dueTimeMin: _afternoon(item.dueTimeMin),
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

ParsedRule _ruleWithAfternoon(ParsedRule rule) {
  if (!_lacksMeridiem(rule.timeExpression)) return rule;
  return ParsedRule(
    kind: rule.kind,
    remove: rule.remove,
    minutes: rule.minutes,
    position: rule.position,
    startMin: _afternoon(rule.startMin),
    endMin: _afternoon(rule.endMin),
    timeExpression: rule.timeExpression,
    weekdays: rule.weekdays,
    course: rule.course,
    taskKind: rule.taskKind,
    briefingMin: rule.briefingMin,
    notifyCap: rule.notifyCap,
    quietStartMin: _afternoon(rule.quietStartMin),
    quietEndMin: _afternoon(rule.quietEndMin),
  );
}

/// 01:00–07:59면 12시간 뒤.
int? _afternoon(int? minuteOfDay) =>
    minuteOfDay != null && minuteOfDay >= 60 && minuteOfDay < 8 * 60
    ? minuteOfDay + 12 * 60
    : minuteOfDay;

/// 오전·오후를 알려 주는 말(때를 가리키는 말, 24시간 표기, 지금 기준 상대 시각).
final _meridiemWords = RegExp(
  r'오전|오후|아침|점심|저녁|밤|새벽|낮|정오|자정|am|pm|(분|시간)\s*(뒤|후)|있다가',
  caseSensitive: false,
);

/// 13시 이상이나 0시를 숫자로 쓴 24시간 표기(13시, 20:30, 0시).
final _twentyFourHour = RegExp(r'(?<!\d)(1[3-9]|2[0-4]|0{1,2})\s*(시|:)');

/// 시각을 말했는데 오전·오후를 알려 주는 말이 없는지.
bool _lacksMeridiem(String? expression) =>
    expression != null &&
    !_meridiemWords.hasMatch(expression) &&
    !_twentyFourHour.hasMatch(expression);

/// 오전·오후를 말하지 않았고 시각 가운데 하나가 8–11시(08:00–11:59, 20:00–23:59)인지. 끝 시각은 시작 뒤라서
/// 오전·오후가 정해지므로 시작이 없을 때만 본다('11시 이후엔 공부 안 해'의 끝). 아침 브리핑 시각은 늘
/// 오전이라(06:00–12:00만 받음) 보지 않는다.
bool _needsMeridiem(String? expression, List<int?> times) =>
    _lacksMeridiem(expression) &&
    times.any((time) => time != null && (time ~/ 60) % 12 >= 8);

/// 'N일'처럼 달 없이 날만 말했는지('3일 뒤' 같은 상대 표현과 'M월 N일', '다음 달 N일'은 아님).
final _dayOfMonth = RegExp(r'(?<!\d)\d{1,2}\s*일(?!\s*(뒤|후|안|동안|째|간|전))');
final _monthWords = RegExp(r'\d\s*월|달');

bool _saysDayOnly(String expression) =>
    _dayOfMonth.hasMatch(expression) && !_monthWords.hasMatch(expression);

/// '다음 주·다음주·담주'를 말했는데 요일을 말하지 않았는지.
final _nextWeek = RegExp(r'다음\s*주|담주');
final _weekdayName = RegExp(r'[월화수목금토일]\s*(요일|욜)|주\s*[월화수목금토일](?![가-힣])');

bool _saysNextWeekOnly(String expression) =>
    _nextWeek.hasMatch(expression) && !_weekdayName.hasMatch(expression);
