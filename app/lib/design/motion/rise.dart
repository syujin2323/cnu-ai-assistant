// rise 프리셋. docs/architecture.md '모션 프리셋'.
//
// 처음 그릴 때 투명하고 조금 아래에 작고 흐린 상태에서 원래대로 떠오른다(`ease.emphasized`). 카드·제목,
// 브리핑 화면, 홈 시간표 카드가 값만 달리 쓴다([RiseStyle]). 여러 개를 차례로 띄울 때는 [Rise.delay]에
// stagger 간격(`AppMotion.staggerList` 등)을 곱해 넘긴다. 떠오르는 동안에도 누를 수 있다.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// rise의 시간과 크기.
enum RiseStyle {
  /// 카드·제목.
  card(
    AppMotion.rise,
    AppMotion.riseOffset,
    AppMotion.riseScaleFrom,
    AppMotion.riseBlur,
  ),

  /// 01 계획 화면.
  briefing(
    AppMotion.riseBriefing,
    AppMotion.riseOffset,
    AppMotion.riseScaleFrom,
    AppMotion.riseBlur,
  ),

  /// 02 홈 시간표 카드.
  homeCard(
    AppMotion.riseHomeCard,
    AppMotion.riseHomeCardOffset,
    AppMotion.riseHomeCardScaleFrom,
    AppMotion.riseHomeCardBlur,
  );

  const RiseStyle(this.duration, this.offset, this.scaleFrom, this.blur);

  final Duration duration;

  /// 처음 아래로 내려가 있는 거리(pt).
  final double offset;

  /// 처음 배율.
  final double scaleFrom;

  /// 처음 흐림(시그마. CSS `blur()`의 표준편차와 같음).
  final double blur;
}

/// [child]를 처음 그릴 때 떠오르게 한다.
class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.child,
    this.style = RiseStyle.card,
    this.delay = Duration.zero,
  });

  final Widget child;
  final RiseStyle style;

  /// 떠오르기 시작할 때까지 기다리는 시간. 그동안은 처음 상태(투명)다.
  final Duration delay;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = MotionScope.of(context);
    if (motion == MotionLevel.off) {
      _controller.value = 1;
      return;
    }
    _controller.duration = motion.duration(widget.style.duration);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final style = widget.style;
      final t = AppEase.emphasized.transform(_controller.value);
      final blur = style.blur * (1 - t);
      final scale = style.scaleFrom + (1 - style.scaleFrom) * t;
      Widget result = Transform(
        alignment: Alignment.center,
        transform: Matrix4.translationValues(0, style.offset * (1 - t), 0)
          ..scaleByDouble(scale, scale, 1, 1),
        child: child,
      );
      if (blur > 0.01) {
        result = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.decal,
          ),
          child: result,
        );
      }
      return Opacity(opacity: t.clamp(0, 1), child: result);
    },
    child: widget.child,
  );
}
