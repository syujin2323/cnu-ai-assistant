// CSS 전환(transition)처럼 움직이는 값. docs/architecture.md '모션 프리셋'.
//
// 프로토타입은 누름·토스트·탭 표시를 CSS 전환으로 움직인다. CSS 전환은 목표가 바뀌면 그때 값에서 새 목표로
// 같은 곡선을 따라 처음부터 다시 간다. Flutter의 `CurvedAnimation`은 도중에 방향을 바꾸면 앞 곡선을 거꾸로
// 쓰므로(되돌아갈 때 천천히 출발) 그렇게 움직이지 않는다. 이 값은 목표를 바꿀 때마다 지금 값을 출발점으로
// 잡고 0→1로 도는 컨트롤러에 곡선을 걸어 계산한다. 곡선이 1을 넘어도(`ease.spring` 계열) 컨트롤러 밖에서
// 셈하므로 잘리지 않는다.

import 'package:material_ui/material_ui.dart';

/// 목표를 바꿀 때마다 지금 값에서 [curve]를 따라 새 목표로 가는 값.
class TransitionValue {
  TransitionValue({
    required TickerProvider vsync,
    required this.curve,
    required double initial,
  }) : _controller = AnimationController(vsync: vsync, value: 1),
       _from = initial,
       _to = initial;

  final Curve curve;
  final AnimationController _controller;
  double _from;
  double _to;

  /// 지금 값.
  double get value =>
      _from + (_to - _from) * curve.transform(_controller.value);

  /// 지금 목표.
  double get target => _to;

  /// 목표에 닿았는지. 곡선이 1을 넘으면 가는 도중에도 값이 목표를 지나칠 수 있으므로, 끝났는지는 값이
  /// 아니라 이것으로 본다.
  bool get settled => _controller.value == 1;

  /// 값이 바뀔 때 알린다.
  Listenable get listenable => _controller;

  /// 지금 값에서 [target]으로 [duration] 동안 간다. [duration]이 0이면 바로 그 값이 된다.
  void animateTo(double target, Duration duration) {
    _from = value;
    _to = target;
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  void dispose() => _controller.dispose();
}
