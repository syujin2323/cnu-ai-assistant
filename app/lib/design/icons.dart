// 아이콘. docs/architecture.md '앱 코드 규약'.
//
// 캔버스의 SVG 원본을 `assets/icons/*.svg`에 두고 `flutter_svg`로 그린다. SVG는
// `stroke="currentColor"`이므로 색은 `colorFilter`로 입힌다. 화면 코드는 SVG 경로나
// `Icons.*`를 직접 쓰지 않고 `AppIcon.<이름>`만 쓴다. 새 아이콘은 SVG를 `assets/icons/`에
// 넣고 [AppIconName]에 한 줄을 더한다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// `assets/icons/`의 아이콘 이름.
enum AppIconName {
  today('assets/icons/today.svg'),
  calendar('assets/icons/calendar.svg'),
  tasks('assets/icons/tasks.svg'),
  me('assets/icons/me.svg'),
  menu('assets/icons/menu.svg'),
  search('assets/icons/search.svg'),
  plus('assets/icons/plus.svg'),
  briefing('assets/icons/briefing.svg'),
  back('assets/icons/back.svg'),
  close('assets/icons/close.svg'),
  agenda('assets/icons/agenda.svg'),
  settings('assets/icons/settings.svg');

  const AppIconName(this.asset);

  /// 에셋 경로.
  final String asset;
}

/// 캔버스 아이콘 하나를 그린다.
///
/// [semanticLabel]이 없으면 장식으로 보고 접근성 트리에서 뺀다. 글자 없는 버튼에 쓸 때는
/// 버튼에 `tooltip`이나 `Semantics(label:)`을 단다.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  });

  const AppIcon.today({
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  }) : name = AppIconName.today;

  const AppIcon.calendar({
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  }) : name = AppIconName.calendar;

  const AppIcon.tasks({
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  }) : name = AppIconName.tasks;

  const AppIcon.me({
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  }) : name = AppIconName.me;

  final AppIconName name;
  final double size;

  /// 선 색. 없으면 주변 `IconTheme`의 색, 그것도 없으면 [AppColors.ink].
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final strokeColor = color ?? IconTheme.of(context).color ?? AppColors.ink;
    return SvgPicture.asset(
      name.asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(strokeColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
