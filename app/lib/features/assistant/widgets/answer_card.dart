// 06 AI 비서의 질문 답 카드. docs/screens.md '06 AI 비서'의 카드 6(마감·하루 계획·빈 시간을 폰 안 데이터로 답함).
//
// 답의 내용은 `answerContentProvider`가 폰 DB로 그때그때 계산한다(할 일을 끝내거나 블록을 확정하면 카드도 바뀜).
// 할 일 블록 줄을 누르면 근거 시트를 열고, 아래 링크는 03 할 일·02 홈·09 일간으로 간다(06은 닫힘). 빈 시간
// 줄의 [놓기](빈 시간에 놓기 시트)는 그 시트가 생기면 붙인다. 문구는 디자인 전 임시 문구이고 최종 프로토타입의
// 06 문구를 따른다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_answers.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_context.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 질문 답 카드.
class AnswerCardView extends ConsumerWidget {
  const AnswerCardView({super.key, required this.card});

  final AnswerCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final content = ref.watch(answerContentProvider(card));
    final lms = ref.watch(lmsStatusProvider);
    final icon = switch (card.type) {
      ParseQueryType.deadlinesThisWeek => AppIconName.flag,
      ParseQueryType.todayPlan => AppIconName.today,
      ParseQueryType.freeTime => AppIconName.freeTime,
    };
    if (content == null) {
      return AssistantCardFrame(
        icon: icon,
        kicker: '폰 안 데이터를 보는 중이에요',
        children: const [],
      );
    }
    return AssistantCardFrame(
      icon: icon,
      kicker: content.kicker,
      children: [
        CardTitle(content.title),
        if (content.sub case final sub?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s4),
            child: Text(sub, style: AppText.small.copyWith(color: colors.ink2)),
          ),
        const SizedBox(height: AppSpace.s8),
        for (final row in content.rows)
          _AnswerRowView(
            row: row,
            onTap: switch (row.block) {
              final block? => () => openBlockSheet(context, ref, block),
              null => null,
            },
          ),
        if (content.rows.isEmpty)
          CardNote(icon: AppIconName.info, text: content.emptyText),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s12),
          child: Row(
            children: [
              AppIcon(AppIconName.refresh, size: 13, color: colors.muted),
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Text(
                  // 받은 적이 있으면 마지막 확인 시각을 붙인다('LMS 정보 10분 전 기준').
                  lms != null &&
                          lms.kind == LmsStatusKind.synced &&
                          lms.lastSuccessAt != null
                      ? '${lms.text} 기준 · 폰 안 데이터로 답했어요'
                      : '폰 안 데이터로 답했어요',
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go(switch (content.link) {
              AnswerLink.tasks => Routes.tasksTab(TaskListTab.all),
              AnswerLink.home => Routes.today,
              AnswerLink.day => Routes.day(card.from),
            }),
            child: Text(content.linkText),
          ),
        ),
      ],
    );
  }
}

/// 답의 한 줄: 종류 색의 점, 이름과 아래 한 줄, 오른쪽 값. 할 일 블록이면 눌러 근거 시트를 연다.
class _AnswerRowView extends StatelessWidget {
  const _AnswerRowView({required this.row, required this.onTap});

  final AnswerRow row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dot = switch (row.kind) {
      AnswerRowKind.course => colors.classInk,
      AnswerRowKind.task => colors.taskInk,
      AnswerRowKind.personal => colors.personalInk,
      AnswerRowKind.free => colors.icon,
    };
    final content = Container(
      constraints: const BoxConstraints(minHeight: AppSize.minTouch),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.edge)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(fontWeight: AppText.medium),
                ),
                Text(
                  row.sub,
                  style: AppText.caption.copyWith(
                    color: row.urgent ? colors.alert : colors.muted,
                    fontWeight: row.urgent ? AppText.semibold : null,
                  ),
                ),
              ],
            ),
          ),
          if (row.right case final right?) ...[
            const SizedBox(width: AppSpace.s8),
            Flexible(
              child: Text(
                right,
                textAlign: TextAlign.end,
                style: AppText.caption.copyWith(
                  color: colors.ink2,
                  fontWeight: AppText.semibold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
