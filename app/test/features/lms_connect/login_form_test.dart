// 로그인 폼 테스트. docs/screens.md '1단계 · LMS 로그인'·'다시 로그인', docs/lms.md '로그인'.
//
// 14 온보딩 1단계(처음 로그인)와 `/login`(다시 로그인)에 띄운 폼을 가짜 로그인 흐름으로 돌린다. 셋을 채워야
// '로그인'이 켜지는지, 원격 스위치·설정 상태, 결과마다의 처리(틀림은 비밀번호 칸을 비움, 점검·네트워크·해석
// 실패는 이유와 '다시 시도'), 진행 줄과 그동안의 잠금, 동의 시각, 다시 로그인 모드를 본다. 글자 배율
// 2.0에서도 돌려 넘침이 없는지 함께 본다. 학번·비밀번호는 합성 값이다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/today/today_screen.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_login_flow.dart';
import '../../helpers/pump_app.dart';

/// 합성 학번·비밀번호.
const _id = '123456';
const _password = 'pw-1234';

/// 테스트 시각. 동의 시각을 초 단위로 견주려고 고정한다.
final _now = DateTime(2026, 11, 13, 9, 30);

const _browse = '로그인 없이 둘러보기 · 샘플 학생의 하루';
const _devSkip = '로그인 없이 다음으로';

