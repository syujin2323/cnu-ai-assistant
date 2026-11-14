// /v1/parse 응답(앱·서버 약속). docs/architecture.md '앱과 서버 사이 약속 (API)'의 POST /v1/parse.
//
// 꼴의 원본은 레포 루트 schema/parse_result.schema.json이다. 서버가 나중에 null 허용 필드를 더할 수 있으므로
// 없는 키는 null로 읽고 모르는 키는 무시한다. 열거값이 모르는 값이거나 날짜·시각의 꼴이 틀리면 짐작하지 않고
// [FormatException]을 던진다(부르는 쪽은 직접 추가 폼으로 넘어간다).
//
// 앱에서 쓰기 좋게 날짜는 그날 0시의 [DateTime](한국 시각 벽시계 값), 시각은 자정 기준 분, 요일은 1(월)–7(일)로
// 바꿔 둔다. [toJson]은 응답과 같은 꼴로 되돌린다(스키마 테스트가 이것을 검증함).

import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';

/// 문장의 의도.
enum ParseIntent {
  createEvent,
  createTask,
  update,
  delete,
  query,
  classException,
  setRule,
  other,
}

/// 서버가 되묻는 값.
enum ParseClarificationField {
  date,
  time,
  title,
  course,
  target,
  repeat,
  rule,
  intent,
  other,
}

/// 질문의 종류. 기간을 말하지 않았으면 마감은 이번 주, 하루 계획은 오늘이다.
enum ParseQueryType { deadlinesThisWeek, todayPlan, freeTime }

/// 정해 둔 규칙 종류로 나타낼 수 없는 조건의 종류.
enum UnsupportedRuleKind { notification, specificDate, mode, priority, other }

/// 항목의 종류: 시작·끝이 있는 일정이나 마감이 있는 할 일.
enum ParseItemKind { event, task }

/// 항목이 과목에 관한 것인지.
enum ParseCategory { course, personal }

/// 반복 주기. 앱은 매주([weekly])만 고정 일정으로 저장한다.
enum ParseRepeatFreq { weekly, biweekly, monthly, other }

/// 서버가 되물은 것.
final class ParseClarification {
  const ParseClarification({required this.field, required this.question});

  final ParseClarificationField field;

  /// 되묻기 카드에 그대로 쓰는 질문.
  final String question;
}

/// 반복 일정의 주기와 요일(1–7).
final class ParseRepeat {
  const ParseRepeat({required this.freq, required this.weekdays});

  final ParseRepeatFreq freq;
  final List<int> weekdays;
}

/// 일정·할 일·수업 변경 항목. 바꾸기의 날짜·시각 칸은 새 값이고, 대상의 날짜는 [targetDate]다.
final class ParseItem {
  const ParseItem({
    this.title,
    this.kind,
    this.category,
    this.course,
    this.date,
    this.weekday,
    this.dateExpression,
    this.timeExpression,
    this.startMin,
    this.endMin,
    this.repeat,
    this.fixedBlockKind,
    this.due,
    this.dueTimeMin,
    this.estimatedMinutes,
    this.reminderMinutes,
    this.place,
    this.prep,
    this.shiftMinutes,
    this.target,
    this.targetDate,
    this.exceptionType,
  });

  final String? title;
  final ParseItemKind? kind;
  final ParseCategory? category;

  /// 요청의 과목 이름 가운데 하나.
  final String? course;

  /// 일정·수업 변경의 날짜(그날 0시).
  final DateTime? date;

  /// 문장에서 읽은 요일 1(월)–7(일). [date](할 일은 [due])와 맞는지 앱이 본다.
  final int? weekday;

  /// 문장 속 날짜의 원래 표현.
  final String? dateExpression;

  /// 문장 속 시각의 원래 표현. 앱이 오전·오후를 말했는지 본다.
  final String? timeExpression;

  /// 시작·끝 시각(자정 기준 분).
  final int? startMin;
  final int? endMin;

  final ParseRepeat? repeat;
  final FixedBlockKind? fixedBlockKind;

  /// 할 일의 마감 날짜(그날 0시)와 시각(자정 기준 분).
  final DateTime? due;
  final int? dueTimeMin;

