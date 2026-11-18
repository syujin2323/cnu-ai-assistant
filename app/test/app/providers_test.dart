// 앱 전역 provider 테스트. docs/architecture.md '데모 모드'. 모션 등급은 test/app/app_binding_test.dart가 본다.

import 'dart:async';
import 'dart:io';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_run_repository.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart' show TestClock;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('appModeProvider', () {
    Future<AppMode> modeFor(Map<String, Object> preferences) async {
      SharedPreferences.setMockInitialValues(preferences);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(appModeProvider);
    }

    test('shared_preferences의 app_mode를 읽고, 없으면 real이다', () async {
      expect(await modeFor({}), AppMode.real);
      expect(await modeFor({'app_mode': 'real'}), AppMode.real);
      expect(await modeFor({'app_mode': 'demo'}), AppMode.demo);
    });

    test('데모를 끝내면 외래 키로 이어진 행까지 데모 DB를 모두 비우고 real로 돌아간다', () async {
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final preferences = await SharedPreferences.getInstance();
      // 끝내기는 비운 데모 DB를 닫으므로, 비웠는지는 같은 파일을 다시 열어(다음 데모처럼) 본다.
      final directory = await Directory.systemTemp.createTemp('demo_exit');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/app_demo.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // 실제 databaseProvider처럼 앱 모드를 보게 해 순환 의존이 없는지도 함께 본다.
          databaseProvider.overrideWith((ref) {
            ref.watch(appModeProvider);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      // 과목(부모)과 그 과목의 시간표 칸(자식). 부모가 먼저 지워져도 실패하지 않아야 한다.
      final courseId = await db
          .into(db.courses)
          .insert(CoursesCompanion.insert(name: '과목A'));
      await db
          .into(db.classSlots)
          .insert(
            ClassSlotsCompanion.insert(
              courseId: courseId,
              weekday: 1,
              startMin: 540,
              endMin: 615,
              campus: Campus.daedeok,
              online: false,
              source: SlotSource.manual,
            ),
          );

      final result = await container
          .read(appModeProvider.notifier)
          .exitDemo(container.read(databaseProvider));

      expect(result, const Ok(DemoEntry.me));
      expect(container.read(appModeProvider), AppMode.real);
      expect(preferences.getString('app_mode'), 'real');
      expect(preferences.containsKey('demo_entry'), isFalse);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(await reopened.select(reopened.courses).get(), isEmpty);
      expect(await reopened.select(reopened.classSlots).get(), isEmpty);
    });

    test('끝내기는 데모 DB를 비운 직후 스스로 닫아, 그 뒤의 데모 DB 저장은 Err다', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      SharedPreferences.setMockInitialValues({
        'app_mode': 'demo',
        'demo_entry': 'me',
      });
      final realDb = AppDatabase.memory();
      final demoDb = AppDatabase.memory();
      addTearDown(realDb.close);
      addTearDown(demoDb.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          // provider가 데모 DB를 닫지 않게 두어(늦게 닫히는 경우) 끝내기가 스스로 닫는지만 본다.
          databaseProvider.overrideWith(
            (ref) => switch (ref.watch(appModeProvider)) {
              AppMode.real => realDb,
              AppMode.demo => demoDb,
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appModeProvider.notifier).exitDemo(demoDb),
        const Ok(DemoEntry.me),
      );
      expect(
        await SettingsRepository(demoDb).write(SettingKeys.aiEnabled, true),
        isA<Err<void>>(),
      );
    });

    group('데모 끝내기·들어가기를 거듭 부를 때', () {
      late SharedPreferences preferences;
      late AppDatabase realDb;
      late AppDatabase demoDb;
      late ProviderContainer container;

      setUp(() async {
        // 실제·데모 메모리 DB 둘을 함께 여므로 같은 연결을 두 번 쓸 때 내는 drift 경고를 끈다.
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        addTearDown(
          () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
        );
        SharedPreferences.setMockInitialValues({
          'app_mode': 'demo',
          'demo_entry': 'onboarding',
        });
        preferences = await SharedPreferences.getInstance();
        realDb = AppDatabase.memory();
        demoDb = AppDatabase.memory();
        addTearDown(realDb.close);
        addTearDown(demoDb.close);
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            // 실제처럼 모드가 바뀌면 데모 DB를 닫는다.
            databaseProvider.overrideWith((ref) {
              switch (ref.watch(appModeProvider)) {
                case AppMode.real:
                  return realDb;
                case AppMode.demo:
                  ref.onDispose(() => unawaited(demoDb.close()));
                  return demoDb;
              }
            }),
          ],
        );
        addTearDown(container.dispose);
        await demoDb
            .into(demoDb.courses)
            .insert(CoursesCompanion.insert(name: '샘플 과목'));
      });

      test('끝내기를 끝나기 전에 또 부르면 같은 Future이고 비우기는 한 번만 한다', () async {
        final controller = container.read(appModeProvider.notifier);
        final db = container.read(databaseProvider);

        final first = controller.exitDemo(db);
        final second = controller.exitDemo(db);

        expect(second, same(first));
        expect(await first, const Ok(DemoEntry.onboarding));
        expect(container.read(appModeProvider), AppMode.real);
        // 끝난 뒤에 다시 부르면(이미 real) 비우지 않고 들어온 곳만 돌려준다.
        expect(await controller.exitDemo(db), const Ok(DemoEntry.onboarding));
      });

      test('데모 DB를 비우지 못하면 모드와 들어온 곳을 그대로 두고 Err다', () async {
        await demoDb.customStatement(
          'CREATE TRIGGER keep_courses BEFORE DELETE ON courses '
          "BEGIN SELECT RAISE(ABORT, 'test'); END",
        );

        final result = await container
            .read(appModeProvider.notifier)
            .exitDemo(container.read(databaseProvider));

        expect(result, isA<Err<DemoEntry>>());
        expect(container.read(appModeProvider), AppMode.demo);
        expect(preferences.getString('app_mode'), 'demo');
        expect(preferences.getString('demo_entry'), 'onboarding');
        expect(await demoDb.select(demoDb.courses).get(), hasLength(1));
      });

      test('들어가기를 끝나기 전에 또 부르면 같은 Future다', () async {
        expect(
          await container
              .read(appModeProvider.notifier)
              .exitDemo(container.read(databaseProvider)),
          isA<Ok<DemoEntry>>(),
        );
        final controller = container.read(appModeProvider.notifier);

        final first = controller.enterDemo(DemoEntry.me);
        final second = controller.enterDemo(DemoEntry.onboarding);

        expect(second, same(first));
        await first;
        expect(container.read(appModeProvider), AppMode.demo);
        expect(preferences.getString('demo_entry'), 'me');
      });
    });
  });

  group('apiProvider', () {
    test('데모 모드에 들어가면 요청을 보내지 않는 클라이언트로 바뀐다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final real = container.read(apiProvider);
      expect(real.demo, isFalse);

      await container
          .read(appModeProvider.notifier)
          .enterDemo(DemoEntry.onboarding);

      final demo = container.read(apiProvider);
      expect(demo.demo, isTrue);
      expect(demo, isNot(same(real)));
    });
  });

  group('minuteClockProvider', () {
    testWidgets('분이 바뀔 때마다 시계의 지금으로 바꾼다', (tester) async {
      final clock = TestClock(DateTime(2026, 11, 16, 9, 0, 30));
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(clock)],
      );
      final seen = <DateTime>[];
      container.listen(
        minuteClockProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      expect(seen, [DateTime(2026, 11, 16, 9, 0, 30)]);

      clock.current = DateTime(2026, 11, 16, 9, 1);
      await tester.pump(const Duration(seconds: 29));
      expect(seen, hasLength(1), reason: '아직 다음 분이 아니다');
      await tester.pump(const Duration(seconds: 1));
      expect(seen.last, DateTime(2026, 11, 16, 9, 1));

      clock.current = DateTime(2026, 11, 16, 9, 2);
      await tester.pump(const Duration(minutes: 1));
      expect(seen.last, DateTime(2026, 11, 16, 9, 2));
      container.dispose();
    });
  });

  group('lmsStatusProvider', () {
    // 2026-11-16(월) 12:00.
    final now = DateTime(2026, 11, 16, 12);

    Future<(ProviderContainer, AppDatabase)> start({
      Map<String, Object> preferences = const {},
      LmsConfig? config,
    }) async {
      SharedPreferences.setMockInitialValues(preferences);
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(TestClock(now)),
          if (config != null)
            lmsConfigProvider.overrideWith(() => _FixedLmsConfig(config)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(lmsStatusProvider, (_, _) {});
      return (container, db);
    }

    /// DB 스트림이 새 값을 낼 때까지 기다린 뒤의 상태 줄 문구.
    Future<String?> textOf(ProviderContainer container) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return container.read(lmsStatusProvider)?.text;
    }

    Future<void> addRun(
      AppDatabase db, {
      required DateTime startedAt,
      required SyncTrigger trigger,
      required SyncResultKind result,
    }) async {
      final added = await SyncRunRepository(db).add(
        startedAt: startedAt,
        trigger: trigger,
        scope: SyncScope.list,
        result: result,
        elapsedMs: 100,
      );
      expect(added, isA<Ok<int>>());
    }

    test('설정과 동기화 기록을 읽어 상태 줄을 정하고, 바뀌면 다시 정한다', () async {
      final (container, db) = await start();
      final settings = SettingsRepository(db);
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      expect(
        await settings.writeAll({
          SettingKeys.lmsSessionState: LmsSessionState.active,
          SettingKeys.lmsLastSuccessAt: fiveMinutesAgo,
        }),
        isA<Ok<void>>(),
      );
      // 마지막 확인을 남긴 동기화가 사용자 새로 고침이면 10분 동안 방금이다.
      await addRun(
        db,
        startedAt: fiveMinutesAgo,
        trigger: SyncTrigger.manual,
        result: SyncResultKind.normal,
      );
      expect(await textOf(container), 'LMS 정보 방금');

      // 그 뒤 자동 동기화가 실패하면 연결할 수 없어요를 붙인다.
      await addRun(
        db,
        startedAt: now.subtract(const Duration(minutes: 1)),
        trigger: SyncTrigger.periodic,
        result: SyncResultKind.networkFailure,
      );
      expect(await textOf(container), 'LMS 정보 방금 · 연결할 수 없어요');
      expect(
        container.read(lmsStatusProvider)?.kind,
        LmsStatusKind.connectionFailed,
      );

      expect(
        await settings.write(
          SettingKeys.lmsSessionState,
          LmsSessionState.reconnectRequired,
        ),
        isA<Ok<void>>(),
      );
      expect(await textOf(container), 'LMS 정보 방금 · 다시 로그인');
    });

    test('마지막 확인을 남긴 동기화가 자동이면 방금이 아니다', () async {
      final (container, db) = await start();
      final settings = SettingsRepository(db);
      final threeMinutesAgo = now.subtract(const Duration(minutes: 3));
      expect(
        await settings.writeAll({
          SettingKeys.lmsSessionState: LmsSessionState.active,
          SettingKeys.lmsLastSuccessAt: threeMinutesAgo,
        }),
        isA<Ok<void>>(),
      );
      await addRun(
        db,
        startedAt: threeMinutesAgo,
        trigger: SyncTrigger.open,
        result: SyncResultKind.normal,
      );
      expect(await textOf(container), 'LMS 정보 3분 전');
    });

    test('새로 고침이 남긴 확인 시각이 아니면(더 늦은 확인이 따로 있음) 방금이 아니다', () async {
      final (container, db) = await start();
      final settings = SettingsRepository(db);
      expect(
        await settings.writeAll({
          SettingKeys.lmsSessionState: LmsSessionState.active,
          SettingKeys.lmsLastSuccessAt: now.subtract(
            const Duration(minutes: 3),
          ),
        }),
        isA<Ok<void>>(),
      );
      await addRun(
        db,
        startedAt: now.subtract(const Duration(minutes: 5)),
        trigger: SyncTrigger.manual,
        result: SyncResultKind.normal,
      );
      expect(await textOf(container), 'LMS 정보 3분 전');
    });

    test('데모 모드면 샘플 데이터 · 데모로 고정이다', () async {
      final (container, db) = await start(preferences: {'app_mode': 'demo'});
      expect(
        await SettingsRepository(
          db,
        ).write(SettingKeys.lmsSessionState, LmsSessionState.reconnectRequired),
        isA<Ok<void>>(),
      );
      expect(await textOf(container), '샘플 데이터 · 데모');
    });

    test('원격 스위치가 꺼졌으면 연동 멈춤이고, 설정을 받는 동안은 켜진 것으로 본다', () async {
      final (paused, pausedDb) = await start(
        config: const LmsConfig(enabled: false, requestParams: null),
      );
      expect(
        await SettingsRepository(pausedDb)
            .write(SettingKeys.lmsSessionState, LmsSessionState.active),
        isA<Ok<void>>(),
      );
      expect(await textOf(paused), 'LMS 연동을 잠시 멈췄어요');

      // Remote Config를 가져오는 중(테스트에서는 끝나지 않음)이면 스위치가 켜진 것으로 본다.
      final (loading, loadingDb) = await start();
      expect(
        await SettingsRepository(loadingDb)
            .write(SettingKeys.lmsSessionState, LmsSessionState.active),
        isA<Ok<void>>(),
      );
      expect(await textOf(loading), 'LMS 정보 받기 전');
    });
  });

  group('dayScheduleProvider·plannerConfigProvider', () {
    test('하루 경계로 그날의 범위를 정하고, 규칙을 읽어 배치 설정을 낸다', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final monday = DateTime(2026, 11, 16);
      container
        ..listen(dayScheduleProvider(monday), (_, _) {})
        ..listen(plannerConfigProvider, (_, _) {});

      // 화요일 03:30 블록은 하루 경계 04:00(기본)이면 월요일의 논리적 하루다.
      final taskId = await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: '과제',
              kind: TaskKind.assignment,
              dueTimeUnknown: false,
              status: TaskStatus.todo,
            ),
          );
      await db
          .into(db.planBlocks)
          .insert(
            PlanBlocksCompanion.insert(
              taskId: taskId,
              startAt: DateTime(2026, 11, 17, 3, 30),
              endAt: DateTime(2026, 11, 17, 3, 50),
              status: PlanBlockStatus.confirmed,
              source: BlockSource.manual,
            ),
          );
      Future<int> blocks() async {
        for (var i = 0; i < 200; i++) {
          if (container.read(dayScheduleProvider(monday)) case AsyncData(
            :final value,
          )) {
            return value.planBlocks.length;
          }
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        fail('일정을 기다리다 끝남');
      }

      expect(await blocks(), 1);
      // 하루 경계를 03:00으로 바꾸면 화요일 03:30은 화요일의 논리적 하루다.
      expect(
        await SettingsRepository(db).write(SettingKeys.dayBoundaryMin, 180),
        isA<Ok<void>>(),
      );
      for (var i = 0; i < 200 && await blocks() != 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await blocks(), 0);

      // 규칙이 없으면 기본값, 규칙을 넣으면 그 값이다.
      for (
        var i = 0;
        i < 200 && container.read(plannerConfigProvider) == null;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(container.read(plannerConfigProvider)?.maxBlockMin, 120);
      final when = DateTime(2026, 11, 1);
      await db
          .into(db.rules)
          .insert(
            RulesCompanion.insert(
              kind: RuleKind.maxBlock,
              params: const RuleParams(minutes: 90),
              active: true,
              source: EntrySource.manual,
              createdAt: when,
              updatedAt: when,
            ),
          );
      for (
        var i = 0;
        i < 200 && container.read(plannerConfigProvider)?.maxBlockMin != 90;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(container.read(plannerConfigProvider)?.maxBlockMin, 90);
    });
  });
}

/// 정해 둔 LMS 설정을 내는 노티파이어.
class _FixedLmsConfig extends LmsConfigController {
  _FixedLmsConfig(this.config);

  final LmsConfig config;

  @override
  Future<LmsConfig> build() async => config;
}
