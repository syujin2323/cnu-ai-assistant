// 06 AI 비서의 내 규칙 카드: 미리보기와 저장, 새 규칙과 겹친 확정 블록, 규칙 지우기, 지울 규칙 고르기.
// docs/screens.md '06 AI 비서'의 카드 4. 문구는 디자인 전 임시 문구이고 최종 프로토타입 06의 문구를 따른다.
//
// [저장]·[지우기]를 누를 때만 쓰고 되돌리기 토스트를 띄운다. 저장한 뒤 새 규칙 때문에 빈 시간에서 빠진 확정
// 블록마다 [옮기기](그 블록을 지우고 다시 계산)·[그대로 두기]를 묻는다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_rules.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 규칙 종류의 아이콘(이동은 버스, 식사는 식사, 예상 시간은 모래시계, 그 밖은 시계).
AppIconName _ruleIcon(RuleKind kind) => switch (kind) {
  RuleKind.travel => AppIconName.bus,
  RuleKind.meal => AppIconName.meal,
  RuleKind.estimate => AppIconName.hourglass,
  _ => AppIconName.clock,
};

/// 내 규칙 미리보기 카드.
class RuleCardView extends ConsumerWidget {
  const RuleCardView({super.key, required this.card});

  final RuleCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final draft = card.draft;
    final saving = card.status == CardStatus.saving;
    final saved = card.status == CardStatus.saved;
    final replaced = saved ? null : ruleReplacedText(card);
    return AssistantCardFrame(
      icon: _ruleIcon(draft.kind),
      kicker: saved ? '내 규칙 · 저장함' : '내 규칙 · 미리보기',
      children: [
        CardTitle(
          rulePreviewSentence(
                draft.kind,
                draft.merged,
                weekdays: draft.weekdays,
                courseName: draft.courseName,
              ) ??
              ruleKindName(draft.kind),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            ruleScopeText(draft.kind, draft.weekdays),
            style: AppText.small.copyWith(color: colors.muted),
          ),
        ),
        if (replaced != null) CardNote(icon: AppIconName.info, text: replaced),
        switch (card.status) {
          CardStatus.pending || CardStatus.saving => CardActions(
            primary: FilledButton(
              onPressed: saving ? null : () => controller.saveRule(card.id),
              child: const Text('저장'),
            ),
            secondary: OutlinedButton(
              onPressed: saving ? null : () => controller.skipCard(card.id),
              child: const Text('취소'),
            ),
          ),
          CardStatus.saved => CardDone(
            text: '저장했어요 · 바로 다시 계산했어요',
            note: card.planNote,
          ),
          CardStatus.declined => const CardSkipped('저장하지 않았어요'),
        },
        if (saved)
          for (final conflict in card.conflicts)
            _ConflictView(
              conflict: conflict,
              onMove: () => controller.moveConflict(card.id, conflict.block.id),
              onKeep: () => controller.keepConflict(card.id, conflict.block.id),
            ),
      ],
    );
  }
}

/// 새 규칙과 겹친 확정 블록 하나와 그 답.
class _ConflictView extends ConsumerWidget {
  const _ConflictView({
    required this.conflict,
    required this.onMove,
    required this.onKeep,
  });

