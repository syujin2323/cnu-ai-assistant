// 데모 모드의 06 AI 비서 응답. docs/architecture.md '데모 모드'(데모에서는 서버·AI를 부르지 않고, 말로 추가와
// 말로 정하는 규칙은 폰에서 문장의 날짜·시각·제목을 직접 읽어 답한다).
//
// 실제 AI가 아니라 정해 둔 표현만 읽는다: 날짜(오늘·내일·모레, 요일, '다음 주 화요일', 'N월 N일'), 시각('오후 3시',
// '7시 반', '2시부터 5시까지'), 반복('주말마다', '매주 화요일'), 마감('…까지'), 걸리는 시간('두 시간쯤'), 규칙 몇 가지
// (하루 최대 공부량, 한 번에 할 최대 시간, 수업 앞뒤 여유, 공부 가능한 시간대의 끝, 피할 시간, 식사), 질문(오늘 계획,
// 이번 주 마감, 빈 시간). 바꾸기·지우기·수업 변경은 읽지 않는다(알아듣지 못한 것). 응답은 실제 /v1/parse 응답과 같은
// 꼴이라 06 화면이 같은 길(오후 기본값, 되묻기, 카드)로 보인다. 읽는 표현은 디자인 전 임시 값이다.

import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';

/// 06 화면의 입력창 예시이자 데모가 읽는 문장의 본보기.
const List<String> demoExampleSentences = [
  '목요일 7시 동아리',
  '내일 오후 3시 도서관에서 스터디, 노트북 챙겨야 해',
  '주말마다 2시부터 5시까지 알바 있어',
  '과제 금요일까지 내야 해',
  '보고서 다음 주 월요일까지, 두 시간쯤 걸릴 듯',
  '하루 공부는 4시간까지만',
];

/// [text]를 읽은 응답. [now]는 보내는 때(한국 시각), [courseNames]는 데모 DB의 과목 이름이다.
ParseResult demoParseResult(
  String text, {
  required DateTime now,
  required List<String> courseNames,
}) {
  final said = text.trim();
  if (said.runes.length < 2) return _other;
  final today = DateTime(now.year, now.month, now.day);
  return _rule(said) ??
      _query(said) ??
      (_change.hasMatch(said) ? _other : _item(said, today, courseNames));
}

const _other = ParseResult(intent: ParseIntent.other);

final _change = RegExp(r'바꿔|바꾸|옮겨|옮기|미뤄|미루|당겨|취소|지워|삭제|빼 ?줘|휴강|보강');

// ───── 시각·시간 길이 ─────

const _meridiem = '오전|오후|아침|낮|점심|저녁|밤|새벽';
const _numberWords = {
  '한': 1,
  '두': 2,
  '세': 3,
  '네': 4,
  '다섯': 5,
  '여섯': 6,
  '일곱': 7,
  '여덟': 8,
  '아홉': 9,
  '열': 10,
  '열한': 11,
  '열두': 12,
};
const _number = r'\d{1,2}|열한|열두|다섯|여섯|일곱|여덟|아홉|한|두|세|네|열';

/// '오후 3시', '7시 반', '11시 30분'. '4시간'의 '4시'는 시각이 아니다.
final _clock = RegExp(
  '(?:($_meridiem)\\s*)?($_number)\\s*시(?!간)(?:\\s*(반)(?![가-힣])|\\s*(\\d{1,2})\\s*분)?',
);

/// '4시간', '1시간 반', '두 시간', '1시간 30분', '40분'.
final _length = RegExp(
  '(?:($_number)\\s*시간\\s*(?:(반)|(\\d{1,2})\\s*분)?)|(?:(\\d{1,3})\\s*분)',
);

int _numberOf(String word) => _numberWords[word] ?? int.parse(word);

typedef _Clock = ({int min, bool said, int start, int end});

