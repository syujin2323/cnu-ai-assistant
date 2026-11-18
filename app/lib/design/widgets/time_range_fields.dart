// 시작·끝 시각을 단계 버튼으로 고르는 칸. docs/screens.md '13 시간표·고정 일정'의 수업 시트(15분 단위)와 고정
// 일정 시트, '14 온보딩' 3단계의 작은 폼, '직접 추가 폼'의 반복 일정이 함께 쓴다. 시각은 폰 DB처럼 자정 기준
// 분이고, 자정을 넘는 끝은 1440을 더해 받는다(화면에는 '다음 날 01:00'). 시작을 끝과 같거나 늦게 옮기면 끝도
// 함께 옮긴다(최종 프로토타입).

import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 시작·끝 두 줄. 시작은 [startLow]–[startHigh], 끝은 시작보다 [step] 이상 늦고 [endHigh] 이하다.
class TimeRangeFields extends StatelessWidget {
  const TimeRangeFields({
    super.key,
    required this.startMin,
    required this.endMin,
    required this.onChanged,
    this.startLow = 0,
    this.startHigh = 1425,
    this.endHigh = 1440,
    this.step = 15,
  });

  final int startMin;

  final int endMin;

  /// 바뀐 (시작, 끝)을 받는다. null이면 바꿀 수 없다.
  final void Function(int startMin, int endMin)? onChanged;

  final int startLow;

  final int startHigh;

  /// 끝의 가장 늦은 값. 1440을 넘으면 자정을 넘는 끝을 받는다.
  final int endHigh;

  /// 한 번 누를 때 옮기는 분.
  final int step;

  /// 끝 시각 'HH:MM'. 자정을 넘으면 '다음 날 HH:MM'이다.
  static String endText(int endMin) =>
      endMin <= 1440 ? hhmmText(endMin) : '다음 날 ${hhmmText(endMin - 1440)}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;
    void setStart(int start) {
      final end = endMin <= start ? start + step : endMin;
      onChanged?.call(start, end > endHigh ? endHigh : end);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        children: [
          StepperRow(
            label: '시작',
            value: hhmmText(startMin),
            decLabel: '시작 $step분 앞당기기',
            incLabel: '시작 $step분 늦추기',
            onDec: onChanged != null && startMin - step >= startLow
                ? () => setStart(startMin - step)
                : null,
            onInc: onChanged != null && startMin + step <= startHigh
                ? () => setStart(startMin + step)
                : null,
          ),
          SizedBox(height: 1, child: ColoredBox(color: colors.edge)),
          StepperRow(
            label: '끝',
            value: endText(endMin),
            decLabel: '끝 $step분 앞당기기',
            incLabel: '끝 $step분 늦추기',
            onDec: onChanged != null && endMin - step > startMin
                ? () => onChanged(startMin, endMin - step)
                : null,
            onInc: onChanged != null && endMin + step <= endHigh
                ? () => onChanged(startMin, endMin + step)
                : null,
          ),
        ],
      ),
    );
  }
}

/// 이름, −, 값, + 한 줄. 시작·끝 시각과 고정 일정의 앞뒤 여유가 쓴다. [onDec]·[onInc]가 null이면 그 버튼을 막는다.
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.decLabel,
    required this.incLabel,
    required this.onDec,
    required this.onInc,
  });

  final String label;

  final String value;

  /// 화면 낭독기가 읽는 − 버튼 이름.
  final String decLabel;

  /// 화면 낭독기가 읽는 + 버튼 이름.
  final String incLabel;

  final VoidCallback? onDec;

  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s16,
      AppSpace.s8,
      AppSpace.s8,
      AppSpace.s8,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // 값 칸은 '다음 날 01:00'이 들어갈 만큼(글자 크기를 따름) 두되, 이름 칸에 누르는 칸 하나 너비는 남긴다.
        // 그래도 좁으면 값을 줄여 한 줄로 쓴다.
        final room = constraints.maxWidth - 3 * AppSize.minTouch;
        final want = MediaQuery.textScalerOf(context).scale(112);
        final valueWidth = room <= 0 ? 0.0 : (want < room ? want : room);
        return Row(
          children: [
            Expanded(child: Text(label, style: AppText.body)),
            _StepButton(plus: false, label: decLabel, onTap: onDec),
            SizedBox(
              width: valueWidth,
              child: Semantics(
                liveRegion: true,
                label: '$label $value',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: AppText.bodyLarge.copyWith(
                      fontWeight: AppText.semibold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            _StepButton(plus: true, label: incLabel, onTap: onInc),
          ],
        );
      },
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.plus,
    required this.label,
    required this.onTap,
  });

  final bool plus;

  final String label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .32 : 1,
        child: Press(
          enabled: onTap != null,
          child: Material(
            color: colors.bg,
            shape: CircleBorder(side: BorderSide(color: colors.edge2)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: AppSize.minTouch,
                child: CustomPaint(
                  painter: _StepGlyph(plus: plus, color: colors.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 단계 버튼의 −·+ 모양. 아이콘 에셋 없이 그린다.
class _StepGlyph extends CustomPainter {
  const _StepGlyph({required this.plus, required this.color});

  final bool plus;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    const half = 7.0;
    canvas.drawLine(
      center.translate(-half, 0),
      center.translate(half, 0),
      paint,
    );
    if (plus) {
      canvas.drawLine(
        center.translate(0, -half),
        center.translate(0, half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StepGlyph old) => old.plus != plus || old.color != color;
}
