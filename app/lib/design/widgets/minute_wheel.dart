// 돌려서 고르는 분 휠(알람 앱의 시간 고르기처럼). 14 온보딩 3단계의 통학 시간이 쓴다.
//
// 값 목록에서 하나를 고르고, 가운데 줄이 고른 값이다. 화면 낭독은 값과 함께 위·아래로 한 칸씩 바꾸는 동작을 준다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:material_ui/material_ui.dart';

/// 분 휠. [values] 가운데 [value]를 고른 채로 열고, 돌리면 [onChanged]로 알린다.
class MinuteWheel extends StatefulWidget {
  const MinuteWheel({
    super.key,
    required this.label,
    required this.values,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// 화면 낭독용 이름('통학 시간').
  final String label;
  final List<int> values;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// 한 줄의 높이.
  static const double itemExtent = 40;

  @override
  State<MinuteWheel> createState() => _MinuteWheelState();
}

class _MinuteWheelState extends State<MinuteWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: _indexOf(widget.value),
  );

  int _indexOf(int value) {
    final index = widget.values.indexOf(value);
    return index < 0 ? 0 : index;
  }

  void _step(int delta) {
    final next = (_indexOf(widget.value) + delta).clamp(
      0,
      widget.values.length - 1,
    );
    _controller.jumpToItem(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final index = _indexOf(widget.value);
    return Semantics(
      container: true,
      label: widget.label,
      value: durationText(widget.value),
      increasedValue: index < widget.values.length - 1
          ? durationText(widget.values[index + 1])
          : null,
      decreasedValue: index > 0 ? durationText(widget.values[index - 1]) : null,
      onIncrease: widget.enabled && index < widget.values.length - 1
          ? () => _step(1)
          : null,
      onDecrease: widget.enabled && index > 0 ? () => _step(-1) : null,
      child: ExcludeSemantics(
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: SizedBox(
            height: MinuteWheel.itemExtent * 4,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: MinuteWheel.itemExtent,
              onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
              children: [
                for (final minutes in widget.values)
                  Center(
                    child: Text(
                      durationText(minutes),
                      maxLines: 1,
                      style: AppText.bodyLarge.copyWith(
                        color: colors.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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
