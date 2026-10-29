// 테마. docs/architecture.md '디자인 토큰', '화면 이동'.
//
// `ThemeData`에 디자인 토큰을 입힌 것 하나뿐이다. R0는 밝은 테마만 있어 `RootApp`이
// `themeMode: ThemeMode.light`로 고정한다(다크 토큰은 R1). 화면 전환은 iOS
// `CupertinoPageTransitionsBuilder`(왼쪽 끝 스와이프로 뒤로), Android
// `PredictiveBackPageTransitionsBuilder`(예측 뒤로 가기)다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// 앱 테마(밝은 테마).
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    secondary: AppColors.strong,
    onSecondary: AppColors.bg,
    error: AppColors.alert,
    onError: AppColors.bg,
    errorContainer: AppColors.alertSoft,
    onErrorContainer: AppColors.alert,
    surface: AppColors.bg,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.ink2,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.tint,
    surfaceContainerHighest: AppColors.tint,
    outline: AppColors.icon,
    outlineVariant: AppColors.edge,
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
  ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  const minTouch = Size(AppSize.minTouch, AppSize.minTouch);
  final buttonText = AppText.body.copyWith(fontWeight: AppText.semibold);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    fontFamily: AppText.fontFamily,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      surfaceTintColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.title.copyWith(color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.edge),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minTouch,
        shape: const StadiumBorder(),
        textStyle: buttonText,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: AppSize.minTouch,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.screen),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.edge),
  );
}
