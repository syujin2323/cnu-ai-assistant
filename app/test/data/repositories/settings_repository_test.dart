// settings 기본값과 저장소 테스트. docs/architecture.md '폰 DB'의 settings 키·기본값, '앱 코드 규약'의 오류 처리.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

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
      expect(settings.lmsMode, LmsMode.none);
      expect(settings.lmsSessionState, LmsSessionState.disconnected);
      expect(settings.lmsAutoLogin, isFalse);
      expect(settings.lmsLastSuccessAt, isNull);
      expect(settings.lmsLastConnectedAt, isNull);
      expect(settings.checkinMin, isNull);
      expect(settings.dueTodayTimeSensitive, isFalse);
      expect(settings.motionLevel, MotionLevelSetting.auto);
      expect(settings.onboardingSkipped, isEmpty);
      expect(settings.installedAt, isNull);
      expect(settings.hiddenCalendars, isEmpty);
      expect(settings, AppSettings.defaults);
    });

    test('기본값을 표에 적을 JSON은 문서의 키 목록·값과 같다', () {
      expect(AppSettings.defaults.toValues(), {
        'dayBoundaryMin': 240,
        'aiEnabled': false,
        'aiConsentAt': null,
        'metricsEnabled': false,
        'metricsLastSentOn': null,
        'lmsMode': 'none',
        'lmsSessionState': 'disconnected',
        'lmsAutoLogin': false,
        'lmsLastSuccessAt': null,
        'lmsLastConnectedAt': null,
        'checkinMin': null,
        'dueTodayTimeSensitive': false,
        'motionLevel': 'auto',
        'onboardingSkipped': <int>[],
        'installedAt': null,
        'lastVisitAt': null,
        'hiddenCalendars': <String>[],
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
      await writeOk(SettingKeys.lmsMode, LmsMode.phone);
      await writeOk(
        SettingKeys.lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
      await writeOk(SettingKeys.checkinMin, 1350);
      await writeOk(SettingKeys.motionLevel, MotionLevelSetting.off);
      await writeOk(SettingKeys.onboardingSkipped, [3, 4]);
      await writeOk(SettingKeys.hiddenCalendars, ['lms']);

      expect(
        await readOk(),
        AppSettings.defaults.copyWith(
          dayBoundaryMin: 300,
          aiEnabled: true,
          aiConsentAt: consentAt,
          metricsLastSentOn: '2026-10-28',
          lmsMode: LmsMode.phone,
          lmsSessionState: LmsSessionState.reconnectRequired,
          checkinMin: 1350,
          motionLevel: MotionLevelSetting.off,
          onboardingSkipped: [3, 4],
          hiddenCalendars: ['lms'],
        ),
      );
    });

    test('같은 키를 다시 쓰면 마지막 값만 남는다', () async {
      await writeOk(SettingKeys.lmsAutoLogin, true);
      await writeOk(SettingKeys.lmsAutoLogin, false);

      expect((await readOk()).lmsAutoLogin, isFalse);
      expect((await rawRows()).length, 1);
    });

    test('watch()는 처음에 기본값을 내고 write 뒤 바뀐 값을 낸다', () async {
      expect(await repo.watch().first, AppSettings.defaults);

      final changed = expectLater(
        repo.watch(),
        emitsThrough(
          isA<AppSettings>()
              .having((s) => s.lmsAutoLogin, 'lmsAutoLogin', isTrue)
              .having((s) => s.dayBoundaryMin, 'dayBoundaryMin', 240),
        ),
      );
      await writeOk(SettingKeys.lmsAutoLogin, true);
      await changed;
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
        (SettingKeys.checkinMin, -1),
        (SettingKeys.aiEnabled, 'true'),
        (SettingKeys.lmsMode, 'phone'),
        (SettingKeys.aiConsentAt, '2026-10-29'),
        (SettingKeys.metricsLastSentOn, '2026-10-32'),
        (SettingKeys.onboardingSkipped, null),
        (SettingKeys.hiddenCalendars, [1]),
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
    test('저장된 값이 깨졌거나 형이 다르면 그 키만 기본값으로 읽는다', () async {
      await writeOk(SettingKeys.lmsAutoLogin, true);
      await putRaw(SettingKeys.dayBoundaryMin, 'not json');
      await putRaw(SettingKeys.aiEnabled, '"yes"');
      await putRaw(SettingKeys.checkinMin, '1440');
      await putRaw(SettingKeys.lmsSessionState, '"reconnectRequired"');
      await putRaw(SettingKeys.motionLevel, '"fast"');
      await putRaw(SettingKeys.onboardingSkipped, '[1, "x"]');
      await putRaw(SettingKeys.hiddenCalendars, '"lms"');
      await putRaw(SettingKeys.installedAt, '"yesterday"');
      await putRaw(SettingKeys.metricsLastSentOn, '"2026-02-30"');
      await putRaw('unknownKey', '1');

      expect(await readOk(), AppSettings.defaults.copyWith(lmsAutoLogin: true));
    });
  });

  group('settings 저장 실패', () {
    test('폰 DB를 읽거나 쓰지 못하면 예외 대신 StorageError를 담은 Err를 돌려준다', () async {
      // 표가 없는 DB로 실패를 만든다.
      await db.customStatement('DROP TABLE settings');

      final readResult = await repo.read();
      expect(readResult, isA<Err<AppSettings>>());
      expect(
        (readResult as Err<AppSettings>).error,
        isA<StorageError>()
            .having((e) => e.operation, 'operation', 'settings.read')
            .having((e) => e.causeType, 'causeType', isNotNull),
      );

      final writeResult = await repo.write(SettingKeys.aiEnabled, true);
      expect(writeResult, isA<Err<void>>());
      expect(
        (writeResult as Err<void>).error,
        isA<StorageError>().having(
          (e) => e.operation,
          'operation',
          'settings.write',
        ),
      );
    });
  });
}