void main() {
  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      group('처음 로그인(14 온보딩 1단계)', () {
        Future<TestApp> pumpStepOne(
          WidgetTester tester, {
          FakeLoginFlow? flow,
          bool enabled = true,
          String requestParams = '{}',
          List<Override> overrides = const [],
        }) => pumpTestApp(
          tester,
          start: TestStart.fresh,
          now: _now,
          textScale: textScale,
          overrides: [
            ...lmsConfigOverrides(
              enabled: enabled,
              requestParams: requestParams,
            ),
            loginFlowOverride(flow ?? FakeLoginFlow()),
            ...overrides,
          ],
        );

        testWidgets('학번·비밀번호·동의 셋을 채워야 로그인이 켜지고, 학번은 숫자만 받는다', (tester) async {
          final app = await pumpStepOne(tester);
          expect(find.text('학번·비밀번호는 이 폰에만 두고 LMS 로그인에만 써요.'), findsOneWidget);
          expect(find.text('설정을 받는 중이에요'), findsNothing);
          expect(find.text('LMS 연동을 잠시 멈췄어요'), findsNothing);
          expect(_loginEnabled(tester), isFalse);

          await _enter(tester, '학번', '12a3-456');
          expect(_text(tester, '학번'), _id);
          await _enter(tester, '비밀번호', _password);
          expect(_loginEnabled(tester), isFalse, reason: '동의 전');

          await _tap(tester, find.byType(Checkbox));
          expect(_consent(tester), isTrue);
          expect(_loginEnabled(tester), isTrue);

          // 동의 문구를 눌러도 체크가 바뀐다.
          await _tap(tester, find.text('개인정보 처리 안내에 동의해요 (필수)'));
          expect(_consent(tester), isFalse);
          expect(_loginEnabled(tester), isFalse);
          await _tap(tester, find.text('개인정보 처리 안내에 동의해요 (필수)'));
          expect(_loginEnabled(tester), isTrue);

          await _enter(tester, '학번', '');
          expect(_loginEnabled(tester), isFalse, reason: '학번 없음');
          await _enter(tester, '학번', _id);
          await _enter(tester, '비밀번호', '');
          expect(_loginEnabled(tester), isFalse, reason: '비밀번호 없음');

          await app.dispose(tester);
        });

        testWidgets("원격 스위치가 꺼져 있으면 '로그인'을 막고 'LMS 연동을 잠시 멈췄어요'를 보이며, "
            '둘러보기는 그대로다', (tester) async {
          final app = await pumpStepOne(tester, enabled: false);
          await _fill(tester);
          expect(find.text('LMS 연동을 잠시 멈췄어요'), findsOneWidget);
          expect(_loginEnabled(tester), isFalse);
          expect(_textButtonEnabled(tester, _browse), isTrue);

          await app.dispose(tester);
        });

        testWidgets("요청 상수를 아직 받지 못했으면 '로그인'을 막고 '설정을 받는 중이에요'를 보인다", (
          tester,
        ) async {
          // fetchAndActivate()가 끝나기 전(덮어쓰지 않으면 끝나지 않는다).
          var app = await pumpTestApp(
            tester,
            start: TestStart.fresh,
            textScale: textScale,
            overrides: [loginFlowOverride(FakeLoginFlow())],
          );
          await _fill(tester);
          expect(find.text('설정을 받는 중이에요'), findsOneWidget);
          expect(_loginEnabled(tester), isFalse);
          await app.dispose(tester);

          // 끝났지만 요청 상수가 비어 있음.
          app = await pumpStepOne(tester, requestParams: '');
          await _fill(tester);
          expect(find.text('설정을 받는 중이에요'), findsOneWidget);
          expect(_loginEnabled(tester), isFalse);
          await app.dispose(tester);
        });

        testWidgets('로그인하면 동의 시각을 적고 진행 줄 셋을 차례로 보이며, 그동안 입력·둘러보기·뒤로 '
            '가기를 받지 않고, 끝나면 2단계로 간다', (tester) async {
          final flow = FakeLoginFlow(holdStages: true);
          final gate = _Gate();
          final app = await pumpStepOne(
            tester,
            flow: flow,
            overrides: [
              settingsRepositoryProvider.overrideWith(
                (ref) => _GatedReads(ref.watch(databaseProvider), gate),
              ),
            ],
          );
          await _fill(tester);
          await _tapLogin(tester);

          expect(await _consentAt(app), _now);
          _expectProgress({
            'LMS 로그인': '진행 중',
            '이번 학기 시간표': '기다리는 중',
            'LMS 할 일': '기다리는 중',
          });
          expect(tester.widget<TextField>(_field('학번')).enabled, isFalse);
          expect(tester.widget<TextField>(_field('비밀번호')).enabled, isFalse);
          expect(
            tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
            isNull,
          );
          expect(_textButtonEnabled(tester, '보기'), isFalse);
          expect(_textButtonEnabled(tester, _browse), isFalse);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(
                    OutlinedButton,
                    _devSkip,
                    skipOffstage: false,
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(_loginEnabled(tester), isFalse);
          // 시스템 뒤로 가기를 받지 않는다(1단계인데도 화면을 닫지 않는다).
          expect(await tester.binding.handlePopRoute(), isTrue);
          await _pumpFrames(tester);
          expect(find.text(OnboardingStep.login.title), findsWidgets);

          flow.advance();
          await _pumpFrames(tester);
          _expectProgress({
            'LMS 로그인': '끝남',
            '이번 학기 시간표': '진행 중',
            'LMS 할 일': '기다리는 중',
          });

          flow.advance();
          await _pumpFrames(tester);
          _expectProgress({
            'LMS 로그인': '끝남',
            '이번 학기 시간표': '끝남',
            'LMS 할 일': '진행 중',
          });

          // 로그인 흐름이 끝나면 2단계로 넘어가는 저장이 끝나기 전까지 세 줄 모두 끝남이다.
          gate.close();
          flow.advance();
          await _pumpFrames(tester);
          _expectProgress({
            'LMS 로그인': '끝남',
            '이번 학기 시간표': '끝남',
            'LMS 할 일': '끝남',
          });

          gate.open();
          await tester.pumpAndSettle();
          expect(find.text(OnboardingStep.timetable.title), findsOneWidget);
          expect(flow.calls, [
            (mode: LoginMode.first, studentId: _id, password: _password),
          ]);

          await app.dispose(tester);
        });

        testWidgets('학번·비밀번호가 틀리면 비밀번호 칸을 비우고 이유를 보이며 1단계에 머문다', (
          tester,
        ) async {
          final flow = FakeLoginFlow(
            results: const [Err(LmsOutcome(LmsOutcomeKind.wrongCredentials))],
          );
          final app = await pumpStepOne(tester, flow: flow);
          await _fill(tester);
          await _tapLogin(tester);
          await tester.pumpAndSettle();

          expect(find.text('학번이나 비밀번호가 맞지 않아요'), findsOneWidget);
          expect(_text(tester, '비밀번호'), isEmpty);
          expect(_text(tester, '학번'), _id);
          expect(_consent(tester), isTrue);
          expect(find.text('다시 시도'), findsNothing);
          expect(_loginEnabled(tester), isFalse, reason: '비밀번호를 다시 받는다');
          expect(find.text(OnboardingStep.login.title), findsOneWidget);

          await _enter(tester, '비밀번호', _password);
          expect(_loginEnabled(tester), isTrue);

          await app.dispose(tester);
        });

        for (final (name, error, reason) in [
          (
            '점검·서버 오류',
            const LmsOutcome(LmsOutcomeKind.serverError),
            'LMS가 점검 중이거나 응답하지 않아요',
          ),
          (
            '네트워크 실패',
            const LmsOutcome(LmsOutcomeKind.networkFailure),
            '인터넷에 연결되지 않았어요',
          ),
          (
            '해석 실패',
            const LmsOutcome(LmsOutcomeKind.parseFailure),
            '지금은 로그인할 수 없어요',
          ),
          ('LMS 밖의 오류', const StorageError('lms.login'), '지금은 로그인할 수 없어요'),
        ]) {
          testWidgets("$name: 이유와 '다시 시도'를 보이고, 다시 시도하면 같은 값으로 다시 "
              '로그인한다', (tester) async {
            final flow = FakeLoginFlow(results: [Err(error), const Ok(null)]);
            final app = await pumpStepOne(tester, flow: flow);
            await _fill(tester);
            await _tapLogin(tester);
            await tester.pumpAndSettle();

            expect(find.text(reason), findsOneWidget);
            expect(_text(tester, '비밀번호'), _password);
            expect(find.widgetWithText(FilledButton, '로그인'), findsNothing);
            expect(_buttonEnabled(tester, '다시 시도'), isTrue);

            await _tap(tester, find.widgetWithText(FilledButton, '다시 시도'));
            expect(find.text(OnboardingStep.timetable.title), findsOneWidget);
            expect(flow.calls, hasLength(2));
            expect(flow.calls.last, flow.calls.first);

            await app.dispose(tester);
          });
        }

        testWidgets("'보기'는 개인정보 처리 안내 시트를 열고, '확인했어요'를 누르면 동의가 체크된다. "
            '그냥 닫으면 체크하지 않는다', (tester) async {
          final app = await pumpStepOne(tester);
          await _tap(tester, find.widgetWithText(TextButton, '보기'));
          expect(find.text('개인정보 처리 안내'), findsOneWidget);

          // 확인하지 않고 닫으면(시스템 뒤로 가기) 체크하지 않는다. 글자가 크면 시트가 화면을 다 덮어
          // 시트 밖을 누를 수 없다.
          expect(await tester.binding.handlePopRoute(), isTrue);
          await tester.pumpAndSettle();
          expect(find.text('개인정보 처리 안내'), findsNothing);
          expect(_consent(tester), isFalse);

          await _tap(tester, find.widgetWithText(TextButton, '보기'));
          await _tap(tester, find.text('확인했어요'));
          expect(find.text('개인정보 처리 안내'), findsNothing);
          expect(_consent(tester), isTrue);

          await app.dispose(tester);
        });
      });

      group('다시 로그인(/login)', () {
        Future<TestApp> pumpRelogin(
          WidgetTester tester, {
          required FakeLoginFlow flow,
          bool enabled = true,
        }) async {
          final app = await pumpTestApp(
            tester,
            now: _now,
            textScale: textScale,
            overrides: [
              ...lmsConfigOverrides(enabled: enabled),
              loginFlowOverride(flow),
            ],
          );
          expect(find.byType(TodayScreen), findsOneWidget);
          app.router.push(Routes.login);
          await tester.pumpAndSettle();
          expect(find.byType(ReloginScreen), findsOneWidget);
          return app;
        }

        testWidgets('저장된 학번을 고정하고 비밀번호만 받는다. 동의·둘러보기·개발용 버튼은 없다', (
          tester,
        ) async {
          final app = await pumpRelogin(
            tester,
            flow: FakeLoginFlow(savedId: _id),
          );
          expect(find.text('받아 둔 할 일은 그대로 있어요.'), findsOneWidget);
          expect(find.text('학번 $_id'), findsOneWidget);
          expect(_field('학번'), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(find.text(_browse), findsNothing);
          expect(find.text(_devSkip), findsNothing);
          expect(find.text(AppStrings.unofficialShort), findsOneWidget);
          expect(_loginEnabled(tester), isFalse);

          await _enter(tester, '비밀번호', _password);
          expect(_loginEnabled(tester), isTrue);

          await app.dispose(tester);
        });

        testWidgets('저장된 학번이 없으면 학번 칸도 받는다', (tester) async {
          final flow = FakeLoginFlow();
          final app = await pumpRelogin(tester, flow: flow);
          await _enter(tester, '비밀번호', _password);
          expect(_loginEnabled(tester), isFalse, reason: '학번 없음');
          await _enter(tester, '학번', _id);
          expect(_loginEnabled(tester), isTrue);

          await _tapLogin(tester);
          await tester.pumpAndSettle();
          expect(flow.calls, [
            (mode: LoginMode.relogin, studentId: _id, password: _password),
          ]);

          await app.dispose(tester);
        });

        testWidgets('진행 줄 둘을 보이고 그동안 뒤로 가기를 받지 않으며, 끝나면 연 화면으로 돌아간다. '
            '동의 시각은 적지 않는다', (tester) async {
          final flow = FakeLoginFlow(savedId: _id, holdStages: true);
          final app = await pumpRelogin(tester, flow: flow);
          await _enter(tester, '비밀번호', _password);
          await _tapLogin(tester);
          _expectProgress({'다시 로그인': '진행 중', '할 일 새로 불러오기': '기다리는 중'});

          expect(await tester.binding.handlePopRoute(), isTrue);
          await _pumpFrames(tester);
          await tester.tap(find.byType(BackButton));
          await _pumpFrames(tester);
          expect(find.byType(ReloginScreen), findsOneWidget);

          flow.advance();
          await _pumpFrames(tester);
          _expectProgress({'다시 로그인': '끝남', '할 일 새로 불러오기': '진행 중'});

          flow.advance();
          await tester.pumpAndSettle();
          expect(find.byType(ReloginScreen), findsNothing);
          expect(find.byType(TodayScreen), findsOneWidget);
          expect(app.router.state.uri.path, Routes.today);
          expect(await _consentAt(app), isNull);

          await app.dispose(tester);
        });

        testWidgets("비밀번호 칸에서 키보드의 '완료'를 누르면 '로그인'이 켜져 있을 때만 로그인한다", (
          tester,
        ) async {
          final flow = FakeLoginFlow(savedId: _id);
          final app = await pumpRelogin(tester, flow: flow);
          await _enter(tester, '비밀번호', '');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(flow.calls, isEmpty);
          expect(find.byType(ReloginScreen), findsOneWidget);

          await _enter(tester, '비밀번호', _password);
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(flow.calls, [
            (mode: LoginMode.relogin, studentId: _id, password: _password),
          ]);
          expect(find.byType(ReloginScreen), findsNothing);

          await app.dispose(tester);
        });

        testWidgets('원격 스위치가 꺼져 있으면 다시 로그인도 막는다', (tester) async {
          final app = await pumpRelogin(
            tester,
            flow: FakeLoginFlow(savedId: _id),
            enabled: false,
          );
          await _enter(tester, '비밀번호', _password);
          expect(find.text('LMS 연동을 잠시 멈췄어요'), findsOneWidget);
          expect(_loginEnabled(tester), isFalse);

          await app.dispose(tester);
        });
      });
    });
  }
}

