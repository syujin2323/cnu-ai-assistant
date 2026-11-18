// 근거 시트. docs/screens.md '근거 시트'.
//
// 할 일 블록을 누르면 여는 시트다(01 계획의 잠긴 줄, 02 홈, 09 일간, 11 주간, 06 AI 비서). 무엇을 보일지는
// `domain/block_sheet.dart`의 [blockSheetContent]가 정하고, 이 시트는 그리기만 한다. 버튼을 누르면 그 동작을
// 돌려주고 닫으며, 동작(저장과 되돌리기 토스트)은 부르는 쪽이 한다. '{종류} 자세히 보기' 링크는 할 일 상세가 재설계
// 예정이라 두지 않는다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/domain/block_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// 근거 시트를 연다. 버튼을 누르면 그 동작, 닫으면 null이다.
Future<BlockSheetAction?> showBlockSheet(
  BuildContext context,
  MotionLevel motion,
  BlockSheetContent content,
) => showAppSheet<BlockSheetAction>(
  context: context,
  motion: motion,
  builder: (context) => BlockSheet(content: content),
);

/// 근거 시트의 몸통.
class BlockSheet extends StatelessWidget {
  const BlockSheet({super.key, required this.content});

  final BlockSheetContent content;

  static String actionLabel(BlockSheetAction action) => switch (action) {
    BlockSheetAction.confirm => '확정',
    BlockSheetAction.complete => '완료',
    BlockSheetAction.uncomplete => '완료 취소',
    BlockSheetAction.move => '옮기기',
    BlockSheetAction.dismiss => '지우기',
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final actions = content.actions;
    Widget note(String text, {AppIconName? icon}) => Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(AppRadius.notice),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon ?? AppIconName.info, size: 16, color: colors.accent),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              text,
              style: AppText.small.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.taskTint,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: colors.taskLine),
              ),
              child: Text(
                content.kicker,
                style: AppText.caption.copyWith(
                  fontWeight: AppText.semibold,
                  color: colors.taskInk,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Semantics(
            header: true,
            child: Text(content.title, style: AppText.title),
          ),
          const SizedBox(height: 2),
          Text(content.time, style: AppText.small.copyWith(color: colors.ink2)),
          if (content.manual) note('직접 정한 시간이에요'),
          if (content.reasons.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpace.s12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.listGroup),
                border: Border.all(color: colors.edge),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < content.reasons.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                        height: 1,
                        child: ColoredBox(color: colors.edge),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 50),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                          vertical: AppSpace.s12,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(content.reasons[i], style: AppText.body),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (content.missedText case final text?)
            note(text, icon: AppIconName.undo),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            // 두 개씩 한 줄. 첫 버튼이 주 버튼이다.
            for (var i = 0; i < actions.length; i += 2) ...[
              if (i > 0) const SizedBox(height: AppSpace.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _button(context, actions[i], primary: i == 0),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: i + 1 < actions.length
                        ? _button(context, actions[i + 1], primary: false)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    BlockSheetAction action, {
    required bool primary,
  }) {
    final colors = AppColors.of(context);
    void pick() => Navigator.of(context).pop(action);
    final label = Text(actionLabel(action), textAlign: TextAlign.center);
    const size = Size.fromHeight(AppSize.minTouch);
    if (primary) {
      return FilledButton(
        onPressed: pick,
        style: FilledButton.styleFrom(minimumSize: size),
        child: label,
      );
    }
    final dismiss = action == BlockSheetAction.dismiss;
    return OutlinedButton(
      onPressed: pick,
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        foregroundColor: dismiss ? colors.ink2 : null,
      ),
      child: label,
    );
  }
}
