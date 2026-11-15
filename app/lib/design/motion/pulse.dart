// pulse 프리셋. docs/architecture.md '모션 프리셋'.
//
// 02 홈 '지금 할 일' 카드의 점 뒤에서 퍼지는 고리다. [AppMotion.pulseScaleFrom]에서 [AppMotion.pulseScaleTo]
// 까지 커지며 투명해지기를 1.8초마다 되풀이한다(`ease-out`). 모션 등급이 off(화면 테스트)면 움직이지 않고
// 고리를 그리지 않는다(되풀이하는 애니메이션은 테스트의 pumpAndSettle을 끝나지 않게 하므로).

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// [child](고리)를 퍼지며 사라지게 되풀이한다. 점은 부르는 쪽이 이 위에 겹쳐 그린다.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});

  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );
  MotionLevel _motion = MotionLevel.full;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = MotionScope.of(context);
    if (_motion == MotionLevel.off) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_motion == MotionLevel.off) {
      return Opacity(opacity: 0, child: widget.child);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = AppEase.pulse.transform(_controller.value);
        final scale =
            AppMotion.pulseScaleFrom +
            (AppMotion.pulseScaleTo - AppMotion.pulseScaleFrom) * t;
        return Opacity(
          opacity: AppMotion.pulseOpacityFrom * (1 - t),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}
