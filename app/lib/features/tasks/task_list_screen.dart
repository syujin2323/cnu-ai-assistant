// 03 할 일(할 일 탭 `/tasks`). docs/screens.md '03 할 일'.
// 탭 [주간 할 일 N | 전체 할 일 N], LMS 상태 줄, '할 일 추가'(06 직접 추가 폼을 할 일로)는 할 일 PR에서 만든다.
// 처음 열 탭은 `/tasks?tab=all`처럼 받는다(`Routes.tasksTab`). 01 아침 브리핑의 '할 일 전체 보기'가
// [TaskListTab.all]로 연다.

import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:material_ui/material_ui.dart';

/// 03 할 일의 탭. 따로 고르지 않으면 [weekly]가 열린다.
enum TaskListTab {
  /// 주간 할 일: 오늘부터 7일 뒤까지 마감인 일과 마감이 지났는데 안 끝낸 일.
  weekly,

  /// 전체 할 일: 남은 할 일 전부.
  all,
}

/// 03 할 일.
///
/// `/tasks`는 할 일 탭 가지의 첫 화면이다. 그래서 다른 탭에서 다른 [initialTab]으로 다시 열면 새 화면이
/// 생기지 않고, 남아 있던 이 화면이 새 값을 받는다(위젯만 바뀌고 상태는 그대로). 탭을 상태로 들고 있게
/// 만들 때는 `didUpdateWidget`에서 [initialTab]이 바뀌었는지 보고 그 탭으로 옮긴다.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key, this.initialTab = TaskListTab.weekly});

  /// 처음 열 탭.
  final TaskListTab initialTab;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: ScreenPlaceholder(title: AppStrings.tabTasks)),
    );
  }
}
