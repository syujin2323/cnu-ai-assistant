// 데모 모드의 06 AI 비서 응답. docs/architecture.md '데모 모드'(데모에서는 서버·AI를 부르지 않고, 말로 추가와
// 말로 정하는 규칙은 미리 적은 응답 중 가장 비슷한 것을 보여 준다).
//
// 보낸 문장과 예시 문장을 공백을 빼고 두 글자씩 끊어 견준 겹침(다이스 계수)이 가장 큰 예시의 응답을 돌려준다.
// 하나도 겹치지 않으면 알아듣지 못한 것(`other`)이다. 응답은 실제 /v1/parse 응답과 같은 꼴이라 06 화면이
// 같은 길(오후 기본값, 되묻기, 카드)로 보인다. 날짜는 보내는 때(한국 시각)의 달력 날짜로 만들고, 과목은 데모
// DB의 과목 이름을 쓴다. 예시와 응답은 디자인 전 임시 값이다.

import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';

/// 데모의 예시 문장 하나와 그 응답.
typedef DemoExample = ({
  String sentence,
  ParseResult Function(DateTime today, List<String> courses) reply,
});

/// [text]와 가장 비슷한 예시의 응답. [now]는 보내는 때(한국 시각), [courseNames]는 데모 DB의 과목 이름이다.
ParseResult demoParseResult(
  String text, {
  required DateTime now,
  required List<String> courseNames,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final said = _bigrams(text);
  DemoExample? best;
  var bestScore = 0.0;
  for (final example in demoExamples) {
    final score = _dice(said, _bigrams(example.sentence));
    if (score > bestScore) {
      best = example;
      bestScore = score;
    }
  }
  if (best == null) return const ParseResult(intent: ParseIntent.other);
  return best.reply(today, courseNames);
}

/// 데모의 예시. 첫 과목 이름이 없으면 과목 할 일 예시는 개인 할 일로 답한다.
final List<DemoExample> demoExamples = [
  (
    sentence: '목요일 7시 동아리',
    reply: (today, _) => _event(
      title: '동아리',
      date: _onOrAfter(today, DateTime.thursday),
      weekday: DateTime.thursday,
      dateExpression: '목요일',
      timeExpression: '7시',
      startMin: 7 * 60,
    ),
  ),
  (
    sentence: '내일 오후 3시 도서관에서 스터디, 노트북 챙겨야 해',
    reply: (today, _) {
      final date = _addDays(today, 1);
      return _event(
        title: '스터디',
        date: date,
        weekday: date.weekday,
        dateExpression: '내일',
        timeExpression: '오후 3시',
        startMin: 15 * 60,
        place: '도서관',
        prep: '노트북',
      );
    },
  ),
  (
    sentence: '주말마다 2시부터 5시까지 알바 있어',
    reply: (_, _) => const ParseResult(
      intent: ParseIntent.createEvent,
      items: [
        ParseItem(
          title: '알바',
          kind: ParseItemKind.event,
          category: ParseCategory.personal,
          dateExpression: '주말마다',
          timeExpression: '2시부터 5시까지',
          startMin: 2 * 60,
          endMin: 5 * 60,
          repeat: ParseRepeat(
            freq: ParseRepeatFreq.weekly,
            weekdays: [DateTime.saturday, DateTime.sunday],
          ),
          fixedBlockKind: FixedBlockKind.work,
        ),
      ],
    ),
  ),
  (
    sentence: '과제 금요일까지 내야 해',
    reply: (today, courses) {
      final course = courses.firstOrNull;
      final due = _onOrAfter(today, DateTime.friday);
      return ParseResult(
        intent: ParseIntent.createTask,
        items: [
          ParseItem(
            title: '과제',
            kind: ParseItemKind.task,
            category: course == null
                ? ParseCategory.personal
                : ParseCategory.course,
            course: course,
            weekday: DateTime.friday,
            dateExpression: '금요일까지',
            due: due,
          ),
        ],
      );
    },
  ),
  (
    sentence: '보고서 다음 주 월요일까지, 두 시간쯤 걸릴 듯',
    reply: (today, _) {
      final due = _addDays(today, 8 - today.weekday);
      return ParseResult(
        intent: ParseIntent.createTask,
        items: [
          ParseItem(
            title: '보고서',
            kind: ParseItemKind.task,
            category: ParseCategory.personal,
            weekday: DateTime.monday,
            dateExpression: '다음 주 월요일까지',
            due: due,
            estimatedMinutes: 120,
          ),
        ],
      );
    },
  ),
];

ParseResult _event({
  required String title,
  required DateTime date,
  required int weekday,
  required String dateExpression,
  required String timeExpression,
  required int startMin,
  String? place,
  String? prep,
}) => ParseResult(
  intent: ParseIntent.createEvent,
  items: [
    ParseItem(
      title: title,
      kind: ParseItemKind.event,
      category: ParseCategory.personal,
      date: date,
      weekday: weekday,
      dateExpression: dateExpression,
      timeExpression: timeExpression,
      startMin: startMin,
      place: place,
      prep: prep,
    ),
  ],
);

/// [today]부터 처음 오는 [weekday](오늘이 그 요일이면 오늘).
DateTime _onOrAfter(DateTime today, int weekday) =>
    _addDays(today, (weekday - today.weekday) % 7);

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// 공백을 뺀 두 글자 묶음들(같은 묶음은 한 번).
Set<String> _bigrams(String text) {
  final letters = text.replaceAll(RegExp(r'\s'), '').runes.toList();
  return {
    for (var i = 0; i + 1 < letters.length; i++)
      String.fromCharCodes(letters.sublist(i, i + 2)),
  };
}

/// 다이스 계수(겹친 묶음 × 2 ÷ 두 묶음 수의 합).
double _dice(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return 2 * a.intersection(b).length / (a.length + b.length);
}
