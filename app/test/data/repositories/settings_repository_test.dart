// settings 기본값과 저장소 테스트. docs/architecture.md '폰 DB'의 settings 키·기본값, '앱 코드 규약'의 오류 처리.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  // 닫힌 DB·두 연결 테스트는 AppDatabase를 한 번에 여럿 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    repo = SettingsRepository(db);
  });

  tearDown(() => db.close());

  Future<void> putRaw(String key, String json) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: json));

  Future<Map<String, String>> rawRows() async => {
    for (final row in await db.select(db.settings).get()) row.key: row.value,
  };

  /// read()가 Ok인지 보고 값을 꺼낸다.
  Future<AppSettings> readOk() async {
    final result = await repo.read();
    expect(result, isA<Ok<AppSettings>>());
    return (result as Ok<AppSettings>).value;
  }

  /// write()가 Ok인지 본다.
  Future<void> writeOk(String key, Object? value) async {
    expect(await repo.write(key, value), isA<Ok<void>>(), reason: key);
  }

  group('settings 기본값', () {
    test('빈 DB에서 read()는 문서의 기본값을 키마다 돌려준다', () async {
      final settings = await readOk();

      // docs/architecture.md '폰 DB'의 settings 키와 기본값을 그대로 옮겼다.
      expect(settings.dayBoundaryMin, 240);
      expect(settings.aiEnabled, isFalse);
      expect(settings.aiConsentAt, isNull);
      expect(settings.metricsEnabled, isFalse);
      expect(settings.metricsLastSentOn, isNull);
      expect(settings.lmsSessionState, LmsSessionState.disconnected);
      expect(settings.lmsLastSuccessAt, isNull);
      expect(settings.lmsLastConnectedAt, isNull);
      expect(settings.checkinMin, isNull);
      expect(settings.dueTodayTimeSensitive, isFalse);
      expect(settings.motionLevel, MotionLevelSetting.auto);
      expect(settings.onboardingSkipped, isEmpty);
      expect(settings.installedAt, isNull);
      expect(settings, AppSettings.defaults);
    });

    test('기본값을 표에 적을 JSON은 문서의 키 목록·값과 같다', () {
      expect(AppSettings.defaults.toValues(), {
        'dayBoundaryMin': 240,
        'aiEnabled': false,
        'aiConsentAt': null,
        'metricsEnabled': false,
        'metricsLastSentOn': null,
        'lmsSessionState': 'disconnected',
        'lmsLastSuccessAt': null,
        'lmsLastConnectedAt': null,
        'checkinMin': null,
        'dueTodayTimeSensitive': false,
        'motionLevel': 'auto',
        'onboardingSkipped': <int>[],
        'installedAt': null,
      });
      expect(SettingKeys.all, AppSettings.defaults.toValues().keys.toList());
    });
  });

  group('settings 쓰기', () {
    test('write 뒤 read에 바로 반영되고 쓰지 않은 키는 기본값 그대로다', () async {
      final consentAt = DateTime(2026, 10, 29, 9, 30);
      await writeOk(SettingKeys.dayBoundaryMin, 300);
      await writeOk(SettingKeys.aiEnabled, true);
      await writeOk(SettingKeys.aiConsentAt, consentAt);
      await writeOk(SettingKeys.metricsLastSentOn, '2026-10-28');
      await writeOk(
        SettingKeys.lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
      await writeOk(SettingKeys.checkinMin, 1350);
      await writeOk(SettingKeys.motionLevel, MotionLevelSetting.off);
      await writeOk(SettingKeys.onboardingSkipped, [3, 4]);

      expect(
        await readOk(),
        AppSettings.defaults.copyWith(
          dayBoundaryMin: 300,
          aiEnabled: true,
          aiConsentAt: consentAt,
          metricsLastSentOn: '2026-10-28',
          lmsSessionState: LmsSessionState.reconnectRequired,
          checkinMin: 1350,
          motionLevel: MotionLevelSetting.off,
          onboardingSkipped: [3, 4],
        ),
      );
    });

    test('같은 키를 다시 쓰면 마지막 값만 남는다', () async {
      await writeOk(SettingKeys.aiEnabled, true);
      await writeOk(SettingKeys.aiEnabled, false);

      expect((await readOk()).aiEnabled, isFalse);
      expect((await rawRows()).length, 1);
    });

    test('watch()는 처음에 기본값을 내고 write 뒤 바뀐 값을 낸다', () async {
      expect(await repo.watch().first, AppSettings.defaults);

      final changed = expectLater(
        repo.watch(),
        emitsThrough(
          isA<AppSettings>()
              .having((s) => s.aiEnabled, 'aiEnabled', isTrue)
              .having((s) => s.dayBoundaryMin, 'dayBoundaryMin', 240),
        ),
      );
      await writeOk(SettingKeys.aiEnabled, true);
      await changed;
    });

    test('하루 경계는 고르는 값 03:00·04:00·05:00·06:00을 쓸 수 있다', () async {
      for (final minute in Defaults.dayBoundaryChoices) {
        await writeOk(SettingKeys.dayBoundaryMin, minute);
        expect((await readOk()).dayBoundaryMin, minute);
      }
    });

    test('null을 받는 키는 null을 써서 다시 비운다', () async {
      await writeOk(SettingKeys.installedAt, DateTime(2026, 10, 29, 8));
      expect((await readOk()).installedAt, DateTime(2026, 10, 29, 8));

      await writeOk(SettingKeys.installedAt, null);
      expect((await readOk()).installedAt, isNull);
    });

    test('열거형은 영문 snake_case, 시각은 UTC 오프셋이 붙은 문자열로 적는다', () async {
      await writeOk(
        SettingKeys.lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
      await writeOk(SettingKeys.lmsLastSuccessAt, DateTime(2026, 10, 29, 9));

      final rows = await rawRows();
      expect(rows[SettingKeys.lmsSessionState], '"reconnect_required"');
      expect(
        jsonDecode(rows[SettingKeys.lmsLastSuccessAt]!),
        matches(RegExp(r'^2026-10-29T09:00:00\.000 [+-]\d\d:\d\d$')),
      );
    });

    test('모르는 키, 맞지 않는 형, 하루 밖의 분은 ArgumentError이고 표를 바꾸지 않는다', () async {
      final invalid = <(String, Object?)>[
        ('unknownKey', 1),
        (SettingKeys.dayBoundaryMin, '240'),
        (SettingKeys.dayBoundaryMin, null),
        (SettingKeys.dayBoundaryMin, 1440),
        // 하루 안이어도 고르는 값(03:00·04:00·05:00·06:00)이 아니면 쓰지 않는다.
        (SettingKeys.dayBoundaryMin, 0),
        (SettingKeys.dayBoundaryMin, 1439),
        (SettingKeys.checkinMin, -1),
        (SettingKeys.aiEnabled, 'true'),
        (SettingKeys.lmsSessionState, 'active'),
        // 없앤 키(자동 로그인 유지, 연결 방식)는 이제 모르는 키다.
        ('lmsAutoLogin', true),
        ('lmsMode', 'phone'),
        (SettingKeys.aiConsentAt, '2026-10-29'),
        (SettingKeys.metricsLastSentOn, '2026-10-32'),
        (SettingKeys.onboardingSkipped, null),
        // 건너뛴 온보딩 단계는 1–5의 중복 없는 오름차순 목록만 쓴다.
        (SettingKeys.onboardingSkipped, [0]),
        (SettingKeys.onboardingSkipped, [6]),
        (SettingKeys.onboardingSkipped, [3, 3]),
        (SettingKeys.onboardingSkipped, [4, 3]),
      ];
      for (final (key, value) in invalid) {
        await expectLater(
          repo.write(key, value),
          throwsArgumentError,
          reason: '$key = $value',
        );
      }
      expect(await rawRows(), isEmpty);
    });
  });

  group('settings 읽기', () {
    test('건너뛴 온보딩 단계는 1–5 밖의 수와 중복을 버리고 오름차순으로 읽는다', () async {
      await putRaw(SettingKeys.onboardingSkipped, '[0, 3, 3, 9]');
      expect((await readOk()).onboardingSkipped, [3]);

      await putRaw(SettingKeys.onboardingSkipped, '[5, 2, 5]');
      expect((await readOk()).onboardingSkipped, [2, 5]);
    });

    test('저장된 값이 깨졌거나 형이 다르면 그 키만 기본값으로 읽는다', () async {
      await writeOk(SettingKeys.metricsEnabled, true);
      await putRaw(SettingKeys.dayBoundaryMin, 'not json');
      await putRaw(SettingKeys.aiEnabled, '"yes"');
      await putRaw(SettingKeys.checkinMin, '1440');
      await putRaw(SettingKeys.lmsSessionState, '"reconnectRequired"');
      await putRaw(SettingKeys.motionLevel, '"fast"');
      await putRaw(SettingKeys.onboardingSkipped, '[1, "x"]');
      await putRaw(SettingKeys.installedAt, '"yesterday"');
      await putRaw(SettingKeys.metricsLastSentOn, '"2026-02-30"');
      await putRaw('unknownKey', '1');
      // 없앤 키가 예전 행으로 남아 있어도 읽지 않는다.
      await putRaw('lmsAutoLogin', 'true');
      await putRaw('lmsMode', '"phone"');

      expect(
        await readOk(),
        AppSettings.defaults.copyWith(metricsEnabled: true),
      );
    });

    test('저장된 하루 경계는 고르는 값이 아니어도 하루 안이면 그대로 읽는다', () async {
      await putRaw(SettingKeys.dayBoundaryMin, '1439');
      expect((await readOk()).dayBoundaryMin, 1439);

      await putRaw(SettingKeys.dayBoundaryMin, '1440');
      expect((await readOk()).dayBoundaryMin, Defaults.dayBoundaryMin);
    });

    test('시각은 UTC 오프셋이 붙은 값만 읽고 오프셋이 없으면 기본값이다', () async {
      await putRaw(SettingKeys.installedAt, '"2026-10-29"');
      await putRaw(SettingKeys.aiConsentAt, '"2026-10-29T09:30:00.000"');
      await putRaw(SettingKeys.lmsLastSuccessAt, '"2026-10-29T00:30:00.000Z"');
      await putRaw(
        SettingKeys.lmsLastConnectedAt,
        '"2026-10-29T09:30:00.000 +09:00"',
      );

      final settings = await readOk();
      expect(settings.installedAt, isNull);
      expect(settings.aiConsentAt, isNull);
      expect(
        settings.lmsLastSuccessAt,
        DateTime.utc(2026, 10, 29, 0, 30).toLocal(),
      );
      expect(settings.lmsLastSuccessAt!.isUtc, isFalse);
      expect(
        settings.lmsLastConnectedAt,
        DateTime.utc(2026, 10, 29, 0, 30).toLocal(),
      );
    });
  });

  group('settings 저장 실패', () {
    test('폰 DB를 읽거나 쓰지 못하면 예외 대신 StorageError를 담은 Err를 돌려준다', () async {
      // 표가 없는 DB로 실패를 만든다. 1은 SQLITE_ERROR(없는 표)다.
      await db.customStatement('DROP TABLE settings');

      expect(
        _errorOf(await repo.read()),
        const StorageError(
          'settings.read',
          causeType: 'SqliteException',
          code: 1,
        ),
      );
      expect(
        _errorOf(await repo.write(SettingKeys.aiEnabled, true)),
        const StorageError(
          'settings.write',
          causeType: 'SqliteException',
          code: 1,
        ),
      );
    });

    test('닫힌 DB를 받아 둔 저장소도 StateError를 던지지 않고 Err를 돌려준다', () async {
      // 데모를 끝내며 닫은 DB를 받아 둔 저장소를 await 뒤에 쓰는 경우.
      final closed = AppDatabase.memory();
      final closedRepo = SettingsRepository(closed);
      expect(await closedRepo.read(), isA<Ok<AppSettings>>());
      await closed.close();

      expect(
        _errorOf(await closedRepo.read()),
        const StorageError('settings.read', causeType: 'StateError'),
      );
      expect(
        _errorOf(await closedRepo.write(SettingKeys.aiEnabled, true)),
        const StorageError('settings.write', causeType: 'StateError'),
      );
    });

    test(
      '앱처럼 백그라운드 연결로 연 파일 DB에서 다른 연결이 쓰는 중이면 잠금 오류(SqliteException, 코드 5)다',
      () async {
        final file = await _tempDatabaseFile();
        final app = AppDatabase(
          NativeDatabase.createBackgroundConnection(file),
        );
        addTearDown(app.close);
        final appRepo = SettingsRepository(app);
        expect(
          await appRepo.write(SettingKeys.aiEnabled, true),
          isA<Ok<void>>(),
        );

        // 같은 파일을 연 다른 연결(백그라운드 작업처럼)이 쓰기 트랜잭션을 연 채로 둔다.
        final other = AppDatabase(NativeDatabase(file));
        addTearDown(other.close);
        final locked = Completer<void>();
        final release = Completer<void>();
        final holding = other.transaction(() async {
          await other
              .into(other.settings)
              .insertOnConflictUpdate(
                SettingsCompanion.insert(
                  key: SettingKeys.motionLevel,
                  value: '"off"',
                ),
              );
          locked.complete();
          await release.future;
        });
        await locked.future;

        final result = await appRepo.write(SettingKeys.aiEnabled, false);
        release.complete();
        await holding;

        // 백그라운드 연결의 오류는 DriftRemoteException에 싸여 오지만 원인과 코드를 담는다.
        expect(
          _errorOf(result),
          const StorageError(
            'settings.write',
            causeType: 'SqliteException',
            code: 5,
          ),
        );
        // 잠금이 풀리면 다시 쓸 수 있다.
        expect(
          await appRepo.write(SettingKeys.aiEnabled, false),
          isA<Ok<void>>(),
        );
        expect(switch (await appRepo.read()) {
          Ok(:final value) => value.aiEnabled,
          Err() => null,
        }, isFalse);
      },
    );
  });
}

/// [result]가 [Err]면 그 오류, [Ok]면 null.
AppError? _errorOf(Result<Object?> result) => switch (result) {
  Ok() => null,
  Err(:final error) => error,
};

/// 테스트마다 새 임시 폴더의 DB 파일(앱처럼 파일에 연다). 테스트가 끝나면 폴더를 지운다.
Future<File> _tempDatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('settings_repository_test');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/app.sqlite');
}
