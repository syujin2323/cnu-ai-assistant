// 작은 할 일 시트. docs/screens.md '할 일 시트'.
//
// 근거 시트(`design/widgets/block_sheet.dart`) 모양으로 머리·제목·마감, 예상 시간 칩, 이 할 일의 블록, [끝내기]와
// [지우기]·[숨기기]를 그린다. 보일 것은 `domain/task_sheet.dart`의 [TaskSheetContent]이고, 예상 시간 칩은 시트를
// 닫지 않고 [TaskSheet.onEstimate]를 부르며, 그 밖의 동작은 고른 것([TaskSheetAction])을 돌려주며 닫는다.
// 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/dashed_border.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/task_sheet.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/tasks/widgets/task_kind_icon.dart';
import 'package:material_ui/material_ui.dart';

/// 시트에서 고른 동작.
sealed class TaskSheetAction {
  const TaskSheetAction();
}

/// [끝내기].
final class TaskSheetComplete extends TaskSheetAction {
  const TaskSheetComplete();
}

/// [지우기](직접 넣은 할 일)·[숨기기](LMS 할 일).
final class TaskSheetRemove extends TaskSheetAction {
  const TaskSheetRemove();
}

/// 블록 줄을 눌러 근거 시트를 연다.
final class TaskSheetOpenBlock extends TaskSheetAction {
  const TaskSheetOpenBlock(this.block);

  final PlanBlock block;
}

/// 작은 할 일 시트.
class TaskSheet extends StatelessWidget {
  const TaskSheet({
    super.key,
    required this.kind,
    required this.content,
    required this.onEstimate,
  });

  /// 할 일 종류(머리의 아이콘).
  final TaskKind kind;
  final TaskSheetContent content;

  /// 예상 시간 칩을 골랐을 때(분). 시트는 닫지 않는다.
  final ValueChanged<int> onEstimate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const size = Size.fromHeight(AppSize.minTouch);
    final estimate = content.estimate;
    final video = content.video;
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
          Row(
            children: [
              AppIcon(taskKindIcon(kind), size: 14, color: colors.icon),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  content.kicker,
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Semantics(
            header: true,
            child: Text(content.title, style: AppText.title),
          ),
          const SizedBox(height: 2),
          Text(
            content.due,
            style: AppText.small.copyWith(
              color: content.dueUrgent ? colors.alert : colors.ink2,
              fontWeight: content.dueUrgent
                  ? AppText.semibold
                  : AppText.regular,
            ),
          ),
          if (video != null) ...[
            const SizedBox(height: AppSpace.s4),
            Text(video, style: AppText.small.copyWith(color: colors.ink2)),
          ],
          if (content.estimateChoices.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            _Label('예상 시간'),
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final minutes in content.estimateChoices)
                  _EstimateChip(
                    label: durationText(minutes),
                    selected: minutes == estimate,
                    onTap: () => onEstimate(minutes),
                  ),
              ],
            ),
            if (content.estimateNote case final note?) ...[
              const SizedBox(height: AppSpace.s8),
              Text(note, style: AppText.caption.copyWith(color: colors.muted)),
            ],
          ],
          const SizedBox(height: AppSpace.s16),
          _Label('계획'),
          const SizedBox(height: AppSpace.s4),
          if (content.blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text(
                '아직 놓인 시간이 없어요',
                style: AppText.small.copyWith(color: colors.muted),
              ),
            )
          else
            for (final line in content.blocks) _BlockRow(line: line),
          const SizedBox(height: AppSpace.s16),
          if (content.remaining) ...[
            Press(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(const TaskSheetComplete()),
                style: FilledButton.styleFrom(minimumSize: size),
                child: const Text('끝내기'),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
          ],
          Press(
            child: OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(const TaskSheetRemove()),
              style: OutlinedButton.styleFrom(
                minimumSize: size,
                foregroundColor: colors.ink2,
              ),
              child: Text(content.lms ? '숨기기' : '지우기'),
            ),
          ),
          if (content.lms) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              '숨겨도 LMS에서는 그대로예요',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.caption.copyWith(
      fontWeight: AppText.semibold,
      color: AppColors.of(context).ink2,
    ),
  );
}

/// 예상 시간 칩 하나. 고른 값은 진하게 칠한다.
class _EstimateChip extends StatelessWidget {
  const _EstimateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '예상 $label',
      excludeSemantics: true,
      child: Press(
        child: Material(
          color: selected ? colors.strong : colors.surface,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? colors.strong : colors.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: selected ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.minTouch,
                minWidth: 64,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppText.body.copyWith(
                      fontSize: 14,
                      fontWeight: AppText.semibold,
                      color: selected ? colors.onStrong : colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 이 할 일의 블록 한 줄. 누르면 근거 시트를 연다.
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.line});

  final TaskSheetBlock line;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final glyph = switch (line.kind) {
      TaskSheetBlockKind.suggested => SizedBox(
        width: 10,
        height: 10,
        child: DashedBorder(
          color: colors.taskInk,
          radius: 3,
          child: const SizedBox.expand(),
        ),
      ),
      TaskSheetBlockKind.now => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colors.strong, shape: BoxShape.circle),
      ),
      TaskSheetBlockKind.confirmed => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: colors.taskInk, width: 1.5),
        ),
      ),
    };
    return Semantics(
      button: true,
      label: '${line.text}, 근거 보기',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(TaskSheetOpenBlock(line.block)),
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Row(
            children: [
              SizedBox(width: 13, child: Center(child: glyph)),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  line.text,
                  style: AppText.small.copyWith(color: colors.ink2),
                ),
              ),
              AppIcon(AppIconName.chevronRight, size: 16, color: colors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
