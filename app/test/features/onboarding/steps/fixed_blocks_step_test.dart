// 온보딩 3단계(고정 일정) 테스트. docs/screens.md '14 온보딩'의 3단계.

import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/minute_wheel.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/onboarding/steps/fixed_blocks_step.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/pump_app.dart' show tabletLandscape;
import '../../../helpers/sheet_harness.dart';

/// 보이게 끌어 올린 뒤 누른다. 단계 화면은 목록이 게으르게 그려지므로 아직 없으면 먼저 스크롤해 찾는다.
Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.widgetWithText(ChoiceChipButton, label);

void main() {
  testWidgets('알바를 골라 추가하면 고정 일정으로 넣고 목록에 보이며, 지우면 뺀다', (tester) async {
    final app = await pumpProviderHarness(
      tester,
      FixedBlocksStep(onNext: () {}),
    );

    expect(find.text('아직 넣은 고정 일정이 없어요'), findsOneWidget);
    // 점심은 배치 엔진이 기본으로 비워 두므로 빠르게 더하기에 없다.
    expect(_chip('점심'), findsNothing);
    await _tapIn(tester, _chip('알바'));
    expect(find.text('알바 일정'), findsOneWidget);
    expect(find.text('앞뒤 여유'), findsNothing);
    expect(find.text('준비물'), findsNothing);
    await _tapIn(tester, find.widgetWithText(FilledButton, '추가'));

    final row = await app.db.select(app.db.fixedBlocks).getSingle();
    expect(
      (row.name, row.kind, row.startMin, row.endMin, row.source),
      ('알바', FixedBlockKind.work, 840, 1080, EntrySource.manual),
    );
    expect(app.toast, '알바를 매주 일정으로 넣었어요');
    expect(find.text('토·일 14:00–18:00'), findsOneWidget);
    expect(find.text('알바 일정'), findsNothing);

    await _tapIn(tester, find.byTooltip('알바 지우기'));
    expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);
    expect(app.toast, '알바를 지웠어요');
    await app.dispose();
  });

  testWidgets('통학은 시간 휠로 내 규칙의 이동 시간(하루 첫 수업 전·마지막 수업 뒤)을 저장하고 고칠 수 있다', (
    tester,
  ) async {
    final app = await pumpProviderHarness(
      tester,
      FixedBlocksStep(onNext: () {}),
    );

    await _tapIn(tester, _chip('통학'));
    expect(find.text('학교까지 얼마나 걸려요?'), findsOneWidget);
    // 처음 값은 40분이고, 휠을 두 칸 내리면(5분 단위) 30분이다.
    expect(tester.widget<MinuteWheel>(find.byType(MinuteWheel)).value, 40);
    await tester.drag(
      find.byType(MinuteWheel),
      const Offset(0, MinuteWheel.itemExtent * 2),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<MinuteWheel>(find.byType(MinuteWheel)).value, 30);
    expect(find.text('준비물'), findsNothing);
    await _tapIn(tester, find.widgetWithText(FilledButton, '저장'));

    final rules = await app.db.select(app.db.rules).get();
    expect(rules.single.kind, RuleKind.travel);
    expect(
      (rules.single.params.minutes, rules.single.params.position),
      (30, TravelPosition.dayEdges),
    );
    expect(rules.single.source, EntrySource.manual);
    expect(app.toast, '통학 시간을 30분으로 정했어요');
    expect(find.text('통학 30분'), findsOneWidget);
    expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);

    await _tapIn(tester, find.byTooltip('통학 시간 바꾸기'));
    expect(tester.widget<MinuteWheel>(find.byType(MinuteWheel)).value, 30);
    await app.dispose();
  });

  testWidgets('기타는 이름과 요일을 넣어야 추가할 수 있다', (tester) async {
    final app = await pumpProviderHarness(
      tester,
      FixedBlocksStep(onNext: () {}),
    );

    await _tapIn(tester, _chip('기타'));
    expect(find.text('새 고정 일정'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, '추가');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, '동아리 연습');
    await tester.pump();
    await _tapIn(tester, find.text('목'));
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);

    await _tapIn(tester, find.widgetWithText(OutlinedButton, '취소'));
    expect(find.text('새 고정 일정'), findsNothing);
    expect(await app.db.select(app.db.fixedBlocks).get(), isEmpty);
    await app.dispose();
  });

  testWidgets('다음을 누르면 다음 단계로 간다', (tester) async {
    var next = 0;
    final app = await pumpProviderHarness(
      tester,
      FixedBlocksStep(onNext: () => next++),
    );
    await _tapIn(tester, find.text('다음'));
    expect(next, 1);
    await app.dispose();
  });

  for (final (size, textScale) in [
    (const Size(320, 640), 2.0),
    (tabletLandscape, 2.0),
  ]) {
    testWidgets('크기 $size, 글자 배율 $textScale에서 폼을 열어도 넘치지 않는다', (tester) async {
      final app = await pumpProviderHarness(
        tester,
        FixedBlocksStep(onNext: () {}),
        textScale: textScale,
        size: size,
      );
      await _tapIn(tester, _chip('알바'));
      expect(tester.takeException(), isNull);
      await _tapIn(tester, find.widgetWithText(OutlinedButton, '취소'));
      await _tapIn(tester, _chip('통학'));
      expect(tester.takeException(), isNull);
      await app.dispose();
    });
  }
}
