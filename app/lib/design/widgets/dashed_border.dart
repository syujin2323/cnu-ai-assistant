// 점선 둥근 테두리. docs/screens.md '할 일 블록'(시간을 옮길 수 있는 할 일 블록은 점선), 빈 시간 카드.
//
// Flutter의 `Border`는 점선을 그리지 못해 둥근 사각형의 테두리 경로를 잘라 그린다. 점과 틈의 길이는 웹 브라우저의
// `border-style: dashed`에 가깝게 선 굵기의 배수로 둔다(최종 프로토타입이 CSS 점선이므로).

import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

/// [child] 뒤에 점선 둥근 테두리와 배경을 그린다.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.color,
    required this.radius,
    this.width = 1.5,
    this.background,
    required this.child,
  });

  final Color color;
  final double radius;
  final double width;

  /// 테두리 안의 배경. 없으면 비워 둔다.
  final Color? background;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: DashedBorderPainter(
      color: color,
      radius: radius,
      width: width,
      background: background,
    ),
    child: child,
  );
}

/// 점선 둥근 테두리 그리기. [DashedBorder]가 쓰고, 테스트가 값을 본다.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.width,
    this.background,
  });

  final Color color;
  final double radius;
  final double width;
  final Color? background;

  /// 점 하나의 길이(선 굵기의 배수).
  double get dash => width * 3;

  /// 점 사이 틈(선 굵기의 배수).
  double get gap => width * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    if (background case final fill?) {
      canvas.drawRRect(rect, Paint()..color = fill);
    }
    final inset = rect.deflate(width / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final PathMetric metric
        in (Path()..addRRect(inset)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.width != width ||
      oldDelegate.background != background;
}