  final int? estimatedMinutes;
  final int? reminderMinutes;
  final String? place;
  final String? prep;

  /// 바꾸기에서 상대로 옮긴 분(늦추면 양수).
  final int? shiftMinutes;

  /// 바꾸기·지우기 대상을 가리키는 원래 표현과, 그 표현이 말한 대상의 날짜.
  final String? target;
  final DateTime? targetDate;

  final ClassExceptionKind? exceptionType;
}

/// 말로 정한 규칙 하나. 값은 그 종류가 쓰는 것만 있다(docs/architecture.md '내 규칙').
final class ParsedRule {
  const ParsedRule({
    required this.kind,
    required this.remove,
    this.minutes,
    this.position,
    this.startMin,
    this.endMin,
    this.timeExpression,
    this.weekdays,
    this.course,
    this.taskKind,
    this.briefingMin,
    this.notifyCap,
    this.quietStartMin,
    this.quietEndMin,
  });

  final RuleKind kind;

  /// 없애기(`remove`)면 true, 정하기(`set`)면 false.
  final bool remove;

  final int? minutes;
  final TravelPosition? position;
  final int? startMin;
  final int? endMin;
  final String? timeExpression;

  /// 규칙이 걸리는 요일 1–7. null이면 매일.
  final List<int>? weekdays;

  final String? course;
  final TaskKind? taskKind;
  final int? briefingMin;
  final int? notifyCap;
  final int? quietStartMin;
  final int? quietEndMin;
}

/// /v1/parse 응답.
final class ParseResult {
  const ParseResult({
    required this.intent,
    this.needsClarification = false,
    this.clarification,
    this.queryType,
    this.queryFrom,
    this.queryTo,
    this.queryCourse,
    this.unsupportedRule,
    this.items = const [],
    this.rules = const [],
  });

  /// 응답 JSON을 읽는다. 꼴이 틀리면 [FormatException]을 던진다.
  factory ParseResult.fromJson(Object? json) {
    final map = _map(json, 'response');
    return ParseResult(
      intent: _enum(ParseIntent.values, map['intent'], 'intent'),
      needsClarification: _bool(map['needsClarification']),
      clarification: _clarification(map['clarification']),
      queryType: _enumOrNull(
        ParseQueryType.values,
        map['queryType'],
        'queryType',
      ),
      queryFrom: _dateOrNull(map['queryFrom'], 'queryFrom'),
      queryTo: _dateOrNull(map['queryTo'], 'queryTo'),
      queryCourse: _stringOrNull(map['queryCourse'], 'queryCourse'),
      unsupportedRule: _enumOrNull(
        UnsupportedRuleKind.values,
        map['unsupportedRule'],
        'unsupportedRule',
      ),
      items: _list(map['items'], 'items').map(_item).toList(),
      rules: _list(map['rules'], 'rules').map(_rule).toList(),
    );
  }

  final ParseIntent intent;

  /// 서버가 되물었는지. 그러면 [clarification]이 있다.
  final bool needsClarification;
  final ParseClarification? clarification;
  final ParseQueryType? queryType;

  /// 질문이 말한 기간의 첫날과 마지막 날(그날 포함).
  final DateTime? queryFrom;
  final DateTime? queryTo;
  final String? queryCourse;
  final UnsupportedRuleKind? unsupportedRule;
  final List<ParseItem> items;
  final List<ParsedRule> rules;

  /// 응답과 같은 꼴의 JSON(모든 키가 있고 없는 값은 null).
  Map<String, Object?> toJson() => {
    'intent': snakeName(intent),
    'needsClarification': needsClarification,
    'clarification': clarification == null
        ? null
        : {
            'field': snakeName(clarification!.field),
            'question': clarification!.question,
          },
    'queryType': _snakeOrNull(queryType),
    'queryFrom': _dateText(queryFrom),
    'queryTo': _dateText(queryTo),
    'queryCourse': queryCourse,
    'unsupportedRule': _snakeOrNull(unsupportedRule),
    'items': [for (final item in items) _itemJson(item)],
    'rules': [for (final rule in rules) _ruleJson(rule)],
  };
}

const _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _weekdayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