  final RuleConflict conflict;
  final VoidCallback onMove;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider).now();
    final boundary =
        ref.watch(settingsProvider).value?.dayBoundaryMin ??
        Defaults.dayBoundaryMin;
    String when(DateTime start, DateTime end) {
      final from = start.hour * 60 + start.minute;
      final minutes = end.difference(start).inMinutes;
      return '${dayWord(start, now: now, dayBoundaryMin: boundary)} '
          '${timeRangeText(from, from + (minutes < 1440 ? minutes : 1439))}';
    }

    final block = conflict.block;
    final result = switch (conflict.answer) {
      ConflictAnswer.ask => null,
      ConflictAnswer.moved => switch ((
        conflict.movedStart,
        conflict.movedEnd,
      )) {
        (final start?, final end?) => '옮겼어요 · ${when(start, end)}에 다시 제안했어요',
        _ => '옮겼어요 · 다음 빈 시간에 다시 놓아요',
      },
      ConflictAnswer.kept => '그대로 뒀어요 · 겹친 채로 둬요',
    };
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: colors.alertSoft,
        borderRadius: BorderRadius.circular(AppRadius.notice),
        border: Border.all(color: colors.alertLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '확정한 블록이 새 규칙과 겹쳐요',
            style: AppText.small.copyWith(
              color: colors.alert,
              fontWeight: AppText.semibold,
            ),
          ),
          Text(
            '${conflict.title} · ${when(block.startAt, block.endAt)} · 확정',
            style: AppText.caption.copyWith(color: colors.ink2),
          ),
          if (result == null)
            CardActions(
              primary: FilledButton(
                onPressed: onMove,
                child: const Text('옮기기'),
              ),
              secondary: OutlinedButton(
                onPressed: onKeep,
                child: const Text('그대로 두기'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                result,
                style: AppText.small.copyWith(color: colors.ink2),
              ),
            ),
        ],
      ),
    );
  }
}

/// 내 규칙 지우기 카드.
class RuleRemoveCardView extends ConsumerWidget {
  const RuleRemoveCardView({super.key, required this.card});

  final RuleRemoveCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final rule = card.rule;
    final saving = card.status == CardStatus.saving;
    return AssistantCardFrame(
      icon: AppIconName.close,
      kicker: '내 규칙 · 지우기',
      children: [
        CardTitle(_ruleTitle(rule, card.courseName)),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            ruleScopeText(rule.kind, rule.weekdays),
            style: AppText.small.copyWith(color: colors.muted),
          ),
        ),
        switch (card.status) {
          CardStatus.pending || CardStatus.saving => CardActions(
            primary: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.alert,
                foregroundColor: colors.onStrong,
              ),
              onPressed: saving ? null : () => controller.removeRule(card.id),
              child: const Text('지우기'),
            ),
            secondary: OutlinedButton(
              onPressed: saving ? null : () => controller.skipCard(card.id),
              child: const Text('그대로 두기'),
            ),
          ),
          CardStatus.saved => CardDone(
            text: '지웠어요 · 바로 다시 계산했어요',
            note: card.planNote,
          ),
          CardStatus.declined => const CardSkipped('그대로 뒀어요'),
        },
      ],
    );
  }
}

/// 지울 규칙이 여럿일 때 고르는 카드. 고르면 고른 것만 남는다.
class RulePickCardView extends ConsumerWidget {
  const RulePickCardView({super.key, required this.card});

  final RulePickCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final picked = card.picked;
    String? courseOf(Rule rule) => card.courseNames[rule.params.courseId];
    return AssistantCardFrame(
      icon: AppIconName.close,
      kicker: '내 규칙 · 지우기',
      children: [
        const CardTitle('어느 규칙을 지울까요?'),
        if (picked == null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s4),
            child: Text(
              '켜진 ${ruleKindName(card.kind)} 규칙이에요',
              style: AppText.small.copyWith(color: colors.muted),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          for (final (index, rule) in card.rules.indexed)
            CardOptionRow(
              label: _ruleTitle(rule, courseOf(rule)),
              sub: ruleShortValue(
                rule.kind,
                rule.params,
                weekdays: rule.weekdays,
                courseName: courseOf(rule),
              ),
              onTap: () => controller.pickRule(card.id, index),
            ),
        ] else
          CardDone(
            text: _ruleTitle(card.rules[picked], courseOf(card.rules[picked])),
          ),
      ],
    );
  }
}

/// 규칙의 문장. 문장을 만들 수 없으면 종류 이름이다.
String _ruleTitle(Rule rule, String? courseName) =>
    rulePreviewSentence(
      rule.kind,
      rule.params,
      weekdays: rule.weekdays,
      courseName: courseName,
    ) ??
    ruleKindName(rule.kind);
