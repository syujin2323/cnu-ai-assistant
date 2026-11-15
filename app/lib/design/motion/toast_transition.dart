// toast 프리셋의 등장과 퇴장. docs/architecture.md '모션 프리셋'.
//
// 토스트는 아래 [AppMotion.toastOffset]에서 올라오고(450ms, `AppEase.toast`. 1을 넘어 살짝 튐), 투명도는
// 300ms(`AppEase.fade`) 동안 바뀐다. 사라질 때는 같은 시간과 곡선으로 그때 값에서 내려간다(프로토타입의 CSS
// 전환, [TransitionValue]). 다 사라진 뒤에는 그리지 않고, 사라지는 동안과 그 뒤에는 누르거나 읽히지 않는다.
// 토스트를 얼마나 보일지(3.4초, 되돌리기가 있으면 10초)는 토스트 위젯이 정한다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/transition_value.dart';
import 'package:material_ui/material_ui.dart';

/// [visible]이 바뀌면 [child]를 올리거나 내린다.
class ToastTransition extends StatefulWidget {
  const ToastTransition({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<ToastTransition> createState() => _ToastTransitionState();
}

class _ToastTransitionState extends State<ToastTransition>
    with TickerProviderStateMixin {
  late final TransitionValue _slide = TransitionValue(
    vsync: this,
    curve: AppEase.toast,
    initial: 0,
  );
  late final TransitionValue _fade = TransitionValue(
    vsync: this,
    curve: AppEase.fade,
    initial: 0,
  );
  bool _started = false;

  void _apply() {
    final motion = MotionScope.of(context);
    final target = widget.visible ? 1.0 : 0.0;
    _slide.animateTo(target, motion.duration(AppMotion.toastIn));
    _fade.animateTo(target, motion.duration(AppMotion.toastFade));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // 처음부터 보이게 그리면 올라오며 나타난다.
    if (widget.visible) _apply();
  }

  @override
  void didUpdateWidget(ToastTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _apply();
  }

  @override
  void dispose() {
    _slide.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_slide.listenable, _fade.listenable]),
    builder: (context, child) {
      // 올라오는 곡선은 1을 넘으므로 내려가는 도중에도 값이 0을 지나칠 수 있다. 다 내려갔는지는 끝났는지로 본다.
      final gone = !widget.visible && _slide.settled && _fade.settled;
      return Visibility(
        visible: !gone,
        maintainState: true,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: Opacity(
            opacity: _fade.value.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, AppMotion.toastOffset * (1 - _slide.value)),
              child: child,
            ),
          ),
        ),
      );
    },
    child: widget.child,
  );
}
