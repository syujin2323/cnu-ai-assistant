// 01 아침 브리핑 provider 테스트. docs/architecture.md '아침 브리핑', docs/screens.md '01 아침 브리핑'.
//
// 화면 테스트는 브리핑 확인을 덮어쓰므로, 여기서는 실제 provider를 메모리 DB와 시계로 돌려 하루 경계에 따라
// 그날을 고르는지, 본 것으로 적는 함수가 그날 행을 적는지, 적지 못하거나 데모를 끝내는 중이면 어떻게
// 하는지 본다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/briefing_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart' show TestClock;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<ProviderContainer> containerWith(TestClock clock) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<bool> openedAt(DateTime now) async =>
      (await containerWith(TestClock(now))).read(briefingOpenedTodayProvider)();

  Future<void> addRow(String date, {DateTime? openedAt}) => db
      .into(db.briefings)
      .insert(
        BriefingsCompanion.insert(
          date: date,
          createdAt: DateTime(2026, 10, 12, 8),
          openedAt: Value(openedAt),
        ),
      );

  Future<List<String>> seenDates(AppDatabase target) async => [
    for (final row in await target.select(target.briefings).get())
      if (row.openedAt != null) row.date,
  ];

  group('briefingOpenedTodayProvider', () {
    test('하루 경계(기본 04:00) 전은 전날 행을, 경계부터는 그날 행을 본다', () async {
      await addRow('2026-10-12', openedAt: DateTime(2026, 10, 12, 8));
      await addRow('2026-10-13');

      expect(await openedAt(DateTime(2026, 10, 13, 3, 59)), isTrue);
      expect(await openedAt(DateTime(2026, 10, 13, 4)), isFalse);
    });

    test('사용자가 바꾼 하루 경계를 따르고, 부를 때마다 그때의 하루로 다시 묻는다', () async {
      expect(
        await SettingsRepository(db).write(SettingKeys.dayBoundaryMin, 360),
        isA<Ok<void>>(),
      );
      await addRow('2026-10-12', openedAt: DateTime(2026, 10, 12, 8));
      final clock = TestClock(DateTime(2026, 10, 13, 5, 59));
      final container = await containerWith(clock);
      final check = container.read(briefingOpenedTodayProvider);

      expect(await check(), isTrue);
      clock.current = DateTime(2026, 10, 13, 6);
      expect(await check(), isFalse);
    });

    test('설정은 읽었지만 기록을 읽지 못해도 본 것으로 보고 오늘로 보낸다', () async {
      await db.customStatement('DROP TABLE briefings');

      expect(await openedAt(DateTime(2026, 10, 13, 9)), isTrue);
    });

    test('설정이나 기록을 읽지 못하면 본 것으로 보고 오늘로 보낸다', () async {
      final container = await containerWith(
        TestClock(DateTime(2026, 10, 13, 9)),
      );
      await db.customSelect('SELECT 1').get();
      await db.close();

      expect(await container.read(briefingOpenedTodayProvider)(), isTrue);
    });
  });

  group('markBriefingSeenProvider', () {
    test('그때의 논리적 하루 행에 지금을 본 시각으로 적는다', () async {
      final now = DateTime(2026, 10, 13, 3, 59);
      final container = await containerWith(TestClock(now));

      // 적은 논리적 하루를 돌려준다(01이 띄운 채 하루가 바뀌었는지 견줄 때 씀).
      expect(
        await container.read(markBriefingSeenProvider)(),
        DateTime(2026, 10, 12),
      );

      expect(
        await BriefingRepository(db).isSeen(DateTime(2026, 10, 12)),
        const Ok(true),
      );
      final [row] = await db.select(db.briefings).get();
      expect(row.date, '2026-10-12');
      expect(row.openedAt, now);
      expect(await container.read(briefingOpenedTodayProvider)(), isTrue);
    });

    test('사용자가 바꾼 하루 경계로 그날을 고른다', () async {
      await SettingsRepository(db).write(SettingKeys.dayBoundaryMin, 360);
      final container = await containerWith(
        TestClock(DateTime(2026, 10, 13, 5, 59)),
      );

      await container.read(markBriefingSeenProvider)();

      expect(await seenDates(db), ['2026-10-12']);
    });

    test('설정은 읽었지만 기록을 쓰지 못해도 던지지 않는다', () async {
      final container = await containerWith(
        TestClock(DateTime(2026, 10, 13, 9)),
      );
      await db.customStatement('DROP TABLE briefings');

      await expectLater(
        container.read(markBriefingSeenProvider)(),
        completion(isNull),
      );
    });

    test('설정을 읽지 못하면 적지 않고 던지지 않는다', () async {
      final container = await containerWith(
        TestClock(DateTime(2026, 10, 13, 9)),
      );
      await db.customSelect('SELECT 1').get();
      await db.close();

      await expectLater(
        container.read(markBriefingSeenProvider)(),
        completion(isNull),
      );
    });

    test('데모를 끝내는 중이면 데모 DB에도 실제 DB에도 적지 않는다', () async {
      // 실제·데모 메모리 DB 둘을 함께 여므로 같은 연결을 두 번 쓸 때 내는 drift 경고를 끈다.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final demoDb = AppDatabase.memory();
      addTearDown(demoDb.close);
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'onboarding',
      });
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          databaseProvider.overrideWith(
            (ref) => switch (ref.watch(appModeProvider)) {
              AppMode.real => db,
              AppMode.demo => demoDb,
            },
          ),
          clockProvider.overrideWithValue(TestClock(DateTime(2026, 10, 13, 9))),
        ],
      );
      addTearDown(container.dispose);

      // 01 아침 브리핑이 뜨는 순간 끝내기를 눌렀다.
      final exit = container
          .read(appModeProvider.notifier)
          .exitDemo(container.read(databaseProvider));
      final mark = container.read(markBriefingSeenProvider)();
      expect(await exit, const Ok(DemoEntry.onboarding));
      expect(await mark, isNull);

      expect(await seenDates(demoDb), isEmpty);
      expect(await seenDates(db), isEmpty);
    });

    test('설정을 읽는 동안 데모 끝내기가 끝나 모드가 바뀌었어도 적지 않는다', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final demoDb = AppDatabase.memory();
      addTearDown(demoDb.close);
      final settings = _GatedSettings(demoDb);
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'onboarding',
      });
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          databaseProvider.overrideWith(
            (ref) => switch (ref.watch(appModeProvider)) {
              AppMode.real => db,
              AppMode.demo => demoDb,
            },
          ),
          settingsRepositoryProvider.overrideWithValue(settings),
          clockProvider.overrideWithValue(TestClock(DateTime(2026, 10, 13, 9))),
        ],
      );
      addTearDown(container.dispose);

      final mark = container.read(markBriefingSeenProvider)();
      expect(
        await container
            .read(appModeProvider.notifier)
            .exitDemo(container.read(databaseProvider)),
        const Ok(DemoEntry.onboarding),
      );
      expect(container.read(appModeProvider), AppMode.real);
      settings.gate.complete();
      expect(await mark, isNull);

      expect(await seenDates(demoDb), isEmpty);
      expect(await seenDates(db), isEmpty);
    });
  });
}

/// [gate]가 열릴 때까지 설정 읽기를 붙잡아 두는 저장소.
class _GatedSettings extends SettingsRepository {
  _GatedSettings(super.db);

  final gate = Completer<void>();

  @override
  Future<Result<AppSettings>> read() async {
    await gate.future;
    return super.read();
  }
}
