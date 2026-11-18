// 20 시스템의 점검·오프라인 띠. docs/screens.md '20 시스템'.

import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_system_band.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart' show phonePortrait;

const maintenance = LmsBand(
  kind: LmsStatusKind.maintenance,
  title: 'LMS가 점검 중이에요',
  sub: '받아 둔 정보로 보여 드려요 · 마지막 확인 3시간 전',
  directAdd: false,
);

const offline = LmsBand(
  kind: LmsStatusKind.offline,
  title: '인터넷에 연결되지 않았어요',
  sub: '폰에 저장된 정보로 그대로 쓸 수 있어요. 말로 추가는 연결되면 다시 돼요',
  directAdd: true,
);

Future<void> pumpBand(
  WidgetTester tester,
  LmsSystemBand band, {
  double textScale = 1,
  Size size = phonePortrait,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MotionScope(
      level: MotionLevel.off,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [band]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('점검 중은 제목·마지막 확인과 [다시 확인]만 둔다', (tester) async {
    var retried = 0;
    await pumpBand(
      tester,
      LmsSystemBand(
        band: maintenance,
        onRetry: () => retried++,
        onDirectAdd: () => fail('점검 중에는 직접 입력하기가 없다'),
      ),
    );
    expect(find.text('LMS가 점검 중이에요'), findsOneWidget);
    expect(find.text('받아 둔 정보로 보여 드려요 · 마지막 확인 3시간 전'), findsOneWidget);
    expect(find.text('직접 입력하기'), findsNothing);
    await tester.tap(find.text('다시 확인'));
    expect(retried, 1);
  });

  testWidgets('오프라인은 [직접 입력하기]와 [다시 확인]을 둔다', (tester) async {
    var retried = 0;
    var added = 0;
    await pumpBand(
      tester,
      LmsSystemBand(
        band: offline,
        onRetry: () => retried++,
        onDirectAdd: () => added++,
      ),
    );
    await tester.tap(find.text('직접 입력하기'));
    await tester.tap(find.text('다시 확인'));
    expect((added, retried), (1, 1));
  });

  testWidgets('받는 중이면 [다시 확인]을 막고 확인하는 중이라고 쓴다', (tester) async {
    var retried = 0;
    await pumpBand(
      tester,
      LmsSystemBand(band: maintenance, busy: true, onRetry: () => retried++),
    );
    expect(find.text('다시 확인'), findsNothing);
    await tester.tap(find.text(LmsSystemBand.busyText));
    expect(retried, 0);
    expect(
      tester.getSemantics(find.text(LmsSystemBand.busyText)),
      matchesSemantics(
        label: LmsSystemBand.busyText,
        isButton: true,
        hasEnabledState: true,
      ),
    );
  });

  testWidgets('좁은 폭과 글자 배율 2.0에서도 넘치지 않는다', (tester) async {
    for (final band in [maintenance, offline]) {
      await pumpBand(
        tester,
        LmsSystemBand(band: band, onRetry: () {}, onDirectAdd: () {}),
        textScale: 2,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
