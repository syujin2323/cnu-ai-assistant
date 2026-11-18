// '얼마나 걸렸어요?' 시트. docs/screens.md '03 할 일'.
//
// 첫 화면은 걸린 시간 칩과 [건너뛰기]이고, 고른 시간이 예상과 크게 다르면 같은 시트가 둘째 화면(다음 예상을 바꿀지)
// 으로 바뀐다. 모양과 문구는 최종 프로토타입(03 할 일의 '걸린 시간 기록' 시트)이고, 문구는 `domain/task_took.dart`가
// 정한다. 시트는 저장하지 않고 고른 것만 돌려준다([showTookSheet]).

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/pop.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/domain/task_took.dart';
import 'package:material_ui/material_ui.dart';

/// 시트에서 고른 것. 건너뛰었거나 칩을 고르기 전에 닫았으면 [minutes]가 null이다.
final class TookOutcome {
  const TookOutcome({this.minutes, this.ask, this.saveEstimate = false});

  /// 고른 걸린 시간(분).
  final int? minutes;

  /// 다음 예상을 바꿀지 물었으면 그 물음.
  final EstimateAsk? ask;

  /// [그렇게 할게요]를 눌렀는지.
  final bool saveEstimate;
}

/// '얼마나 걸렸어요?' 시트를 연다. [askFor]는 고른 시간으로 다음 예상을 바꿀지 물을 것을 준다(묻지 않으면 null).
Future<TookOutcome> showTookSheet(
  BuildContext context,
  MotionLevel motion, {
  required TookSheetContent content,
  required EstimateAsk? Function(int minutes) askFor,
}) async {
  int? picked;
  EstimateAsk? asked;
  final save = await showAppSheet<bool>(
    context: context,
    motion: motion,
    builder: (context) => TookSheet(
      content: content,
      askFor: (minutes) {
        picked = minutes;
        return asked = askFor(minutes);
      },
    ),
  );
  return TookOutcome(minutes: picked, ask: asked, saveEstimate: save == true);
}

/// '얼마나 걸렸어요?' 시트. [건너뛰기]·[이번만이에요]는 false, [그렇게 할게요]는 true로 닫고, 묻지 않는 시간을
/// 고르면 false로 닫는다.
class TookSheet extends StatefulWidget {
  const TookSheet({super.key, required this.content, required this.askFor});

  final TookSheetContent content;
  final EstimateAsk? Function(int minutes) askFor;

  @override
  State<TookSheet> createState() => _TookSheetState();
}

class _TookSheetState extends State<TookSheet> {
  EstimateAsk? _ask;

  void _pick(int minutes) {
    final ask = widget.askFor(minutes);
    if (ask == null) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _ask = ask);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ask = _ask;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: ask == null ? _first(context) : _second(context, ask),
    );
  }

  Widget _first(BuildContext context) {
    final colors = AppColors.of(context);
    final content = widget.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pop(child: _Kicker(content.kicker)),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: const Text('얼마나 걸렸어요?', style: AppText.title),
        ),
        const SizedBox(height: 2),
        Text(content.sub, style: AppText.small.copyWith(color: colors.muted)),
        const SizedBox(height: AppSpace.s16),
        Semantics(
          container: true,
          label: '걸린 시간',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < content.choices.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: _Chip(
                    label: content.choices[i].label,
                    onTap: () => _pick(content.choices[i].minutes),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSize.minTouch),
            foregroundColor: colors.ink2,
          ),
          child: const Text('건너뛰기'),
        ),
      ],
    );
  }

  Widget _second(BuildContext context, EstimateAsk ask) {
    final colors = AppColors.of(context);
    const size = Size.fromHeight(AppSize.minTouch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Kicker(ask.kicker),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text(ask.title, style: AppText.title),
              ),
              const SizedBox(height: 2),
              Text(ask.sub, style: AppText.small.copyWith(color: colors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Rise(
          delay: const Duration(milliseconds: 80),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.tint,
              borderRadius: BorderRadius.circular(AppRadius.notice),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppIcon(AppIconName.rule, size: 16, color: colors.ink2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ask.ruleSentence,
                      style: AppText.small.copyWith(color: colors.ink2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Rise(
          delay: const Duration(milliseconds: 140),
          child: Row(
            children: [
              Expanded(
                child: Press(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(minimumSize: size),
                    child: const Text('이번만이에요', textAlign: TextAlign.center),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Press(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(minimumSize: size),
                    child: const Text('그렇게 할게요', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 체크 아이콘과 머리 한 줄(강조색).
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        AppIcon(AppIconName.check, size: 14, color: colors.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: AppText.caption.copyWith(
              fontWeight: AppText.semibold,
              color: colors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

/// 걸린 시간 칩 하나.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Press(
      child: Material(
        color: colors.surface,
        shape: StadiumBorder(side: BorderSide(color: colors.edge)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    fontSize: 14,
                    fontWeight: AppText.semibold,
                    color: colors.accent,
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
