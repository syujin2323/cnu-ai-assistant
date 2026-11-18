// 아이콘. docs/architecture.md '앱 코드 규약'.
//
// 캔버스의 SVG 원본을 `design/icon_svgs.dart`에 Dart 문자열로 두고 `flutter_svg`로 그린다(에셋이 아니라
// Shorebird 패치로 새 아이콘을 낼 수 있음, docs/decisions.md 2026-11-19 '아이콘 SVG는 Dart 문자열로 둔다').
// SVG는 `stroke="currentColor"`이므로 색은 `colorFilter`로 입힌다. 화면 코드는 SVG 문자열이나 `Icons.*`를
// 직접 쓰지 않고 `AppIcon.<이름>`만 쓴다. 새 아이콘은 `IconSvgs`에 문자열 하나를 넣고 [AppIconName]에 한 줄을
// 더한다.

import 'package:cnu_ai_assistant/design/icon_svgs.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// 아이콘 이름. SVG는 [IconSvgs]에 있다.
enum AppIconName {
  today(IconSvgs.today),
  calendar(IconSvgs.calendar),
  tasks(IconSvgs.tasks),
  me(IconSvgs.me),

  /// 하단 탭 옆 'AI 비서에게 말하기' 버튼(말풍선).
  assistant(IconSvgs.assistant),

  // 02 홈과 그 시트·카드(캔버스 '최종 프로토타입'의 아이콘).

  /// 알림.
  bell(IconSvgs.bell),

  /// 새로 고침·다시 확인.
  refresh(IconSvgs.refresh),

  /// 네모 안 체크(했어요).
  checkSquare(IconSvgs.checkSquare),

  /// 체크(완료 표시, 굵은 선).
  check(IconSvgs.check),

  /// 시계(시각).
  clock(IconSvgs.clock),

  /// 빈 시간(찻잔).
  freeTime(IconSvgs.freeTime),

  /// 오른쪽 꺾쇠(더 보기).
  chevronRight(IconSvgs.chevronRight),

  /// 모래시계(시간 부족).
  hourglass(IconSvgs.hourglass),

  /// 위 꺾쇠(접기).
  chevronUp(IconSvgs.chevronUp),

  /// 더하기(놓기).
  plus(IconSvgs.plus),

  /// 이동 시간(버스).
  bus(IconSvgs.bus),

  /// 식사.
  meal(IconSvgs.meal),

  /// 일정·고정 일정(사람).
  person(IconSvgs.person),

  /// 운동 고정 일정(아령).
  exercise(IconSvgs.exercise),

  /// 직접 정한 시간(연필).
  pencil(IconSvgs.pencil),

  /// 급한 순번(깃발).
  flag(IconSvgs.flag),

  /// 안내.
  info(IconSvgs.info),

  /// 되돌리기(돌아가는 화살표).
  undo(IconSvgs.undo),

  /// 경고(세모 안 느낌표). LMS 상태 줄의 연결 실패.
  warning(IconSvgs.warning),

  // 01 아침 브리핑.

  /// 닫기(X).
  close(IconSvgs.close),

  /// 보내기(위 화살표). 말로 추가 칸, 10 나의 사용 지표 보내기.
  send(IconSvgs.send),

  // 10 나.

  /// LMS에 로그인(열쇠).
  key(IconSvgs.key),

  /// 데모 모드(재생 화면).
  demo(IconSvgs.demo),

  /// 데이터 삭제(휴지통).
  trash(IconSvgs.trash),

  /// 개인정보 처리방침(방패).
  shield(IconSvgs.shield),

  /// 문서(이용약관·동의 문구).
  doc(IconSvgs.doc),

  /// 목록(오픈소스 라이선스).
  list(IconSvgs.list),

  /// 문의 메일(봉투).
  mail(IconSvgs.mail),

  /// 학기 카드(학사모).
  school(IconSvgs.school),

  /// 하루 경계(달).
  moon(IconSvgs.moon),

  /// 해(다크 모드 고르기 등).
  sun(IconSvgs.sun),

  /// 글자 크기(눈).
  eye(IconSvgs.eye),

  // 13 시간표·고정 일정의 고정 일정 종류(캔버스 '최종 프로토타입'의 아이콘).

  /// 알바(가방).
  work(IconSvgs.work),

  /// 기타 고정 일정·장소(핀).
  place(IconSvgs.place);

  const AppIconName(this.svg);

  /// SVG 문자열([IconSvgs]).
  final String svg;
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
    return SvgPicture.string(
      name.svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(strokeColor, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
