// LMS 동기화 코디네이터 테스트. docs/lms.md '동기화'·'호출 예산'·'세션 상태'·'세션 복원'.
//
// 가짜 LMS 서버(합성 키 스크립트·과목 목록·할 일 목록·홈)와 합성 요청 상수로 계기·예산·잠금·판별·쓰기·상태 전이를 본다.
// 학번·쿠키·키는 모두 합성 값이다.
import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/lms_sync_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_lease_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/sync_run_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/sync_lease.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/sync_budget.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_lms_server.dart';
import '../helpers/lms_samples.dart';

final _now = DateTime(2026, 11, 15, 10, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final params = parseLmsRequestParams(
    syntheticSyncParamsJson,
    schoolDomain: syntheticSchoolDomain,
  ).params!;
  const vault = CookieVault(FlutterSecureStorage());

  late AppDatabase db;
  late SettingsRepository settings;
  late SyncRunRepository syncRuns;
  late List<(String, Map<String, Object>)> events;
  late bool demo;
  late bool updateRequired;

  setUp(() async {
    db = AppDatabase.memory();
    settings = SettingsRepository(db);
    syncRuns = SyncRunRepository(db);
    events = [];
    demo = false;
    updateRequired = false;
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
    await settings.write(SettingKeys.lmsSessionState, LmsSessionState.active);
  });
  tearDown(() => db.close());

  String todosBody() => lmsFixture('normal_todo_list.json');

  Map<String, FakeLmsResponse Function(FakeLmsRequest)> routes({
    FakeLmsResponse Function(FakeLmsRequest)? todos,
    FakeLmsResponse Function(FakeLmsRequest)? courses,
  }) => {
    ...syntheticLoginRoutes(),
    'POST /api/synthetic-courses':
        courses ??
        (_) => FakeLmsResponse(
          200,
          contentType: 'application/json',
          body: lmsFixture('normal_course_list.json'),
        ),
    'POST /api/synthetic-todos':
        todos ??
        (_) => FakeLmsResponse(
          200,
          contentType: 'application/json',
          body: todosBody(),
          setCookies: const ['fresh=f1; Path=/'],
        ),
  };

  SyncCoordinator coordinator(
    FakeLmsServer server, {
    LmsConfig? config,
    LmsConfig Function()? configNow,
    DateTime? now,
  }) => SyncCoordinator(
    config: () async =>
        configNow?.call() ??
        config ??
        LmsConfig(enabled: true, requestParams: params),
    vault: vault,
    settings: settings,
    syncRuns: syncRuns,
    leases: SyncLeaseRepository(db),
    store: LmsSyncRepository(db),
    clock: FixedClock(now ?? _now),
    schoolDomain: syntheticSchoolDomain,
    createDio: () => createLmsDio(adapter: server),
    sleep: (_) async {},
    isDemo: () => demo,
    updateRequired: () => updateRequired,
    reportEvent: (event, data) => events.add((event, data)),
  );

  Future<List<SyncRun>> runs() => (db.select(
    db.syncRuns,
  )..orderBy([(r) => OrderingTerm(expression: r.id)])).get();

  Future<AppSettings> readSettings() async =>
      (await settings.read() as Ok<AppSettings>).value;

  Future<SyncResult> manual(
    SyncCoordinator c, {
    SyncScope scope = SyncScope.list,
  }) => c.run(trigger: SyncTrigger.manual, scope: scope);

  group('조회', () {
    test('갱신은 키 스크립트로 암호 키를 받아 할 일 목록을 암호화해 묻고, 항목과 할 일을 쓰며 기록을 남긴다', () async {
      final server = FakeLmsServer(routes());

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.normal);
      expect(result.changedCount, 2);
      final request = server.to('/api/synthetic-todos').single;
      final payload = jsonDecode(
        aesCbcDecryptBase64(
          request.form['e']!,
          utf8.encode(syntheticBodyKey),
          List.filled(16, 0),
        ),
      );
      expect(payload, {'year': '2026', 'term': '20'});
      expect(request.header('cookie'), contains('sess=s1'));
      expect(request.header('user-agent'), 'SyntheticAgent/1.0');
      expect(server.to('/api/synthetic-courses'), isEmpty);

      final items = await db.select(db.lmsItems).get();
      expect(items, hasLength(2));
      expect(
        items.every((i) => i.remoteKey.startsWith('$syntheticSemester:')),
        isTrue,
      );
      expect(await db.select(db.tasks).get(), hasLength(2));

      final run = (await runs()).single;
      expect(
        (run.trigger, run.scope, run.result, run.changedCount, run.detail),
        (SyncTrigger.manual, SyncScope.list, SyncResultKind.normal, 2, null),
      );
      expect(run.startedAt, _now);
      expect((await readSettings()).lmsLastSuccessAt, _now);
      expect(await db.select(db.syncLeases).get(), isEmpty);
    });

    test('전체는 과목 목록을 먼저 쓰고 할 일 목록을 쓴다', () async {
      final server = FakeLmsServer(routes());

      final result = await manual(coordinator(server), scope: SyncScope.full);

      expect(result.kind, SyncResultKind.normal);
      expect(
        server.requests
            .map((r) => r.url.path)
            .where((p) => p.startsWith('/api/')),
        ['/api/synthetic-courses', '/api/synthetic-todos'],
      );
      final courses = await db.select(db.courses).get();
      expect(courses, isNotEmpty);
      expect(courses.every((c) => c.semester == syntheticSemester), isTrue);
      expect((await runs()).single.scope, SyncScope.full);
    });

    test('빈 목록도 성공이라 마지막 확인 시각을 올린다', () async {
      final server = FakeLmsServer(
        routes(
          todos: (_) => FakeLmsResponse(
            200,
            contentType: 'application/json',
            body: lmsFixture('empty_todo_list.json'),
          ),
        ),
      );

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.empty);
      expect((await readSettings()).lmsLastSuccessAt, _now);
    });

    test('받은 쿠키를 금고에 다시 쓴다', () async {
      final server = FakeLmsServer(routes());

      await manual(coordinator(server));

      final session = (await vault.readSession() as Ok<LmsSession?>).value!;
      expect(
        session.cookies.map((c) => c.name),
        containsAll(['sess', 'fresh']),
      );
      expect(session.userAgent, 'SyntheticAgent/1.0');
    });

    test('해석 실패는 필드 이름과 함께 남기고 오류 보고로도 보내며 상태와 마지막 확인 시각은 그대로 둔다', () async {
      final server = FakeLmsServer(
        routes(
          todos: (_) => FakeLmsResponse(
            200,
            contentType: 'application/json',
            body: lmsFixture('parse_failure_todo_missing_id.json'),
          ),
        ),
      );

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.parseFailure);
      final run = (await runs()).single;
      expect(run.result, SyncResultKind.parseFailure);
      expect(run.detail, isNotNull);
      expect(events.single.$1, 'lms_parse_failure');
      expect(events.single.$2['scope'], 'list');
      expect(events.single.$2['field'], run.detail);
      final after = await readSettings();
      expect(after.lmsSessionState, LmsSessionState.active);
      expect(after.lmsLastSuccessAt, isNull);
    });

    test('도중에 로그아웃해 금고가 비었으면 받은 쿠키를 다시 쓰지 않는다', () async {
      final server = FakeLmsServer(
        routes(
          todos: (_) {
            // 로그아웃이 금고를 비운 것처럼(요청 처리 중).
            vault.clear();
            return FakeLmsResponse(
              200,
              contentType: 'application/json',
              body: todosBody(),
              setCookies: const ['fresh=f1; Path=/'],
            );
          },
        ),
      );

      await manual(coordinator(server));

      expect((await vault.readSession() as Ok<LmsSession?>).value, isNull);
    });

    test('네트워크 실패는 그대로 남기고 상태를 바꾸지 않는다', () async {
      final server = FakeLmsServer(routes())..failNext = 100;

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.networkFailure);
      expect((await runs()).single.result, SyncResultKind.networkFailure);
      expect((await readSettings()).lmsSessionState, LmsSessionState.active);
      expect(await db.select(db.syncLeases).get(), isEmpty);
    });

    test('같은 isolate에서 두 번 부르면 진행 중인 것을 함께 받고 도는 동안만 알린다', () async {
      final server = FakeLmsServer(routes());
      final c = coordinator(server);
      final running = <bool>[];
      final subscription = c.runningChanges.listen(running.add);
      addTearDown(subscription.cancel);

      final first = manual(c);
      final second = manual(c);
      expect(c.isRunning, isTrue);
      final results = await Future.wait([first, second]);

      expect(identical(results[0], results[1]), isTrue);
      expect(await runs(), hasLength(1));
      expect(server.to('/api/synthetic-todos'), hasLength(1));
      expect(c.isRunning, isFalse);
      await pumpEventQueue();
      expect(running, [true, false]);
    });
  });

  group('세션 복원', () {
    FakeLmsResponse loginPage() => const FakeLmsResponse(
      200,
      contentType: 'text/html; charset=utf-8',
      body: '<form data-synthetic-login-form></form>',
    );

    test('재로그인 필요면 restoring으로 바꾸고 홈을 연 뒤 다시 물어 성공하면 active로 돌린다', () async {
      var calls = 0;
      final server = FakeLmsServer(
        routes(
          todos: (_) => calls++ == 0
              ? loginPage()
              : FakeLmsResponse(
                  200,
                  contentType: 'application/json',
                  body: todosBody(),
                ),
        ),
      );
      final states = <LmsSessionState>[];
      final sub = settings.watch().listen((s) => states.add(s.lmsSessionState));
      addTearDown(sub.cancel);

      final result = await manual(coordinator(server));
      await pumpEventQueue();

      expect(result.kind, SyncResultKind.normal);
      expect(server.to('/home'), hasLength(1));
      expect(server.to('/api/synthetic-todos'), hasLength(2));
      expect(
        states,
        containsAllInOrder([LmsSessionState.restoring, LmsSessionState.active]),
      );
      expect((await readSettings()).lmsSessionState, LmsSessionState.active);
    });

    test('복원해도 끊겨 있으면 reconnectRequired로 두고 판별 종류를 남긴다', () async {
      final server = FakeLmsServer(routes(todos: (_) => loginPage()));

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.reloginRequired);
      expect((await runs()).single.result, SyncResultKind.reloginRequired);
      expect(server.to('/home'), hasLength(1));
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
    });

    test('인증 오류 JSON(복원 필요)도 같다', () async {
      final server = FakeLmsServer(
        routes(
          todos: (_) => FakeLmsResponse(
            200,
            contentType: 'application/json',
            body: lmsFixture('restore_required_auth_error.json'),
          ),
        ),
      );

      final result = await manual(coordinator(server));

      expect(result.kind, SyncResultKind.restoreRequired);
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
    });

    test('시작할 때 restoring이면 복원부터 하고, 네트워크 실패면 restoring에 둔다', () async {
      await settings.write(
        SettingKeys.lmsSessionState,
        LmsSessionState.restoring,
      );
      final ok = FakeLmsServer(routes());

      expect((await manual(coordinator(ok))).kind, SyncResultKind.normal);
      expect(
        ok.requests.map((r) => r.url.path),
        containsAllInOrder(['/home', '/api/synthetic-todos']),
      );
      expect((await readSettings()).lmsSessionState, LmsSessionState.active);

      await settings.write(
        SettingKeys.lmsSessionState,
        LmsSessionState.restoring,
      );
      final down = FakeLmsServer(routes())..failNext = 100;
      expect(
        (await manual(coordinator(down))).kind,
        SyncResultKind.networkFailure,
      );
      expect((await readSettings()).lmsSessionState, LmsSessionState.restoring);
    });
  });

  group('부르지 않을 때', () {
    test('데모 모드·원격 스위치 꺼짐·설정 없음은 이유와 함께 건너뛴다', () async {
      final server = FakeLmsServer(routes());
      final noSync = parseLmsRequestParams(
        syntheticRequestParamsJson,
        schoolDomain: syntheticSchoolDomain,
      ).params!;

      demo = true;
      await manual(coordinator(server));
      demo = false;
      await manual(
        coordinator(
          server,
          config: LmsConfig(enabled: false, requestParams: params),
        ),
      );
      await manual(
        coordinator(
          server,
          config: const LmsConfig(enabled: true, requestParams: null),
        ),
      );
      await manual(
        coordinator(
          server,
          config: LmsConfig(enabled: true, requestParams: noSync),
        ),
      );

      expect((await runs()).map((r) => (r.result, r.detail)), [
        (SyncResultKind.skipped, SyncRunDetail.demoMode),
        (SyncResultKind.skipped, SyncRunDetail.switchOff),
        (SyncResultKind.skipped, SyncRunDetail.configMissing),
        (SyncResultKind.skipped, SyncRunDetail.configMissing),
      ]);
      expect(server.requests, isEmpty);
    });

    test('업데이트가 필요하거나, 로그인 전·다시 로그인 필요이거나, 금고에 세션이 없으면 기록 없이 끝낸다', () async {
      final server = FakeLmsServer(routes());

      updateRequired = true;
      await manual(coordinator(server));
      updateRequired = false;
      for (final state in [
        LmsSessionState.disconnected,
        LmsSessionState.connecting,
        LmsSessionState.reconnectRequired,
      ]) {
        await settings.write(SettingKeys.lmsSessionState, state);
        expect(
          (await manual(coordinator(server))).kind,
          SyncResultKind.skipped,
        );
      }
      await settings.write(SettingKeys.lmsSessionState, LmsSessionState.active);
      await vault.clear();
      await manual(coordinator(server));

      expect(await runs(), isEmpty);
      expect(server.requests, isEmpty);
    });

    test('금고에 User-Agent가 없으면 reconnectRequired로 둔다', () async {
      await vault.writeSession(
        LmsSession(savedAt: kstToUtc(_now), userAgent: ' ', cookies: const []),
      );
      final server = FakeLmsServer(routes());

      await manual(coordinator(server));

      expect(server.requests, isEmpty);
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.reconnectRequired,
      );
    });

    test('다른 쪽이 잠금을 잡고 있으면 lease로 건너뛴다', () async {
      await SyncLeaseRepository(db).acquire(LeaseHolder.background, now: _now);
      final server = FakeLmsServer(routes());

      final result = await manual(coordinator(server));

      expect(
        (result.kind, result.detail),
        (SyncResultKind.skipped, SyncRunDetail.lease),
      );
      expect(server.requests, isEmpty);
    });

    test('도중에 데모 모드에 들어가면 그 자리에서 멈추고 cancelled로 남긴다', () async {
      final server = FakeLmsServer({
        ...routes(),
        'GET /assets/synthetic-key-3.js': (_) {
          demo = true;
          return const FakeLmsResponse(
            200,
            contentType: 'application/javascript',
            body: "var syntheticKey = '$syntheticBodyKey';",
          );
        },
      });

      final result = await manual(coordinator(server));

      expect(
        (result.kind, result.detail),
        (SyncResultKind.cancelled, SyncRunDetail.demoMode),
      );
      expect(server.to('/api/synthetic-todos'), isEmpty);
    });

    test('도중에 원격 스위치가 꺼지면 다음 조회 앞에서 멈추고 cancelled로 남긴다', () async {
      for (final scope in [SyncScope.list, SyncScope.full]) {
        var enabled = true;
        final server = FakeLmsServer({
          ...routes(),
          'GET /assets/synthetic-key-3.js': (_) {
            enabled = false;
            return const FakeLmsResponse(
              200,
              contentType: 'application/javascript',
              body: "var syntheticKey = '$syntheticBodyKey';",
            );
          },
        });

        final result = await manual(
          coordinator(
            server,
            configNow: () => LmsConfig(enabled: enabled, requestParams: params),
          ),
          scope: scope,
        );

        expect(
          (result.kind, result.detail),
          (SyncResultKind.cancelled, SyncRunDetail.switchOff),
          reason: scope.name,
        );
        expect(
          server.to('/api/synthetic-courses'),
          isEmpty,
          reason: scope.name,
        );
        expect(server.to('/api/synthetic-todos'), isEmpty, reason: scope.name);
        expect(
          (await runs()).last.detail,
          SyncRunDetail.switchOff,
          reason: scope.name,
        );
      }
    });
  });

  group('호출 예산(자동 계기)', () {
    Future<SyncResult> open(
      FakeLmsServer server, {
      DateTime? now,
      LmsConfig? config,
    }) => coordinator(
      server,
      now: now,
      config: config,
    ).run(trigger: SyncTrigger.open, scope: SyncScope.list);

    test('조용한 시간에는 quiet_hours로 건너뛰고, 사용자 새로 고침은 그때도 부른다', () async {
      final server = FakeLmsServer(routes());
      final night = DateTime(2026, 11, 15, 2);

      final auto = await open(server, now: night);
      final manualResult = await coordinator(
        server,
        now: night,
      ).run(trigger: SyncTrigger.manual, scope: SyncScope.list);

      expect(
        (auto.kind, auto.detail),
        (SyncResultKind.skipped, SyncRunDetail.quietHours),
      );
      expect(manualResult.kind, SyncResultKind.normal);
    });

    test('마지막 성공이 간격 안이면 기록 없이 끝내고, 지나면 부른다', () async {
      final server = FakeLmsServer(routes());
      await settings.advanceLmsLastSuccessAt(
        _now.subtract(const Duration(minutes: 179)),
      );

      expect((await open(server)).kind, SyncResultKind.skipped);
      expect(await runs(), isEmpty);

      expect(
        (await open(server, now: _now.add(const Duration(minutes: 1)))).kind,
        SyncResultKind.normal,
      );
    });

    test('쓰는 동안 계기는 foregroundPollMin을 본다', () async {
      final server = FakeLmsServer(routes());
      await settings.advanceLmsLastSuccessAt(
        _now.subtract(const Duration(minutes: 30)),
      );
      final config = LmsConfig(
        enabled: true,
        requestParams: params,
        budget: const LmsSyncBudget(
          listMinIntervalMin: 10,
          listMaxPerDay: 8,
          detailMaxPerDay: 2,
          foregroundPollMin: 20,
          openStaleMin: 180,
          quietStartMin: 60,
          quietEndMin: 360,
        ),
      );

      final periodic = await coordinator(
        server,
        config: config,
      ).run(trigger: SyncTrigger.periodic, scope: SyncScope.list);
      final opened = await open(server, config: config);

      expect(periodic.kind, SyncResultKind.normal);
      expect(opened.kind, SyncResultKind.skipped);
    });

    test('자동 조회가 실패한 뒤 최소 간격 안이면 budget으로 건너뛴다', () async {
      final down = FakeLmsServer(routes())..failNext = 100;
      expect((await open(down)).kind, SyncResultKind.networkFailure);

      final up = FakeLmsServer(routes());
      final soon = await open(up, now: _now.add(const Duration(minutes: 9)));
      final later = await open(up, now: _now.add(const Duration(minutes: 10)));

      expect(
        (soon.kind, soon.detail),
        (SyncResultKind.skipped, SyncRunDetail.budget),
      );
      expect(later.kind, SyncResultKind.normal);
    });

    test('최소 간격은 자동 조회가 실패했을 때만 보고, 성공했으면 간격 안이어도 부른다', () async {
      final config = LmsConfig(
        enabled: true,
        requestParams: params,
        budget: const LmsSyncBudget(
          listMinIntervalMin: 10,
          listMaxPerDay: 8,
          detailMaxPerDay: 2,
          foregroundPollMin: 5,
          openStaleMin: 5,
          quietStartMin: 60,
          quietEndMin: 360,
        ),
      );
      final server = FakeLmsServer(routes());
      expect((await open(server, config: config)).kind, SyncResultKind.normal);

      final again = await open(
        server,
        config: config,
        now: _now.add(const Duration(minutes: 7)),
      );

      expect(again.kind, SyncResultKind.normal);
    });

    test('오늘 자동 조회 횟수를 다 썼으면 budget으로 건너뛴다', () async {
      for (var i = 0; i < LmsSyncBudget.defaults.listMaxPerDay; i++) {
        await syncRuns.add(
          startedAt: DateTime(2026, 11, 15, 7, i),
          trigger: SyncTrigger.periodic,
          scope: SyncScope.list,
          result: SyncResultKind.serverError,
          elapsedMs: 1,
        );
      }
      final server = FakeLmsServer(routes());

      final result = await open(server, now: DateTime(2026, 11, 15, 23));

      expect(
        (result.kind, result.detail),
        (SyncResultKind.skipped, SyncRunDetail.budget),
      );
      expect(server.requests, isEmpty);
    });

    test('예산 설정을 해석하지 못했으면 그 계기의 기록에 남긴다', () async {
      final server = FakeLmsServer(routes());

      await open(
        server,
        config: LmsConfig(
          enabled: true,
          requestParams: params,
          budgetParseFailed: true,
        ),
      );

      expect((await runs()).single.detail, SyncRunDetail.budgetParseFailed);
    });
  });
}
