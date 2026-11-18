// 10 나 화면 테스트. docs/screens.md '10 나', docs/lms.md '로그아웃, 데이터 삭제, 내보내기'.
//
// 2026-11-16(월) 10:00이고, 실제 모드에서 LMS에 로그인해 있다(저장된 학번 202412345).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/design/legal_texts.dart';
import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/features/lms_connect/relogin_screen.dart';
import 'package:cnu_ai_assistant/features/me/me_controller.dart';
import 'package:cnu_ai_assistant/features/me/me_screen.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_screen.dart';
import 'package:cnu_ai_assistant/lms/account.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final now = DateTime(2026, 11, 16, 10);

/// 저장된 학번·비밀번호(보안 저장소 키는 `SecureKeys.lmsCredential`).
const _credential = '{"studentId":"202412345","password":"pw-1"}';

/// 과목 둘과 할 일 셋(사흘 뒤 마감, 열흘 뒤 마감, 어제 마감)을 넣는다.
Future<void> seed(AppDatabase db) async {
  await db.into(db.courses).insert(CoursesCompanion.insert(name: '자료구조'));
  await db.into(db.courses).insert(CoursesCompanion.insert(name: '선형대수'));
  for (final (title, due) in [
    ('사흘 뒤 과제', DateTime(2026, 11, 19, 23, 59)),
    ('열흘 뒤 과제', DateTime(2026, 11, 26, 23, 59)),
    ('어제 과제', DateTime(2026, 11, 15, 23, 59)),
  ]) {
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: title,
            kind: TaskKind.assignment,
            dueAt: Value(due),
            dueTimeUnknown: false,
            status: TaskStatus.todo,
          ),
        );
  }
}

/// 10 나를 띄운다. [logout]은 로그아웃을 흉내 낸다(없으면 LMS 상태만 로그인 전으로 바꾸고 성공).
Future<TestApp> pumpMe(
  WidgetTester tester, {
  double textScale = 1.0,
  Size size = phonePortrait,
  TestStart start = TestStart.loggedIn,
  Map<String, Object?> settings = const {},
  Future<Result<void>> Function(TestApp app)? logout,
  Map<String, String> secure = const {'lms_credential': _credential},
}) async {
  FlutterSecureStorage.setMockInitialValues({...secure});
  late TestApp app;
  app = await pumpTestApp(
    tester,
    now: now,
    textScale: textScale,
    size: size,
    start: start,
    settings: settings,
    overrides: [
      appVersionProvider.overrideWith((ref) async => '0.1.0'),
      lmsClearWebViewCookiesProvider.overrideWithValue(() async {}),
      logoutProvider.overrideWithValue(
        () =>
            logout?.call(app) ??
            SettingsRepository(
              app.db,
            ).write(SettingKeys.lmsSessionState, LmsSessionState.disconnected),
      ),
    ],
  );
  await seed(app.db);
  await tester.pumpAndSettle();
  await tapTab(tester, '나');
  expect(find.byType(MeScreen), findsOneWidget);
  return app;
}