/// 문장 속 시각들. 앞 시각이 오후였으면 오전·오후를 말하지 않은 뒤 시각도 오후로 본다('오후 2시부터 5시까지').
List<_Clock> _clocks(String text) {
  final found = <_Clock>[];
  var afternoon = false;
  for (final match in _clock.allMatches(text)) {
    var hour = _numberOf(match.group(2)!);
    if (hour > 24) continue;
    final word = match.group(1);
    final pm = switch (word) {
      '오후' || '낮' || '점심' || '저녁' || '밤' => true,
      null => afternoon,
      _ => false,
    };
    if (word != null) afternoon = pm;
    if (word == '밤' && hour == 12) {
      hour = 0;
    } else if (pm && hour < 12 && !(word == '점심' && hour >= 11)) {
      hour += 12;
    }
    final minute = match.group(3) != null
        ? 30
        : int.tryParse(match.group(4) ?? '') ?? 0;
    if (minute > 59) continue;
    found.add((
      min: (hour % 24) * 60 + minute,
      // 앞 시각의 오전·오후를 이어받은 것도 말한 것으로 본다.
      said: word != null || afternoon,
      start: match.start,
      end: match.end,
    ));
  }
  return found;
}

/// 문장 속 첫 시간 길이(분)와 그 자리.
({int minutes, int start, int end})? _lengthIn(String text) {
  final match = _length.firstMatch(text);
  if (match == null) return null;
  final minutes = match.group(1) != null
      ? _numberOf(match.group(1)!) * 60 +
            (match.group(2) != null
                ? 30
                : int.tryParse(match.group(3) ?? '') ?? 0)
      : int.parse(match.group(4)!);
  return (minutes: minutes, start: match.start, end: match.end);
}

// ───── 날짜 ─────

const _weekdayLetters = '월화수목금토일';
final _monthDay = RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일');
final _weekday = RegExp('(?:(다음|이번)\\s*주\\s*)?([$_weekdayLetters])요일');
final _relative = RegExp('오늘|내일|모레|글피');
final _repeat = RegExp(
  '주말\\s*마다|평일\\s*마다|매일|매주\\s*((?:[$_weekdayLetters]요일[,·\\s]*)+)|'
  '((?:[$_weekdayLetters]요일[,·\\s]*)+)마다',
);

typedef _Day = ({DateTime date, int? weekday, int start, int end});

_Day? _day(String text, DateTime today) {
  if (_monthDay.firstMatch(text) case final match?) {
    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      var date = DateTime(today.year, month, day);
      if (date.isBefore(today)) date = DateTime(today.year + 1, month, day);
      return (date: date, weekday: null, start: match.start, end: match.end);
    }
  }
  if (_weekday.firstMatch(text) case final match?) {
    final weekday = _weekdayLetters.indexOf(match.group(2)!) + 1;
    final date = match.group(1) == '다음'
        ? _addDays(today, 7 - today.weekday + weekday)
        : _addDays(today, (weekday - today.weekday) % 7);
    return (date: date, weekday: weekday, start: match.start, end: match.end);
  }
  if (_relative.firstMatch(text) case final match?) {
    final days = const {'오늘': 0, '내일': 1, '모레': 2, '글피': 3}[match.group(0)]!;
    return (
      date: _addDays(today, days),
      weekday: null,
      start: match.start,
      end: match.end,
    );
  }
  return null;
}

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

List<int> _weekdaysIn(String text) => [
  for (final match in RegExp('([$_weekdayLetters])요일').allMatches(text))
    _weekdayLetters.indexOf(match.group(1)!) + 1,
];

// ───── 규칙 ─────

