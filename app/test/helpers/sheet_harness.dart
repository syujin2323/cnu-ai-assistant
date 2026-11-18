// 폰 DB를 쓰는 시트 테스트의 띄우기 도우미. 메모리 DB, 모션 끔, 멈춘 시계로 버튼 하나를 띄우고, 누르면 [open]이
// 시트를 연다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/theme.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pump_app.dart' show TestClock, phonePortrait;

/// 띄운 시트 테스트.
class SheetHarness {
  SheetHarness._(this.db, this._tester);

  final AppDatabase db;

  final WidgetTester _tester;

  /// 마지막으로 연 시트가 돌려준 값.
  Object? result;

  ProviderContainer get container =>
      ProviderScope.containerOf(_tester.element(find.byType(Scaffold).first));

  /// 지금 토스트 문구.
  String? get toast => container.read(toastControllerProvider)?.text;

  /// '열기'를 눌러 시트를 연다.
  Future<void> open() async {
    await _tester.tap(find.text('열기'));
    await _tester.pumpAndSettle();
  }

  /// 위젯 트리를 내려 provider를 정리한 뒤 DB를 닫는다(drift 스트림 타이머가 남지 않게).
  Future<void> dispose() async {
    expect(_tester.takeException(), isNull);
    await _tester.pumpWidget(const SizedBox.shrink());
    await _tester.pump(const Duration(seconds: 1));
    await db.close();
  }
}

/// 2026-11-16(월) 09:00.
final sheetTestNow = DateTime(2026, 11, 16, 9);

/// [open]으로 시트를 여는 버튼 하나를 띄운다. [seed]는 띄우기 전에 DB에 넣는다.
Future<SheetHarness> pumpSheetHarness(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context, WidgetRef ref) open, {
  Future<void> Function(AppDatabase db)? seed,
  double textScale = 1,
  Size size = phonePortrait,
}) async {
  late SheetHarness harness;
  harness = await pumpProviderHarness(
    tester,
    Consumer(
      builder: (context, ref, _) => Center(
        child: FilledButton(
          onPressed: () async => harness.result = await open(context, ref),
          child: const Text('열기'),
        ),
      ),
    ),
    seed: seed,
    textScale: textScale,
    size: size,
  );
  return harness;
}

/// [body]를 메모리 DB·모션 끔·멈춘 시계의 ProviderScope 안 Scaffold에 띄운다. [seed]는 띄우기 전에 DB에 넣는다.
Future<SheetHarness> pumpProviderHarness(
  WidgetTester tester,
  Widget body, {
  Future<void> Function(AppDatabase db)? seed,
  double textScale = 1,
  Size size = phonePortrait,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase.memory();
  await seed?.call(db);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        realDatabaseProvider.overrideWithValue(db),
        databaseProvider.overrideWithValue(db),
        motionLevelProvider.overrideWithValue(MotionLevel.off),
        clockProvider.overrideWithValue(TestClock(sheetTestNow)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: Scaffold(body: body),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return SheetHarness._(db, tester);
}
