// 06 AI 비서 카드 만들기 테스트. docs/screens.md '06 AI 비서'(카드 1·2·7, 되묻기), docs/architecture.md
// 'POST /v1/parse'(날짜·요일 일치와 되묻기 판단은 앱이 함).
//
// 지금은 2026-11-19(목) 10:30이다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19, 10, 30);

DateTime _day(int month, int day) => DateTime(2026, month, day);

ParseResult _events(List<ParseItem> items) =>
    ParseResult(intent: ParseIntent.createEvent, items: items);

ParseItem _event({
  String? title = '회의',
  DateTime? date,
  int? weekday,
  String? dateExpression,
  String? timeExpression = '오후 3시',
  int? start = 15 * 60,
  int? end,
  ParseRepeat? repeat,
  FixedBlockKind? fixedKind,
}) => ParseItem(
  title: title,
  kind: ParseItemKind.event,
  category: ParseCategory.personal,
  date: date,
  weekday: weekday,
  dateExpression: dateExpression,
  timeExpression: timeExpression,
  startMin: start,
  endMin: end,
  repeat: repeat,
  fixedBlockKind: fixedKind,
);

ParseItem _task({
  String title = '과제',
  String? course,
  DateTime? due,
  int? dueTime,
  int? weekday,
  String? dateExpression,
  int? estimate,
}) => ParseItem(
  title: title,
  kind: ParseItemKind.task,
  category: course == null ? ParseCategory.personal : ParseCategory.course,
  course: course,
  due: due,
  dueTimeMin: dueTime,
  weekday: weekday,
  dateExpression: dateExpression,
  estimatedMinutes: estimate,
);

/// 카드 번호를 1부터 주는 [replyCards].
List<AssistantMessage> _reply(ParseResult result, {bool ruleMode = false}) {
  var id = 0;
  return replyCards(result, now: _now, ruleMode: ruleMode, nextId: () => ++id);
}

/// [card]의 [index]번째를 고른 뒤의 카드(번호는 100부터).
List<AssistantMessage> _pick(AssistantMessage card, int index) {
  var id = 99;
  return afterPick(card as AskCard, index, now: _now, nextId: () => ++id);
}

EventDraft _draftOf(AssistantMessage message) => (message as EventCard).draft;

