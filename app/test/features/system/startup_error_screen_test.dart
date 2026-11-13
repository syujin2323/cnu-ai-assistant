// 20 시스템 시작 실패 화면 테스트. docs/screens.md '20 시스템'.
//
// 이유마다 문구와 [다시 시도]가 맞는지, 새 버전 DB에는 [다시 시도]가 없는지, 다시 시도하는 동안
// 버튼을 막는지, 글자 배율 2.0에서도 넘치지 않는지 본다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/startup_failure.dart';
import 'package:cnu_ai_assistant/features/system/startup_error_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait;

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    StartupFailure reason, {
    Future<void> Function()? onRetry,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = phonePortrait * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(StartupErrorApp(reason: reason, onRetry: onRetry));
  }

  Finder retryButton() => find.widgetWithText(FilledButton, '다시 시도');

  Future<void> noRetry() async {}

  const titles = {
    StartupFailure.newerDatabase: '앱을 업데이트해 주세요',
    StartupFailure.database: '폰 DB를 열 수 없어요',
    StartupFailure.other: '앱을 시작하지 못했어요',
  };

  testWidgets('새 버전 DB는 최신 버전 안내만 보이고 다시 시도를 두지 않는다', (tester) async {
    await pumpScreen(tester, StartupFailure.newerDatabase, onRetry: noRetry);

    expect(find.text('앱을 업데이트해 주세요'), findsOneWidget);
    expect(find.textContaining('최신 버전을 설치하면'), findsOneWidget);
    expect(retryButton(), findsNothing);
  });

  testWidgets('폰 DB를 열지 못했으면 이유와 다시 시도를 보인다(지우는 버튼은 없다)', (tester) async {
    await pumpScreen(tester, StartupFailure.database, onRetry: noRetry);

    expect(find.text('폰 DB를 열 수 없어요'), findsOneWidget);
    expect(find.textContaining('읽지 못했어요'), findsOneWidget);
    expect(retryButton(), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      findsOneWidget,
    );
  });

  testWidgets('그 밖의 실패는 다시 시도를 보인다', (tester) async {
    await pumpScreen(tester, StartupFailure.other, onRetry: noRetry);

    expect(find.text('앱을 시작하지 못했어요'), findsOneWidget);
    expect(retryButton(), findsOneWidget);
  });

  testWidgets('다시 시도할 방법이 없으면 버튼을 두지 않는다', (tester) async {
    await pumpScreen(tester, StartupFailure.database);

    expect(retryButton(), findsNothing);
  });

  testWidgets('제목은 머리글이다', (tester) async {
    for (final MapEntry(key: reason, value: title) in titles.entries) {
      await pumpScreen(tester, reason, onRetry: noRetry);
      expect(
        tester.getSemantics(find.text(title)),
        isSemantics(label: title, isHeader: true),
        reason: reason.name,
      );
    }
  });

  testWidgets('다시 시도하는 동안 버튼을 막고, 끝나면 다시 받는다', (tester) async {
    var calls = 0;
    var pending = Completer<void>();
    await pumpScreen(
      tester,
      StartupFailure.database,
      onRetry: () {
        calls++;
        return pending.future;
      },
    );

    await tester.tap(retryButton());
    await tester.pump();

    expect(calls, 1);
    expect(tester.widget<FilledButton>(retryButton()).onPressed, isNull);
    await tester.tap(retryButton());
    expect(calls, 1);

    pending.complete();
    await tester.pump();

    expect(tester.widget<FilledButton>(retryButton()).onPressed, isNotNull);
    pending = Completer<void>()..complete();
    await tester.tap(retryButton());
    await tester.pump();
    expect(calls, 2);
  });

  testWidgets('글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    for (final reason in StartupFailure.values) {
      await pumpScreen(tester, reason, onRetry: noRetry, textScale: 2.0);
      expect(tester.takeException(), isNull, reason: reason.name);
    }
  });
}
