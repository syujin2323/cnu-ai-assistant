// 디자인 토큰. docs/architecture.md '디자인 토큰'.
//
// 여기의 값은 모두 임시 결정이다. 정해진 디자인이 아니라 최종 프로토타입의 디자인 규칙에서 뽑은
// 값이고, 디자인이 확정되면 docs/architecture.md의 그 절과 이 파일을 함께 바꾼다. 확정 전까지는
// 그 표가 원본이다(`test/design/tokens_test.dart`가 표와 값을 견준다). 화면 코드는 색·글자·간격·
// 모서리 값을 직접 쓰지 않고 이 토큰만 쓴다. 색은 같은 이름의 라이트·다크 두 벌이고 화면은
// `AppColors.of(context)`로 지금 테마의 값을 읽는다(decisions.md 2026-11-06 '색 토큰은 라이트·다크
// 두 벌로 둔다'). R0는 라이트만 쓰고, 다크 값은 최종 프로토타입의 다크 화면이 검수되지 않은
// 임시값이다(R1).

import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// 색(임시값). 테마의 `extensions`에 들어가는 라이트([light])·다크([dark]) 두 벌이고, 화면은
/// [AppColors.of]로 읽는다. 종류별 색은 늘 아이콘이나 글자와 함께 쓴다(색만으로 구분하지 않음).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.tint,
    required this.edge,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.icon,
    required this.accent,
    required this.strong,
    required this.alert,
    required this.alertSoft,
    required this.stripe,
    required this.classTint,
    required this.taskTint,
    required this.personalTint,
    required this.deadlineTint,
    required this.tint2,
    required this.edge2,
    required this.onStrong,
    required this.faint,
    required this.alertLine,
    required this.sheet,
    required this.scrim,
    required this.classLine,
    required this.classInk,
    required this.taskLine,
    required this.taskInk,
    required this.personalLine,
    required this.personalInk,
    required this.deadlineLine,
    required this.deadlineInk,
  });

  /// 라이트 테마(R0).
  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFBFF),
    tint: Color(0xFFF0F2FB),
    edge: Color(0xFFE9ECF5),
    ink: Color(0xFF202027),
    ink2: Color(0xFF4A4B57),
    muted: Color(0xFF676D80),
    icon: Color(0xFF83889A),
    accent: Color(0xFF525F89),
    strong: Color(0xFF535F8E),
    alert: Color(0xFFB4475F),
    alertSoft: Color(0xFFFBEFF2),
    stripe: Color(0xFFB0B9DF),
    classTint: Color(0xFFEEF2FC),
    taskTint: Color(0xFFF3F0FC),
    personalTint: Color(0xFFFCF2EC),
    deadlineTint: Color(0xFFFBEFF2),
    tint2: Color(0xFFE7EAF6),
    edge2: Color(0xFFDCE0EC),
    onStrong: Color(0xFFFFFFFF),
    faint: Color(0xFFC3C7D4),
    alertLine: Color(0xFFF1D3DB),
    sheet: Color(0xFFFFFFFF),
    scrim: Color.fromRGBO(26, 30, 46, 0.26),
    classLine: Color(0xFFDCE4F7),
    classInk: Color(0xFF4F67A8),
    taskLine: Color(0xFFE3DCF6),
    taskInk: Color(0xFF6A58A8),
    personalLine: Color(0xFFF3E1D6),
    personalInk: Color(0xFF925B40),
    deadlineLine: Color(0xFFF1D3DB),
    deadlineInk: Color(0xFFB4475F),
  );

  /// 다크 테마(R1). 최종 프로토타입의 다크 화면이 검수되지 않아 디자인 확정이 아닌 임시값이다.
  /// '(60%)'는 알파 60%(0x99)다.
  static const dark = AppColors(
    bg: Color(0xFF0F1116),
    surface: Color(0xFF161922),
    tint: Color(0xFF1D212C),
    edge: Color(0xFF242936),
    ink: Color(0xFFECEEF4),
    ink2: Color(0xFFC4C8D4),
    muted: Color(0xFF979DB0),
    icon: Color(0xFF80869B),
    accent: Color(0xFFB4BEF0),
    strong: Color(0xFFAEB8EA),
    alert: Color(0xFFF2879D),
    alertSoft: Color(0xFF2C1820),
    stripe: Color(0xFF56629A),
    classTint: Color(0xFF192136),
    taskTint: Color(0xFF201C33),
    personalTint: Color(0xFF281F19),
    deadlineTint: Color(0xFF2C1820),
    tint2: Color(0xFF252A38),
    edge2: Color(0xFF313748),
    onStrong: Color(0xFF141726),
    faint: Color(0xFF4A5063),
    alertLine: Color(0xFF4B2633),
    sheet: Color(0xFF171A23),
    scrim: Color.fromRGBO(0, 0, 0, 0.52),
    classLine: Color(0x99293551),
    classInk: Color(0xFFA7BBF3),
    taskLine: Color(0x99342C52),
    taskInk: Color(0xFFC2B3F6),
    personalLine: Color(0x9943332A),
    personalInk: Color(0xFFE7BB9C),
    deadlineLine: Color(0xFF4B2633),
    deadlineInk: Color(0xFFF2879D),
  );

  /// 지금 테마의 색. 테마 밖(테스트에서 앱 테마 없이 띄운 위젯 등)에서는 [light]다.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  /// 화면 배경.
  final Color bg;

  /// 카드.
  final Color surface;

  /// 눌린 카드, 틴트 배경.
  final Color tint;

  /// 테두리.
  final Color edge;

  /// 제목·본문.
  final Color ink;

  /// 두 번째 본문.
  final Color ink2;

  /// 보조 글자(흰 배경에서 5.15:1).
  final Color muted;

  /// 보조 아이콘, 라디오 테두리.
  final Color icon;

  /// 포인트 글자·링크·보조 버튼 글자.
  final Color accent;

  /// 주 버튼 배경, 켜진 스위치, 지금 선.
  final Color strong;

  /// 경고 글자.
  final Color alert;

  /// 경고 배경.
  final Color alertSoft;

  /// 점선, 오늘 테두리, 학사일정 띠 선.
  final Color stripe;

  /// 수업.
  final Color classTint;

  /// 할 일.
  final Color taskTint;

  /// 개인.
  final Color personalTint;

  /// 마감·겹침.
  final Color deadlineTint;

  /// 진행 막대 바탕.
  final Color tint2;

  /// 진한 테두리, 꺼진 스위치.
  final Color edge2;

  /// 주 버튼 글자.
  final Color onStrong;

  /// 아주 옅은 점, 취소선.
  final Color faint;

  /// 경고 테두리.
  final Color alertLine;

  /// 시트 배경.
  final Color sheet;

  /// 시트 뒤 어둡게.
  final Color scrim;

  /// 수업 테두리.
  final Color classLine;

  /// 수업 글자.
  final Color classInk;

  /// 할 일 테두리.
  final Color taskLine;

  /// 할 일 글자.
  final Color taskInk;

  /// 개인 테두리.
  final Color personalLine;

  /// 개인 글자.
  final Color personalInk;

  /// 마감 테두리.
  final Color deadlineLine;

  /// 마감 글자.
  final Color deadlineInk;

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? tint,
    Color? edge,
    Color? ink,
    Color? ink2,
    Color? muted,
    Color? icon,
    Color? accent,
    Color? strong,
    Color? alert,
    Color? alertSoft,
    Color? stripe,
    Color? classTint,
    Color? taskTint,
    Color? personalTint,
    Color? deadlineTint,
    Color? tint2,
    Color? edge2,
    Color? onStrong,
    Color? faint,
    Color? alertLine,
    Color? sheet,
    Color? scrim,
    Color? classLine,
    Color? classInk,
    Color? taskLine,
    Color? taskInk,
    Color? personalLine,
    Color? personalInk,
    Color? deadlineLine,
    Color? deadlineInk,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      tint: tint ?? this.tint,
      edge: edge ?? this.edge,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      muted: muted ?? this.muted,
      icon: icon ?? this.icon,
      accent: accent ?? this.accent,
      strong: strong ?? this.strong,
      alert: alert ?? this.alert,
      alertSoft: alertSoft ?? this.alertSoft,
      stripe: stripe ?? this.stripe,
      classTint: classTint ?? this.classTint,
      taskTint: taskTint ?? this.taskTint,
      personalTint: personalTint ?? this.personalTint,
      deadlineTint: deadlineTint ?? this.deadlineTint,
      tint2: tint2 ?? this.tint2,
      edge2: edge2 ?? this.edge2,
      onStrong: onStrong ?? this.onStrong,
      faint: faint ?? this.faint,
      alertLine: alertLine ?? this.alertLine,
      sheet: sheet ?? this.sheet,
      scrim: scrim ?? this.scrim,
      classLine: classLine ?? this.classLine,
      classInk: classInk ?? this.classInk,
      taskLine: taskLine ?? this.taskLine,
      taskInk: taskInk ?? this.taskInk,
      personalLine: personalLine ?? this.personalLine,
      personalInk: personalInk ?? this.personalInk,
      deadlineLine: deadlineLine ?? this.deadlineLine,
      deadlineInk: deadlineInk ?? this.deadlineInk,
    );
  }

  @override
  AppColors lerp(covariant ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      icon: Color.lerp(icon, other.icon, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      strong: Color.lerp(strong, other.strong, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      alertSoft: Color.lerp(alertSoft, other.alertSoft, t)!,
      stripe: Color.lerp(stripe, other.stripe, t)!,
      classTint: Color.lerp(classTint, other.classTint, t)!,
      taskTint: Color.lerp(taskTint, other.taskTint, t)!,
      personalTint: Color.lerp(personalTint, other.personalTint, t)!,
      deadlineTint: Color.lerp(deadlineTint, other.deadlineTint, t)!,
      tint2: Color.lerp(tint2, other.tint2, t)!,
      edge2: Color.lerp(edge2, other.edge2, t)!,
      onStrong: Color.lerp(onStrong, other.onStrong, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      alertLine: Color.lerp(alertLine, other.alertLine, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      classLine: Color.lerp(classLine, other.classLine, t)!,
      classInk: Color.lerp(classInk, other.classInk, t)!,
      taskLine: Color.lerp(taskLine, other.taskLine, t)!,
      taskInk: Color.lerp(taskInk, other.taskInk, t)!,
      personalLine: Color.lerp(personalLine, other.personalLine, t)!,
      personalInk: Color.lerp(personalInk, other.personalInk, t)!,
      deadlineLine: Color.lerp(deadlineLine, other.deadlineLine, t)!,
      deadlineInk: Color.lerp(deadlineInk, other.deadlineInk, t)!,
    );
  }
}

/// 글자(Pretendard, 크기/줄 높이, 임시값). 무게는 제목(`title` 이상) 600, 본문 400, 강조 500이다.
/// 줄 높이의 여백은 CSS line-height처럼 위아래에 반씩 나누고(`TextLeadingDistribution.even`), 숫자는
/// 고정 폭으로 쓴다. 음수 자간을 쓰는 제목에는 글자 그림자를 넣지 않는다(Android Impeller 이슈).
/// 시스템 글자 크기 200%에서도 줄이 깨지지 않게 글자 영역에 고정 높이를 쓰지 않는다.
abstract final class AppText {
  /// `pubspec.yaml`의 글꼴 family 이름. 테마의 기본 글꼴이다.
  static const String fontFamily = 'Pretendard';

  /// 본문 무게.
  static const FontWeight regular = FontWeight.w400;

  /// 강조 무게.
  static const FontWeight medium = FontWeight.w500;

  /// 제목 무게.
  static const FontWeight semibold = FontWeight.w600;

  /// 숫자는 고정 폭으로 쓴다(시각·분·개수가 바뀔 때 글자 폭이 흔들리지 않게).
  static const List<FontFeature> _numbers = [FontFeature.tabularFigures()];

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.45,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: regular,
  );
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.5,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: regular,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.55,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: regular,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 1.45,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: regular,
    letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.35,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 1.3,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 1.1,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: _numbers,
    fontWeight: semibold,
    letterSpacing: -1.6,
  );
}

