// /v1/parse 응답의 되묻기 판단 테스트. docs/screens.md '06 AI 비서'의 되묻기, docs/architecture.md 'POST /v1/parse'.

import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/parse_checks.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-10-12(월) 10:30.
final _now = DateTime(2026, 10, 12, 10, 30);

int _hm(int hour, [int minute = 0]) => hour * 60 + minute;

ParseItem _event({
  DateTime? date,
  int? weekday,
  String? dateExpression,
  String? timeExpression,
  int? start,
  int? end,
  ParseRepeat? repeat,
}) => ParseItem(
  kind: ParseItemKind.event,
  date: date,
  weekday: weekday ?? date?.weekday,
  dateExpression: dateExpression,
  timeExpression: timeExpression,
  startMin: start,
  endMin: end,
  repeat: repeat,
);

ParseItem _task({
  DateTime? due,
  int? weekday,
  String? dateExpression,
  String? timeExpression,
  int? dueTime,
}) => ParseItem(
  kind: ParseItemKind.task,
  due: due,
  weekday: weekday ?? due?.weekday,
  dateExpression: dateExpression,
  timeExpression: timeExpression,
  dueTimeMin: dueTime,
);

List<ParseQuestionKind> _kinds(ParseIntent intent, ParseItem item) =>
    parseQuestions(
      ParseResult(intent: intent, items: [item]),
      now: _now,
    ).map((question) => question.kind).toList();

List<ParseQuestionKind> _eventKinds(ParseItem item) =>
    _kinds(ParseIntent.createEvent, item);

final _tomorrow = DateTime(2026, 10, 13);

