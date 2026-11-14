import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('할 일 종류마다 다른 이름을 쓴다', () {
    expect(
      {for (final kind in TaskKind.values) kind: taskKindText(kind)},
      {
        TaskKind.assignment: '과제',
        TaskKind.video: '영상',
        TaskKind.quiz: '퀴즈',
        TaskKind.team: '팀플',
        TaskKind.discussion: '토론',
        TaskKind.exam: '시험',
        TaskKind.material: '자료',
        TaskKind.personal: '개인',
      },
    );
  });
}
