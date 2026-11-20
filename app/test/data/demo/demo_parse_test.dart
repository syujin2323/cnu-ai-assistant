// 데모 모드의 06 AI 비서 응답 테스트. docs/architecture.md '데모 모드'(폰에서 문장의 날짜·시각·제목을 직접 읽음).

import 'package:cnu_ai_assistant/data/demo/demo_parse.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-19(목) 10:30.
final _now = DateTime(2026, 11, 19, 10, 30);

ParseResult _reply(String text, {List<String> courses = const ['자료구조']}) =>
    demoParseResult(text, now: _now, courseNames: courses);

void main() {
  test('일정: 날짜·시각·제목을 읽는다', () {
    final club = _reply('목요일 7시 동아리');
    expect(club.intent, ParseIntent.createEvent);
    final item = club.items.single;
    expect(item.title, '동아리');
    // 오늘이 목요일이면 오늘이다.
    expect(item.date, DateTime(2026, 11, 19));
    expect(item.weekday, DateTime.thursday);
    // 오전·오후를 말하지 않은 7시라 화면이 오후로 고친다(실제 응답과 같은 꼴).
    expect((item.startMin, item.timeExpression), (7 * 60, '7시'));

    final meeting = _reply('내일 2시에 팀 회의').items.single;
    expect(meeting.title, '팀 회의');
    expect(meeting.date, DateTime(2026, 11, 20));
    expect(meeting.startMin, 120);

    final dentist = _reply('다음 주 화요일 저녁 6시 반 치과').items.single;
    expect(dentist.title, '치과');
    expect(dentist.date, DateTime(2026, 11, 24));
    expect(
      (dentist.startMin, dentist.timeExpression),
      (18 * 60 + 30, '저녁 6시 반'),
    );

    final study = _reply('내일 오후 3시 도서관에서 스터디, 노트북 챙겨야 해').items.single;
    expect(study.title, '스터디');
    expect((study.place, study.prep), ('도서관', '노트북'));
    expect(study.startMin, 15 * 60);

    final ranged = _reply('12월 3일 오후 2시부터 4시까지 발표 연습').items.single;
    expect(ranged.kind, ParseItemKind.event);
    expect(ranged.title, '발표 연습');
    expect(ranged.date, DateTime(2026, 12, 3));
    expect((ranged.startMin, ranged.endMin), (14 * 60, 16 * 60));

    // 날짜 없이 시각만 말하면 오늘이다.
    expect(_reply('8시 저녁 약속').items.single.date, DateTime(2026, 11, 19));
  });

  test('반복 일정: 요일과 시간대를 읽는다', () {
    final work = _reply('주말마다 2시부터 5시까지 알바 있어').items.single;
    expect(work.title, '알바');
    expect(work.repeat?.weekdays, [DateTime.saturday, DateTime.sunday]);
    expect((work.startMin, work.endMin), (120, 300));
    expect(work.fixedBlockKind, FixedBlockKind.work);

    final gym = _reply('매주 화요일 저녁 7시부터 8시까지 헬스').items.single;
    expect(gym.title, '헬스');
    expect(gym.repeat?.weekdays, [DateTime.tuesday]);
    expect(gym.fixedBlockKind, FixedBlockKind.exercise);
  });

  test('할 일: 마감·과목·걸리는 시간을 읽는다', () {
    final task = _reply('자료구조 과제 금요일까지 내야 해');
    expect(task.intent, ParseIntent.createTask);
    final item = task.items.single;
    expect(item.title, '과제');
    expect(item.due, DateTime(2026, 11, 20));
    expect((item.course, item.category), ('자료구조', ParseCategory.course));

    final report = _reply('보고서 다음 주 월요일까지, 두 시간쯤 걸릴 듯').items.single;
    expect(report.title, '보고서');
    expect(report.due, DateTime(2026, 11, 23));
    expect(report.estimatedMinutes, 120);
    expect(report.category, ParseCategory.personal);

    final timed = _reply('일요일 밤 11시까지 독후감 제출').items.single;
    expect(timed.kind, ParseItemKind.task);
    expect(timed.title, '독후감 제출');
    expect((timed.due, timed.dueTimeMin), (DateTime(2026, 11, 22), 23 * 60));
  });

  test('빠진 값은 되묻는다', () {
    final noTime = _reply('내일 팀 회의');
    expect(noTime.needsClarification, isTrue);
    expect(noTime.clarification?.field, ParseClarificationField.time);
    // 답을 이어 붙이면 읽는다.
    expect(_reply('내일 팀 회의 3시').items.single.startMin, 180);

    final noDue = _reply('보고서 써야 해');
    expect(noDue.clarification?.field, ParseClarificationField.date);
    expect(_reply('내일 3시').clarification?.field, ParseClarificationField.title);
  });

  test('규칙을 읽는다', () {
    ParsedRule rule(String text) {
      final reply = _reply(text);
      expect(reply.intent, ParseIntent.setRule, reason: text);
      return reply.rules.single;
    }

    expect(
      (rule('하루 공부는 4시간까지만').kind, rule('하루 공부는 4시간까지만').minutes),
      (RuleKind.dailyCap, 240),
    );
    expect(
      (rule('한 번에 1시간 반까지만').kind, rule('한 번에 1시간 반까지만').minutes),
      (RuleKind.maxBlock, 90),
    );
    expect(rule('수업 앞뒤 여유 15분').minutes, 15);
    final night = rule('밤 11시 이후엔 공부 안 할래');
    expect(
      (night.kind, night.startMin, night.endMin),
      (RuleKind.workWindow, null, 23 * 60),
    );
    final lunch = rule('점심은 12시부터 1시 사이에 먹어');
    expect(lunch.kind, RuleKind.meal);
    final off = rule('화요일 저녁 7시부터 9시는 비워 줘');
    expect(
      (off.kind, off.startMin, off.endMin),
      (RuleKind.blackout, 19 * 60, 21 * 60),
    );
    expect(off.weekdays, [DateTime.tuesday]);
  });

  test('질문을 읽는다', () {
    expect(_reply('오늘 일정 알려줘').queryType, ParseQueryType.todayPlan);
    expect(_reply('이번 주 마감 뭐 있어?').queryType, ParseQueryType.deadlinesThisWeek);
    expect(_reply('내일 빈 시간 언제야').queryType, ParseQueryType.freeTime);
  });

  test('읽지 못하는 말은 알아듣지 못한 것이다', () {
    for (final text in ['ㅎ', '', 'zzz qqq', '안녕', '내일 회의 4시로 바꿔 줘']) {
      expect(_reply(text).intent, ParseIntent.other, reason: text);
    }
  });

  test('본보기 문장은 모두 읽는다', () {
    for (final sentence in demoExampleSentences) {
      final reply = _reply(sentence);
      expect(reply.intent, isNot(ParseIntent.other), reason: sentence);
      expect(reply.needsClarification, isFalse, reason: sentence);
    }
  });
}
