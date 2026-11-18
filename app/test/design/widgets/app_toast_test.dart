// 토스트 위젯과 자리 테스트. docs/screens.md '되돌리기', docs/architecture.md '모션 프리셋'(toast).

import 'dart:async';

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/widgets/app_tab_bar.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait, tabletLandscape;

const _long = '연결 리스트 구현을 오늘 14:00–15:30으로 옮기고 다른 할 일 두 개를 다시 놓았어요';

/// [size] 화면에 [toast] 자리와 그 아래 [home] 화면을 그린다. [bottomPadding]은 홈 표시줄, [keyboard]는
/// 키보드 높이다.
Future<void> _pump(
  WidgetTester tester, {
  Widget? toast,
  bool visible = true,
  Widget home = const Scaffold(body: SizedBox.expand()),
  double textScale = 1,
  Size size = phonePortrait,
  double bottomPadding = 0,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MotionScope(
      level: MotionLevel.off,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(bottom: bottomPadding),
            viewPadding: EdgeInsets.only(bottom: bottomPadding),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            textScaler: TextScaler.linear(textScale),
          ),
          child: AppToastLayer(visible: visible, toast: toast, child: child!),
        ),
        home: home,
      ),
    ),
  );
  await tester.pump();
}

/// 네 탭의 하단 탭바가 있는 화면. 글자를 키우면 '캘린더' 글자가 두 줄이 되어 알약이 더 커진다.
Widget _withTabBar() => Scaffold(
  extendBody: true,
  body: const SizedBox.expand(),
  bottomNavigationBar: AppTabBar(
    items: const [
      AppTabItem(label: '오늘', icon: AppIconName.today),
      AppTabItem(label: '캘린더', icon: AppIconName.calendar),
      AppTabItem(label: '할 일', icon: AppIconName.tasks),
      AppTabItem(label: '나', icon: AppIconName.me),
    ],
    currentIndex: 1,
    onSelected: (_) {},
    onAssistant: () {},
  ),
);

/// 하단 탭 알약(과 AI 비서 버튼) 줄의 윗변.
double _pillTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ToastAnchor)).dy;

/// 기준점이 없을 때 화면 아래 끝에서 토스트 아래 끝까지의 거리. 홈 표시줄이 8pt보다 작으면 8pt를 둔다(탭바의
/// SafeArea 최소값과 같음).
double _fallback(double bottomPadding) =>
    (bottomPadding < 8 ? 8 : bottomPadding) +
    8 +
    AppTabBar.barHeight +
    AppToastLayer.gap;

