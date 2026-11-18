// 데모 모드의 06 AI 비서 응답 테스트. docs/architecture.md '데모 모드'(미리 적은 응답 중 가장 비슷한 것).

import 'package:cnu_ai_assistant/data/demo/demo_parse.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-19(목) 10:30.
final _now = DateTime(2026, 11, 19, 10, 30);

ParseResult _reply(String text, {List<String> courses = const ['자료구조']}) =>
    demoParseResult(text, now: _now, courseNames: courses);

void main() {
  test('예시 문장 그대로면 그 응답이고, 날짜는 보내는 때를 기준으로 만든다', () {
    final club = _reply('목요일 7시 동아리');
    expect(club.intent, ParseIntent.createEvent);
    final item = club.items.single;
    expect(item.title, '동아리');
    // 오늘이 목요일이면 오늘이다.
    expect(item.date, DateTime(2026, 11, 19));
    expect(item.weekday, DateTime.thursday);
    // 오전·오후를 말하지 않은 7시라 화면이 오후로 고친다(실제 응답과 같은 꼴).
    expect((item.startMin, item.timeExpression), (7 * 60, '7시'));

    final work = _reply('주말마다 2시부터 5시까지 알바 있어').items.single;
    expect(work.repeat?.weekdays, [DateTime.saturday, DateTime.sunday]);
    expect(work.fixedBlockKind, FixedBlockKind.work);
  });

  test('가장 비슷한 예시의 응답이다', () {
    final study = _reply('내일 3시 스터디 있어');
    expect(study.items.single.title, '스터디');
    expect(study.items.single.date, DateTime(2026, 11, 20));

    final task = _reply('운영체제 과제 금요일까지야');
    expect(task.intent, ParseIntent.createTask);
    expect(task.items.single.due, DateTime(2026, 11, 20));
    expect(task.items.single.course, '자료구조');
    expect(task.items.single.category, ParseCategory.course);

    final report = _reply('보고서 다음 주 월요일');
    expect(report.items.single.due, DateTime(2026, 11, 23));
    expect(report.items.single.estimatedMinutes, 120);
  });

  test('과목이 없으면 과목 할 일 예시는 개인 할 일이다', () {
    final task = _reply('과제 금요일까지 내야 해', courses: const []);
    expect(task.items.single.course, isNull);
    expect(task.items.single.category, ParseCategory.personal);
  });

  test('하나도 겹치지 않으면 알아듣지 못한 것이다', () {
    expect(_reply('ㅎ').intent, ParseIntent.other);
    expect(_reply('').intent, ParseIntent.other);
    expect(_reply('zzz qqq').intent, ParseIntent.other);
  });

  test('예시는 모두 응답을 만든다', () {
    for (final example in demoExamples) {
      final reply = _reply(example.sentence);
      expect(reply.intent, isNot(ParseIntent.other), reason: example.sentence);
      expect(reply.items, isNotEmpty, reason: example.sentence);
    }
  });
}
