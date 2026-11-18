// 빈 시간에 놓기 시트. docs/screens.md '빈 시간에 놓기 시트'.
//
// 02 홈의 빈 시간 카드와 피드백 카드 [빈 시간에 할 일 놓기]가 연다(09 일간과 06 AI 비서의 빈 시간 답도 같은 것을
// 쓴다). 보일 것은 `domain/move_sheet.dart`의 [freeSlotContent]가 정하고, 이 시트는 할 일 줄을 누르거나
// [일정은 말로 추가하기]를 누르면 그것을 돌려주고 닫는다. 저장과 되돌리기 토스트, 06 AI 비서 열기는 부르는 쪽이
// 한다. 06 AI 비서 안에서 열면 [일정은 말로 추가하기]를 두지 않는다([FreeSlotSheet.speech]). 모양은 최종 프로토타입을 따른다: 제목('15:00–16:30 · 1시간 30분 비어 있어요')과 안내 한 줄, 할 일 줄(점,
// 이름과 종류·마감, 오른쪽에 놓을 길이), 보조 버튼. 놓을 할 일이 없을 때의 안내는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 빈 시간에 놓기 시트에서 고른 것.
sealed class FreeSlotPick {
  const FreeSlotPick();
}

/// 할 일 [choice]를 놓는다.
final class FreeSlotPlace extends FreeSlotPick {
  const FreeSlotPlace(this.choice);

  final FreeSlotChoice choice;
}

/// [일정은 말로 추가하기].
final class FreeSlotSpeak extends FreeSlotPick {
  const FreeSlotSpeak();
}

/// 빈 시간에 놓기 시트를 연다. [speech]가 false면 [일정은 말로 추가하기]를 두지 않는다. 닫으면 null이다.
Future<FreeSlotPick?> showFreeSlotSheet(
  BuildContext context,
  MotionLevel motion,
  FreeSlotContent content, {
  bool speech = true,
}) => showAppSheet<FreeSlotPick>(
  context: context,
  motion: motion,
  builder: (context) => FreeSlotSheet(content: content, speech: speech),
);

/// 빈 시간에 놓기 시트의 몸통.
class FreeSlotSheet extends StatelessWidget {
  const FreeSlotSheet({super.key, required this.content, this.speech = true});

  final FreeSlotContent content;

  /// [일정은 말로 추가하기]를 둘지. 06 AI 비서 안에서 열면 false다(06 위에 06을 또 열지 않게).
  final bool speech;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final choices = content.choices;
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
            child: Text(content.title, style: AppText.title),
          ),
          const SizedBox(height: 2),
          Text(
            '무엇을 놓을까요? 직접 놓은 시간은 확정으로 저장해요',
            style: AppText.small.copyWith(color: colors.muted),
          ),
          if (choices.isEmpty)
            const FormNote('이 시간에 놓을 남은 할 일이 없어요')
          else ...[
            const SizedBox(height: 14),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.listGroup),
                side: BorderSide(color: colors.edge),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < choices.length; i++) ...[
                    if (i > 0)
                      SizedBox(
                        height: 1,
                        child: ColoredBox(color: colors.edge),
                      ),
                    _ChoiceRow(choice: choices[i]),
                  ],
                ],
              ),
            ),
          ],
          if (speech) ...[
            const SizedBox(height: AppSpace.s12),
            Press(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(const FreeSlotSpeak()),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSize.minTouch),
                ),
                icon: const AppIcon(AppIconName.assistant, size: 17),
                label: const Text('일정은 말로 추가하기', textAlign: TextAlign.center),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 할 일 줄 하나: 점, 이름과 종류·마감, 오른쪽에 놓을 길이. 누르면 그 할 일을 놓는다.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice});

  final FreeSlotChoice choice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final length = durationText(choice.minutes);
    void pick() => Navigator.of(context).pop(FreeSlotPlace(choice));
    return Semantics(
      container: true,
      button: true,
      label: '${choice.title}, ${choice.sub}, $length 놓기',
      excludeSemantics: true,
      onTap: pick,
      child: InkWell(
        onTap: pick,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: 10,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.taskInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontWeight: AppText.medium,
                        ),
                      ),
                      Text(
                        choice.sub,
                        style: AppText.caption.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Text(
                  length,
                  style: AppText.small.copyWith(
                    fontWeight: AppText.semibold,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