/// 화면 아래 끝에서 토스트 아래 끝까지의 거리.
double _toastBottom(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio -
    tester.getBottomLeft(find.byType(AppToast)).dy;

void main() {
  testWidgets('문구와 체크를 그리고, 되돌리기가 있을 때만 버튼을 단다', (tester) async {
    var undos = 0;
    await _pump(
      tester,
      toast: AppToast(text: '확정했어요', onUndo: () => undos++),
    );
    expect(find.text('확정했어요'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppToast),
        matching: find.byWidgetPredicate(
          (widget) => widget is AppIcon && widget.name == AppIconName.check,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('되돌리기'));
    expect(undos, 1);
    // 누를 자리는 48pt 이상이다.
    final button = tester.getSize(find.byType(TextButton));
    expect(button.width, greaterThanOrEqualTo(48));
    expect(button.height, greaterThanOrEqualTo(48));

    await _pump(tester, toast: const AppToast(text: '기록했어요'));
    expect(find.text('기록했어요'), findsOneWidget);
    expect(find.text('되돌리기'), findsNothing);
  });

  testWidgets('읽기 도구가 나타날 때 알리는 자리(live region)이고 되돌리기는 버튼으로 읽는다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      toast: AppToast(text: '확정했어요', onUndo: () {}),
    );
    expect(
      tester.getSemantics(find.byType(AppToast)),
      isSemantics(isLiveRegion: true),
    );
    expect(
      tester.getSemantics(find.text('되돌리기')),
      isSemantics(label: '되돌리기', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('토스트는 하단 탭 알약 위 12pt에 가운데로 붙는다(홈 표시줄이 있거나 글자를 키워도)', (
    tester,
  ) async {
    for (final (bottomPadding, textScale) in [
      (0.0, 1.0),
      (34.0, 1.0),
      (34.0, 2.0),
    ]) {
      final reason = '홈 표시줄 $bottomPadding, 글자 $textScale';
      var undos = 0;
      await _pump(
        tester,
        bottomPadding: bottomPadding,
        textScale: textScale,
        toast: AppToast(text: '확정했어요', onUndo: () => undos++),
        home: _withTabBar(),
      );
      expect(
        _pillTop(tester) - tester.getBottomLeft(find.byType(AppToast)).dy,
        AppToastLayer.gap,
        reason: reason,
      );
      expect(
        tester.getCenter(find.byType(AppToast)).dx,
        tester.getCenter(find.byType(ToastAnchor)).dx,
        reason: reason,
      );
      // 붙어 따라간 자리에서도 누를 수 있다.
      await tester.tap(find.text('되돌리기'));
      expect(undos, 1, reason: reason);
      if (textScale == 1) {
        // 알약과 AI 비서 버튼이 같은 높이라 토스트와 버튼 사이도 같다.
        expect(_toastBottom(tester), _fallback(bottomPadding), reason: reason);
        expect(
          tester.getSize(find.bySemanticsLabel(AppStrings.askAssistant)).height,
          AppTabBar.barHeight,
        );
      } else {
        // 글자를 키우면 알약이 커지고 토스트도 그만큼 올라간다.
        expect(
          _toastBottom(tester),
          greaterThan(_fallback(bottomPadding)),
          reason: reason,
        );
      }
    }
  });

  testWidgets('기준점이 없는 화면은 탭 알약이 있을 높이 위에 두고, 키보드가 올라오면 그만큼 올라간다', (
    tester,
  ) async {
    await _pump(tester, toast: const AppToast(text: '확정했어요'));
    expect(_toastBottom(tester), _fallback(0));

    await _pump(tester, keyboard: 300, toast: const AppToast(text: '확정했어요'));
    expect(_toastBottom(tester), 300 + _fallback(0));

    // 탭바가 있어도 키보드가 올라오면(탭바가 키보드 밑에 깔림) 기준점을 쓰지 않는다.
    await _pump(
      tester,
      keyboard: 300,
      toast: const AppToast(text: '확정했어요'),
      home: _withTabBar(),
    );
    expect(_toastBottom(tester), 300 + _fallback(0));
  });

  testWidgets('기준점이 든 화면 위에 다른 화면이 열리면 기준점을 쓰지 않는다', (tester) async {
    await _pump(
      tester,
      bottomPadding: 34,
      textScale: 2,
      toast: const AppToast(text: '확정했어요'),
      home: _withTabBar(),
    );
    final anchored = _toastBottom(tester);
    expect(anchored, greaterThan(_fallback(34)));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
    );
    await tester.pumpAndSettle();
    expect(_toastBottom(tester), _fallback(34));

    navigator.pop();
    await tester.pumpAndSettle();
    expect(_toastBottom(tester), anchored);
  });

  testWidgets('위에 열린 화면에 기준점이 있으면 그것을 쓰고(바뀌는 동안에도 하나만), 닫으면 탭바로 돌아온다', (
    tester,
  ) async {
    // iOS 화면 전환은 두 화면을 그대로 함께 그린다(Android 전환은 아래 화면을 스냅숏으로 그려 기준점이 함께
    // 쓰이지 않음).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pump(
      tester,
      bottomPadding: 34,
      textScale: 2,
      toast: const AppToast(text: '확정했어요'),
      home: _withTabBar(),
    );
    final onTabBar = _toastBottom(tester);
    expect(onTabBar, greaterThan(_fallback(34)));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            bottomNavigationBar: ToastAnchor(child: SizedBox(height: 200)),
          ),
        ),
      ),
    );
    // 두 화면이 함께 그려지는 동안 기준점이 둘 쓰이면 LayerLink 검사가 실패한다.
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(_toastBottom(tester), 200 + AppToastLayer.gap);

    navigator.pop();
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(_toastBottom(tester), onTabBar);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('닫히는 화면의 기준점이 탭바보다 나중에 놓아도 탭바 기준점의 크기가 지워지지 않는다', (tester) async {
    // 위 화면의 기준점을 탭바보다 깊이 두면, 화면을 닫는 프레임에서 탭바 기준점이 먼저 연결을 잡고 위 화면
    // 기준점이 뒤에 놓는다. 놓는 쪽이 연결의 크기를 지우면 따라가는 토스트가 그 프레임에 단정에 걸린다.
    Widget deep(Widget child, int levels) =>
        levels == 0 ? child : deep(KeyedSubtree(child: child), levels - 1);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      await _pump(
        tester,
        bottomPadding: 34,
        toast: const AppToast(text: '확정했어요'),
        home: _withTabBar(),
      );
      final onTabBar = _toastBottom(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              bottomNavigationBar: deep(
                const ToastAnchor(child: SizedBox(height: 200)),
                60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_toastBottom(tester), 200 + AppToastLayer.gap);

      navigator.pop();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: '$platform $frame');
      }
      await tester.pumpAndSettle();
      expect(_toastBottom(tester), onTabBar);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('내려간 토스트는 그리지 않고 누를 수 없다', (tester) async {
    var undos = 0;
    await _pump(
      tester,
      visible: false,
      toast: AppToast(text: '확정했어요', onUndo: () => undos++),
    );
    expect(find.text('확정했어요'), findsNothing);
    await tester.tapAt(const Offset(300, 700));
    expect(undos, 0);

    await _pump(tester);
    expect(find.byType(AppToast), findsNothing);
  });

  for (final (name, size) in [
    ('폰', phonePortrait),
    ('태블릿 가로', tabletLandscape),
  ]) {
    testWidgets('$name 폭, 글자 200%에서 긴 문구도 두 줄로 줄이고 넘치지 않는다', (tester) async {
      await _pump(
        tester,
        size: size,
        textScale: 2,
        toast: AppToast(text: _long, onUndo: () {}),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(_long));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.text('되돌리기'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppToast)).height,
        greaterThanOrEqualTo(AppToast.minHeight),
      );
    });
  }
}
