// 빈 시간에 놓기 시트를 열고 고른 동작을 한다. docs/screens.md '빈 시간에 놓기 시트'.
//
// 02 홈의 빈 시간 카드와 피드백 카드 [빈 시간에 할 일 놓기]가 쓰고, 09 일간과 06 AI 비서의 빈 시간 답도 같은
// 것을 쓴다. 후보는 `domain/move_sheet.dart`의 [freeSlotContent]가 할 일 목록과 배치 엔진의 급한 순서로 고르고,
// 할 일을 고르면 `PlanBlockRepository.place`로 그 빈 시간의 시작에 직접 정한 확정 블록을 만든다(10초 되돌리기
// 토스트). [일정은 말로 추가하기]는 06 AI 비서를 연다. 토스트 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_block_repository.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/free_slot_sheet.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// [gap] 빈 시간에 놓기 시트를 연다. 할 일·규칙·설정은 열 때 저장소에서 읽고(그 값을 지켜보지 않는 화면에서
/// 불러도 열리게. 듣는 쪽이 없는 provider는 Riverpod이 멈춰 둠), 읽지 못하면 알린다. 빈 시간이 이미 지났으면 알린다.
/// [speech]가 false면 [일정은 말로 추가하기]를 두지 않는다(06 AI 비서 안에서 열 때). [fillAssistant]면 그 버튼이
/// 06 AI 비서에 빈 시간의 날짜·시각을 넘긴다(09 일간, [AssistantArgs.at]).
Future<void> openFreeSlotSheet(
  BuildContext context,
  WidgetRef ref,
  TimeSpan gap, {
  bool speech = true,
  bool fillAssistant = false,
}) async {
  final clock = ref.read(clockProvider);
  final repository = ref.read(planBlockRepositoryProvider);
  final toast = ref.read(toastControllerProvider.notifier);
  final motion = ref.read(motionLevelProvider);
  final ranked = ref.read(planControllerProvider)?.ranked ?? const <int>[];
  final entriesRead = ref.read(taskRepositoryProvider).read();
  final rulesRead = ref.read(rulesRepositoryProvider).read();
  final settingsRead = ref.read(settingsRepositoryProvider).read();
  final read = (await entriesRead, await rulesRead, await settingsRead);
  if (read case (
    Ok(value: final entries),
    Ok(value: final rules),
    Ok(value: final settings),
  )) {
    if (!context.mounted) return;
    await _open(
      context,
      gap,
      speech: speech,
      fillAssistant: fillAssistant,
      entries: entries,
      rules: rules,
      boundary: settings.dayBoundaryMin,
      ranked: ranked,
      clock: clock,
      motion: motion,
      repository: repository,
      toast: toast,
    );
    return;
  }
  for (final result in [read.$1, read.$2, read.$3]) {
    if (result case Err(:final error)) {
      appLog('free_slot_read_failed', area: 'today', data: errorLogData(error));
    }
  }
  toast.show('할 일을 읽지 못했어요. 다시 해 주세요');
}

/// 읽은 값으로 시트를 열고 고른 동작을 한다.
Future<void> _open(
  BuildContext context,
  TimeSpan gap, {
  required bool speech,
  required bool fillAssistant,
  required List<TaskEntry> entries,
  required List<Rule> rules,
  required int boundary,
  required List<int> ranked,
  required Clock clock,
  required MotionLevel motion,
  required PlanBlockRepository repository,
  required ToastController toast,
}) async {
  final content = freeSlotContent(
    gap: gap,
    entries: entries,
    ranked: ranked,
    config: PlannerConfig.from(rules),
    now: clock.now(),
    dayBoundaryMin: boundary,
  );
  if (content == null) {
    toast.show('이 빈 시간은 지났어요');
    return;
  }
  final pick = await showFreeSlotSheet(
    context,
    motion,
    content,
    speech: speech,
  );
  switch (pick) {
    case null:
      return;
    case FreeSlotSpeak():
      if (!context.mounted) return;
      context.push(
        Routes.assistant,
        extra: AssistantArgs(at: fillAssistant ? content.span.start : null),
      );
    case FreeSlotPlace(:final choice):
      final span = TimeSpan(
        content.span.start,
        content.span.start.add(Duration(minutes: choice.minutes)),
      );
      final at = clock.now();
      switch (await repository.place(
        taskId: choice.taskId,
        start: span.start,
        end: span.end,
        now: at,
      )) {
        case Ok(value: _?):
          toast.show(
            placedToast(choice.title, span, now: at, dayBoundaryMin: boundary),
            undoable: true,
          );
        case Ok(value: null):
          // 시트를 연 사이 그 할 일이 지워졌다.
          toast.show('할 일이 바뀌었어요. 다시 열어 주세요');
        case Err(:final error):
          appLog('free_place_failed', area: 'today', data: errorLogData(error));
          toast.show('놓지 못했어요. 다시 해 주세요');
      }
  }
}
