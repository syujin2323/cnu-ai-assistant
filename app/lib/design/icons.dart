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

  /// 하단 탭 옆 'AI 비서에게 말하기' 버튼(말풍선).
  assistant('assets/icons/assistant.svg'),

  // 02 홈과 그 시트·카드(캔버스 '최종 프로토타입'의 아이콘).

  /// 알림.
  bell('assets/icons/bell.svg'),

  /// 새로 고침·다시 확인.
  refresh('assets/icons/refresh.svg'),

  /// 네모 안 체크(했어요).
  checkSquare('assets/icons/check_square.svg'),

  /// 체크(완료 표시, 굵은 선).
  check('assets/icons/check.svg'),

  /// 시계(시각).
  clock('assets/icons/clock.svg'),

  /// 빈 시간(찻잔).
  freeTime('assets/icons/free_time.svg'),

  /// 오른쪽 꺾쇠(더 보기).
  chevronRight('assets/icons/chevron_right.svg'),

  /// 모래시계(시간 부족).
  hourglass('assets/icons/hourglass.svg'),

  /// 위 꺾쇠(접기).
  chevronUp('assets/icons/chevron_up.svg'),

  /// 더하기(놓기).
  plus('assets/icons/plus.svg'),

  /// 이동 시간(버스).
  bus('assets/icons/bus.svg'),

  /// 식사.
  meal('assets/icons/meal.svg'),

  /// 일정·고정 일정(사람).
  person('assets/icons/person.svg'),

  /// 운동 고정 일정(아령).
  exercise('assets/icons/exercise.svg'),

  /// 직접 정한 시간(연필).
  pencil('assets/icons/pencil.svg'),

  /// 급한 순번(깃발).
  flag('assets/icons/flag.svg'),

  /// 안내.
  info('assets/icons/info.svg'),

  /// 되돌리기(돌아가는 화살표).
  undo('assets/icons/undo.svg');

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

  const AppIcon.assistant({
    super.key,
    this.size = AppSize.icon,
    this.color,
    this.semanticLabel,
  }) : name = AppIconName.assistant;

  final AppIconName name;
  final double size;

  /// 선 색. 없으면 주변 `IconTheme`의 색, 그것도 없으면 지금 테마의 `ink`([AppColors.of]).
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final strokeColor =
        color ?? IconTheme.of(context).color ?? AppColors.of(context).ink;
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
