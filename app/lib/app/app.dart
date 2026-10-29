// 루트 위젯. docs/architecture.md '한눈에 보기'(앱), '디자인 토큰', '데모 모드'.
//
// [RootApp]은 Firebase를 부르지 않는다. Firebase·폰 DB·설정 준비는 `bootstrap.dart`가 runApp
// 전에 끝내므로, 화면 테스트는 `ProviderScope(overrides: ...)` 안에 [RootApp]만 띄운다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 앱의 루트 위젯. 한국어 전용, 밝은 테마 고정.
class RootApp extends ConsumerWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      routerConfig: ref.watch(routerProvider),
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // webview_flutter와 그 플랫폼 구현, flutter_riverpod가 아직 package:flutter/material.dart를
        // import하므로 그 위젯들이 옛 Theme·MaterialLocalizations를 찾을 수 있게 감싼다. material_ui
        // 1.8.0의 폐기 안내는 '의존성이 material_ui로 옮겨 가는 동안만 쓰는 임시 도구'라는 뜻이다.
        // 의존성이 모두 옮겨 가면 이 줄을 지운다.
        // ignore: deprecated_member_use
        return MaterialUiCompatibilityBridge(child: _DemoFrame(child: child!));
      },
    );
  }
}

/// 데모 모드면 화면 위에 데모 띠를 늘 보여 준다. 띠가 생기고 없어져도 아래 화면(Navigator)의
/// 상태는 그대로 둔다.
class _DemoFrame extends ConsumerWidget {
  const _DemoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    return Column(
      children: [
        if (demo) DemoBand(onExit: () => _exitDemo(ref)),
        Expanded(
          key: const ValueKey('app-navigator'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: demo,
            child: child,
          ),
        ),
      ],
    );
  }

  /// '끝내기': 데모 DB를 지우고 들어온 곳으로 돌아간다.
  Future<void> _exitDemo(WidgetRef ref) async {
    final entry = await ref
        .read(appModeProvider.notifier)
        .exitDemo(ref.read(databaseProvider));
    ref
        .read(routerProvider)
        .go(entry == DemoEntry.me ? Routes.me : Routes.onboarding);
  }
}