/// 이름표가 [label]인 입력 칸.
Finder _field(String label) => find.widgetWithText(TextField, label);

/// 입력 칸 [label]의 지금 값.
String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

/// 입력 칸 [label]에 [text]를 넣는다.
Future<void> _enter(WidgetTester tester, String label, String text) async {
  await scrollTo(tester, _field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

/// [target]을 보이게 한 뒤 누르고 화면이 멈출 때까지 기다린다.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// 학번·비밀번호를 넣고 동의를 체크한다.
Future<void> _fill(WidgetTester tester) async {
  await _enter(tester, '학번', _id);
  await _enter(tester, '비밀번호', _password);
  await _tap(tester, find.byType(Checkbox));
}

/// '로그인'을 누른다. 진행 중 표시가 계속 돌므로 화면이 멈출 때까지 기다리지 않는다.
Future<void> _tapLogin(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, '로그인');
  await scrollTo(tester, button);
  await tester.tap(button);
  await _pumpFrames(tester);
}

/// 진행 중 표시가 도는 동안 몇 프레임을 넘긴다(폰 DB 쓰기 같은 비동기 일이 끝나도록).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

bool _buttonEnabled(WidgetTester tester, String label) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed !=
    null;

bool _loginEnabled(WidgetTester tester) => _buttonEnabled(tester, '로그인');

/// 글자 버튼 [label]이 켜져 있는지. 글자가 크면 화면 아래 버튼은 스크롤해야 보이므로 화면 밖도 찾는다.
bool _textButtonEnabled(WidgetTester tester, String label) =>
    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, label, skipOffstage: false),
        )
        .onPressed !=
    null;

