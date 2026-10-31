// 디자인 토큰. docs/architecture.md '디자인 토큰'.
//
// 여기의 값은 모두 임시 결정이다. 정해진 디자인이 아니라 캔버스 v3에서 뽑은 작업용
// 값이고, 디자인이 확정되면 docs/architecture.md의 그 절과 이 파일을 함께 바꾼다.
// 확정 전까지는 그 표가 원본이다. 화면 코드는 색·글자·간격·모서리 값을 직접 쓰지 않고
// 이 토큰만 쓴다. R0는 밝은 테마뿐이고 다크 토큰은 R1에 더한다.

import 'package:material_ui/material_ui.dart';

/// 색(임시값).
abstract final class AppColors {
  /// 화면 배경.
  static const Color bg = Color(0xFFFFFFFF);

  /// 카드.
  static const Color surface = Color(0xFFFAFBFF);

  /// 눌린 카드, 틴트 배경.
  static const Color tint = Color(0xFFF0F2FB);

  /// 테두리.
  static const Color edge = Color(0xFFE9ECF5);

  /// 제목·본문.
  static const Color ink = Color(0xFF202027);

  /// 두 번째 본문.
  static const Color ink2 = Color(0xFF4A4B57);

  /// 보조 글자(흰 배경에서 5.15:1).
  static const Color muted = Color(0xFF676D80);

  /// 보조 아이콘, 라디오 테두리.
  static const Color icon = Color(0xFF83889A);

  /// 포인트, 버튼.
  static const Color accent = Color(0xFF525F89);

  /// 진한 포인트.
  static const Color strong = Color(0xFF535F8E);

  /// 경고 글자.
  static const Color alert = Color(0xFFB4475F);

  /// 경고 배경.
  static const Color alertSoft = Color(0xFFFBEFF2);

  /// 현재 시각 점선.
  static const Color stripe = Color(0xFFB0B9DF);

  /// 수업.
  static const Color classTint = Color(0xFFEEF2FC);

  /// 할 일.
  static const Color taskTint = Color(0xFFF3F0FC);

  /// 개인.
  static const Color personalTint = Color(0xFFFCF2EC);

  /// 마감·겹침.
  static const Color deadlineTint = Color(0xFFFBEFF2);

  /// 일요일 날짜 글자(캘린더).
  static const Color sunday = Color(0xFFB4475F);

  /// 토요일 날짜 글자(캘린더).
  static const Color saturday = Color(0xFF3A63B8);
}

/// 글자(Pretendard, 임시값). 무게는 제목(`title` 이상) 600, 본문 400, 강조 500이다.
/// 음수 자간을 쓰는 제목에는 글자 그림자를 넣지 않는다(Android Impeller 이슈).
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

  /// 월 그리드 날짜 칸의 일정 칩.
  static const TextStyle tiny = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: regular,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: regular,
  );
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: regular,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: regular,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: regular,
    letterSpacing: -0.3,
  );
  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: semibold,
    letterSpacing: -0.6,
  );
  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
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

  /// 칩·입력.
  static const double chip = 14;

  /// 시트.
  static const double sheet = 32;

  /// 알약.
  static const double pill = 999;

  /// 월 그리드의 날짜 칸.
  static const double dayCell = 10;

  /// 날짜 칸 안의 일정 칩.
  static const double tag = 4;
}

/// 크기(임시값). 누를 수 있는 것은 48×48pt 이상이다.
abstract final class AppSize {
  /// 누를 수 있는 것의 최소 한 변.
  static const double minTouch = 48;

  /// 아이콘 기본 크기(캔버스 SVG의 viewBox).
  static const double icon = 24;

  /// 하단 바의 추가 알약·원형 버튼 높이.
  static const double bottomBar = 56;

  /// 실시간 시간표의 한 시간 높이.
  static const double timelineHour = 44;
}
