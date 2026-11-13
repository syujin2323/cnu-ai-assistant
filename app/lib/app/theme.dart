// 테마. docs/architecture.md '디자인 토큰', '화면 이동'.
//
// `ThemeData`에 디자인 토큰을 입힌 것이다. 색은 [AppColors]의 라이트·다크 두 벌 가운데 하나를
// 골라 `ColorScheme`과 위젯 테마에 표의 역할대로 묶고, 같은 값을 `extensions`에 넣어 화면이
// `AppColors.of(context)`로 읽게 한다. R0는 라이트만 써서 `RootApp`이 `themeMode: ThemeMode.light`로
// 고정한다(다크는 R1). 화면 전환은 iOS `CupertinoPageTransitionsBuilder`(왼쪽 끝 스와이프로 뒤로),
// Android `PredictiveBackPageTransitionsBuilder`(예측 뒤로 가기)다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// 앱 테마. [brightness]가 dark면 [AppColors.dark](R1, 검수 전 임시값)를 쓴다.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  // 칸마다 표의 '쓰는 곳'을 따른다. 정하지 않은 칸은 ColorScheme이 primary·secondary로 채우므로
  // (예: FilterChip의 선택 배경 secondaryContainer) 쓰는 칸은 모두 적는다.
  final colorScheme = ColorScheme(
    brightness: brightness,
    // 주 버튼 배경·켜진 스위치와 그 위 글자.
    primary: colors.strong,
    onPrimary: colors.onStrong,
    primaryContainer: colors.tint,
    onPrimaryContainer: colors.ink,
    // 포인트 글자·링크.
    secondary: colors.accent,
    onSecondary: colors.onStrong,
    secondaryContainer: colors.tint,
    onSecondaryContainer: colors.ink,
    tertiary: colors.accent,
    onTertiary: colors.onStrong,
    tertiaryContainer: colors.tint,
    onTertiaryContainer: colors.ink,
    error: colors.alert,
    onError: colors.onStrong,
    errorContainer: colors.alertSoft,
    onErrorContainer: colors.alert,
    surface: colors.bg,
    onSurface: colors.ink,
    onSurfaceVariant: colors.ink2,
    surfaceContainerLowest: colors.bg,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.tint,
    surfaceContainerHighest: colors.tint,
    // 보조 아이콘·라디오 테두리, 테두리.
    outline: colors.icon,
    outlineVariant: colors.edge,
    scrim: colors.scrim,
    // 높이에 따라 표면을 물들이지 않는다(시트·카드 색은 토큰 그대로).
    surfaceTint: Colors.transparent,
  );

  final textTheme = TextTheme(
    displayLarge: AppText.hero,
    displayMedium: AppText.display,
    displaySmall: AppText.display,
    headlineLarge: AppText.heading,
    headlineMedium: AppText.heading,
    headlineSmall: AppText.heading,
    titleLarge: AppText.title,
    titleMedium: AppText.bodyLarge.copyWith(fontWeight: AppText.medium),
    titleSmall: AppText.body.copyWith(fontWeight: AppText.medium),
    bodyLarge: AppText.bodyLarge,
    bodyMedium: AppText.body,
    bodySmall: AppText.small,
    labelLarge: AppText.body.copyWith(fontWeight: AppText.medium),
    labelMedium: AppText.small.copyWith(fontWeight: AppText.medium),
    labelSmall: AppText.caption.copyWith(fontWeight: AppText.medium),
  ).apply(bodyColor: colors.ink, displayColor: colors.ink);

  const minTouch = Size(AppSize.minTouch, AppSize.minTouch);
  final buttonText = AppText.body.copyWith(fontWeight: AppText.semibold);

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: [colors],
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    fontFamily: AppText.fontFamily,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.ink,
      surfaceTintColor: colors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.title.copyWith(color: colors.ink),
    ),
    // 주 버튼: strong 배경에 onStrong 글자.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.strong,
        foregroundColor: colors.onStrong,
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    // 보조 버튼: accent 글자.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.accent,
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.edge),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    // 켜진 스위치 strong, 꺼진 스위치 edge2.
    switchTheme: SwitchThemeData(
      thumbColor: _bySelected(colors.onStrong, colors.icon),
      trackColor: _bySelected(colors.strong, colors.edge2),
      trackOutlineColor: _bySelected(colors.strong, colors.edge2),
    ),
    // 라디오: 꺼짐 icon, 켜짐 strong.
    radioTheme: RadioThemeData(
      fillColor: _bySelected(colors.strong, colors.icon),
    ),
    // 시트: sheet 배경, 위 모서리 32, 뒤는 scrim. 여는 곳은 `design/widgets/app_sheet.dart`.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.sheet,
      modalBackgroundColor: colors.sheet,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: AppSize.minTouch,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.screen),
    ),
    dividerTheme: DividerThemeData(color: colors.edge),
  );
}

/// 선택된 상태면 [selected], 아니면 [unselected].
WidgetStateProperty<Color> _bySelected(Color selected, Color unselected) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? selected : unselected,
    );
