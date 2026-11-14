// 앱의 바텀 시트를 여는 곳. docs/architecture.md '화면 이동'·'디자인 토큰', docs/screens.md의 각 시트.
//
// 화면 코드는 `showModalBottomSheet`를 직접 부르지 않고 [showAppSheet]를 쓴다. 탭 화면은 탭 가지의
// Navigator 안에 있어서, 기본값으로 열면 시트가 떠 있는 하단 탭바 아래에 깔리고 시트를 연 채 탭을
// 바꿀 수 있다. 그래서 늘 루트 Navigator에 연다. 모양(배경 `sheet`, 위 모서리 32, 뒤 `scrim`)은
// 테마의 `bottomSheetTheme`(`app/theme.dart`)이 정하고, 움직임은 sheet 프리셋(750ms, `ease.emphasized`)이다.
//
// 시트 위에는 끌기 손잡이를 둔다(docs/decisions.md 2026-11-14 '시트는 끌기 손잡이로도 닫는다'). 글자를 키워
// 시트가 화면을 다 덮으면 바깥을 누를 수 없고, 아래로 끌어도 안쪽 스크롤이 먼저 받으며 iOS에는 뒤로 버튼이
// 없어 시트 안의 버튼 말고는 닫을 길이 없기 때문이다. 시트는 화면 아래 끝까지 그려지므로(Android 15부터는
// 내비게이션 바 밑까지) 내용은 아래 시스템 영역(내비게이션 바·홈 표시줄)만큼 띄우고 배경만 끝까지 그린다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:material_ui/material_ui.dart';

/// 바텀 시트를 루트 Navigator에 연다. 높이는 내용을 따르고(글자 200%에서도 넘치지 않게
/// `isScrollControlled`), 상태 표시줄은 가리지 않으며(`useSafeArea`), 내용은 아래 시스템 영역 위에 둔다.
/// 위에는 끌기 손잡이가 있다. [motion]이 `off`면 움직이지 않고 바로 열고 닫는다. 부르는 곳은
/// `motionLevelProvider`의 값을 넘긴다.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  MotionLevel motion = MotionLevel.full,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (context) => SafeArea(top: false, child: builder(context)),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: motion == MotionLevel.off
        ? AnimationStyle.noAnimation
        : AnimationStyle(duration: AppMotion.sheet, curve: AppEase.emphasized),
  );
}
