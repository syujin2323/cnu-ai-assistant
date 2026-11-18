// 할 일 종류의 아이콘(최종 프로토타입 03 할 일). 03 할 일의 줄 머리와 작은 할 일 시트가 쓴다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// [kind]의 아이콘. 과제·자료는 문서, 시험은 깃발, 개인은 사람이다.
AppIconName taskKindIcon(TaskKind kind) => switch (kind) {
  TaskKind.assignment || TaskKind.material => AppIconName.doc,
  TaskKind.video => AppIconName.video,
  TaskKind.quiz => AppIconName.quiz,
  TaskKind.team => AppIconName.team,
  TaskKind.discussion => AppIconName.discussion,
  TaskKind.exam => AppIconName.flag,
  TaskKind.personal => AppIconName.person,
};