/// 간격(4pt 격자, 임시값).
abstract final class AppSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// 화면 좌우 여백.
  static const double screen = s20;

  /// 카드 안 여백.
  static const double card = s16;
}

/// 모서리 반지름(임시값).
abstract final class AppRadius {
  /// 카드.
  static const double card = 24;

  /// 작은 카드.
  static const double smallCard = 18;

  /// 목록 묶음.
  static const double listGroup = 20;

  /// 안내 상자.
  static const double notice = 16;

  /// 시간표 블록.
  static const double timetableBlock = 16;

  /// 입력·빈 시간.
  static const double input = 14;

  /// 시트.
  static const double sheet = 32;

  /// 토스트.
  static const double toast = 26;

  /// 칩·버튼·알약.
  static const double pill = 999;
}

/// 크기(임시값). 누를 수 있는 것은 48×48pt 이상이다.
abstract final class AppSize {
  /// 누를 수 있는 것의 최소 한 변.
  static const double minTouch = 48;

  /// 아이콘 기본 크기(캔버스 SVG의 viewBox).
  static const double icon = 24;

  /// 하단 탭바 아이콘.
  static const double tabIcon = 20;
}

/// 하단 탭바와 그 옆 AI 비서 버튼의 유리 효과(임시값): 흰색 32%에 blur 18px, saturate 110%.
/// 유리는 이 두 곳에만 쓴다. (R1) OS가 투명도를 줄이라고 하면 유리 대신 흰 배경으로 그린다.
abstract final class AppGlass {
  /// 흰색 32%.
  static const Color fill = Color.fromRGBO(255, 255, 255, 0.32);

  /// blur(CSS `blur(18px)`의 표준편차와 같은 시그마).
  static const double blur = 18;

  /// 채도(CSS `saturate(110%)`).
  static const double saturate = 1.1;

  /// 유리 뒤를 흐리게 한 뒤 채도를 올리는 필터(CSS `backdrop-filter: blur(18px) saturate(110%)`).
  static ImageFilter get filter => ImageFilter.compose(
    outer: ColorFilter.matrix(saturationMatrix(saturate)),
    inner: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
  );

  /// CSS `saturate(s)`와 같은 색 행렬(Filter Effects 명세의 계수).
  static List<double> saturationMatrix(double s) => [
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