ParseResult? _rule(String text) {
  final flat = text.replaceAll(RegExp(r'\s'), '');
  final length = _lengthIn(text);
  final clocks = _clocks(text);
  final days = _weekdaysIn(text);
  final weekdays = days.isEmpty ? null : days;
  String? expression() => clocks.isEmpty
      ? null
      : text.substring(clocks.first.start, clocks.last.end);
  ParsedRule? rule;
  if (flat.contains('하루') && length != null && !flat.contains('걸')) {
    rule = ParsedRule(
      kind: RuleKind.dailyCap,
      remove: false,
      minutes: length.minutes,
    );
  } else if (flat.contains('한번에') && length != null) {
    rule = ParsedRule(
      kind: RuleKind.maxBlock,
      remove: false,
      minutes: length.minutes,
    );
  } else if (flat.contains('수업') &&
      RegExp('여유|앞뒤|전후').hasMatch(flat) &&
      length != null) {
    rule = ParsedRule(
      kind: RuleKind.classBuffer,
      remove: false,
      minutes: length.minutes,
    );
  } else if (RegExp('점심|저녁|아침|식사|밥').hasMatch(flat) &&
      flat.contains('먹') &&
      clocks.length >= 2) {
    rule = ParsedRule(
      kind: RuleKind.meal,
      remove: false,
      startMin: clocks[0].min,
      endMin: clocks[1].min,
      minutes: length?.minutes,
      timeExpression: expression(),
    );
  } else if (RegExp('이후|넘어|넘으면').hasMatch(flat) &&
      RegExp('안할|안해|하지않|못해|쉴|그만').hasMatch(flat) &&
      clocks.isNotEmpty) {
    rule = ParsedRule(
      kind: RuleKind.workWindow,
      remove: false,
      endMin: clocks.first.min,
      timeExpression: expression(),
      weekdays: weekdays,
    );
  } else if (RegExp('비워|피해|놓지마|잡지마').hasMatch(flat) && clocks.length >= 2) {
    rule = ParsedRule(
      kind: RuleKind.blackout,
      remove: false,
      startMin: clocks[0].min,
      endMin: clocks[1].min,
      timeExpression: expression(),
      weekdays: weekdays,
    );
  }
  if (rule == null) return null;
  return ParseResult(intent: ParseIntent.setRule, rules: [rule]);
}

// ───── 질문 ─────

ParseResult? _query(String text) {
  final flat = text.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'알려|보여|뭐있|뭐야|뭐해|뭐지|언제|있어\?|있나|\?$').hasMatch(flat)) {
    return null;
  }
  return ParseResult(
    intent: ParseIntent.query,
    queryType: RegExp('마감|과제|제출').hasMatch(flat)
        ? ParseQueryType.deadlinesThisWeek
        : RegExp('빈시간|비는|남는시간|한가').hasMatch(flat)
        ? ParseQueryType.freeTime
        : ParseQueryType.todayPlan,
  );
}

// ───── 일정·할 일 ─────

final _taskWord = RegExp('과제|보고서|레포트|리포트|숙제|제출|퀴즈|시험 ?공부|복습|예습');
final _ending = RegExp(
  r'\s*(?:이|가|을|를|은|는)?\s*(?:있어요?|있음|있다|해야\s*해요?|해야\s*함|해야\s*돼요?|내야\s*해요?|내야\s*함|'
  r'잡아\s*줘요?|추가해\s*줘요?|추가|넣어\s*줘요?|만들어\s*줘요?|이야|야|임)$',
);
final _prep = RegExp(r'[,.]?\s*(\S+?)(?:을|를)?\s*챙겨(?:야\s*해요?|야\s*함|와|가)?');
final _place = RegExp(r'(\S+)에서');
final _lengthTail = RegExp(
  r'^\s*(?:쯤|정도|은|는)?\s*(?:걸릴\s*듯|걸릴\s*것\s*같아요?|걸려요?|걸림)?',
);

/// 자리 표시(지운 날짜·시각 뒤에 붙은 조사를 함께 지우려고 둠).
const _gap = '\u0000';

