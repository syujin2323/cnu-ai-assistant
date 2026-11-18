// 할 일에서 하는 동작. docs/screens.md '03 할 일'.
//
// [afterTaskCompleted]: 할 일을 끝낸 뒤 영상은 토스트만 띄우고, 그 밖에는 '얼마나 걸렸어요?' 시트를 거쳐 걸린 시간과
// 다음 예상(예상 시간 규칙)을 저장한 뒤 되돌리기 토스트를 띄운다. 걸린 시간은 끝내기와 같은 되돌리기에 담아, 토스트의
// [되돌리기]가 끝내기까지 함께 되돌리게 한다(`TaskRepository.recordTook`). 다음 예상을 저장했으면 토스트의
// [되돌리기]는 그 규칙만 되돌린다. 03 할 일의 동그라미가 부른다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_took.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/took_sheet.dart';
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
