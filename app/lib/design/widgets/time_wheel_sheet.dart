// 시각을 시·분 휠로 고르는 시트(알람 앱의 시간 고르기처럼). 단계 버튼(−·+)으로 맞추기 어려운 시각을 고를 때
// 값 칸을 누르면 연다. 06 AI 비서의 직접 추가 폼(일정·반복 일정의 시작·끝, 할 일의 마감 시각)이 쓴다.
//
// 시각은 자정 기준 분이고 [low]–[high] 안에서 [step]분 단위로 고른다. 1440을 넘는 값(자정을 넘는 끝)은 시 휠에
// '다음 날 01'처럼 쓴다. 범위를 벗어난 조합(시 휠의 처음·마지막 시)은 [확인] 때 범위 안으로 맞춘다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:material_ui/material_ui.dart';

/// 시각 휠 시트를 열고 고른 시각(자정 기준 분)을 돌려준다. 그냥 닫으면 null이다.
Future<int?> showTimeWheelSheet(
  BuildContext context, {
  required String title,
  required int initial,
  required int low,
  required int high,
  int step = 5,
}) => showAppSheet<int>(
  context: context,
  motion: MotionScope.of(context),
  builder: (context) => TimeWheelSheet(
    title: title,
    initial: initial,
    low: low,
    high: high,
    step: step,
  ),
);

/// [initial]을 [low]–[high] 안의 [step]분 단위 값으로 맞춘다(가까운 쪽으로).
int snapTimeWheel(
  int value, {
  required int low,
  required int high,
  int step = 5,
}) {
  final first = (low / step).ceil() * step;
  final last = (high / step).floor() * step;
  final snapped = (value / step).round() * step;
  return snapped < first ? first : (snapped > last ? last : snapped);
}

/// 시·분 휠과 [확인].
class TimeWheelSheet extends StatefulWidget {
  const TimeWheelSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.low,
    required this.high,
    this.step = 5,
  });

  final String title;
  final int initial;
  final int low;
  final int high;
  final int step;

  static const double itemExtent = 40;

  @override
  State<TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<TimeWheelSheet> {
  late final int _firstHour = widget.low ~/ 60;
  late final int _lastHour = widget.high ~/ 60;
  late int _value = snapTimeWheel(
    widget.initial,
    low: widget.low,
    high: widget.high,
    step: widget.step,
  );
  late final _hours = FixedExtentScrollController(
    initialItem: _value ~/ 60 - _firstHour,
  );
  late final _minutes = FixedExtentScrollController(
    initialItem: (_value % 60) ~/ widget.step,
  );

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _pick() {
    final hour = _firstHour + _hours.selectedItem;
    final minute = _minutes.selectedItem * widget.step;
    setState(
      () => _value = snapTimeWheel(
        hour * 60 + minute,
        low: widget.low,
        high: widget.high,
        step: widget.step,
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _hourText(int hour) =>
      hour >= 24 ? '다음 날 ${_two(hour - 24)}' : _two(hour);

  String get _valueText => '${_hourText(_value ~/ 60)}:${_two(_value % 60)}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppText.bodyLarge.copyWith(
      color: colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget wheel(FixedExtentScrollController controller, List<String> labels) =>
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: TimeWheelSheet.itemExtent,
            onSelectedItemChanged: (_) => _pick(),
            children: [
              for (final label in labels)
                Center(child: Text(label, maxLines: 1, style: style)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        0,
        AppSpace.s20,
        AppSpace.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${widget.title} $_valueText',
              style: AppText.title.copyWith(fontWeight: AppText.semibold),
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          SizedBox(
            height: TimeWheelSheet.itemExtent * 4,
            child: Row(
              children: [
                wheel(_hours, [
                  for (var h = _firstHour; h <= _lastHour; h++)
                    '${_hourText(h)}시',
                ]),
                wheel(_minutes, [
                  for (var m = 0; m < 60; m += widget.step) '${_two(m)}분',
                ]),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_value),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
