// 옮기기 시트. docs/screens.md '옮기기 시트'.
//
// 근거 시트의 [옮기기]가 연다(02 홈 블록 손잡이는 끌어 옮기기 PR에서). 보일 것은 `domain/move_sheet.dart`의
// [moveSheetContent]가 정하고, 이 시트는 후보 하나를 고르게 한 뒤 버튼을 누르면 고른 후보를 돌려주고 닫는다.
// 저장과 되돌리기 토스트는 부르는 쪽이 한다. 모양은 최종 프로토타입을 따른다: 제목 '어디로 옮길까요?'와 아래 줄,
// 라디오 카드(때·이유, 처음에는 첫 후보), 후보가 없으면 안내, 주 버튼('{시각}으로 옮기기', 후보가 없으면 '닫기').

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// 옮기기 시트를 연다. 후보를 골라 버튼을 누르면 그 후보, 그 밖에는(닫음, 후보 없음) null이다.
Future<MoveChoice?> showMoveSheet(
  BuildContext context,
  MotionLevel motion,
  MoveSheetContent content,
) => showAppSheet<MoveChoice>(
  context: context,
  motion: motion,
  builder: (context) => MoveSheet(content: content),
);

/// 옮기기 시트의 몸통.
class MoveSheet extends StatefulWidget {
  const MoveSheet({super.key, required this.content});

  final MoveSheetContent content;

  @override
  State<MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<MoveSheet> {
  int _picked = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = widget.content;
    final choices = content.choices;
    final picked = choices.isEmpty
        ? null
        : choices[_picked.clamp(0, choices.length - 1)];
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
          Semantics(
            header: true,
            child: const Text('어디로 옮길까요?', style: AppText.title),
          ),
          const SizedBox(height: 2),
          Text(content.sub, style: AppText.small.copyWith(color: colors.muted)),
          if (choices.isEmpty)
            FormNote(content.noneText)
          else ...[
            const SizedBox(height: 14),
            RadioGroup<int>(
              groupValue: _picked,
              onChanged: (index) {
                if (index != null) setState(() => _picked = index);
              },
              child: Column(
                children: [
                  for (var i = 0; i < choices.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpace.s8),
                    _ChoiceCard(
                      choice: choices[i],
                      index: i,
                      selected: i == _picked,
                      onTap: () => setState(() => _picked = i),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          Press(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(picked),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSize.minTouch),
              ),
              child: Text(picked?.cta ?? '닫기', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

/// 후보 하나: 왼쪽 라디오, 때(굵게)와 이유. 고른 카드는 진한 테두리다.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final MoveChoice choice;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: '${choice.when}, ${choice.why}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.smallCard),
          side: BorderSide(
            color: selected ? colors.strong : colors.edge,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, AppSpace.s16, 10),
              child: Row(
                children: [
                  IgnorePointer(child: Radio<int>(value: index)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          choice.when,
                          style: AppText.body.copyWith(
                            fontWeight: AppText.semibold,
                          ),
                        ),
                        Text(
                          choice.why,
                          style: AppText.small.copyWith(color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