/// 동의 칸이 체크됐는지.
bool _consent(WidgetTester tester) =>
    tester.widget<Checkbox>(find.byType(Checkbox)).value!;

/// 진행 줄마다 '이름 상태'로 읽히는지.
void _expectProgress(Map<String, String> lines) {
  for (final MapEntry(key: label, value: progress) in lines.entries) {
    expect(
      find.bySemanticsLabel('$label $progress'),
      findsOneWidget,
      reason: label,
    );
  }
}

/// 실제 모드 DB에 적힌 개인정보 처리 안내 동의 시각.
Future<DateTime?> _consentAt(TestApp app) async =>
    switch (await SettingsRepository(app.db).read()) {
      Ok(:final value) => value.privacyConsentAt,
      Err(:final error) => fail('settings를 읽지 못했다: $error'),
    };

/// 저장소 읽기를 붙잡아 두는 문. 닫혀 있는 동안 읽기가 끝나지 않는다(온보딩의 다음 단계 저장 중 흉내).
class _Gate {
  Completer<void>? _closed;

  void close() => _closed = Completer<void>();

  void open() {
    _closed?.complete();
    _closed = null;
  }

  Future<void> wait() => _closed?.future ?? Future<void>.value();
}

/// 문이 닫혀 있으면 읽기를 기다리게 하는 저장소.
class _GatedReads extends SettingsRepository {
  _GatedReads(super.db, this.gate);

  final _Gate gate;

  @override
  Future<Result<AppSettings>> read() async {
    await gate.wait();
    return super.read();
  }
}
