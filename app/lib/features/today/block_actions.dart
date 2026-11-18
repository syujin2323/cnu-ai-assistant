// 할 일 블록의 근거 시트와 옮기기 시트를 열고 고른 동작을 한다. docs/screens.md '근거 시트'·'옮기기 시트'.
//
// 01 계획의 잠긴 줄과 02 홈의 시간표가 쓰고, 09 일간·11 주간·06 AI 비서도 같은 것을 쓴다. 시트에 보일 것은
// `domain/block_sheet.dart`·`domain/move_sheet.dart`가 정하고, 동작은 `PlanBlockRepository`가 한 트랜잭션에서
// 하며 되돌리기를 남긴다(10초 되돌리기 토스트). 근거 시트의 [옮기기]는 옮기기 시트를 연다. 후보는 시트를 열 때
// 오늘부터 배치 지평의 일정으로 계산하고(`suggestSlots`), 고르면 그 자리의 직접 정한 확정 블록으로 옮긴다.
// 토스트 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/design/widgets/block_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/block_sheet.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// [block]의 근거 시트를 연다. 블록의 할 일을 읽지 못했으면 열지 않는다.
Future<void> openBlockSheet(
  BuildContext context,
  WidgetRef ref,
  PlanBlock block,
) async {
  final entry = _entryOf(ref, block);
  if (entry == null) return;
  final now = ref.read(clockProvider).now();
  final boundary = _boundary(ref);
  DateTime? next;
  for (final draft in ref.read(planControllerProvider)?.blocks ?? const []) {
    if (draft.taskId != block.taskId || !draft.startAt.isAfter(now)) continue;
    if (next == null || draft.startAt.isBefore(next)) next = draft.startAt;
  }
  final content = blockSheetContent(
    block: block,
    entry: entry,
    courseName: _courseName(entry),
    now: now,
    dayBoundaryMin: boundary,
    nextSuggestionAt: next,
  );
  final repository = ref.read(planBlockRepositoryProvider);
  final toast = ref.read(toastControllerProvider.notifier);
  final clock = ref.read(clockProvider);
  final action = await showBlockSheet(
    context,
    ref.read(motionLevelProvider),
    content,
  );
  if (action == null) return;

  final at = clock.now();
  final title = entry.task.title;
  final Result<bool> result;
  final String done;
  switch (action) {
    case BlockSheetAction.confirm:
      result = await repository.confirm([block.id], now: at);
      done =
          '${withJosa(title, Josa.eulReul)} '
          '${dayWord(block.startAt, now: at, dayBoundaryMin: boundary)} '
          '${hhmmText(block.startAt.hour * 60 + block.startAt.minute)}에 확정했어요';
    case BlockSheetAction.complete:
      result = await repository.complete(block.id, now: at);
      done =
          '$title · '
          '${durationText(block.endAt.difference(block.startAt).inMinutes)} 끝냈어요';
    case BlockSheetAction.uncomplete:
      result = await repository.uncomplete(block.id, now: at);
      done = '${withJosa(title, Josa.eulReul)} 다시 할 일로 돌렸어요';
    case BlockSheetAction.dismiss:
      result = await repository.dismiss(block.id, now: at);
      done = '${withJosa(title, Josa.eulReul)} 지웠어요 · 다른 빈 시간에 다시 제안해요';
    case BlockSheetAction.move:
      if (context.mounted) await openMoveSheet(context, ref, block);
      return;
  }
  switch (result) {
    case Ok(value: true):
      toast.show(done, undoable: true);
    case Ok(value: false):
      _changed(toast);
    case Err():
      _failed(toast);
  }
}

/// [block]의 옮기기 시트를 연다(근거 시트 [옮기기]). 후보는 오늘(논리적 하루)부터 배치 지평의 일정으로 찾고
/// (`suggestSlots`), 고르면 그 자리의 직접 정한 확정 블록으로 옮긴다(되돌리기 토스트). 블록의 할 일이나 규칙을
/// 읽지 못했으면 열지 않고, 일정을 읽지 못하면 열지 않고 알린다.
Future<void> openMoveSheet(
  BuildContext context,
  WidgetRef ref,
  PlanBlock block,
) async {
  final entry = _entryOf(ref, block);
  final config = ref.read(plannerConfigProvider);
  if (entry == null || config == null) return;
  final clock = ref.read(clockProvider);
  final boundary = _boundary(ref);
  final schedules = ref.read(scheduleRepositoryProvider);
  final repository = ref.read(planBlockRepositoryProvider);
  final toast = ref.read(toastControllerProvider.notifier);
  final motion = ref.read(motionLevelProvider);

  final now = clock.now();
  final today = logicalDate(now, dayBoundaryMin: boundary);
  final last = DateTime(
    today.year,
    today.month,
    today.day + Defaults.planHorizonDays - 1,
  );
  final schedule = await schedules.read(
    start: logicalDayStart(today, dayBoundaryMin: boundary),
    end: logicalDayEnd(last, dayBoundaryMin: boundary),
  );
  final List<SlotOption> options;
  switch (schedule) {
    case Ok(:final value):
      options = suggestSlots(
        now: now,
        block: block,
        entry: entry,
        schedule: value,
        config: config,
        dayBoundaryMin: boundary,
      );
    case Err(:final error):
      appLog('move_read_failed', area: 'today', data: errorLogData(error));
      toast.show('옮길 자리를 찾지 못했어요. 다시 해 주세요');
      return;
  }
  if (!context.mounted) return;
  final choice = await showMoveSheet(
    context,
    motion,
    moveSheetContent(
      block: block,
      entry: entry,
      options: options,
      courseName: _courseName(entry),
      now: now,
      dayBoundaryMin: boundary,
    ),
  );
  if (choice == null) return;

  final at = clock.now();
  final span = choice.option.span;
  switch (await repository.move(
    block.id,
    start: span.start,
    end: span.end,
    now: at,
  )) {
    case Ok(value: _?):
      toast.show(
        movedToast(
          entry.task.title,
          span.start,
          now: at,
          dayBoundaryMin: boundary,
        ),
        undoable: true,
      );
    case Ok(value: null):
      _changed(toast);
    case Err(:final error):
      appLog('move_failed', area: 'today', data: errorLogData(error));
      _failed(toast);
  }
}

/// [block]의 할 일. 읽지 못했거나 없으면 null이다.
TaskEntry? _entryOf(WidgetRef ref, PlanBlock block) => ref
    .read(taskEntriesProvider)
    .value
    ?.where((entry) => entry.task.id == block.taskId)
    .firstOrNull;

int _boundary(WidgetRef ref) =>
    ref.read(settingsProvider).value?.dayBoundaryMin ?? Defaults.dayBoundaryMin;

String? _courseName(TaskEntry entry) =>
    entry.course?.name ?? entry.lmsItem?.courseName;

/// 시트를 연 사이 블록이 바뀌었다(재계산이 제안을 바꿔 끼웠거나 다른 곳에서 고침).
void _changed(ToastController toast) => toast.show('블록이 바뀌었어요. 다시 열어 주세요');

void _failed(ToastController toast) => toast.show('바꾸지 못했어요. 다시 해 주세요');