Future<void> tapFinder(WidgetTester tester, Finder target) async {
  await scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('maskStudentId', () {
    test('앞 4자리와 끝 2자리만 보이고, 짧으면 끝 2자리만 보인다', () {
      expect(maskStudentId('202412345'), '2024•••45');
      expect(maskStudentId(' 20241234 '), '2024••34');
      expect(maskStudentId('123456'), '••••56');
      expect(maskStudentId('12'), '••');
    });
  });

  test('문의 메일은 처리방침의 연락처에서 읽고, 없으면 null이다', () {
    expect(
      contactEmailFrom('- 운영자: 송유진\n- 연락처: team@example.invalid\n'),
      'team@example.invalid',
    );
    expect(contactEmailFrom('연락처 없음'), isNull);
    expect(contactEmailFrom(privacyPolicyMarkdown), isNotNull);
  });

  for (final textScale in [1.0, 2.0]) {
    group('글자 배율 $textScale', () {
      testWidgets('머리·학기 카드·LMS 계정·일정·데이터·앱 정보를 보이고, 학기 카드는 03 할 일을 연다', (
        tester,
      ) async {
        final app = await pumpMe(tester, textScale: textScale);

        expect(find.text('CNU PLANNER'), findsOneWidget);
        expect(find.text('충남대 비공식 앱'), findsOneWidget);
        expect(find.text('과목 2개 · 이번 주 할 일 2개'), findsOneWidget);
        expect(find.text('2024•••45'), findsOneWidget);
        expect(find.text('지금 새로 고침'), findsOneWidget);
        await scrollTo(tester, find.text('로그아웃'));
        expect(find.textContaining('PC·웹 LMS 세션이 끊길 수 있어요'), findsOneWidget);
        await scrollTo(tester, find.text('데이터 삭제'));
        await scrollTo(tester, find.text('버전'));
        expect(find.text('0.1.0'), findsOneWidget);
        expect(
          find.text(contactEmailFrom(privacyPolicyMarkdown)!),
          findsOneWidget,
        );

        await tester.scrollUntilVisible(find.text('이번 학기'), -200);
        await tapFinder(tester, find.text('이번 학기'));
        expect(app.router.state.uri.path, Routes.tasks);

        await app.dispose(tester);
      });

      testWidgets('로그아웃은 지우는 것과 두는 것을 보이고, 하면 14 온보딩 1단계로 간다', (tester) async {
        final app = await pumpMe(tester, textScale: textScale);

        await tapFinder(tester, find.text('로그아웃'));
        expect(find.text('로그아웃할까요?'), findsOneWidget);
        expect(find.text('그대로 두는 것'), findsOneWidget);
        await tapFinder(tester, find.widgetWithText(FilledButton, '로그아웃'));

        expect(find.byType(OnboardingScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('로그아웃 시트를 [취소]하면 그대로이고, 로그아웃하지 못하면 알린다', (tester) async {
        final app = await pumpMe(
          tester,
          textScale: textScale,
          logout: (_) async => const Err(StorageError('vault.clear')),
        );

        await tapFinder(tester, find.text('로그아웃'));
        await tapFinder(tester, find.text('취소'));
        expect(find.byType(MeScreen), findsOneWidget);

        await tapFinder(tester, find.text('로그아웃'));
        await tapFinder(tester, find.widgetWithText(FilledButton, '로그아웃'));
        expect(find.text('로그아웃하지 못했어요. 다시 해 주세요'), findsOneWidget);
        expect(find.byType(MeScreen), findsOneWidget);

        await app.dispose(tester);
      });

      testWidgets('데이터 삭제는 되돌릴 수 없다고 알리고, 지우면 모든 것을 비우고 14 온보딩 1단계로 간다', (
        tester,
      ) async {
        final app = await pumpMe(tester, textScale: textScale);

        await tapFinder(tester, find.text('데이터 삭제'));
        expect(find.text('지운 데이터는 되돌릴 수 없어요'), findsOneWidget);
        await tapFinder(tester, find.text('취소'));
        expect(await app.db.select(app.db.tasks).get(), hasLength(3));

        await tapFinder(tester, find.text('데이터 삭제'));
        await tapFinder(tester, find.text('모두 지우기'));

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(await app.db.select(app.db.tasks).get(), isEmpty);
        expect(await app.db.select(app.db.courses).get(), isEmpty);
        expect(app.preferences.containsKey(PrefKeys.onboardingDone), isFalse);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
        final settings = await SettingsRepository(app.db).read();
        expect((settings as Ok<AppSettings>).value.installedAt, isNotNull);

        await app.dispose(tester);
      });

      testWidgets('다시 로그인해야 하면 다시 로그인 줄이 다시 로그인 화면을 연다', (tester) async {
        final app = await pumpMe(
          tester,
          textScale: textScale,
          settings: {
            SettingKeys.lmsSessionState: LmsSessionState.reconnectRequired,
          },
        );

        await tapFinder(tester, find.text('다시 로그인'));

        expect(find.byType(ReloginScreen), findsOneWidget);
        expect(app.router.state.uri.path, Routes.login);

        await app.dispose(tester);
      });

      testWidgets('로그인 정보가 없으면 LMS에 로그인 줄이 있고 로그아웃은 없다', (tester) async {
        final app = await pumpMe(
          tester,
          textScale: textScale,
          secure: const {},
        );
        await SettingsRepository(app.db)
            .write(SettingKeys.lmsSessionState, LmsSessionState.disconnected);
        await tester.pumpAndSettle();

        expect(find.text('로그인하지 않았어요'), findsOneWidget);
        expect(find.text('LMS에 로그인'), findsOneWidget);
        expect(find.text('로그아웃'), findsNothing);

        await app.dispose(tester);
      });

      testWidgets('처리방침·이용약관은 앱 안 화면으로, 오픈소스 라이선스는 라이선스 화면으로 연다', (
        tester,
      ) async {
        final app = await pumpMe(tester, textScale: textScale);

        await tapFinder(tester, find.text(LegalDocument.privacy.title));
        expect(
          tester
              .widget<LegalDocumentPage>(find.byType(LegalDocumentPage))
              .document,
          LegalDocument.privacy,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tapFinder(tester, find.text(LegalDocument.terms.title));
        expect(
          tester
              .widget<LegalDocumentPage>(find.byType(LegalDocumentPage))
              .document,
          LegalDocument.terms,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tapFinder(tester, find.text('오픈소스 라이선스'));
        expect(find.byType(LicensePage), findsOneWidget);

        await app.dispose(tester);
      });
    });
  }

  testWidgets('데모 모드에서는 LMS 계정 동작과 데이터 삭제가 없고, 태블릿 가로 폭에서도 넘치지 않는다', (
    tester,
  ) async {
    final app = await pumpMe(
      tester,
      textScale: 2.0,
      size: tabletLandscape,
      start: TestStart.demo,
    );

    expect(find.text('데모 계정'), findsOneWidget);
    expect(find.text('로그아웃'), findsNothing);
    expect(find.text('지금 새로 고침'), findsNothing);
    await scrollTo(tester, find.text('데모 모드 끝내기'));
    expect(find.text('데이터 삭제'), findsNothing);

    await app.dispose(tester);
  });
}
