// 내 규칙의 이름·짧은 값·문장 테스트. docs/screens.md '12 내 규칙'·'06 AI 비서'.

import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ruleKindName', () {
    test('12 내 규칙 표의 이름이고 종류마다 다르다', () {
      final names = RuleKind.values.map(ruleKindName).toList();
      expect(names.toSet(), hasLength(RuleKind.values.length));
      expect(ruleKindName(RuleKind.workWindow), '공부 가능한 시간대');
      expect(ruleKindName(RuleKind.maxBlock), '한 번에 할 최대 시간');
    });
  });

  group('ruleShortValue', () {
    test('새 폼 값은 12 내 규칙 표의 꼴이다', () {
      expect(
        {
          for (final kind in RuleKind.values)
            kind: ruleShortValue(kind, ruleFormDefault(kind)),
        },
        {
          RuleKind.travel: '30분 · 매 수업 앞뒤',
          RuleKind.classBuffer: '15분',
          RuleKind.workWindow: '09:00–23:00',
          RuleKind.blackout: '21:00–23:00',
          RuleKind.preferred: '20:00–22:00',
          RuleKind.maxBlock: '1시간 30분',
          RuleKind.dailyCap: '4시간',
          RuleKind.meal: '17:30–19:30 · 40분',
          RuleKind.estimate: '과제 · 1시간 30분',
          RuleKind.notify: '08:00',
        },
      );
    });

    test('요일을 고르면 요일 순서로 앞에 붙이고, 자정을 넘는 끝은 실제 시각, 자정 끝은 24:00이다', () {
      expect(
        ruleShortValue(
          RuleKind.blackout,
          const RuleParams(startMin: 1140, endMin: 1260),
          weekdays: [3, 1],
        ),
        '월·수 · 19:00–21:00',
      );
      expect(
        ruleShortValue(
          RuleKind.workWindow,
          const RuleParams(startMin: 1320, endMin: 1560),
        ),
        '22:00–02:00',
      );
      expect(
        ruleShortValue(
          RuleKind.blackout,
          const RuleParams(startMin: 1380, endMin: 1440),
        ),
        '23:00–24:00',
      );
      expect(
        ruleShortValue(
          RuleKind.travel,
          const RuleParams(minutes: 60, position: TravelPosition.dayEdges),
        ),
        '1시간 · 첫 수업 전·마지막 수업 뒤',
      );
    });

    test('예상 시간은 과목 이름과 종류를 앞에 쓴다', () {
      expect(
        ruleShortValue(
          RuleKind.estimate,
          const RuleParams(
            courseId: 7,
            taskKind: TaskKind.assignment,
            minutes: 180,
          ),
          courseName: '데이터구조',
        ),
        '데이터구조 과제 · 3시간',
      );
      expect(
        ruleShortValue(
          RuleKind.estimate,
          const RuleParams(courseId: 7, minutes: 180),
          courseName: '데이터구조',
        ),
        '데이터구조 · 3시간',
      );
      expect(
        ruleShortValue(
          RuleKind.estimate,
          const RuleParams(courseId: 7, minutes: 180),
        ),
        '과목 · 3시간',
      );
    });

    test('필요한 값이 없거나 읽지 못한 값이면 null이다', () {
      expect(
        ruleShortValue(RuleKind.travel, const RuleParams(minutes: 30)),
        isNull,
      );
      expect(
        ruleShortValue(RuleKind.notify, const RuleParams(notifyCap: 3)),
        isNull,
      );
      expect(
        ruleShortValue(
          RuleKind.classBuffer,
          const UnreadableRuleParams('{"minutes":"60"}'),
        ),
        isNull,
      );
    });
  });

  group('rulePreviewSentence', () {
    String? sentence(
      RuleKind kind,
      RuleParams params, {
      List<int>? weekdays,
      String? courseName,
    }) => rulePreviewSentence(
      kind,
      params,
      weekdays: weekdays,
      courseName: courseName,
    );

    test('종류마다 규칙 문장을 쓴다', () {
      expect(
        sentence(
          RuleKind.travel,
          const RuleParams(minutes: 40, position: TravelPosition.everyClass),
        ),
        '대면 수업마다 앞뒤로 40분씩 비워요',
      );
      expect(
        sentence(
          RuleKind.travel,
          const RuleParams(minutes: 60, position: TravelPosition.dayEdges),
          weekdays: [1, 3],
        ),
        '월·수요일에는 하루 첫 대면 수업 전과 마지막 대면 수업 뒤에 1시간씩 비워요',
      );
      expect(
        sentence(RuleKind.classBuffer, const RuleParams(minutes: 15)),
        '수업마다 앞뒤로 15분씩 비워요. 실시간 온라인 수업은 비우지 않아요',
      );
      expect(
        sentence(
          RuleKind.workWindow,
          const RuleParams(startMin: 480, endMin: 1380),
        ),
        '오전 8시부터 오후 11시까지만 할 일을 놓아요',
      );
      expect(
        sentence(
          RuleKind.blackout,
          const RuleParams(startMin: 1260, endMin: 1380),
          weekdays: [2],
        ),
        '화요일에는 오후 9시부터 오후 11시까지는 할 일을 놓지 않아요',
      );
      expect(
        sentence(
          RuleKind.preferred,
          const RuleParams(startMin: 1200, endMin: 1320),
        ),
        '오후 8시부터 오후 10시 사이에 되도록 할 일을 놓아요',
      );
      expect(
        sentence(RuleKind.maxBlock, const RuleParams(minutes: 90)),
        '할 일은 한 번에 1시간 30분까지만 놓아요',
      );
      expect(
        sentence(RuleKind.dailyCap, const RuleParams(minutes: 240)),
        '하루에 4시간까지만 할 일을 놓아요',
      );
      expect(
        sentence(RuleKind.notify, const RuleParams(briefingMin: 450)),
        '아침 브리핑을 오전 7시 30분에 보여 줘요',
      );
    });

    test("자정을 넘는 끝은 '다음 날'을 붙이고, 자정 시각은 '밤 12시'다", () {
      expect(
        sentence(
          RuleKind.workWindow,
          const RuleParams(startMin: 1200, endMin: 1500),
        ),
        '오후 8시부터 다음 날 오전 1시까지만 할 일을 놓아요',
      );
      expect(
        sentence(
          RuleKind.blackout,
          const RuleParams(startMin: 1380, endMin: 1440),
        ),
        '오후 11시부터 밤 12시까지는 할 일을 놓지 않아요',
      );
      expect(
        sentence(
          RuleKind.workWindow,
          const RuleParams(startMin: 0, endMin: 180),
        ),
        '밤 12시부터 오전 3시까지만 할 일을 놓아요',
      );
    });

    test('식사는 시간대 전부·일부·0분을 나눠 쓴다', () {
      expect(
        sentence(
          RuleKind.meal,
          const RuleParams(startMin: 1050, endMin: 1170, minutes: 40),
        ),
        '오후 5시 30분부터 오후 7시 30분 사이에 식사 시간 40분을 비워요',
      );
      expect(
        sentence(
          RuleKind.meal,
          const RuleParams(startMin: 720, endMin: 780, minutes: 60),
        ),
        '오후 12시부터 오후 1시까지 식사 시간으로 비워요',
      );
      expect(
        sentence(
          RuleKind.meal,
          const RuleParams(startMin: 690, endMin: 810, minutes: 0),
        ),
        '오전 11시 30분부터 오후 1시 30분 사이에는 식사 시간을 비우지 않아요',
      );
    });

    test('예상 시간은 과목·종류에 맞는 조사를 붙이고, 영문·로마 숫자·괄호 과목명도 받침을 본다', () {
      String estimate(String? course, TaskKind? kind, int minutes) => sentence(
        RuleKind.estimate,
        RuleParams(
          courseId: course == null ? null : 7,
          taskKind: kind,
          minutes: minutes,
        ),
        courseName: course,
      )!;
      expect(
        estimate('데이터구조', TaskKind.assignment, 180),
        '데이터구조 과제는 보통 3시간으로 잡아요',
      );
      expect(estimate(null, TaskKind.exam, 300), '시험은 보통 5시간으로 잡아요');
      expect(estimate(null, TaskKind.quiz, 30), '퀴즈는 보통 30분으로 잡아요');
      expect(estimate('Programming', null, 120), 'Programming은 보통 2시간으로 잡아요');
      expect(estimate('Docker', null, 45), 'Docker는 보통 45분으로 잡아요');
      expect(estimate('미적분학I', null, 90), '미적분학I은 보통 1시간 30분으로 잡아요');
      expect(estimate('공학수학(2)', null, 90), '공학수학(2)은 보통 1시간 30분으로 잡아요');
      expect(estimate('HTML', null, 60), 'HTML은 보통 1시간으로 잡아요');
    });

    test('필요한 값이 없거나 읽지 못한 값이면 null이다', () {
      expect(sentence(RuleKind.meal, const RuleParams(minutes: 40)), isNull);
      expect(
        sentence(RuleKind.notify, const UnreadableRuleParams('{}')),
        isNull,
      );
    });
  });

  group('ruleChangeSentence·ruleTurnOffSentence', () {
    test('짧은 값으로 고치기 전과 뒤를 견주고, 같으면 null이다', () {
      expect(
        ruleChangeSentence(
          RuleKind.classBuffer,
          before: const RuleParams(minutes: 10),
          after: const RuleParams(minutes: 15),
        ),
        '수업 앞뒤 여유를 10분에서 15분으로 바꿔요',
      );
      expect(
        ruleChangeSentence(
          RuleKind.workWindow,
          before: const RuleParams(startMin: 480, endMin: 1380),
          after: const RuleParams(startMin: 540, endMin: 1380),
        ),
        '공부 가능한 시간대를 08:00–23:00에서 09:00–23:00으로 바꿔요',
      );
      expect(
        ruleChangeSentence(
          RuleKind.notify,
          before: const RuleParams(briefingMin: 480),
          after: const RuleParams(briefingMin: 450),
        ),
        '알림을 08:00에서 07:30으로 바꿔요',
      );
      expect(
        ruleChangeSentence(
          RuleKind.classBuffer,
          before: const RuleParams(minutes: 10),
          after: const RuleParams(minutes: 10),
        ),
        isNull,
      );
    });

    test('함께 끄는 이전 규칙 수를 알리고, 없으면 null이다', () {
      expect(ruleTurnOffSentence(1), '같은 자리의 이전 규칙 1개는 꺼요');
      expect(ruleTurnOffSentence(0), isNull);
    });
  });

  group('ruleProposalQuestion', () {
    final current = PlannerConfig.from(const []);

    test('제안한 공부 시간대와 식사 시간을 확인하는 문장이다', () {
      expect(
        ruleProposalQuestion(
          RuleKind.workWindow,
          completeRule(
            RuleKind.workWindow,
            const RuleParams(endMin: 1380),
            current: current,
          ),
        ),
        '오전 8시부터 오후 11시까지만 할 일을 놓을까요?',
      );
      expect(
        ruleProposalQuestion(
          RuleKind.workWindow,
          completeRule(
            RuleKind.workWindow,
            const RuleParams(endMin: 1380),
            current: current,
            weekdays: [1],
          ),
          weekdays: [1],
        ),
        '월요일에는 오전 8시부터 오후 11시까지만 할 일을 놓을까요?',
      );
      expect(
        ruleProposalQuestion(
          RuleKind.meal,
          completeRule(
            RuleKind.meal,
            const RuleParams(startMin: 720, endMin: 780),
            current: current,
          ),
        ),
        '오후 12시부터 오후 1시까지 모두 식사 시간으로 비울까요?',
      );
    });

    test('제안한 값이 없으면 null이다', () {
      expect(
        ruleProposalQuestion(
          RuleKind.travel,
          completeRule(
            RuleKind.travel,
            const RuleParams(minutes: 40),
            current: current,
          ),
        ),
        isNull,
      );
    });
  });

  group('ruleIssueQuestion', () {
    String ask(RuleKind kind, String field, RuleIssueKind issue) =>
        ruleIssueQuestion(kind, RuleIssue(field, issue));

    test('빈 값·범위·짝·종류에 맞지 않는 값을 되묻는다', () {
      expect(
        ask(RuleKind.travel, 'position', RuleIssueKind.missing),
        '매 수업 앞뒤인가요, 하루 첫 수업 전과 마지막 수업 뒤인가요?',
      );
      expect(
        ask(RuleKind.estimate, 'minutes', RuleIssueKind.missing),
        '보통 얼마나 걸리나요?',
      );
      expect(
        ask(RuleKind.blackout, 'startMin', RuleIssueKind.missing),
        '몇 시부터 몇 시까지 비울까요?',
      );
      expect(
        ask(RuleKind.estimate, 'courseId|taskKind', RuleIssueKind.missingOneOf),
        '어느 과목이나 종류의 할 일인가요?',
      );
      expect(
        ask(
          RuleKind.notify,
          'briefingMin|notifyCap|quietStartMin|quietEndMin',
          RuleIssueKind.missingOneOf,
        ),
        '아침 브리핑을 몇 시에 받을까요?',
      );
      expect(
        ask(RuleKind.meal, 'weekdays', RuleIssueKind.notAllowed),
        '식사는 요일을 나눠 정할 수 없어요',
      );
      expect(
        ask(RuleKind.estimate, 'taskKind', RuleIssueKind.notAllowed),
        '영상과 자료에는 예상 시간을 정할 수 없어요',
      );
      expect(
        ask(RuleKind.estimate, 'courseId', RuleIssueKind.notAllowed),
        '개인 할 일에는 과목을 정할 수 없어요',
      );
      expect(
        ask(RuleKind.estimate, 'minutes', RuleIssueKind.outOfRange),
        '10분부터 12시간 사이로 정해 주세요',
      );
      expect(
        ask(RuleKind.meal, 'minutes', RuleIssueKind.outOfRange),
        '식사 시간은 0분부터 4시간 사이로, 시간대보다 길지 않게 정해 주세요',
      );
      expect(
        ask(RuleKind.notify, 'briefingMin', RuleIssueKind.outOfRange),
        '아침 브리핑은 오전 6시부터 오후 12시 사이, 30분 단위로 정해 주세요',
      );
      expect(
        ask(RuleKind.workWindow, 'endMin', RuleIssueKind.badOrder),
        '끝 시각이 시작 시각과 같거나 하루를 넘어요. 몇 시부터 몇 시까지 공부할 수 있나요?',
      );
      expect(
        ask(RuleKind.travel, 'params', RuleIssueKind.unreadable),
        '저장된 값을 읽을 수 없는 규칙이에요. 지우고 다시 정해 주세요',
      );
    });

    test('값 검사가 내는 이유마다 빈 문장이 아닌 되묻기가 있다', () {
      final bad = <(RuleKind, RuleParams, List<int>?)>[
        for (final kind in RuleKind.values) (kind, const RuleParams(), null),
        (
          RuleKind.meal,
          const RuleParams(startMin: 720, endMin: 780, minutes: 300),
          [1],
        ),
        (
          RuleKind.workWindow,
          const RuleParams(startMin: 600, endMin: 600),
          [0],
        ),
        (
          RuleKind.estimate,
          const RuleParams(taskKind: TaskKind.video, minutes: 5),
          null,
        ),
        (
          RuleKind.notify,
          const RuleParams(briefingMin: 1000, notifyCap: 99),
          null,
        ),
      ];
      for (final (kind, params, weekdays) in bad) {
        for (final issue in validateRule(kind, params, weekdays: weekdays)) {
          expect(
            ruleIssueQuestion(kind, issue),
            isNotEmpty,
            reason: '$kind $issue',
          );
        }
      }
    });
  });
}
