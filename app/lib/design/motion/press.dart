// press 프리셋. docs/architecture.md '모션 프리셋'.
//
// 누르는 동안 [AppMotion.pressScale]로 줄고 떼면 돌아온다(180ms, `ease.emphasized`). 프로토타입의 버튼
// `:active` 전환과 같아서, 줄 때와 돌아올 때 모두 그때 크기에서 빠르게 출발해 천천히 멈춘다
// ([TransitionValue]). 누름은 포인터만 보고 제스처를 가로채지 않으므로 안쪽 버튼의 탭·길게 누르기는 그대로다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/transition_value.dart';
import 'package:material_ui/material_ui.dart';

/// 누르는 동안 [child]를 조금 줄인다. 모든 버튼에 쓴다.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// false면 줄지 않는다(막힌 버튼).
  final bool enabled;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> with SingleTickerProviderStateMixin {
  late final TransitionValue _scale = TransitionValue(
    vsync: this,
    curve: AppEase.emphasized,
    initial: 1,
  );

  void _press(bool down) {
    if (down && !widget.enabled) return;
    _scale.animateTo(
      down ? AppMotion.pressScale : 1,
      MotionScope.of(context).duration(AppMotion.press),
    );
  }

  @override
  void didUpdateWidget(Press oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _scale.target != 1) {
      _scale.animateTo(1, Duration.zero);
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _press(true),
    onPointerUp: (_) => _press(false),
    onPointerCancel: (_) => _press(false),
    child: AnimatedBuilder(
      animation: _scale.listenable,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    ),
  );
}
