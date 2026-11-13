// 하단 탭바(단순판). docs/screens.md '하단 탭과 AI 비서 버튼', docs/architecture.md '화면 이동',
// '디자인 토큰', '모션 프리셋'.
//
// 흰색 32%에 blur 18px인 유리 알약 위에 탭을 같은 너비로 놓고, 그 오른쪽에 'AI 비서에게 말하기'
// 둥근 버튼을 둔다. 유리 효과는 이 탭바와 그 버튼에서만 쓰고, (R1) OS가 투명도를 줄이라고 하면 유리
// 대신 흰 배경으로 그린다([AppTabBar.glass]). 지금 탭만 글자를 그리고, 글자가 없는 탭도 이름을 읽을 수
// 있게 모든 탭에 Semantics 이름을 준다.
// 탭 모션(navDrop·navIconPop), 지금 탭이 넓어지는 배치와 활성 표시의 모양 바꾸기는 R0 모션 PR에서
// 더한다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 탭 하나의 라벨과 아이콘.
class AppTabItem {
  const AppTabItem({required this.label, required this.icon});

  final String label;
  final AppIconName icon;
}

/// 화면 아래에 떠 있는 하단 탭바와 AI 비서 버튼. 누를 영역은 탭마다, 버튼도 48pt 이상이다.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.onAssistant,
    this.glass = true,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// 'AI 비서에게 말하기' 버튼을 눌렀을 때. 셸은 06 AI 비서를 push로 열어, 닫으면 같은 탭으로
  /// 돌아오게 한다.
  final VoidCallback onAssistant;

  /// true면 유리(흰색 32% + blur), false면 흰 배경.
  final bool glass;

  /// 탭 알약과 AI 비서 버튼의 기본 높이(탭 하나의 최소 높이 + 알약 안쪽 여백).
  static const double barHeight = AppSize.minTouch + AppSpace.s4 * 2;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    // 지금 탭의 배경(Ink)은 가장 가까운 Material에 그려진다. 그 Material을 유리 배경 안쪽에 두어,
    // 배경이 blur 아래에 깔려 함께 흐려지거나 알약 밖으로 번지지 않게 한다.
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? AppGlass.fill : colors.bg,
        borderRadius: radius,
        border: Border.all(color: colors.edge),
      ),
      child: Material(
        type: MaterialType.transparency,
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
      ),
    );
    if (glass) {
      bar = BackdropFilter(filter: AppGlass.filter, child: bar);
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
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: '주요 메뉴',
                child: ClipRRect(borderRadius: radius, child: bar),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            _AssistantButton(glass: glass, onTap: onAssistant),
          ],
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
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    final iconColor = selected ? colors.accent : colors.icon;
    // 탭마다 따로 읽히는 버튼으로 묶는다. 지금 탭만 글자를 그리므로 이름은 글자가 아니라
    // Semantics의 label로 주고, 안쪽(글자·InkWell)의 의미는 빼서 두 번 읽히지 않게 한다.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? colors.tint : null,
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
                    if (selected)
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: AppText.small.copyWith(
                          fontWeight: AppText.medium,
                          color: colors.accent,
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

/// 탭 알약 오른쪽의 'AI 비서에게 말하기' 둥근 버튼. 알약과 같은 유리(또는 흰 배경)를 쓴다.
class _AssistantButton extends StatelessWidget {
  const _AssistantButton({required this.glass, required this.onTap});

  final bool glass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget button = Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: glass ? AppGlass.fill : colors.bg,
          shape: BoxShape.circle,
          border: Border.all(color: colors.edge),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: AppTabBar.barHeight,
            child: Center(child: AppIcon.assistant(color: colors.accent)),
          ),
        ),
      ),
    );
    if (glass) {
      button = BackdropFilter(filter: AppGlass.filter, child: button);
    }
    return Semantics(
      container: true,
      button: true,
      label: AppStrings.askAssistant,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: AppStrings.askAssistant,
        excludeFromSemantics: true,
        child: ClipOval(child: button),
      ),
    );
  }
}
