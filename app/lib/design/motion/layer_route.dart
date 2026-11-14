// layer 프리셋. docs/architecture.md '모션 프리셋'.
//
// 전체 화면 덮개(06 AI 비서의 직접 추가 폼 등)를 오른쪽에서 밀어 넣고(550ms, `ease.emphasized`), 닫으면
// 오른쪽으로 내보낸다. 라우트 표에 없는 화면을 지금 화면 위에 덮을 때 `Navigator.push`로 쓴다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// [builder]의 화면을 덮개로 여는 라우트. [motion]은 여는 곳의 `MotionScope.of(context)`다(라우트의
/// 시간은 만들 때 정해지므로).
PageRoute<T> layerRoute<T>({
  required WidgetBuilder builder,
  required MotionLevel motion,
  RouteSettings? settings,
}) => PageRouteBuilder<T>(
  settings: settings,
  transitionDuration: motion.duration(AppMotion.layer),
  reverseTransitionDuration: motion.duration(AppMotion.layer),
  pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: AppEase.emphasized,
                reverseCurve: AppEase.emphasized.flipped,
              ),
            ),
        child: child,
      ),
);