ParseItem _item(Object? json) {
  final map = _map(json, 'item');
  return ParseItem(
    title: _stringOrNull(map['title'], 'title'),
    kind: _enumOrNull(ParseItemKind.values, map['kind'], 'kind'),
    category: _enumOrNull(ParseCategory.values, map['category'], 'category'),
    course: _stringOrNull(map['course'], 'course'),
    date: _dateOrNull(map['date'], 'date'),
    weekday: _koreanWeekdayOrNull(map['weekday']),
    dateExpression: _stringOrNull(map['dateExpression'], 'dateExpression'),
    timeExpression: _stringOrNull(map['timeExpression'], 'timeExpression'),
    startMin: _timeOrNull(map['start'], 'start'),
    endMin: _timeOrNull(map['end'], 'end'),
    repeat: _repeat(map['repeat']),
    fixedBlockKind: _enumOrNull(
      FixedBlockKind.values,
      map['fixedBlockKind'],
      'fixedBlockKind',
    ),
    due: _dateOrNull(map['due'], 'due'),
    dueTimeMin: _timeOrNull(map['dueTime'], 'dueTime'),
    estimatedMinutes: _intOrNull(map['estimatedMinutes'], 'estimatedMinutes'),
    reminderMinutes: _intOrNull(map['reminderMinutes'], 'reminderMinutes'),
    place: _stringOrNull(map['place'], 'place'),
    prep: _stringOrNull(map['prep'], 'prep'),
    shiftMinutes: _intOrNull(map['shiftMinutes'], 'shiftMinutes'),
    target: _stringOrNull(map['target'], 'target'),
    targetDate: _dateOrNull(map['targetDate'], 'targetDate'),
    exceptionType: _enumOrNull(
      ClassExceptionKind.values,
      map['exceptionType'],
      'exceptionType',
    ),
  );
}

ParsedRule _rule(Object? json) {
  final map = _map(json, 'rule');
  final action = map['action'];
  if (action != 'set' && action != 'remove') {
    throw FormatException('Unknown rule action', '$action');
  }
  final weekdays = map['weekdays'];
  return ParsedRule(
    kind: _enum(RuleKind.values, map['kind'], 'rule kind'),
    remove: action == 'remove',
    minutes: _intOrNull(map['minutes'], 'minutes'),
    position: _enumOrNull(TravelPosition.values, map['position'], 'position'),
    startMin: _timeOrNull(map['start'], 'start'),
    endMin: _timeOrNull(map['end'], 'end'),
    timeExpression: _stringOrNull(map['timeExpression'], 'timeExpression'),
    weekdays: weekdays == null ? null : _weekdayCodeList(weekdays),
    course: _stringOrNull(map['course'], 'course'),
    taskKind: _enumOrNull(TaskKind.values, map['taskKind'], 'taskKind'),
    briefingMin: _timeOrNull(map['briefingTime'], 'briefingTime'),
    notifyCap: _intOrNull(map['notifyCap'], 'notifyCap'),
    quietStartMin: _timeOrNull(map['quietStart'], 'quietStart'),
    quietEndMin: _timeOrNull(map['quietEnd'], 'quietEnd'),
  );
}

ParseClarification? _clarification(Object? json) {
  if (json == null) return null;
  final map = _map(json, 'clarification');
  return ParseClarification(
    field: _enum(ParseClarificationField.values, map['field'], 'field'),
    question: _string(map['question'], 'question'),
  );
}

ParseRepeat? _repeat(Object? json) {
  if (json == null) return null;
  final map = _map(json, 'repeat');
  return ParseRepeat(
    freq: _enum(ParseRepeatFreq.values, map['freq'], 'freq'),
    weekdays: _weekdayCodeList(map['byDay']),
  );
}

