// 로그인 흐름 테스트. docs/lms.md '로그인'·'학번·비밀번호와 자동 재로그인'·'쿠키 금고'·'세션 상태'.
//
// 가짜 LMS 서버(합성 로그인 경로)와 합성 요청 상수로 준비 요청 → 암호화한 로그인 요청 → 결과 규칙 → 세션 넘기기와,
// 성공·실패 때 저장하는 것(학번·비밀번호, 쿠키 금고, LMS 상태)을 본다. 학번·비밀번호·키는 모두 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/lms_config.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/failing_secure_storage.dart';
import '../helpers/fake_lms_server.dart';
import '../helpers/lms_samples.dart';

final _now = DateTime(2026, 11, 15, 10, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final synthetic = parseLmsRequestParams(
    syntheticRequestParamsJson,
    schoolDomain: syntheticSchoolDomain,
  ).params!;

  late AppDatabase db;
  late SettingsRepository settings;
  late List<Duration> sleeps;

  setUp(() {
    db = AppDatabase.memory();
    settings = SettingsRepository(db);
    sleeps = [];
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => db.close());

  LmsLoginFlow flowWith(
    FakeLmsServer server, {
    LmsConfig? config,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) => LmsLoginFlow(
    config: () async =>
        config ?? LmsConfig(enabled: true, requestParams: synthetic),
    vault: CookieVault(storage),
    settings: settings,
    clock: FixedClock(_now),
    schoolDomain: syntheticSchoolDomain,
    createDio: () => createLmsDio(adapter: server),
    sleep: (duration) async => sleeps.add(duration),
  );

  Future<(Result<void>, List<LoginStage>)> login(
    LmsLoginFlow flow, {
    LoginMode mode = LoginMode.first,
    String studentId = syntheticStudentId,
    String password = syntheticPassword,
  }) async {
    final stages = <LoginStage>[];
    final result = await flow.run(
      mode: mode,
      studentId: studentId,
      password: password,
      onStage: stages.add,
    );
    return (result, stages);
  }

  Future<AppSettings> readSettings() async =>
      (await settings.read() as Ok<AppSettings>).value;

  Future<LmsSession?> savedSession() async =>
      (await const CookieVault(FlutterSecureStorage()).readSession()
              as Ok<LmsSession?>)
          .value;

  Future<LmsCredential?> savedCredential() async =>
      (await const CookieVault(FlutterSecureStorage()).readCredential()
              as Ok<LmsCredential?>)
          .value;

  Matcher outcome(LmsOutcomeKind kind, {int? status}) => isA<Err<void>>()
      .having((r) => r.error, 'error', LmsOutcome(kind, statusCode: status));

  group('성공', () {
    test('준비 요청으로 값을 뽑고, 암호화한 로그인 요청을 보내고, 세션 넘기기를 따라간다', () async {
      final server = FakeLmsServer(syntheticLoginRoutes());
      final (result, stages) = await login(flowWith(server));

      expect(result, const Ok<void>(null));
      expect(stages, [LoginStage.login]);
      expect(
        [for (final r in server.requests) '${r.method} ${r.url.path}'],
        [
          'GET /synthetic-login',
          'GET /assets/synthetic-key-3.js',
          'POST /synthetic-login/submit',
          'GET /handoff',
          'GET /home',
        ],
      );
      expect(server.closed, isTrue);

      final submit = server.to('/synthetic-login/submit').single;
      expect(submit.header('X-Synthetic'), 'yes');
      expect(submit.header('user-agent'), 'SyntheticAgent/1.0');
      expect(
        submit.header('content-type'),
        'application/x-www-form-urlencoded; charset=UTF-8',
      );
      expect(submit.form.keys, ['payload']);
      // 틀의 키 순서 그대로, 학번·비밀번호와 앞에서 뽑은 값을 넣은 JSON을 암호화했다.
      expect(
        aesCbcDecryptBase64(
          submit.form['payload']!,
          utf8.encode(syntheticBodyKey),
          List.filled(16, 0),
        ),
        '{"id":"$syntheticStudentId","pw":"$syntheticPassword",'
        '"token":"tok-1","fixed":"합성"}',
      );
      // 앞 응답에서 받은 쿠키를 다음 요청에 붙인다(리다이렉트 사이에 받은 쿠키 포함).
      expect(submit.header('cookie'), 'pre=p1');
      expect(server.to('/handoff').single.header('cookie'), 'pre=p1; auth=a1');
      expect(
        server.to('/home').single.header('cookie'),
        'pre=p1; auth=a1; sess=s1',
      );
    });

    test(
      '학번·비밀번호와 쿠키 금고를 저장하고, LMS 상태를 active로, 마지막 로그인 시각을 지금으로 쓴다',
      () async {
        final (result, _) = await login(
          flowWith(FakeLmsServer(syntheticLoginRoutes())),
        );
        expect(result, const Ok<void>(null));

        expect(
          await savedCredential(),
          const LmsCredential(
            studentId: syntheticStudentId,
            password: syntheticPassword,
          ),
        );
        final session = (await savedSession())!;
        expect(session.userAgent, 'SyntheticAgent/1.0');
        expect(session.savedAt, kstToUtc(_now));
        expect(
          {for (final c in session.cookies) c.name: c.value},
          {'pre': 'p1', 'auth': 'a1', 'sess': 's1'},
        );
        final after = await readSettings();
        expect(after.lmsSessionState, LmsSessionState.active);
        expect(after.lmsLastConnectedAt, _now);
      },
    );

    test('다시 로그인도 같은 로그인 요청이고 새 비밀번호로 바꿔 저장한다', () async {
      await const CookieVault(FlutterSecureStorage()).writeCredential(
        const LmsCredential(studentId: syntheticStudentId, password: 'old'),
      );
      final (result, stages) = await login(
        flowWith(FakeLmsServer(syntheticLoginRoutes())),
        mode: LoginMode.relogin,
      );
      expect(result, const Ok<void>(null));
      expect(stages, [LoginStage.login]);
      expect((await savedCredential())!.password, syntheticPassword);
    });

    test('연결에 한 번 실패하면 3초 뒤 한 번 다시 보내고 이어 간다', () async {
      final server = FakeLmsServer(syntheticLoginRoutes())..failNext = 1;
      final (result, _) = await login(flowWith(server));
      expect(result, const Ok<void>(null));
      expect(sleeps, [const Duration(seconds: 3)]);
      expect(server.to('/synthetic-login'), hasLength(2));
    });
  });

  group('실패하면 저장하지 않고 connecting에 둔다', () {
    Future<void> expectNothingSaved() async {
      expect(await savedCredential(), isNull);
      expect(await savedSession(), isNull);
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.connecting,
      );
    }

    test('학번·비밀번호가 틀리면 학번·비밀번호 틀림이고 세션 넘기기를 하지 않는다', () async {
      final server = FakeLmsServer(syntheticLoginRoutes());
      final (result, _) = await login(flowWith(server), password: 'wrong');
      expect(result, outcome(LmsOutcomeKind.wrongCredentials, status: 200));
      expect(server.to('/handoff'), isEmpty);
      await expectNothingSaved();
    });

    test('두 번 다 연결에 실패하면 네트워크 실패다', () async {
      final server = FakeLmsServer(syntheticLoginRoutes())..failNext = 2;
      final (result, _) = await login(flowWith(server));
      expect(result, outcome(LmsOutcomeKind.networkFailure));
      expect(sleeps, [const Duration(seconds: 3)]);
      await expectNothingSaved();
    });

    test('5xx·429와 점검 표식은 어느 요청에서든 서버 오류·점검이다', () async {
      for (final (path, response) in [
        ('GET /synthetic-login', const FakeLmsResponse(503)),
        ('GET /assets/synthetic-key-3.js', const FakeLmsResponse(429)),
        (
          'POST /synthetic-login/submit',
          const FakeLmsResponse(
            200,
            body: '<p data-synthetic-maintenance></p>',
          ),
        ),
        ('GET /handoff', const FakeLmsResponse(500)),
      ]) {
        final server = FakeLmsServer({
          ...syntheticLoginRoutes(),
          path: (_) => response,
        });
        final (result, _) = await login(flowWith(server));
        expect(
          result,
          outcome(LmsOutcomeKind.serverError, status: response.status),
          reason: path,
        );
      }
      await expectNothingSaved();
    });

    test('준비 요청이 2xx가 아니거나 꼭 뽑을 값을 찾지 못하면 해석 실패다', () async {
      for (final (path, response, status) in [
        ('GET /synthetic-login', const FakeLmsResponse(404), 404),
        (
          'GET /synthetic-login',
          const FakeLmsResponse(200, body: '<p>키 스크립트 없음</p>'),
          200,
        ),
        (
          'GET /assets/synthetic-key-3.js',
          const FakeLmsResponse(200, body: 'var other = 1;'),
          200,
        ),
      ]) {
        final server = FakeLmsServer({
          ...syntheticLoginRoutes(),
          path: (_) => response,
        });
        final (result, _) = await login(flowWith(server));
        expect(
          result,
          outcome(LmsOutcomeKind.parseFailure, status: status),
          reason: '$path ${response.body}',
        );
        expect(server.to('/synthetic-login/submit'), isEmpty);
      }
      await expectNothingSaved();
    });

    test('준비 요청이 2xx가 아니면 뽑을 값이 있어도 멈춘다', () async {
      final routes = syntheticLoginRoutes();
      final page = routes['GET /synthetic-login']!;
      final server = FakeLmsServer({
        ...routes,
        'GET /synthetic-login': (request) {
          final ok = page(request);
          return FakeLmsResponse(403, body: ok.body);
        },
      });
      final (result, _) = await login(flowWith(server));
      expect(result, outcome(LmsOutcomeKind.parseFailure, status: 403));
      expect(server.requests, hasLength(1));
    });

    test('키가 32바이트가 아니면 로그인 요청을 만들지 못해 해석 실패다', () async {
      final server = FakeLmsServer({
        ...syntheticLoginRoutes(),
        'GET /assets/synthetic-key-3.js': (_) =>
            const FakeLmsResponse(200, body: "var syntheticKey = 'short';"),
      });
      final (result, _) = await login(flowWith(server));
      expect(result, outcome(LmsOutcomeKind.parseFailure));
      expect(server.to('/synthetic-login/submit'), isEmpty);
    });

    test('로그인 응답이 어떤 결과 규칙에도 맞지 않으면 해석 실패다', () async {
      for (final body in [
        '{"result": {"code": "locked"}}',
        '<p>HTML</p>',
        '',
      ]) {
        final server = FakeLmsServer(
          syntheticLoginRoutes(
            loginResult: (_) => FakeLmsResponse(200, body: body),
          ),
        );
        final (result, _) = await login(flowWith(server));
        expect(
          result,
          outcome(LmsOutcomeKind.parseFailure, status: 200),
          reason: body,
        );
      }
      await expectNothingSaved();
    });

    test('세션 넘기기가 2xx로 끝나지 않거나 로그인 주소로 돌아가면 해석 실패다', () async {
      for (final handoff in [
        const FakeLmsResponse(404),
        const FakeLmsResponse(302, location: '/synthetic-login?next=home'),
      ]) {
        final server = FakeLmsServer({
          ...syntheticLoginRoutes(),
          'GET /handoff': (_) => handoff,
        });
        final (result, _) = await login(flowWith(server));
        expect(
          result,
          isA<Err<void>>().having(
            (r) => (r.error as LmsOutcome).kind,
            'kind',
            LmsOutcomeKind.parseFailure,
          ),
        );
      }
      await expectNothingSaved();
    });

    test('세션 넘기기 주소가 학교 도메인 밖이면 보내지 않고 해석 실패다', () async {
      final server = FakeLmsServer(
        syntheticLoginRoutes(
          loginResult: (_) => const FakeLmsResponse(
            200,
            body: '{"result": {"code": "ok", "next": "https://example.com/x"}}',
          ),
        ),
      );
      final (result, _) = await login(flowWith(server));
      expect(result, outcome(LmsOutcomeKind.parseFailure));
      expect(server.requests.map((r) => r.url.host).toSet(), {
        'example.invalid',
      });
      await expectNothingSaved();
    });

    test('저장하지 못하면 그 오류이고 상태는 connecting에 남는다', () async {
      final (result, _) = await login(
        flowWith(
          FakeLmsServer(syntheticLoginRoutes()),
          storage: FailingSecureStorage(failWrites: true),
        ),
      );
      expect(
        result,
        isA<Err<void>>().having((r) => r.error, 'error', isA<StorageError>()),
      );
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.connecting,
      );
    });
  });

  test('원격 스위치가 꺼졌거나 설정이 없으면 요청하지 않고 상태도 쓰지 않는다', () async {
    for (final config in [
      LmsConfig(enabled: false, requestParams: synthetic),
      const LmsConfig(enabled: true, requestParams: null),
    ]) {
      final server = FakeLmsServer(syntheticLoginRoutes());
      final (result, stages) = await login(flowWith(server, config: config));
      expect(result, outcome(LmsOutcomeKind.parseFailure));
      expect(stages, isEmpty);
      expect(server.requests, isEmpty);
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.disconnected,
      );
    }
  });

  group('abandon', () {
    test(
      'connecting이면 저장된 학번·비밀번호가 없을 때 disconnected, 있을 때 reconnectRequired다',
      () async {
        final flow = flowWith(FakeLmsServer(syntheticLoginRoutes()));
        await settings.write(
          SettingKeys.lmsSessionState,
          LmsSessionState.connecting,
        );
        await flow.abandon();
        expect(
          (await readSettings()).lmsSessionState,
          LmsSessionState.disconnected,
        );

        await const CookieVault(FlutterSecureStorage()).writeCredential(
          const LmsCredential(studentId: syntheticStudentId, password: 'pw'),
        );
        await settings.write(
          SettingKeys.lmsSessionState,
          LmsSessionState.connecting,
        );
        await flow.abandon();
        expect(
          (await readSettings()).lmsSessionState,
          LmsSessionState.reconnectRequired,
        );
      },
    );

    test('connecting이 아니면 그대로 둔다', () async {
      final flow = flowWith(FakeLmsServer(syntheticLoginRoutes()));
      for (final state in [
        LmsSessionState.active,
        LmsSessionState.restoring,
        LmsSessionState.reconnectRequired,
        LmsSessionState.disconnected,
      ]) {
        await settings.write(SettingKeys.lmsSessionState, state);
        await flow.abandon();
        expect((await readSettings()).lmsSessionState, state);
      }
    });

    test('학번·비밀번호를 읽지 못하면 없는 것으로 보고 disconnected다', () async {
      final flow = flowWith(
        FakeLmsServer(syntheticLoginRoutes()),
        storage: FailingSecureStorage(failReads: true),
      );
      await settings.write(
        SettingKeys.lmsSessionState,
        LmsSessionState.connecting,
      );
      await flow.abandon();
      expect(
        (await readSettings()).lmsSessionState,
        LmsSessionState.disconnected,
      );
    });
  });

  group('savedStudentId', () {
    test('저장된 학번을 돌려주고, 없거나 읽지 못하면 null이다', () async {
      final flow = flowWith(FakeLmsServer(syntheticLoginRoutes()));
      expect(await flow.savedStudentId(), isNull);
      await const FlutterSecureStorage().write(
        key: SecureKeys.lmsCredential,
        value: jsonEncode({'studentId': '654321', 'password': 'x'}),
      );
      expect(await flow.savedStudentId(), '654321');
      final failing = flowWith(
        FakeLmsServer(syntheticLoginRoutes()),
        storage: FailingSecureStorage(failReads: true),
      );
      expect(await failing.savedStudentId(), isNull);
    });
  });
}
