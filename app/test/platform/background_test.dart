// 백그라운드 동기화 테스트. docs/architecture.md '앱 코드 규약'의 백그라운드 작업, docs/lms.md '동기화'.
//
// 작업 이름이 iOS 설정과 같은지, 앱을 켤 때의 작업 등록, 백그라운드 엔진의 작업 한 번(준비 → 갱신 → 정리)을 본다.
// OS 작업·Firebase 대신 가짜를 쓰고, LMS는 합성 응답의 가짜 서버다. 작업은 폰 DB를 닫으므로 임시 폴더의 파일 DB를
// 쓰고 다른 연결로 결과를 읽는다.

import 'dart:convert';
import 'dart:io';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/remote_config.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/platform/background.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../helpers/fake_lms_server.dart';
import '../helpers/lms_samples.dart';

final _now = DateTime(2026, 11, 18, 10, 30);

/// 부른 것을 적는 가짜 workmanager. [failWith]가 있으면 모든 호출이 그 오류로 끝난다.
class _FakeWorkmanager implements Workmanager {
  final invocations = <Invocation>[];
  Object? failWith;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    invocations.add(invocation);
    if (failWith case final error?) return Future<void>.error(error);
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('작업 이름은 iOS의 AppDelegate.swift·Info.plist와 같다', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(r'static let syncIdentifier = "([^"]+)"')
          .firstMatch(delegate)
          ?.group(1),
      backgroundSyncTask,
    );
    expect(
      RegExp(
        r'<key>BGTaskSchedulerPermittedIdentifiers</key>\s*<array>\s*'
        r'<string>([^<]+)</string>\s*</array>',
      ).firstMatch(plist)?.group(1),
      backgroundSyncTask,
    );
  });

  group('scheduleBackgroundSync', () {
    test('진입점을 알린 뒤 주기 작업을 네트워크가 있을 때만, 이미 있으면 새 설정으로 등록한다', () async {
      final manager = _FakeWorkmanager();

      await scheduleBackgroundSync(workmanager: manager);

      expect(manager.invocations.map((i) => i.memberName), [
        #initialize,
        #registerPeriodicTask,
      ]);
      expect(
        manager.invocations.first.positionalArguments.single,
        same(callbackDispatcher),
      );
      final register = manager.invocations.last;
      expect(register.positionalArguments, [
        backgroundSyncTask,
        backgroundSyncTask,
      ]);
      expect(register.namedArguments[#frequency], const Duration(hours: 3));
      expect(
        (register.namedArguments[#constraints] as Constraints).networkType,
        NetworkType.connected,
      );
      expect(
        register.namedArguments[#existingWorkPolicy],
        ExistingPeriodicWorkPolicy.update,
      );
    });

    test('등록하지 못해도 던지지 않는다', () async {
      final manager = _FakeWorkmanager()..failWith = StateError('합성');

      await scheduleBackgroundSync(workmanager: manager);

      expect(manager.invocations.map((i) => i.memberName), [#initialize]);
    });
  });

  group('runBackgroundSync', () {
    const vault = CookieVault(FlutterSecureStorage());
    late Directory dir;
    late File file;

    /// 파일 DB를 따로 열어 [action]을 하고 닫는다(작업 전에 채우거나, 작업이 쓰고 닫은 파일을 읽을 때).
    Future<T> withDb<T>(Future<T> Function(AppDatabase db) action) async {
      final db = AppDatabase(NativeDatabase(file));
      try {
        return await action(db);
      } finally {
        await db.close();
      }
    }

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('background_sync_');
      file = File('${dir.path}/app.sqlite');
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await vault.writeSession(
        LmsSession(
          savedAt: kstToUtc(_now),
          userAgent: 'SyntheticAgent/1.0',
          cookies: const [
            LmsCookie(name: 'sess', value: 's1', domain: 'example.invalid'),
          ],
        ),
      );
      await withDb(
        (db) =>
            SettingsRepository(db)
                .write(SettingKeys.lmsSessionState, LmsSessionState.active),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    FakeLmsServer server() => FakeLmsServer({
      ...syntheticLoginRoutes(),
      'POST /api/synthetic-courses': (_) => FakeLmsResponse(
        200,
        contentType: 'application/json',
        body: lmsFixture('normal_course_list.json'),
      ),
      'POST /api/synthetic-todos': (_) => FakeLmsResponse(
        200,
        contentType: 'application/json',
        body: lmsFixture('normal_todo_list.json'),
      ),
    });

    List<Override> overrides(
      FakeLmsServer lms, {
      String minVersion = '0.0.0',
    }) => [
      lmsRemoteValuesProvider.overrideWithValue(
        () => (
          enabled: true,
          requestParams: syntheticSyncParamsJson,
          syncBudget: jsonEncode(lmsSyncBudgetDefaults),
        ),
      ),
      lmsSchoolDomainProvider.overrideWithValue(syntheticSchoolDomain),
      lmsHttpAdapterProvider.overrideWithValue(lms),
      lmsSleepProvider.overrideWithValue((_) async {}),
      clockProvider.overrideWithValue(FixedClock(_now)),
      // 실제로는 플랫폼에 묻는 값이라 곧바로 오지 않는다.
      appVersionProvider.overrideWith(
        (ref) =>
            Future.delayed(const Duration(milliseconds: 20), () => '0.1.0'),
      ),
      minAppVersionReaderProvider.overrideWithValue(() => minVersion),
    ];

    test(
      'Firebase → 폰 DB → Remote Config 받기 차례로 준비한 뒤 백그라운드 계기로 갱신하고 폰 DB를 닫는다',
      () async {
        final lms = server();
        final steps = <String>[];
        late AppDatabase opened;

        final result = await runBackgroundSync(
          prepareFirebase: () async => steps.add('firebase'),
          fetchRemoteConfig: () async => steps.add('fetch'),
          openDatabase: () {
            steps.add('open');
            return opened = AppDatabase(NativeDatabase(file));
          },
          overrides: overrides(lms),
        );

        expect(result?.kind, SyncResultKind.normal);
        expect(steps, ['firebase', 'open', 'fetch']);
        expect(lms.to('/api/synthetic-todos'), hasLength(1));
        final runs = await withDb((db) => db.select(db.syncRuns).get());
        expect(runs.map((run) => (run.trigger, run.scope, run.result)), [
          (SyncTrigger.background, SyncScope.list, SyncResultKind.normal),
        ]);
        await expectLater(
          opened.customSelect('SELECT 1').get(),
          throwsA(anything),
        );
      },
    );

    test('마지막 성공 뒤 3시간이 지나지 않았으면 앱 열기처럼 LMS를 부르지 않는다', () async {
      await withDb(
        (db) => SettingsRepository(db).write(
          SettingKeys.lmsLastSuccessAt,
          _now.subtract(const Duration(hours: 1)),
        ),
      );
      final lms = server();

      final result = await runBackgroundSync(
        prepareFirebase: () async {},
        fetchRemoteConfig: () async {},
        openDatabase: () => AppDatabase(NativeDatabase(file)),
        overrides: overrides(lms),
      );

      expect(result?.kind, SyncResultKind.skipped);
      expect(lms.requests, isEmpty);
    });

    test('업데이트가 필요한 빌드면 LMS를 부르지 않는다', () async {
      final lms = server();

      final result = await runBackgroundSync(
        prepareFirebase: () async {},
        fetchRemoteConfig: () async {},
        openDatabase: () => AppDatabase(NativeDatabase(file)),
        overrides: overrides(lms, minVersion: '9.0.0'),
      );

      expect(result?.kind, SyncResultKind.skipped);
      expect(lms.requests, isEmpty);
    });

    test('준비하다 실패하면 기록만 남기고 null이며 폰 DB를 열지 않는다', () async {
      var opened = false;

      final result = await runBackgroundSync(
        prepareFirebase: () async => throw StateError('합성'),
        fetchRemoteConfig: () async {},
        openDatabase: () {
          opened = true;
          return AppDatabase(NativeDatabase(file));
        },
      );

      expect(result, isNull);
      expect(opened, isFalse);
    });
  });
}
