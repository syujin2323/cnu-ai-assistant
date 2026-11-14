// 루트 위젯. docs/architecture.md '한눈에 보기'(앱), '디자인 토큰', '데모 모드', '화면 이동'.
//
// [RootApp]은 Firebase를 부르지 않는다. Firebase·폰 DB·설정 준비는 `bootstrap.dart`가 runApp
// 전에 끝내므로, 화면 테스트는 `ProviderScope(overrides: ...)` 안에 [RootApp]만 띄운다.
// 앱이 백그라운드에서 돌아올 때(resumed) 하는 일도 여기서 건다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/demo_band.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 앱의 루트 위젯. 한국어 전용, 밝은 테마 고정.
class RootApp extends ConsumerStatefulWidget {
  const RootApp({super.key});

  @override
  ConsumerState<RootApp> createState() => _RootAppState();
}

class _RootAppState extends ConsumerState<RootApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 앱이 백그라운드에서 돌아왔을 때(resumed). 처음 실행은 시작 위치 규칙이 따로 맡는다.
  void _onResume() {
    // (R1) 백그라운드 작업이 폰 DB에 쓴 변경을 화면 스트림에 알리는 `markTablesUpdated`를 여기서
    // 먼저 부른다(docs/architecture.md '앱 코드 규약'의 백그라운드 작업).
    // 하루가 바뀌었고 그날 브리핑을 아직 보지 않았으면 시작 위치 규칙을 다시 돌린다.
    unawaited(ref.read(startRulesProvider).onResume());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      routerConfig: ref.watch(routerProvider),
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      // R0는 라이트만 쓴다(다크는 R1).
      themeMode: ThemeMode.light,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // OS의 애니메이션 끄기 신호는 앱 바인딩이 무시하고(`app/app_binding.dart`), 위젯이 보는 MediaQuery의
        // 값도 같게 둔다(docs/decisions.md 2026-11-14 'OS의 애니메이션 끄기 신호는 앱 전체에서 무시한다').
        // 글자 배율 등 그 밖의 값은 그대로 둔다.
        final media = MediaQuery.of(context).copyWith(disableAnimations: false);
        // webview_flutter와 그 플랫폼 구현, flutter_riverpod가 아직 package:flutter/material.dart를
        // import하므로 그 위젯들이 옛 Theme·MaterialLocalizations를 찾을 수 있게 감싼다. material_ui
        // 1.8.0의 폐기 안내는 '의존성이 material_ui로 옮겨 가는 동안만 쓰는 임시 도구'라는 뜻이다.
        // 의존성이 모두 옮겨 가면 이 줄을 지운다.
        return MediaQuery(
          data: media,
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(
            child: _DemoFrame(child: child!),
          ),
        );
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
    final exit = ref.watch(demoExitProvider);
    return Column(
      children: [
        if (demo)
          DemoBand(
            onExit: () => ref.read(demoExitProvider.notifier).exit(),
            exiting: exit == DemoExitState.exiting,
            failed: exit == DemoExitState.failed,
          ),
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
}
