// 앱 바인딩. docs/architecture.md '모션 프리셋', docs/decisions.md 2026-11-14 'OS의 애니메이션 끄기 신호는
// 앱 전체에서 무시한다'.
//
// 모션은 모든 사람에게 같다(docs/decisions.md 2026-11-13 '모션은 모든 사람에게 같게 보인다'). 그런데 Android
// '애니메이션 삭제'를 켜면 Flutter는 OS의 애니메이션 끄기 신호(`SemanticsBinding.disableAnimations`)를 보고
// 기본 동작(`AnimationBehavior.normal`)인 `AnimationController`를 모두 원래 시간의 5%로 돌린다. 시트·화면 전환·
// 모션 프리셋은 거의 한 프레임에 끝나고 스크롤로 움직이는 온보딩 PageView는 그대로라, 앱 바인딩에서 이 신호를
// 늘 false로 본다.
// 위젯이 보는 `MediaQueryData.disableAnimations`는 플랫폼 값을 따로 읽으므로 `RootApp`이 false로 덮어쓴다.

import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:material_ui/material_ui.dart';

/// OS의 애니메이션 끄기 신호를 늘 false로 보는 바인딩 조각. 앱 바인딩([AppBinding])과, 같은 동작을
/// 시험하는 테스트 바인딩이 섞어 쓴다.
mixin IgnoreOsDisableAnimations on SemanticsBinding {
  @override
  bool get disableAnimations => false;
}

/// 앱 바인딩. 바인딩은 한 번만 만들 수 있으므로 `main`의 맨 처음에 [install]로 만든다. 그 뒤의
/// `WidgetsFlutterBinding.ensureInitialized()`와 `runApp`은 이 바인딩을 그대로 쓴다.
class AppBinding extends WidgetsFlutterBinding with IgnoreOsDisableAnimations {
  /// 앱 바인딩을 만든다. 다른 코드가 바인딩을 만들기 전에 한 번만 부른다.
  static void install() {
    AppBinding();
  }
}
