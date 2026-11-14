// 할 일 종류의 이름. docs/screens.md '03 할 일'·'12 내 규칙'.

import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 할 일 종류의 이름(과제·영상·퀴즈·팀플·토론·시험·자료·개인). 03 할 일 줄의 '{과목} · {종류}', 12 내 규칙의
/// 예상 시간, 06 AI 비서의 종류 칩이 쓴다.
String taskKindText(TaskKind kind) => switch (kind) {
  TaskKind.assignment => '과제',
  TaskKind.video => '영상',
  TaskKind.quiz => '퀴즈',
  TaskKind.team => '팀플',
  TaskKind.discussion => '토론',
  TaskKind.exam => '시험',
  TaskKind.material => '자료',
  TaskKind.personal => '개인',
};
