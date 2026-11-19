// 12 내 규칙 화면 테스트. docs/screens.md '12 내 규칙'. 지금은 목록(카드, 켜고 끄기, 지우기, 말로 정하기)까지다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_screen.dart';
import 'package:cnu_ai_assistant/features/me/rules_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final _now = DateTime(2026, 11, 16, 11, 2);

Future<int> _rule(
  AppDatabase db,
  RuleKind kind,
  RuleParams params, {
  bool active = true,
  EntrySource source = EntrySource.manual,
  String? sentence,
}) => db
    .into(db.rules)
    .insert(
      RulesCompanion.insert(
        kind: kind,
        params: params,
        active: active,
        source: source,
        sentence: Value(sentence),
        createdAt: DateTime(2026, 11, 1),
        updatedAt: DateTime(2026, 11, 1),
      ),
    );

Future<TestApp> _open(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  double textScale = 1.0,
  Size size = phonePortrait,
}) async {
  final app = await pumpTestApp(
    tester,
    now: _now,
    textScale: textScale,
    size: size,
    settings: const {SettingKeys.aiEnabled: true},
  );
  if (seed != null) await seed(app.db);
  app.router.go(Routes.me);
  await tester.pumpAndSettle();
  app.router.push(Routes.meRules);
  await tester.pumpAndSettle();
  return app;
}

Future<List<Rule>> _rules(AppDatabase db) => db.select(db.rules).get();

void main() {
  for (final textScale in [1.0, 2.0]) {
    testWidgets('글자 배율 $textScale: 규칙마다 종류·짧은 값·원래 문장·출처를 보이고 켜진 수를 센다', (
      tester,
    ) async {
      final app = await _open(
        tester,
        textScale: textScale,
        seed: (db) async {
          await _rule(
            db,
            RuleKind.dailyCap,
            const RuleParams(minutes: 240),
            source: EntrySource.ai,
            sentence: '하루 공부는 4시간까지만',
          );
          await _rule(
            db,
            RuleKind.workWindow,
            const RuleParams(startMin: 540, endMin: 1380),
            active: false,
          );
        },
      );

      expect(find.byType(RulesScreen), findsOneWidget);
      expect(find.text('1개 켜짐'), findsOneWidget);
      expect(find.text('하루 최대 공부량'), findsOneWidget);
      expect(find.text('4시간'), findsOneWidget);
      expect(find.text('“하루 공부는 4시간까지만”'), findsOneWidget);
      expect(find.text('말로 정함'), findsOneWidget);
      await scrollTo(tester, find.text('09:00–23:00'));
      expect(find.text('공부 가능한 시간대'), findsOneWidget);
      expect(find.text('직접 정함'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await app.dispose(tester);
    });
  }

  testWidgets('스위치로 끄고 켜고, 지우면 되돌릴 수 있다', (tester) async {
    final app = await _open(
      tester,
      seed: (db) =>
          _rule(db, RuleKind.dailyCap, const RuleParams(minutes: 240)),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await _rules(app.db)).single.active, isFalse);
    expect(find.text('하루 최대 공부량 규칙을 껐어요'), findsOneWidget);
    expect(find.text('0개 켜짐'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await _rules(app.db)).single.active, isTrue);

    await tapText(tester, '지우기');
    expect(await _rules(app.db), isEmpty);
    expect(find.text('하루 최대 공부량 규칙을 지웠어요'), findsOneWidget);
    expect(find.text('아직 정한 규칙이 없어요'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(await _rules(app.db), hasLength(1));
    await app.dispose(tester);
  });

  testWidgets('규칙이 없으면 예시 문장을 보이고, 누르면 그 문장을 채운 AI 비서(규칙 모드)를 연다', (
    tester,
  ) async {
    final app = await _open(tester);

    expect(find.text('아직 정한 규칙이 없어요'), findsOneWidget);
    await tapText(tester, ruleExampleSentences.first);
    expect(find.byType(AssistantScreen), findsOneWidget);
    // 입력창에 그 문장이 들어 있다(아래에 깔린 12 내 규칙의 칩은 가려져 세지 않는다).
    expect(find.text(ruleExampleSentences.first), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('규칙 추가는 AI 비서를 규칙 모드로 연다. 알림 규칙은 보이지 않는다', (tester) async {
    final app = await _open(
      tester,
      seed: (db) => _rule(db, RuleKind.notify, const RuleParams(notifyCap: 3)),
    );

    expect(find.text('알림'), findsNothing);
    expect(find.text('아직 정한 규칙이 없어요'), findsOneWidget);
    await tapText(tester, '규칙 추가 · 말로 정하기');
    expect(find.byType(AssistantScreen), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('태블릿 가로 폭에서도 넘치지 않는다', (tester) async {
    final app = await _open(
      tester,
      size: tabletLandscape,
      textScale: 2.0,
      seed: (db) => _rule(
        db,
        RuleKind.meal,
        const RuleParams(startMin: 1050, endMin: 1170, minutes: 40),
        sentence: '저녁은 5시 반부터 7시 반 사이에 40분 먹어',
        source: EntrySource.ai,
      ),
    );
    expect(tester.takeException(), isNull);
    await app.dispose(tester);
  });
}
