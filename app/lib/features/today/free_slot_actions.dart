// 빈 시간에 놓기 시트를 열고 고른 동작을 한다. docs/screens.md '빈 시간에 놓기 시트'.
//
// 02 홈의 빈 시간 카드와 피드백 카드 [빈 시간에 할 일 놓기]가 쓰고, 09 일간과 06 AI 비서의 빈 시간 답도 같은
// 것을 쓴다. 후보는 `domain/move_sheet.dart`의 [freeSlotContent]가 할 일 목록과 배치 엔진의 급한 순서로 고르고,
// 할 일을 고르면 `PlanBlockRepository.place`로 그 빈 시간의 시작에 직접 정한 확정 블록을 만든다(10초 되돌리기
// 토스트). [일정은 말로 추가하기]는 06 AI 비서를 연다. 토스트 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/free_slot_sheet.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// [gap] 빈 시간에 놓기 시트를 연다. 할 일이나 규칙을 읽지 못했으면 열지 않고, 빈 시간이 이미 지났으면 알린다.
/// 09 일간에서 열 때 [일정은 말로 추가하기]가 06 AI 비서에 날짜·시각을 채우는 것은 09 일간 PR에서 더한다.
Future<void> openFreeSlotSheet(
  BuildContext context,
  WidgetRef ref,
  TimeSpan gap,
) async {
  final entries = ref.read(taskEntriesProvider).value;
  final config = ref.read(plannerConfigProvider);
  if (entries == null || config == null) return;
  final clock = ref.read(clockProvider);
  final boundary =
      ref.read(settingsProvider).value?.dayBoundaryMin ??
      Defaults.dayBoundaryMin;
  final repository = ref.read(planBlockRepositoryProvider);
  final toast = ref.read(toastControllerProvider.notifier);

  final content = freeSlotContent(
    gap: gap,
    entries: entries,
    ranked: ref.read(planControllerProvider)?.ranked ?? const [],
    config: config,
    now: clock.now(),
    dayBoundaryMin: boundary,
  );
  if (content == null) {
    toast.show('이 빈 시간은 지났어요');
    return;
  }
  final pick = await showFreeSlotSheet(
    context,
    ref.read(motionLevelProvider),
    content,
  );
  switch (pick) {
    case null:
      return;
    case FreeSlotSpeak():
      if (!context.mounted) return;
      context.push(Routes.assistant, extra: const AssistantArgs());
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
