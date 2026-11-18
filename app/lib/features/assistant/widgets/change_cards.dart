// 06 AI 비서의 수업 변경·일정 바꾸기·지우기 카드. docs/screens.md '06 AI 비서'의 카드 3·5. 문구는 디자인 전
// 임시 문구이고 최종 프로토타입의 06 문구를 따른다.
//
// 수업 변경은 그날 하루만 바꾸고 시간표는 그대로 둔다. 바꾸기는 지금과 바꾼 뒤를 보이고, 바꾼 뒤와 겹치는 것은
// 알리기만 한다(막지 않음). 바꿀 일정이 여럿이면 먼저 고르게 한다. [적용]·[바꾸기]·[지우기]를 누를 때만 쓰고
// 되돌리기 토스트를 띄운다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_context.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 수업 변경 카드(그날 하루만).
class ExceptionCardView extends ConsumerWidget {
  const ExceptionCardView({super.key, required this.card});

  final ExceptionCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final draft = card.draft;
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final name = exceptionKindName(draft.kind);
    final saving = card.status == CardStatus.saving;
    final saved = card.status == CardStatus.saved;
    final makeup = draft.kind == ClassExceptionKind.makeup;
    final time = timeRangeText(draft.startMin, draft.endMin);
    return AssistantCardFrame(
      icon: AppIconName.calendar,
      kicker: '수업 변경 · 그날만',
      tag: draft.courseName,
      children: [
        CardTitle(
          '${monthDayText(draft.date, today: today)} ${draft.courseName} $name',
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            '그날만 바뀌어요 · 시간표는 그대로예요',
            style: AppText.small.copyWith(color: colors.muted),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        CardDetailRow(
          label: makeup ? '보강' : '수업',
          value: makeup || draft.originalPlace == null
              ? time
              : '$time · ${draft.originalPlace}',
          strike: saved && draft.kind == ClassExceptionKind.cancelled,
        ),
        if (draft.kind == ClassExceptionKind.placeChange)
          CardDetailRow(label: '바뀐 곳', value: draft.place ?? '새 강의실'),
        if (draft.kind == ClassExceptionKind.exam)
          CardDetailRow(
            label: '그날',
            value: draft.place == null ? '시험' : '시험 · ${draft.place}',
          ),
        if (makeup && draft.place != null)
          CardDetailRow(label: '장소', value: draft.place),
        switch (card.status) {
          CardStatus.pending || CardStatus.saving => CardActions(
            primary: FilledButton(
              onPressed: saving
                  ? null
                  : () => controller.applyException(card.id),
              child: const Text('적용'),
            ),
            secondary: OutlinedButton(
              onPressed: saving ? null : () => controller.skipCard(card.id),
              child: const Text('취소'),
            ),
          ),
          CardStatus.saved => CardDone(
            text: '${withJosa(name, Josa.euroRo)} 표시했어요 · 홈과 캘린더에 보여요',
            note: card.planNote,
          ),
          CardStatus.declined => const CardSkipped('바꾸지 않았어요'),
        },
      ],
    );
  }
}

/// 일정 바꾸기·지우기 카드.
class ChangeCardView extends ConsumerWidget {
  const ChangeCardView({super.key, required this.card});

  final ChangeCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final delete = card.delete;
    final after = card.after;
    final saving = card.status == CardStatus.saving;
    final pending = card.status == CardStatus.pending || saving;
    final overlaps = pending && !delete
        ? ref.watch(changeOverlapsProvider(card))
        : null;
    return AssistantCardFrame(
      icon: delete ? AppIconName.close : AppIconName.pencil,
      kicker: delete ? '일정 지우기' : '일정 바꾸기',
      tag: card.target is FixedTarget ? '고정 일정' : '개인 일정',
      children: [
        CardTitle(card.target.title),
        const SizedBox(height: AppSpace.s12),
        CardDetailRow(
          label: '지금',
          value: targetWhenText(card.target, today: today),
          strike: delete && card.status == CardStatus.saved,
        ),
        if (!delete && after != null)
          CardDetailRow(
            label: '바꾼 뒤',
            value: afterWhenText(after, today: today),
            valueColor: colors.accent,
          ),
        if (overlaps case final overlaps?) OverlapLine(overlaps),
        switch (card.status) {
          CardStatus.pending || CardStatus.saving => CardActions(
            primary: FilledButton(
              style: delete
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.alert,
                      foregroundColor: colors.onStrong,
                    )
                  : null,
              onPressed: saving ? null : () => controller.applyChange(card.id),
              child: Text(delete ? '지우기' : '바꾸기'),
            ),
            secondary: OutlinedButton(
              onPressed: saving ? null : () => controller.skipCard(card.id),
              child: const Text('그대로 두기'),
            ),
          ),
          CardStatus.saved => CardDone(
            text: delete ? '지웠어요 · 캘린더에서 빠져요' : '바꿨어요 · 홈과 캘린더에 바로 보여요',
          ),
          CardStatus.declined => const CardSkipped('그대로 뒀어요'),
        },
      ],
    );
  }
}

/// 바꾸거나 지울 일정이 여럿일 때 고르는 카드. 고르면 고른 것만 남는다.
class TargetPickCardView extends ConsumerWidget {
  const TargetPickCardView({super.key, required this.card});

  final TargetPickCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = card.picked;
    final target = card.item.target?.trim() ?? '';
    return AssistantCardFrame(
      icon: card.delete ? AppIconName.close : AppIconName.pencil,
      kicker: card.delete ? '일정 지우기' : '일정 바꾸기',
      children: [
        CardTitle('「$target」'),
        if (picked == null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s4),
            child: Text(
              card.delete ? '어느 일정을 지울까요?' : '어느 일정을 바꿀까요?',
              style: AppText.small.copyWith(color: colors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          for (final (index, candidate) in card.candidates.indexed)
            CardOptionRow(
              label: candidate.title,
              sub:
                  '${targetWhenText(candidate, today: today)}'
                  '${candidate is FixedTarget ? ' · 반복' : ''}',
              onTap: () => controller.pickTarget(card.id, index),
            ),
        ] else
          CardDone(
            text:
                '${card.candidates[picked].title} · '
                '${targetWhenText(card.candidates[picked], today: today)}',
          ),
      ],
    );
  }
}
