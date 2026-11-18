// 할 일 블록의 근거 시트를 열고 고른 동작을 한다. docs/screens.md '근거 시트'.
//
// 01 계획의 잠긴 줄과 02 홈의 시간표가 쓰고, 09 일간·11 주간·06 AI 비서도 같은 것을 쓴다. 시트에 보일 것은
// `domain/block_sheet.dart`가 정하고, 동작은 `PlanBlockRepository`가 한 트랜잭션에서 하며 되돌리기를 남긴다(10초
// 되돌리기 토스트). [옮기기]는 옮기기 시트가 붙을 때 더한다. 토스트 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/widgets/block_sheet.dart';
import 'package:cnu_ai_assistant/domain/block_sheet.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
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
  final entry = ref
      .read(taskEntriesProvider)
      .value
      ?.where((entry) => entry.task.id == block.taskId)
      .firstOrNull;
  if (entry == null) return;
  final now = ref.read(clockProvider).now();
  final boundary =
      ref.read(settingsProvider).value?.dayBoundaryMin ??
      Defaults.dayBoundaryMin;
  DateTime? next;
  for (final draft in ref.read(planControllerProvider)?.blocks ?? const []) {
    if (draft.taskId != block.taskId || !draft.startAt.isAfter(now)) continue;
    if (next == null || draft.startAt.isBefore(next)) next = draft.startAt;
  }
  final content = blockSheetContent(
    block: block,
    entry: entry,
    courseName: entry.course?.name ?? entry.lmsItem?.courseName,
    now: now,
    dayBoundaryMin: boundary,
    nextSuggestionAt: next,
    canMove: false,
  );
  final action = await showBlockSheet(
    context,
    ref.read(motionLevelProvider),
    content,
  );
  if (action == null) return;

  final repository = ref.read(planBlockRepositoryProvider);
  final at = ref.read(clockProvider).now();
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
      // 옮기기 시트가 붙기 전에는 [옮기기]를 두지 않는다.
      return;
  }
  final toast = ref.read(toastControllerProvider.notifier);
  switch (result) {
    case Ok(value: true):
      toast.show(done, undoable: true);
    case Ok(value: false):
      // 시트를 연 사이 블록이 바뀌었다(재계산이 제안을 바꿔 끼웠거나 다른 곳에서 고침).
      toast.show('블록이 바뀌었어요. 다시 열어 주세요');
    case Err():
      toast.show('바꾸지 못했어요. 다시 해 주세요');
  }
}