void main() {
  group('새 일정', () {
    test('날짜·시각이 있으면 일정 카드이고, 끝이 없으면 한 시간(임시)이다', () {
      final cards = _reply(
        _events([_event(date: _day(11, 20), weekday: 5, dateExpression: '내일')]),
      );
      expect(cards, hasLength(1));
      final card = cards.single as EventCard;
      expect(card.id, 1);
      expect(card.status, CardStatus.pending);
      expect(card.draft.date, _day(11, 20));
      expect(card.draft.weekdays, isNull);
      expect(card.draft.startMin, 15 * 60);
      expect(card.draft.endMin, 16 * 60);
      expect(card.draft.startAt, DateTime(2026, 11, 20, 15));
      expect(card.draft.endAt, DateTime(2026, 11, 20, 16));
      expect(card.say, '11월 20일 (금) 15:00 회의로 정리했어요.');
    });

    test('끝이 시작보다 이르면 자정을 넘는 것으로 본다', () {
      final draft = _draftOf(
        _reply(
          _events([
            _event(
              date: _day(11, 20),
              timeExpression: '밤 10시부터 새벽 2시까지',
              start: 22 * 60,
              end: 2 * 60,
            ),
          ]),
        ).single,
      );
      expect(draft.endMin, 26 * 60);
      expect(draft.endAt, DateTime(2026, 11, 21, 2));
    });

    test('시각이 없으면 시간 미정 카드다', () {
      final card =
          _reply(
                _events([
                  _event(date: _day(11, 20), timeExpression: null, start: null),
                ]),
              ).single
              as EventCard;
      expect(card.draft.timeUnknown, isTrue);
      expect(card.draft.endMin, isNull);
      expect(card.draft.startAt, isNull);
      expect(card.say, '시간을 말하지 않아서 시간 미정으로 정리했어요. 시간을 고르거나 그대로 넣을 수 있어요.');
    });

    test('매주 반복이면 요일을 정렬해 반복 일정 카드로 만든다', () {
      final card =
          _reply(
                _events([
                  _event(
                    title: '알바',
                    timeExpression: '오후 2시부터 5시까지',
                    start: 14 * 60,
                    end: 17 * 60,
                    repeat: const ParseRepeat(
                      freq: ParseRepeatFreq.weekly,
                      weekdays: [7, 6, 7],
                    ),
                    fixedKind: FixedBlockKind.work,
                  ),
                ]),
              ).single
              as EventCard;
      expect(card.draft.repeating, isTrue);
      expect(card.draft.weekdays, [6, 7]);
      expect(card.draft.date, isNull);
      expect(card.draft.fixedKind, FixedBlockKind.work);
      expect(card.say, '주말마다 알바로 정리했어요. 맞으면 캘린더에 넣을게요.');
    });

    test('반복 일정에 요일이나 시각이 없으면 저장할 수 없어 안내한다', () {
      for (final item in [
        _event(
          repeat: const ParseRepeat(
            freq: ParseRepeatFreq.weekly,
            weekdays: [1],
          ),
          timeExpression: null,
          start: null,
        ),
        _event(
          repeat: const ParseRepeat(freq: ParseRepeatFreq.weekly, weekdays: []),
        ),
      ]) {
        final card = _reply(_events([item])).single as InfoCard;
        expect(card.kind, InfoKind.repeatIncomplete);
      }
    });

    test('매주가 아닌 반복은 안내한다', () {
      final card =
          _reply(
                _events([
                  _event(
                    repeat: const ParseRepeat(
                      freq: ParseRepeatFreq.biweekly,
                      weekdays: [2],
                    ),
                  ),
                ]),
              ).single
              as InfoCard;
      expect(card.kind, InfoKind.unsupportedRepeat);
    });

    test('일정이 둘 이상이면 첫 카드 위에 개수를 적는다', () {
      final cards = _reply(
        _events([
          _event(date: _day(11, 20)),
          _event(title: '스터디', date: _day(11, 21)),
        ]),
      );
      expect(cards.map((card) => card.id), [1, 2]);
      expect((cards[0] as EventCard).say, '일정 2개를 찾았어요. 하나씩 확인해 주세요.');
      expect((cards[1] as EventCard).say, '11월 21일 (토) 15:00 스터디로 정리했어요.');
    });

    test('제목이 비면 일정이다', () {
      expect(
        _draftOf(
          _reply(_events([_event(title: ' ', date: _day(11, 20))])).single,
        ).title,
        '일정',
      );
    });
  });

  group('되묻기', () {
    test('날짜가 없으면 오늘부터 닷새를 고르게 하고, 고르면 그날 일정이다', () {
      final ask = _reply(_events([_event(date: null)])).single as AskCard;
      expect(ask.topic, AskTopic.date);
      expect(ask.question, '「회의」 언제인가요?');
      expect(ask.sub, '날짜를 말하지 않았어요');
      expect(ask.options.map((option) => option.label), [
        '11월 19일 (목)',
        '11월 20일 (금)',
        '11월 21일 (토)',
        '11월 22일 (일)',
        '11월 23일 (월)',
      ]);
      expect(ask.options.map((option) => option.sub), [
        '오늘',
        '내일',
        '모레',
        '일요일',
        '월요일',
      ]);
      final next = _pick(ask, 1);
      expect(next.single.id, 100);
      expect(_draftOf(next.single).date, _day(11, 20));
    });

    test("'N일'만 말하면 그날이 오는 두 달을 고르게 한다", () {
      final ask =
          _reply(_events([_event(date: _day(11, 25), dateExpression: '25일')]))
                  .single
              as AskCard;
      expect(ask.topic, AskTopic.dayOnly);
      expect(ask.question, '25일이 언제인가요?');
      expect(ask.options.map((option) => option.label), [
        '11월 25일 (수)',
        '12월 25일 (금)',
      ]);
      // 고르면 날짜 표현으로 다시 묻지 않는다.
      expect(_draftOf(_pick(ask, 1).single).date, _day(12, 25));
    });

    test("'N일'이 이번 달에 지났거나 없는 달은 건너뛴다", () {
      final ask =
          _reply(_events([_event(date: _day(12, 31), dateExpression: '31일')]))
                  .single
              as AskCard;
      // 11월에는 31일이 없고, 12월 31일 다음은 2027년 1월 31일이다.
      expect(ask.options.map((option) => option.items.single.date), [
        _day(12, 31),
        DateTime(2027, 1, 31),
      ]);
    });

    test('주말이면 토·일과 이틀 모두를 고르게 하고, 이틀 모두면 카드 둘이다', () {
      final ask =
          _reply(_events([_event(date: _day(11, 21), dateExpression: '이번 주말')]))
                  .single
              as AskCard;
      expect(ask.topic, AskTopic.weekend);
      expect(ask.question, '이번 주말 언제인가요?');
      expect(ask.options.map((option) => option.label), [
        '11월 21일 (토)',
        '11월 22일 (일)',
        '토·일 이틀 모두',
      ]);
      expect(ask.options.last.sub, '11월 21일–22일');
      final both = _pick(ask, 2);
      expect(both.map(_draftOf).map((draft) => draft.date), [
        _day(11, 21),
        _day(11, 22),
      ]);
      expect((both.first as EventCard).say, '이틀 모두 넣을게요. 하나씩 확인해 주세요.');
    });

    test('다음 주말이면 질문이 다음 주말이다', () {
      final ask =
          _reply(_events([_event(date: _day(11, 28), dateExpression: '다음 주말')]))
                  .single
              as AskCard;
      expect(ask.question, '다음 주말 언제인가요?');
    });

    test('다음 주만 말하면 그 주의 요일을 고르게 한다', () {
      final ask =
          _reply(_events([_event(date: _day(11, 23), dateExpression: '다음 주')]))
                  .single
              as AskCard;
      expect(ask.topic, AskTopic.nextWeek);
      expect(ask.options, hasLength(7));
      expect(ask.options.first.label, '11월 23일 (월)');
      expect(_draftOf(_pick(ask, 2).single).date, _day(11, 25));
    });

    test('날짜와 요일이 어긋나면 어느 쪽인지 묻는다', () {
      final ask =
          _reply(
                _events([
                  _event(
                    date: _day(11, 27),
                    weekday: 4,
                    dateExpression: '27일 목요일',
                  ),
                ]),
              ).single
              as AskCard;
      // '27일'은 달이 없지만 날짜·요일을 먼저 묻는 차례가 아니라 'N일'이 먼저다.
      expect(ask.topic, AskTopic.dayOnly);

      final mismatch =
          _reply(
                _events([
                  _event(
                    date: _day(11, 27),
                    weekday: 4,
                    dateExpression: '11월 27일 목요일',
                  ),
                ]),
              ).single
              as AskCard;
      expect(mismatch.topic, AskTopic.weekdayMismatch);
      expect(mismatch.question, '11월 27일은 금요일이에요. 어느 날인가요?');
      expect(mismatch.options.map((option) => option.sub), ['날짜 기준', '목요일 기준']);
      expect(_draftOf(_pick(mismatch, 1).single).date, _day(11, 26));
    });

    test('8–11시에 오전·오후가 없으면 묻고, 고른 쪽으로 시작과 끝을 함께 옮긴다', () {
      final ask =
          _reply(
                _events([
                  _event(
                    date: _day(11, 20),
                    timeExpression: '9시부터 10시 반까지',
                    start: 9 * 60,
                    end: 10 * 60 + 30,
                  ),
                ]),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.meridiem);
      expect(ask.question, '9시가 오전인가요, 오후인가요?');
      expect(ask.sub, '「회의」 · 11월 20일 (금)');
      expect(ask.options.map((option) => option.label), ['오전 9시', '오후 9시']);
      expect(ask.options.map((option) => option.sub), [
        '09:00–10:30',
        '21:00–22:30',
      ]);
      final draft = _draftOf(_pick(ask, 1).single);
      expect((draft.startMin, draft.endMin), (21 * 60, 22 * 60 + 30));
    });

    test('오늘인데 오전이면 이미 끝난 시각이면 묻지 않고 오후로 본다', () {
      final draft = _draftOf(
        _reply(
          _events([
            _event(date: _day(11, 19), timeExpression: '8시', start: 8 * 60),
          ]),
        ).single,
      );
      expect(draft.startMin, 20 * 60);
      expect(draft.endMin, 21 * 60);
    });

    test('지난 날짜면 같은 요일·오늘·내일을 고르게 한다', () {
      final ask =
          _reply(_events([_event(date: _day(11, 17), weekday: 2)])).single
              as AskCard;
      expect(ask.topic, AskTopic.pastDate);
      expect(ask.question, '11월 17일은 이미 지났어요. 언제인가요?');
      expect(ask.options.map((option) => (option.label, option.sub)), [
        ('11월 24일 (화)', '같은 요일'),
        ('11월 19일 (목)', '오늘'),
        ('11월 20일 (금)', '내일'),
      ]);
      expect(_draftOf(_pick(ask, 0).single).date, _day(11, 24));
    });

    test('오늘 지난 시각이면 다음 주 같은 요일이나 그대로를 고르게 하고, 그대로면 다시 묻지 않는다', () {
      final ask =
          _reply(
                _events([
                  _event(
                    date: _day(11, 19),
                    timeExpression: '오전 9시',
                    start: 9 * 60,
                  ),
                ]),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.pastTime);
      expect(ask.question, '오늘 오전 9시는 이미 지났어요. 언제인가요?');
      expect(ask.sub, '지금은 오전 10시 30분이에요');
      expect(ask.options.map((option) => option.label), [
        '11월 26일 (목)',
        '오늘 그대로',
      ]);
      final kept = _draftOf(_pick(ask, 1).single);
      expect((kept.date, kept.startMin), (_day(11, 19), 9 * 60));
    });

    test('고른 날짜에 아직 물을 것이 남으면 이어서 묻는다', () {
      final ask =
          _reply(
                _events([
                  _event(date: null, timeExpression: '10시', start: 10 * 60),
                ]),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.date);
      final meridiem = _pick(ask, 1).single as AskCard;
      expect(meridiem.topic, AskTopic.meridiem);
      expect(meridiem.answered, contains(AskTopic.date));
      final draft = _draftOf(_pick(meridiem, 0).single);
      expect((draft.date, draft.startMin), (_day(11, 20), 10 * 60));
    });
  });

  group('새 할 일', () {
    test('과목·마감이 있으면 과목 할 일이고, 시각이 없으면 23:59로 본다', () {
      final card =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [
                    _task(
                      course: '데이터구조',
                      due: _day(11, 20),
                      weekday: 5,
                      dateExpression: '금요일까지',
                      estimate: 120,
                    ),
                  ],
                ),
              ).single
              as TaskCard;
      final draft = card.draft;
      expect(draft.courseName, '데이터구조');
      expect(draft.kind, TaskKind.assignment);
      expect(draft.dueAt, DateTime(2026, 11, 20, 23, 59));
      expect(draft.dueTimeUnknown, isTrue);
      expect(draft.saidEstimateMin, 120);
      expect(draft.estimateToStore, 120);
      expect(card.say, '11월 20일 (금) 23:59 마감인 할 일로 정리했어요.');
    });

    test('과목 할 일의 처음 종류는 제목을 보고 고르고, 없으면 과제다', () {
      expect(courseTaskKindOf('퀴즈 3'), TaskKind.quiz);
      expect(courseTaskKindOf('팀 프로젝트 발표'), TaskKind.team);
      expect(courseTaskKindOf('조별 보고서'), TaskKind.team);
      expect(courseTaskKindOf('중간고사 준비'), TaskKind.exam);
      expect(courseTaskKindOf('토론 글'), TaskKind.discussion);
      expect(courseTaskKindOf('레포트'), TaskKind.assignment);
      expect(courseTaskKinds, isNot(contains(TaskKind.personal)));
    });

    test('과목이 없거나 개인이면 개인 할 일이고, 0 이하 예상 시간은 버린다', () {
      final card =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [
                    ParseItem(
                      title: '세탁',
                      kind: ParseItemKind.task,
                      category: ParseCategory.personal,
                      course: '데이터구조',
                      due: _day(11, 20),
                      estimatedMinutes: 0,
                    ),
                  ],
                ),
              ).single
              as TaskCard;
      expect(card.draft.courseName, isNull);
      expect(card.draft.kind, TaskKind.personal);
      expect(card.draft.saidEstimateMin, isNull);
    });

    test('마감이 없으면 묻고, 마감 없음을 고르면 마감 없는 할 일이다', () {
      final ask =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [_task(title: '보고서')],
                ),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.taskDue);
      expect(ask.question, '「보고서」 마감이 언제인가요?');
      expect(ask.options, hasLength(6));
      expect(ask.options.last.label, '마감 없음');
      final card = _pick(ask, 5).single as TaskCard;
      expect(card.draft.dueAt, isNull);
      expect(card.say, '마감 없는 할 일로 정리했어요.');
      final dated = _pick(ask, 2).single as TaskCard;
      expect(dated.draft.dueDate, _day(11, 21));
    });

    test('오늘 지난 마감 시각이면 내일 같은 시각이나 그대로를 고르게 한다', () {
      final ask =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [_task(due: _day(11, 19), dueTime: 9 * 60 + 30)],
                ),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.pastTime);
      expect(ask.question, '오늘 오전 9시 30분은 이미 지났어요. 언제인가요?');
      expect(ask.options.map((option) => (option.label, option.sub)), [
        ('11월 20일 (금)', '내일 같은 시각'),
        ('오늘 그대로', '이미 지난 마감으로 넣어요'),
      ]);
      final card = _pick(ask, 0).single as TaskCard;
      expect(card.draft.dueAt, DateTime(2026, 11, 20, 9, 30));
    });

    test('마감 시각에 오전·오후가 없으면 묻고, 오늘 오전이 지났으면 오후로 본다', () {
      final ask =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [
                    ParseItem(
                      title: '과제',
                      kind: ParseItemKind.task,
                      category: ParseCategory.personal,
                      due: _day(11, 20),
                      dueTimeMin: 11 * 60,
                      timeExpression: '11시까지',
                    ),
                  ],
                ),
              ).single
              as AskCard;
      expect(ask.topic, AskTopic.meridiem);
      expect(ask.options.map((option) => option.sub), ['마감 11:00', '마감 23:00']);

      final today =
          _reply(
                ParseResult(
                  intent: ParseIntent.createTask,
                  items: [
                    ParseItem(
                      title: '과제',
                      kind: ParseItemKind.task,
                      category: ParseCategory.personal,
                      due: _day(11, 19),
                      dueTimeMin: 9 * 60,
                      timeExpression: '9시까지',
                    ),
                  ],
                ),
              ).single
              as TaskCard;
      expect(today.draft.dueAt, DateTime(2026, 11, 19, 21));
    });
  });

  group('그 밖의 응답', () {
    test('AI가 되물으면 그 질문을 안내 카드로 보이고, 질문이 비면 못 알아들은 것이다', () {
      final question =
          _reply(
                const ParseResult(
                  intent: ParseIntent.createEvent,
                  needsClarification: true,
                  clarification: ParseClarification(
                    field: ParseClarificationField.intent,
                    question: '두 가지를 한 번에 하기는 어려워요. 먼저 스터디를 넣을까요?',
                  ),
                ),
              ).single
              as InfoCard;
      expect(question.kind, InfoKind.serverQuestion);
      expect(question.question, '두 가지를 한 번에 하기는 어려워요. 먼저 스터디를 넣을까요?');

      final empty =
          _reply(
                const ParseResult(
                  intent: ParseIntent.delete,
                  needsClarification: true,
                  clarification: ParseClarification(
                    field: ParseClarificationField.target,
                    question: ' ',
                  ),
                ),
              ).single
              as InfoCard;
      expect(empty.kind, InfoKind.notUnderstood);
    });

    test('일정을 찾지 못하면 못 알아들은 것이고, 아직 처리하지 않는 의도는 안내한다', () {
      expect(
        (_reply(const ParseResult(intent: ParseIntent.other)).single
                as InfoCard)
            .kind,
        InfoKind.notUnderstood,
      );
      expect(
        (_reply(const ParseResult(intent: ParseIntent.createEvent)).single
                as InfoCard)
            .kind,
        InfoKind.notUnderstood,
      );
      for (final intent in [
        ParseIntent.update,
        ParseIntent.delete,
        ParseIntent.query,
        ParseIntent.classException,
        ParseIntent.setRule,
      ]) {
        expect(
          (_reply(ParseResult(intent: intent)).single as InfoCard).kind,
          InfoKind.notYet,
          reason: '$intent',
        );
      }
    });

    test('규칙 모드에서는 일정·할 일·바꾸기를 받지 않는다(질문·수업 변경·규칙은 받음)', () {
      for (final intent in [
        ParseIntent.createEvent,
        ParseIntent.createTask,
        ParseIntent.update,
        ParseIntent.delete,
        ParseIntent.other,
      ]) {
        expect(
          (_reply(ParseResult(intent: intent), ruleMode: true).single
                  as InfoCard)
              .kind,
          InfoKind.ruleOnly,
          reason: '$intent',
        );
      }
      for (final intent in [
        ParseIntent.query,
        ParseIntent.classException,
        ParseIntent.setRule,
      ]) {
        expect(
          (_reply(ParseResult(intent: intent), ruleMode: true).single
                  as InfoCard)
              .kind,
          isNot(InfoKind.ruleOnly),
          reason: '$intent',
        );
      }
    });
  });
}
