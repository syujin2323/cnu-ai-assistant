// 앱의 바텀 시트를 여는 곳. docs/architecture.md '화면 이동'·'디자인 토큰', docs/screens.md의 각 시트.
//
// 화면 코드는 `showModalBottomSheet`를 직접 부르지 않고 [showAppSheet]를 쓴다. 탭 화면은 탭 가지의
// Navigator 안에 있어서, 기본값으로 열면 시트가 떠 있는 하단 탭바 아래에 깔리고 시트를 연 채 탭을
// 바꿀 수 있다. 그래서 늘 루트 Navigator에 연다. 모양(배경 `sheet`, 위 모서리 32, 뒤 `scrim`)은
// 테마의 `bottomSheetTheme`(`app/theme.dart`)이 정하고, 움직임은 sheet 프리셋(750ms, `ease.emphasized`)이다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// 바텀 시트를 루트 Navigator에 연다. 높이는 내용을 따르고(글자 200%에서도 넘치지 않게
/// `isScrollControlled`), 상태 표시줄은 가리지 않는다(`useSafeArea`). [motion]이 `off`면 움직이지
/// 않고 바로 열고 닫는다. 부르는 곳은 `motionLevelProvider`의 값을 넘긴다.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  MotionLevel motion = MotionLevel.full,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: motion == MotionLevel.off
        ? AnimationStyle.noAnimation
        : AnimationStyle(duration: AppMotion.sheet, curve: AppEase.emphasized),
  );
}
