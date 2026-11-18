// 고정 일정 시트·빠르게 더하기의 처음 값 테스트. docs/screens.md '13 시간표·고정 일정', '14 온보딩' 3단계.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('기타를 뺀 처음 값은 그대로 저장할 수 있고 종류가 맞다', () {
    for (final kind in FixedBlockKind.values) {
      final draft = fixedBlockTemplate(kind);
      expect(draft.kind, kind);
      if (kind == FixedBlockKind.other) continue;
      expect(draft.name, isNotEmpty, reason: '$kind');
      expect(
        checkFixedBlock(
          weekdays: draft.weekdays.toList(),
          startMin: draft.startMin,
          endMin: draft.endMin,
          bufferMin: draft.bufferMin,
        ),
        isEmpty,
        reason: '$kind',
      );
    }
  });

  test('기타는 이름과 요일이 비어 사용자가 채운다', () {
    final other = fixedBlockTemplate(FixedBlockKind.other);
    expect(other.name, isEmpty);
    expect(other.weekdays, isEmpty);
  });

  test('운동의 준비물은 기본값(운동복)이다', () {
    expect(
      fixedBlockTemplate(FixedBlockKind.exercise).prep,
      Defaults.exercisePrep,
    );
    expect(fixedBlockTemplate(FixedBlockKind.meal).prep, isEmpty);
  });

  test('of는 고정 일정의 지금 값을 담고, copyWith는 준 값만 바꾼다', () {
    final draft = FixedBlockDraft.of(
      const FixedBlock(
        id: 3,
        name: '헬스',
        weekdays: [1, 3],
        startMin: 1080,
        endMin: 1170,
        bufferMin: 10,
        kind: FixedBlockKind.exercise,
        source: EntrySource.manual,
        place: '합성 체육관',
      ),
    );
    expect((draft.name, draft.prep, draft.place), ('헬스', '', '합성 체육관'));
    expect(draft.weekdays, {1, 3});

    final changed = draft.copyWith(name: '수영', bufferMin: 0);
    expect(
      (changed.name, changed.bufferMin, changed.startMin, changed.place),
      ('수영', 0, 1080, '합성 체육관'),
    );
  });

  test('종류 이름', () {
    expect(FixedBlockKind.values.map(fixedBlockKindText), [
      '식사',
      '알바',
      '운동',
      '통학',
      '기타',
    ]);
  });
}