void main() {
  test('서버가 되물었으면 그것 하나만 돌려준다', () {
    final result = ParseResult(
      intent: ParseIntent.createEvent,
      needsClarification: true,
      clarification: const ParseClarification(
        field: ParseClarificationField.intent,
        question: '먼저 무엇을 할까요?',
      ),
      items: [_event()],
    );
    expect(parseQuestions(result, now: _now), [
      const ParseQuestion(ParseQuestionKind.server),
    ]);
  });

  test('맞는 일정은 되묻지 않는다', () {
    expect(
      _eventKinds(
        _event(
          date: _tomorrow,
          dateExpression: '내일',
          timeExpression: '오후 3시',
          start: _hm(15),
        ),
      ),
      isEmpty,
    );
  });

  group('오전·오후', () {
    for (final (expression, start) in [
      ('8시', _hm(8)),
      ('9시 반', _hm(9, 30)),
      ('11시', _hm(23)),
      ('8시부터 10시까지', _hm(8)),
    ]) {
      test('$expression은 되묻는다', () {
        expect(
          _eventKinds(
            _event(date: _tomorrow, timeExpression: expression, start: start),
          ),
          [ParseQuestionKind.meridiem],
        );
      });
    }

    for (final (expression, start) in [
      ('오후 8시', _hm(20)),
      ('저녁 8시', _hm(20)),
      ('아침 9시', _hm(9)),
      ('20시', _hm(20)),
      ('20:30', _hm(20, 30)),
      ('3시', _hm(15)),
      ('12시', _hm(12)),
      ('30분 뒤', _hm(11)),
      ('2시부터 9시까지', _hm(14)),
    ]) {
      test('$expression은 되묻지 않는다', () {
        expect(
          _eventKinds(
            _event(
              date: _tomorrow,
              timeExpression: expression,
              start: start,
              end: expression == '2시부터 9시까지' ? _hm(21) : null,
            ),
          ),
          isEmpty,
        );
      });
    }

    test('시각을 말하지 않았으면 되묻지 않는다', () {
      expect(_eventKinds(_event(date: _tomorrow, start: _hm(9))), isEmpty);
    });

    test('할 일의 마감 시각도 본다', () {
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: _tomorrow, timeExpression: '10시', dueTime: _hm(10)),
        ),
        [ParseQuestionKind.meridiem],
      );
    });

    test('규칙은 시작(없으면 끝)과 조용한 시간을 본다', () {
      const unclear = ParsedRule(
        kind: RuleKind.workWindow,
        remove: false,
        endMin: 11 * 60,
        timeExpression: '11시 이후',
      );
      const clear = ParsedRule(
        kind: RuleKind.workWindow,
        remove: false,
        endMin: 23 * 60,
        timeExpression: '밤 11시',
      );
      const briefing = ParsedRule(
        kind: RuleKind.notify,
        remove: false,
        briefingMin: 8 * 60,
        timeExpression: '8시',
      );
      final questions = parseQuestions(
        const ParseResult(
          intent: ParseIntent.setRule,
          rules: [clear, unclear, briefing],
        ),
        now: _now,
      );
      expect(questions, [
        const ParseQuestion(ParseQuestionKind.meridiem, ruleIndex: 1),
      ]);
    });
  });

  group('날짜', () {
    test('한 번뿐인 일정과 수업 변경에 날짜가 없으면 되묻는다', () {
      expect(_eventKinds(_event()), [ParseQuestionKind.missingDate]);
      expect(_kinds(ParseIntent.classException, const ParseItem()), [
        ParseQuestionKind.missingDate,
      ]);
    });

    test('반복 일정, 할 일, 바꾸기는 날짜가 없어도 된다', () {
      expect(
        _eventKinds(
          _event(
            repeat: const ParseRepeat(
              freq: ParseRepeatFreq.weekly,
              weekdays: [2],
            ),
          ),
        ),
        isEmpty,
      );
      expect(_kinds(ParseIntent.createTask, _task()), isEmpty);
      expect(
        _kinds(ParseIntent.update, const ParseItem(shiftMinutes: 60)),
        isEmpty,
      );
    });

    test('달 없이 날만 말했으면 되묻는다', () {
      final day = DateTime(2026, 10, 20);
      expect(_eventKinds(_event(date: day, dateExpression: '20일')), [
        ParseQuestionKind.dayOnly,
      ]);
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: day, dateExpression: '20일 자정까지'),
        ),
        [ParseQuestionKind.dayOnly],
      );
      for (final expression in ['10월 20일', '다음 달 20일', '3일 뒤', '8일 안에']) {
        expect(
          _eventKinds(_event(date: day, dateExpression: expression)),
          isEmpty,
          reason: expression,
        );
      }
    });

    test('한 번뿐인 일정의 주말·다음 주는 되묻는다', () {
      expect(
        _eventKinds(
          _event(date: DateTime(2026, 10, 17), dateExpression: '주말에'),
        ),
        [ParseQuestionKind.weekend],
      );
      expect(
        _eventKinds(
          _event(date: DateTime(2026, 10, 19), dateExpression: '다음 주에'),
        ),
        [ParseQuestionKind.nextWeek],
      );
      for (final expression in ['다음 주 화요일', '담주 화욜', '다음주 화']) {
        expect(
          _eventKinds(
            _event(date: DateTime(2026, 10, 20), dateExpression: expression),
          ),
          isEmpty,
          reason: expression,
        );
      }
    });

    test('할 일의 주말·다음 주 마감은 되묻지 않는다', () {
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: DateTime(2026, 10, 25), dateExpression: '다음 주 안에'),
        ),
        isEmpty,
      );
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: DateTime(2026, 10, 18), dateExpression: '주말까지'),
        ),
        isEmpty,
      );
    });

    test('날짜(할 일은 마감)와 요일이 어긋나면 되묻는다', () {
      expect(_eventKinds(_event(date: _tomorrow, weekday: 3)), [
        ParseQuestionKind.weekdayMismatch,
      ]);
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: DateTime(2026, 10, 16), weekday: 4),
        ),
        [ParseQuestionKind.weekdayMismatch],
      );
    });

    test('지난 날짜와 오늘의 지난 시각은 되묻는다', () {
      final yesterday = DateTime(2026, 10, 11);
      final today = DateTime(2026, 10, 12);
      expect(_eventKinds(_event(date: yesterday)), [
        ParseQuestionKind.pastDate,
      ]);
      expect(_kinds(ParseIntent.createTask, _task(due: yesterday)), [
        ParseQuestionKind.pastDate,
      ]);
      expect(
        _eventKinds(
          _event(date: yesterday, timeExpression: '오후 3시', start: _hm(15)),
        ),
        [ParseQuestionKind.pastDate],
      );
      expect(
        _eventKinds(
          _event(date: today, timeExpression: '아침 9시', start: _hm(9)),
        ),
        [ParseQuestionKind.pastTime],
      );
      expect(
        _kinds(
          ParseIntent.createTask,
          _task(due: today, timeExpression: '오전 10시', dueTime: _hm(10)),
        ),
        [ParseQuestionKind.pastTime],
      );
      expect(
        _eventKinds(
          _event(date: today, timeExpression: '오전 11시', start: _hm(11)),
        ),
        isEmpty,
      );
      expect(_eventKinds(_event(date: today)), isEmpty);
    });
  });

  test('매주가 아닌 반복은 되묻는다', () {
    for (final freq in [ParseRepeatFreq.biweekly, ParseRepeatFreq.monthly]) {
      expect(
        _eventKinds(
          _event(
            repeat: ParseRepeat(freq: freq, weekdays: const [6]),
          ),
        ),
        [ParseQuestionKind.unsupportedRepeat],
        reason: '$freq',
      );
    }
  });

  test('지우기·질문·그 밖의 의도는 항목을 보지 않는다', () {
    for (final intent in [
      ParseIntent.delete,
      ParseIntent.query,
      ParseIntent.other,
    ]) {
      expect(
        _kinds(intent, _event(date: DateTime(2026, 10, 1), weekday: 1)),
        isEmpty,
        reason: '$intent',
      );
    }
  });

  test('항목마다 순번을 담는다', () {
    final result = ParseResult(
      intent: ParseIntent.classException,
      items: [
        ParseItem(date: _tomorrow, weekday: _tomorrow.weekday),
        const ParseItem(),
      ],
    );
    expect(parseQuestions(result, now: _now), [
      const ParseQuestion(ParseQuestionKind.missingDate, itemIndex: 1),
    ]);
  });

  group('withAfternoonDefault', () {
    ParseItem only(ParseResult result) => result.items.single;

    test('오전·오후를 말하지 않은 1–7시를 오후로 고친다', () {
      final fixed = withAfternoonDefault(
        ParseResult(
          intent: ParseIntent.createEvent,
          items: [
            _event(timeExpression: '3시부터 5시까지', start: _hm(3), end: _hm(5)),
          ],
        ),
      );
      expect(only(fixed).startMin, _hm(15));
      expect(only(fixed).endMin, _hm(17));
    });

    test('경계: 1:00과 7:59는 고치고 0:59와 8:00은 두며, 마감 시각도 본다', () {
      final fixed = withAfternoonDefault(
        ParseResult(
          intent: ParseIntent.createTask,
          items: [
            _task(timeExpression: '1시', dueTime: _hm(1)),
            _task(timeExpression: '7시 59분', dueTime: _hm(7, 59)),
            _task(timeExpression: '0시 59분', dueTime: _hm(0, 59)),
            _task(timeExpression: '8시', dueTime: _hm(8)),
          ],
        ),
      );
      expect(fixed.items.map((item) => item.dueTimeMin), [
        _hm(13),
        _hm(19, 59),
        _hm(0, 59),
        _hm(8),
      ]);
    });

    test('오전·새벽을 말했거나 시각을 말하지 않았으면 그대로 둔다', () {
      for (final expression in ['새벽 3시', '아침 7시', '오전 6시', '3시간 뒤', null]) {
        final fixed = withAfternoonDefault(
          ParseResult(
            intent: ParseIntent.createEvent,
            items: [_event(timeExpression: expression, start: _hm(3))],
          ),
        );
        expect(only(fixed).startMin, _hm(3), reason: expression);
      }
    });

    test('규칙의 시각도 고치고 다른 값은 그대로 둔다', () {
      final fixed = withAfternoonDefault(
        const ParseResult(
          intent: ParseIntent.setRule,
          rules: [
            ParsedRule(
              kind: RuleKind.blackout,
              remove: false,
              startMin: 6 * 60,
              endMin: 7 * 60,
              timeExpression: '6시부터 7시까지',
              weekdays: [5],
            ),
          ],
        ),
      );
      final rule = fixed.rules.single;
      expect(rule.startMin, 18 * 60);
      expect(rule.endMin, 19 * 60);
      expect(rule.weekdays, [5]);
      expect(rule.kind, RuleKind.blackout);
    });
  });
}