Map<String, Object?> _itemJson(ParseItem item) => {
  'title': item.title,
  'kind': _snakeOrNull(item.kind),
  'category': _snakeOrNull(item.category),
  'course': item.course,
  'date': _dateText(item.date),
  'weekday': item.weekday == null ? null : _koreanWeekdays[item.weekday! - 1],
  'dateExpression': item.dateExpression,
  'timeExpression': item.timeExpression,
  'start': _timeText(item.startMin),
  'end': _timeText(item.endMin),
  'repeat': item.repeat == null
      ? null
      : {
          'freq': snakeName(item.repeat!.freq),
          'byDay': _weekdayCodeTexts(item.repeat!.weekdays),
        },
  'fixedBlockKind': _snakeOrNull(item.fixedBlockKind),
  'due': _dateText(item.due),
  'dueTime': _timeText(item.dueTimeMin),
  'estimatedMinutes': item.estimatedMinutes,
  'reminderMinutes': item.reminderMinutes,
  'place': item.place,
  'prep': item.prep,
  'shiftMinutes': item.shiftMinutes,
  'target': item.target,
  'targetDate': _dateText(item.targetDate),
  'exceptionType': _snakeOrNull(item.exceptionType),
};

Map<String, Object?> _ruleJson(ParsedRule rule) => {
  'kind': snakeName(rule.kind),
  'action': rule.remove ? 'remove' : 'set',
  'minutes': rule.minutes,
  'position': _snakeOrNull(rule.position),
  'start': _timeText(rule.startMin),
  'end': _timeText(rule.endMin),
  'timeExpression': rule.timeExpression,
  'weekdays': rule.weekdays == null ? null : _weekdayCodeTexts(rule.weekdays!),
  'course': rule.course,
  'taskKind': _snakeOrNull(rule.taskKind),
  'briefingTime': _timeText(rule.briefingMin),
  'notifyCap': rule.notifyCap,
  'quietStart': _timeText(rule.quietStartMin),
  'quietEnd': _timeText(rule.quietEndMin),
};

Map<String, Object?> _map(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw FormatException('Expected an object for $what');
}

List<Object?> _list(Object? json, String what) {
  if (json is List<Object?>) return json;
  throw FormatException('Expected a list for $what');
}

bool _bool(Object? json) {
  if (json is bool) return json;
  throw const FormatException('Expected a bool for needsClarification');
}

String _string(Object? json, String what) {
  if (json is String) return json;
  throw FormatException('Expected a string for $what');
}

String? _stringOrNull(Object? json, String what) =>
    json == null ? null : _string(json, what);

int? _intOrNull(Object? json, String what) {
  if (json == null) return null;
  if (json is int) return json;
  throw FormatException('Expected an integer for $what');
}

T _enum<T extends Enum>(List<T> values, Object? json, String what) =>
    enumFromSnake(values, _string(json, what));

T? _enumOrNull<T extends Enum>(List<T> values, Object? json, String what) =>
    json == null ? null : _enum(values, json, what);

String? _snakeOrNull(Enum? value) => value == null ? null : snakeName(value);

/// 'YYYY-MM-DD'를 그날 0시로 읽는다. 달력에 없는 날짜(2026-02-30)는 받지 않는다.
DateTime? _dateOrNull(Object? json, String what) {
  if (json == null) return null;
  final match = _datePattern.firstMatch(_string(json, what));
  if (match == null) throw FormatException('Expected YYYY-MM-DD for $what');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Not a calendar date for $what');
  }
  return date;
}

String? _dateText(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

/// 'HH:mm'을 자정 기준 분으로 읽는다.
int? _timeOrNull(Object? json, String what) {
  if (json == null) return null;
  final match = _timePattern.firstMatch(_string(json, what));
  if (match == null) throw FormatException('Expected HH:mm for $what');
  return int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

String? _timeText(int? minuteOfDay) => minuteOfDay == null
    ? null
    : '${_two(minuteOfDay ~/ 60)}:${_two(minuteOfDay % 60)}';

int? _koreanWeekdayOrNull(Object? json) {
  if (json == null) return null;
  final index = _koreanWeekdays.indexOf(_string(json, 'weekday'));
  if (index < 0) throw FormatException('Unknown weekday', '$json');
  return index + 1;
}

List<int> _weekdayCodeList(Object? json) => [
  for (final code in _list(json, 'weekday codes'))
    switch (_weekdayCodes.indexOf(_string(code, 'weekday code'))) {
      -1 => throw FormatException('Unknown weekday code', '$code'),
      final index => index + 1,
    },
];

List<String> _weekdayCodeTexts(List<int> weekdays) => [
  for (final weekday in weekdays) _weekdayCodes[weekday - 1],
];

String _two(int value) => value.toString().padLeft(2, '0');
