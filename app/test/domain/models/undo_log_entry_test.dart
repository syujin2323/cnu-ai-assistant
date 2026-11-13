// 되돌리기 단계 목록 테스트. docs/architecture.md '폰 DB'의 되돌리기.

import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('단계 목록은 JSON으로 바꿨다 읽어도 같다', () {
    final steps = <UndoStep>[
      const UndoRestore('rules', {'id': 3, 'active': 1, 'sentence': null}),
      const UndoDelete('rules', 7),
      const UndoPatch('tasks', 9, {'status': 'todo', 'spent_min': 30}),
    ];
    final json = encodeUndoSteps(steps);
    expect(
      [for (final step in decodeUndoSteps(json)) step.toJson()],
      [for (final step in steps) step.toJson()],
    );
    expect(decodeUndoSteps(json).map((step) => step.runtimeType), [
      UndoRestore,
      UndoDelete,
      UndoPatch,
    ]);
    expect(decodeUndoSteps('[]'), isEmpty);
  });

  test('모양이 맞지 않으면 FormatException이다', () {
    for (final bad in [
      '{}',
      '[1]',
      '[{"op": "delete", "id": 1}]',
      '[{"table": "rules", "op": "drop", "id": 1}]',
      '[{"table": "rules", "op": "delete", "id": "1"}]',
      '[{"table": "rules", "op": "restore", "row": {}}]',
      '[{"table": "rules", "op": "restore", "row": [1]}]',
      '[{"table": "tasks", "op": "patch", "id": 1}]',
      'not json',
    ]) {
      expect(() => decodeUndoSteps(bad), throwsFormatException, reason: bad);
    }
  });
}
