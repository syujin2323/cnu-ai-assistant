// 미배정 할 일(`/tasks`, 드로어에서 엶). docs/architecture.md '도메인 기본값, 빈 시간과 여유도' 3단계.
//
// 시간이 덜 정해진 할 일을 여유도가 작은 순서로 보여 준다. 줄마다 마감·남은 시간·급한 정도와
// '배치' 버튼이 있다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/unassigned_task_row.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 미배정 할 일.
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(unassignedTasksProvider);
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider).now();
    final boundary = ref.watch(dayBoundaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.unassignedTasks)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.screen,
            vertical: AppSpace.s8,
          ),
          children: [
            Text(
              '급한 순서예요. 마감 전 빈 시간에서 남은 시간을 뺀 여유가 적을수록 위에 있어요.',
              style: AppText.small.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.s8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
                child: Text(
                  '시간을 정할 할 일이 없어요.',
                  style: AppText.body.copyWith(color: AppColors.muted),
                ),
              ),
            for (final item in items)
              UnassignedTaskRow(
                item: item,
                now: now,
                dayBoundaryMin: boundary,
                onPlace: () => showAddSheet(
                  context,
                  day: ref.read(calendarTodayProvider),
                  taskId: item.task.id,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
