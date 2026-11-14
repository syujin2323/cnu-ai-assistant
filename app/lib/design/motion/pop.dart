// pop 프리셋. docs/architecture.md '모션 프리셋'.
//
// 투명하고 작은 상태([AppMotion.popScaleFrom])에서 원래대로 튀어나온다(550ms, `ease.spring`. 1을 넘어서
// 잠깐 커졌다가 돌아온다). 체크·칩에 쓴다. 처음 그릴 때 튀고, [Pop.trigger]가 바뀔 때마다 처음부터 다시
// 튄다(체크를 켤 때 등).

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// [child]를 튀어나오게 한다.
class Pop extends StatefulWidget {
  const Pop({super.key, required this.child, this.trigger});

  final Widget child;

  /// 바뀌면 처음부터 다시 튄다. null이면 처음 그릴 때만 튄다.
  final Object? trigger;

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  void _run() {
    final motion = MotionScope.of(context);
    if (motion == MotionLevel.off) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = motion.duration(AppMotion.pop)
      ..forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run();
  }

  @override
  void didUpdateWidget(Pop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      // spring은 1을 넘으므로 배율은 잠깐 1보다 커지고, 투명도는 1에서 멈춘다.
      final t = AppEase.spring.transform(_controller.value);
      final scale = AppMotion.popScaleFrom + (1 - AppMotion.popScaleFrom) * t;
      return Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: scale, child: child),
      );
    },
    child: widget.child,
  );
}
