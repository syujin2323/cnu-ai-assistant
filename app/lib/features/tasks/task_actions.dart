// 할 일에서 하는 동작. docs/screens.md '03 할 일'·'할 일 시트'.
//
// [openTaskSheet]: 할 일을 누르면 여는 작은 할 일 시트(docs/decisions.md 2026-11-19 '할 일을 누르면 작은 할 일
// 시트를 연다'). 예상 시간 칩은 시트를 연 채로 저장하고(다음 재계산이 다시 놓음), [끝내기]는 03의 동그라미와 같은
// 흐름([afterTaskCompleted])이며, [지우기]·[숨기기]는 되돌리기 토스트를 띄우고, 블록 줄은 근거 시트를 연다. 03 할 일의
// 줄이 부르고, 11 주간·09 일간의 마감 줄과 06 AI 비서의 할 일 카드도 이것을 부른다.
//
// [afterTaskCompleted]: 할 일을 끝낸 뒤 영상은 토스트만 띄우고, 그 밖에는 '얼마나 걸렸어요?' 시트를 거쳐 걸린 시간과
// 다음 예상(예상 시간 규칙)을 저장한 뒤 되돌리기 토스트를 띄운다. 걸린 시간은 끝내기와 같은 되돌리기에 담아, 토스트의
// [되돌리기]가 끝내기까지 함께 되돌리게 한다(`TaskRepository.recordTook`). 다음 예상을 저장했으면 토스트의
// [되돌리기]는 그 규칙만 되돌린다. 03 할 일의 동그라미가 부른다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_sheet.dart';
import 'package:cnu_ai_assistant/domain/task_took.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_controller.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/task_sheet.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/took_sheet.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// [entry]를 끝낸 뒤([completedAt]에 `TaskRepository.complete`로 저장함) 걸린 시간을 묻고 토스트를 띄운다.
Future<void> afterTaskCompleted(
  BuildContext context,
  WidgetRef ref,
  TaskEntry entry, {
  required DateTime completedAt,
}) async {
  final task = entry.task;
  final toast = ref.read(toastControllerProvider.notifier);
  if (!asksTook(task)) {
    toast.show(taskDoneToast(task), undoable: true);
    return;
  }
  final tasks = ref.read(taskRepositoryProvider);
  final rules = ref.read(rulesRepositoryProvider);
  final clock = ref.read(clockProvider);
  final config = PlannerConfig.from(ref.read(rulesProvider).value ?? const []);
  final outcome = await showTookSheet(
    context,
    ref.read(motionLevelProvider),
    content: tookSheetContent(entry, config),
    askFor: (minutes) => estimateAsk(entry, minutes, config),
  );
  final minutes = outcome.minutes;
  final bool merged;
  switch (await tasks.recordTook(
    task.id,
    minutes: minutes,
    completed: UndoMark('tasks', completedAt),
    now: clock.now(),
  )) {
    case Ok(:final value):
      merged = value;
    case Err(:final error):
      appLog('task_took_failed', area: 'tasks', data: errorLogData(error));
      toast.show(AppStrings.saveFailed);
      return;
  }
  final ask = outcome.ask;
  if (minutes != null && ask != null && outcome.saveEstimate) {
    switch (await rules.save(
      kind: RuleKind.estimate,
      params: ask.params,
      source: EntrySource.manual,
      now: clock.now(),
    )) {
      case Ok():
        toast.show(ask.savedToast, undoable: true);
      case Err(:final error):
        appLog(
          'estimate_rule_failed',
          area: 'tasks',
          data: errorLogData(error),
        );
        toast.show(AppStrings.saveFailed);
    }
    return;
  }
  toast.show(
    minutes == null ? taskDoneToast(task) : tookToast(task, minutes),
    // 끝내기 기록을 잇지 못했으면(그사이 다른 동작) 되돌리기가 다른 동작을 되돌리지 않게 한다.
    undoable: merged || minutes != null,
  );
}

/// [taskId] 할 일의 작은 할 일 시트를 연다. 시트는 할 일·블록·규칙이 바뀌면 다시 그리고, 할 일이 없어지면 닫는다.
Future<void> openTaskSheet(
  BuildContext context,
  WidgetRef ref,
  int taskId,
) async {
  TaskEntry? find(List<TaskEntry>? entries) =>
      entries?.where((entry) => entry.task.id == taskId).firstOrNull;
  if (find(ref.read(taskEntriesProvider).value) == null) return;
  final tasks = ref.read(taskRepositoryProvider);
  final clock = ref.read(clockProvider);
  final toast = ref.read(toastControllerProvider.notifier);
  final action = await showAppSheet<TaskSheetAction>(
    context: context,
    motion: ref.read(motionLevelProvider),
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final entry = find(ref.watch(taskEntriesProvider).value);
        if (entry == null) {
          // 그사이 지워졌다(다른 곳에서 지움, 데모를 끝냄). 그릴 것이 없으니 닫는다.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (sheetContext.mounted) Navigator.of(sheetContext).maybePop();
          });
          return const SizedBox.shrink();
        }
        final now = ref.watch(minuteClockProvider);
        final boundary =
            ref.watch(settingsProvider).value?.dayBoundaryMin ??
            Defaults.dayBoundaryMin;
        final today = logicalDate(now, dayBoundaryMin: boundary);
        return TaskSheet(
          kind: entry.task.kind,
          content: taskSheetContent(
            entry,
            blocks:
                ref.watch(taskListScheduleProvider(today)).value?.planBlocks ??
                const [],
            config: PlannerConfig.from(
              ref.watch(rulesProvider).value ?? const [],
            ),
            now: now,
            dayBoundaryMin: boundary,
          ),
          onEstimate: (minutes) => unawaited(() async {
            if (await tasks.setEstimate(taskId, minutes, now: clock.now())
                case Err(:final error)) {
              appLog(
                'task_estimate_failed',
                area: 'tasks',
                data: errorLogData(error),
              );
              toast.show(AppStrings.saveFailed);
            }
          }()),
        );
      },
    ),
  );
  if (action == null || !context.mounted) return;
  final entry = find(ref.read(taskEntriesProvider).value);
  if (entry == null) return;
  switch (action) {
    case TaskSheetOpenBlock(:final block):
      await openBlockSheet(context, ref, block);
    case TaskSheetComplete():
      final completedAt = clock.now();
      switch (await tasks.complete(taskId, now: completedAt)) {
        case Ok(value: true):
          if (context.mounted) {
            await afterTaskCompleted(
              context,
              ref,
              entry,
              completedAt: completedAt,
            );
          }
        case Ok():
          break;
        case Err(:final error):
          appLog(
            'task_complete_failed',
            area: 'tasks',
            data: errorLogData(error),
          );
          toast.show(AppStrings.saveFailed);
      }
    case TaskSheetRemove():
      final lms = entry.task.lmsKey != null;
      switch (await tasks.remove(taskId, now: clock.now())) {
        case Ok(value: true):
          toast.show(
            '${withJosa(entry.task.title, Josa.eulReul)} ${lms ? '숨겼어요' : '지웠어요'}',
            undoable: true,
          );
        case Ok():
          break;
        case Err(:final error):
          appLog(
            'task_remove_failed',
            area: 'tasks',
            data: errorLogData(error),
          );
          toast.show(AppStrings.saveFailed);
      }
  }
}
