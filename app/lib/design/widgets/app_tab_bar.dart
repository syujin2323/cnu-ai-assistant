// 하단 탭바(단순판). docs/architecture.md '화면 이동', '디자인 토큰', '모션 프리셋'.
//
// 흰색 32%에 blur 18px인 유리 알약 위에 탭을 같은 너비로 놓는다. 유리 효과는 이 탭바
// 한 곳에서만 쓰고, 모션 등급이 `full`이 아니면 유리 대신 흰 배경으로 그린다([glass]).
// 탭 모션(navDrop·navIconPop)과 활성 표시의 모양 바꾸기는 R0 모션 PR에서 더한다.
// 탭바 옆의 'AI 비서에게 말하기' 둥근 버튼은 그 아이콘 SVG가 들어올 때 더한다.

import 'dart:ui' show ImageFilter;

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 탭 하나의 라벨과 아이콘.
class AppTabItem {
  const AppTabItem({required this.label, required this.icon});

  final String label;
  final AppIconName icon;
}

/// 화면 아래에 떠 있는 하단 탭바. 누를 영역은 탭마다 48pt 이상이다.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    this.glass = true,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// true면 유리(흰색 32% + blur), false면 흰 배경.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? AppGlass.fill : AppColors.bg,
        borderRadius: radius,
        border: Border.all(color: AppColors.edge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _TabButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
    if (glass) {
      bar = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppGlass.blur, sigmaY: AppGlass.blur),
        child: bar,
      );
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.s8,
          AppSpace.screen,
          AppSpace.s8,
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: '주요 메뉴',
          child: ClipRRect(
            borderRadius: radius,
            child: Material(type: MaterialType.transparency, child: bar),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    final labelColor = selected ? AppColors.accent : AppColors.muted;
    final iconColor = selected ? AppColors.accent : AppColors.icon;
    // 탭마다 따로 읽히도록 container로 묶는다(라벨은 아래 글자, 누르기는 InkWell).
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? AppColors.tint : null,
              borderRadius: radius,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(item.icon, size: AppSize.tabIcon, color: iconColor),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(
                        fontWeight: AppText.medium,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