ParseResult _item(String text, DateTime today, List<String> courseNames) {
  final repeat = _repeat.firstMatch(text);
  final day = repeat == null ? _day(text, today) : null;
  final clocks = _clocks(text);
  final lengthAt = _lengthIn(text);
  final ranged = clocks.length >= 2;
  final isTask =
      repeat == null &&
      !ranged &&
      (_taskWord.hasMatch(text) ||
          (text.contains('까지') && !text.contains('부터')));
  if (repeat == null && day == null && clocks.isEmpty && !isTask) return _other;

  // 읽은 표현을 지우고 남은 말이 제목이다.
  final cuts = <(int, int)>[
    if (repeat != null) (repeat.start, repeat.end),
    if (day != null) (day.start, day.end),
    for (final clock in clocks.take(2)) (clock.start, clock.end),
    if (lengthAt != null && isTask)
      (
        lengthAt.start,
        lengthAt.end +
            (_lengthTail.firstMatch(text.substring(lengthAt.end))?.end ?? 0),
      ),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  var rest = text;
  for (final (start, end) in cuts) {
    if (start < rest.length && end <= rest.length) {
      rest = rest.replaceRange(start, end, _gap);
    }
  }
  rest = rest
      .replaceAll(RegExp('(?:다음|이번)\\s*주\\s*(?=$_gap)'), '')
      .replaceAll(RegExp('$_gap(?:에는|에|엔|까지는|까지만|까지|부터|쯤|은|는)?'), ' ');
  String? prep;
  if (_prep.firstMatch(rest) case final match?) {
    prep = match.group(1);
    rest = rest.replaceRange(match.start, match.end, ' ');
  }
  String? place;
  if (_place.firstMatch(rest) case final match?) {
    place = match.group(1);
    rest = rest.replaceRange(match.start, match.end, ' ');
  }
  String? course;
  for (final name in courseNames) {
    if (name.isNotEmpty && rest.contains(name)) {
      course = name;
      rest = rest.replaceFirst(name, ' ');
      break;
    }
  }
  rest = rest
      .replaceAll(RegExp(r'[,.!~]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(_ending, '')
      .replaceAll(RegExp(r'^(?:까지|부터|에)\s+|\s+(?:까지|부터|에)$'), '')
      .trim();
  var title = rest.isEmpty ? null : rest;
  if (title == null && isTask && course != null) title = '과제';

  final timeExpression = clocks.isEmpty
      ? null
      : text.substring(
          clocks.first.start,
          clocks.length >= 2 ? clocks[1].end : clocks.first.end,
        );
  final dateExpression = repeat != null
      ? text.substring(repeat.start, repeat.end).trim()
      : day == null
      ? null
      : text.substring(day.start, day.end);
  final category = course == null
      ? ParseCategory.personal
      : ParseCategory.course;

  if (isTask) {
    final item = ParseItem(
      title: title,
      kind: ParseItemKind.task,
      category: category,
      course: course,
      weekday: day?.weekday,
      dateExpression: dateExpression,
      timeExpression: timeExpression,
      due: day?.date,
      dueTimeMin: clocks.firstOrNull?.min,
      estimatedMinutes: lengthAt?.minutes,
    );
    if (title == null) {
      return _ask(item, ParseClarificationField.title, '어떤 할 일인가요?');
    }
    if (day == null) {
      return _ask(item, ParseClarificationField.date, '언제까지인가요?');
    }
    return ParseResult(intent: ParseIntent.createTask, items: [item]);
  }

  final repeatDays = repeat == null
      ? null
      : switch (text.substring(repeat.start, repeat.end)) {
          final said when said.startsWith('주말') => const [6, 7],
          final said when said.startsWith('평일') => const [1, 2, 3, 4, 5],
          '매일' => const [1, 2, 3, 4, 5, 6, 7],
          final said => _weekdaysIn(said),
        };
  final item = ParseItem(
    title: title,
    kind: ParseItemKind.event,
    category: category,
    course: course,
    // 날짜 없이 시각만 말했으면 오늘이다.
    date: repeat != null ? null : (day?.date ?? today),
    weekday: day?.weekday,
    dateExpression: dateExpression,
    timeExpression: timeExpression,
    startMin: clocks.firstOrNull?.min,
    endMin: ranged ? clocks[1].min : null,
    repeat: repeatDays == null
        ? null
        : ParseRepeat(freq: ParseRepeatFreq.weekly, weekdays: repeatDays),
    fixedBlockKind: repeatDays == null
        ? null
        : RegExp('알바|아르바이트|근무').hasMatch(text)
        ? FixedBlockKind.work
        : RegExp('운동|헬스|러닝|수영').hasMatch(text)
        ? FixedBlockKind.exercise
        : FixedBlockKind.other,
    place: place,
    prep: prep,
  );
  if (title == null) {
    return _ask(item, ParseClarificationField.title, '어떤 일정인가요?');
  }
  if (clocks.isEmpty) {
    return _ask(item, ParseClarificationField.time, '몇 시인가요?');
  }
  return ParseResult(intent: ParseIntent.createEvent, items: [item]);
}

ParseResult _ask(
  ParseItem item,
  ParseClarificationField field,
  String question,
) => ParseResult(
  intent: item.kind == ParseItemKind.task
      ? ParseIntent.createTask
      : ParseIntent.createEvent,
  needsClarification: true,
  clarification: ParseClarification(field: field, question: question),
  items: [item],
);
