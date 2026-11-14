// 앱 바인딩 테스트. docs/architecture.md '모션 프리셋', docs/decisions.md 2026-11-14 'OS의 애니메이션 끄기
// 신호는 앱 전체에서 무시한다'.
//
// 화면 테스트는 앱 바인딩(`AppBinding`)을 쓸 수 없으므로, 같은 조각(`IgnoreOsDisableAnimations`)을 섞은 테스트
// 바인딩으로 시험한다. 바인딩은 테스트 파일마다 하나라서 이 파일의 모든 테스트가 이 바인딩을 쓴다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/app_binding.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _AppLikeBinding extends AutomatedTestWidgetsFlutterBinding
    with IgnoreOsDisableAnimations {}

void main() {
  _AppLikeBinding();

  testWidgets('OS가 애니메이션을 끄라고 해도 시트는 sheet 프리셋 시간을 다 써서 열린다', (tester) async {
    // Android '애니메이션 삭제'. 이 조각이 없으면 Flutter는 시트를 750ms의 5%(약 38ms)에 끝낸다.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    expect(
      tester.platformDispatcher.accessibilityFeatures.disableAnimations,
      isTrue,
    );
    expect(SemanticsBinding.instance.disableAnimations, isFalse);

    // 앱 안의 모션 선택은 없고 앱은 늘 full이다(docs/decisions.md 2026-11-13 '모션은 모든 사람에게 같게 보인다').
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final motion = container.read(motionLevelProvider);
    expect(motion, MotionLevel.full);

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showAppSheet<void>(
        context: context,
        motion: motion,
        builder: (_) => const Text('시트'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final sheet = ModalRoute.of(tester.element(find.text('시트')))!.animation!;
    expect(sheet.status, AnimationStatus.forward);
    expect(sheet.value, lessThan(1));

    await tester.pump(AppMotion.sheet);
    expect(sheet.status, AnimationStatus.completed);
  });
}
