// 규칙 모델 테스트. docs/architecture.md '내 규칙'.
//
// 하나만 두는 종류를 저장할 때 쓰는 합치기([RuleParams.mergedWith])와, 폼이 쓸 고친 사본(copyWith)·값
// 비교를 본다.

import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = RuleParams(
    minutes: 1,
    position: TravelPosition.dayEdges,
    startMin: 2,
    endMin: 3,
    courseId: 4,
    taskKind: TaskKind.quiz,
    briefingMin: 5,
    notifyCap: 6,
    quietStartMin: 7,
    quietEndMin: 8,
  );

  group('RuleParams', () {
    test('값이 모두 같을 때만 같다', () {
      expect(full, full.copyWith());
      expect(full.hashCode, full.copyWith().hashCode);
      for (final other in [
        full.copyWith(minutes: 9),
        full.copyWith(position: TravelPosition.everyClass),
        full.copyWith(startMin: 9),
        full.copyWith(endMin: 9),
        full.copyWith(courseId: 9),
        full.copyWith(taskKind: TaskKind.exam),
        full.copyWith(briefingMin: 9),
        full.copyWith(notifyCap: 9),
        full.copyWith(quietStartMin: 9),
        full.copyWith(quietEndMin: 9),
      ]) {
        expect(full, isNot(other), reason: '$other');
      }
    });

    test('copyWith는 주지 않은 값을 두고, null을 주면 그 값을 뺀다', () {
      final changed = full.copyWith(minutes: 30, briefingMin: null);
      expect(changed.minutes, 30);
      expect(changed.briefingMin, isNull);
      expect(changed.copyWith(minutes: full.minutes, briefingMin: 5), full);

      const travel = RuleParams(minutes: 40, position: TravelPosition.dayEdges);
      expect(travel.copyWith(position: null), const RuleParams(minutes: 40));
      expect(
        travel.copyWith(
          minutes: null,
          position: null,
          startMin: 1,
          endMin: 2,
          courseId: 3,
          taskKind: TaskKind.team,
          notifyCap: 4,
          quietStartMin: 5,
          quietEndMin: 6,
        ),
        const RuleParams(
          startMin: 1,
          endMin: 2,
          courseId: 3,
          taskKind: TaskKind.team,
          notifyCap: 4,
          quietStartMin: 5,
          quietEndMin: 6,
        ),
      );
    });

    test('mergedWith는 들어온 값으로 덮고 들어온 값이 null이면 기존 값을 둔다', () {
      const current = RuleParams(briefingMin: 480, notifyCap: 3);
      expect(
        current.mergedWith(const RuleParams(briefingMin: 540)),
        const RuleParams(briefingMin: 540, notifyCap: 3),
      );
      expect(current.mergedWith(const RuleParams()), current);
      expect(const RuleParams().mergedWith(full), full);
      expect(full.mergedWith(const RuleParams()), full);
      // 값마다 들어온 쪽이 이긴다.
      final other = full.copyWith(
        minutes: 11,
        position: TravelPosition.everyClass,
        startMin: 12,
        endMin: 13,
        courseId: 14,
        taskKind: TaskKind.exam,
        briefingMin: 15,
        notifyCap: 16,
        quietStartMin: 17,
        quietEndMin: 18,
      );
      expect(full.mergedWith(other), other);
    });
  });

  group('저장된 JSON 읽기', () {
    // docs/decisions.md 2026-11-14 '모르는 값이 든 행은 안전한 열만 대체값으로 읽는다'. fromJson은 형이 틀리거나
    // 모르는 열거값이면 FormatException을 내고, 변환기가 그 행을 UnreadableRuleParams로 읽는다.
    test('모르는 키는 무시한다', () {
      expect(
        RuleParams.fromJson(const {'minutes': 5, 'unknownKey': true}),
        const RuleParams(minutes: 5),
      );
    });

    test('형이 틀리거나 모르는 열거값이면 FormatException이다', () {
      for (final json in const <Map<String, Object?>>[
        {'minutes': 60.0},
        {'minutes': '60'},
        {'position': 'both'},
        {'taskKind': 'lecture'},
      ]) {
        expect(
          () => RuleParams.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });

  group('UnreadableRuleParams', () {
    test('저장된 문자열이 같을 때만 같고, 값이 빈 규칙 값과도 다르다', () {
      expect(
        const UnreadableRuleParams('{"minutes":"60"}'),
        const UnreadableRuleParams('{"minutes":"60"}'),
      );
      expect(
        const UnreadableRuleParams('{"minutes":"60"}').hashCode,
        const UnreadableRuleParams('{"minutes":"60"}').hashCode,
      );
      expect(
        const UnreadableRuleParams('{"minutes":"60"}'),
        isNot(const UnreadableRuleParams('{"minutes":"61"}')),
      );
      expect(const UnreadableRuleParams('{}'), isNot(const RuleParams()));
      expect(const RuleParams(), isNot(const UnreadableRuleParams('{}')));
    });

    test('저장된 값은 문자열로 남기지 않는다', () {
      const params = UnreadableRuleParams('{"minutes":"60"}');
      expect(params.toString(), 'UnreadableRuleParams()');
      expect(params.toJson(), isEmpty);
    });

    test('합치면 들어온 값만 남은 보통 규칙 값이 된다', () {
      final merged = const UnreadableRuleParams('{"briefingMin":"x"}')
          .mergedWith(const RuleParams(briefingMin: 450));
      expect(merged, const RuleParams(briefingMin: 450));
      expect(merged, isNot(isA<UnreadableRuleParams>()));
    });
  });

  group('Rule', () {
    test('값을 읽지 못한 규칙인지 안다', () {
      Rule ruleWith(RuleParams params) => Rule(
        id: 1,
        kind: RuleKind.travel,
        params: params,
        active: true,
        source: EntrySource.manual,
        createdAt: DateTime(2026, 11, 14),
        updatedAt: DateTime(2026, 11, 14),
      );
      expect(ruleWith(const UnreadableRuleParams('x')).isUnreadable, isTrue);
      expect(
        ruleWith(
          const RuleParams(minutes: 30, position: TravelPosition.dayEdges),
        ).isUnreadable,
        isFalse,
      );
    });

    final at = DateTime(2026, 11, 13, 9);
    final rule = Rule(
      id: 1,
      kind: RuleKind.travel,
      params: const RuleParams(minutes: 40, position: TravelPosition.dayEdges),
      weekdays: const [1, 3],
      active: true,
      source: EntrySource.ai,
      sentence: '월수는 통학 40분',
      createdAt: at,
      updatedAt: at,
    );

    test('copyWith는 주지 않은 값을 두고, 요일·문장에 null을 주면 비운다', () {
      final later = at.add(const Duration(minutes: 5));
      final changed = rule.copyWith(
        active: false,
        updatedAt: later,
        weekdays: null,
        sentence: null,
      );
      expect(changed.id, rule.id);
      expect(changed.kind, rule.kind);
      expect(changed.params, rule.params);
      expect(changed.weekdays, isNull);
      expect(changed.active, isFalse);
      expect(changed.source, rule.source);
      expect(changed.sentence, isNull);
      expect(changed.createdAt, at);
      expect(changed.updatedAt, later);

      final kept = rule.copyWith();
      expect(kept.weekdays, rule.weekdays);
      expect(kept.sentence, rule.sentence);

      final replaced = rule.copyWith(
        id: 2,
        kind: RuleKind.dailyCap,
        params: const RuleParams(minutes: 240),
        weekdays: const [5],
        source: EntrySource.manual,
        sentence: '금요일은 4시간까지',
        createdAt: later,
      );
      expect(replaced.id, 2);
      expect(replaced.kind, RuleKind.dailyCap);
      expect(replaced.params, const RuleParams(minutes: 240));
      expect(replaced.weekdays, [5]);
      expect(replaced.source, EntrySource.manual);
      expect(replaced.sentence, '금요일은 4시간까지');
      expect(replaced.createdAt, later);
    });
  });
}
