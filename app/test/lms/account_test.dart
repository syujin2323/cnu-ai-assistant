// 로그아웃 테스트. docs/lms.md '로그아웃, 데이터 삭제'.
//
// 학번·비밀번호와 쿠키 금고, WebView 쿠키, 불러온 시간표·LMS 할 일을 지우고 상태를 disconnected로 쓰는지, 비밀값을
// 먼저 지우고 하나라도 실패하면 거기서 멈추는지 본다. 값은 모두 합성 값이다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/local_data_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/lms/account.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/failing_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SettingsRepository settings;
  late int webViewClears;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.memory();
    settings = SettingsRepository(db);
    webViewClears = 0;
    FlutterSecureStorage.setMockInitialValues({});
    const vault = CookieVault(FlutterSecureStorage());
    await vault.writeCredential(
      const LmsCredential(studentId: '123456', password: 'pw-1'),
    );
    await vault.writeSession(
      LmsSession(
        savedAt: DateTime.utc(2026, 11, 15),
        userAgent: 'SyntheticAgent/1.0',
        cookies: const [
          LmsCookie(name: 'a', value: 'v1', domain: 'example.invalid'),
        ],
      ),
    );
    await settings.write(SettingKeys.lmsSessionState, LmsSessionState.active);
  });

  tearDown(() => db.close());

  LmsAccount account({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    Future<void> Function()? clearWebView,
  }) => LmsAccount(
    vault: CookieVault(storage),
    localData: LocalDataRepository(db),
    settings: settings,
    clearWebViewCookies: clearWebView ?? () async => webViewClears++,
  );

  /// 불러온 수업과 직접 넣은 수업을 하나씩 넣는다.
  Future<void> addSlots() async {
    final courseId = await db
        .into(db.courses)
        .insert(CoursesCompanion.insert(name: '과목A'));
    for (final source in [SlotSource.auto, SlotSource.manual]) {
      await db
          .into(db.classSlots)
          .insert(
            ClassSlotsCompanion.insert(
              courseId: courseId,
              weekday: 1,
              startMin: 540,
              endMin: 600,
              online: false,
              source: source,
            ),
          );
    }
  }

  Future<LmsSessionState> state() async =>
      (await settings.read() as Ok<AppSettings>).value.lmsSessionState;

  test('비밀값·WebView 쿠키·불러온 시간표를 지우고 상태를 disconnected로 쓴다', () async {
    await addSlots();
    expect(await account().logout(), const Ok<void>(null));

    const vault = CookieVault(FlutterSecureStorage());
    expect(await vault.readCredential(), const Ok<LmsCredential?>(null));
    expect(await vault.readSession(), const Ok<LmsSession?>(null));
    expect(webViewClears, 1);
    final slots = await db.select(db.classSlots).get();
    expect([for (final s in slots) s.source], [SlotSource.manual]);
    expect(await state(), LmsSessionState.disconnected);
  });

  test('비밀값을 지우지 못하면 거기서 멈추고 나머지는 그대로 둔다', () async {
    await addSlots();
    final result = await account(
      storage: FailingSecureStorage(failDeletes: true),
    ).logout();
    expect(
      result,
      isA<Err<void>>().having(
        (r) => r.error,
        'error',
        const StorageError('vault.clear', causeType: 'PlatformException'),
      ),
    );
    expect(webViewClears, 0);
    expect(await db.select(db.classSlots).get(), hasLength(2));
    expect(await state(), LmsSessionState.active);
  });

  test('WebView 쿠키를 지우지 못하면 폰 DB를 지우지 않고 오류다', () async {
    await addSlots();
    final result = await account(
      clearWebView: () async => throw Exception('synthetic'),
    ).logout();
    expect(
      result,
      isA<Err<void>>().having(
        (r) => (r.error as StorageError).operation,
        'operation',
        'webview.clearCookies',
      ),
    );
    expect(await db.select(db.classSlots).get(), hasLength(2));
    expect(await state(), LmsSessionState.active);
  });

  test('폰 DB를 지우지 못하면 비밀값은 지운 채 그 오류다', () async {
    await db.close();
    final result = await account().logout();
    expect(
      result,
      isA<Err<void>>().having(
        (r) => (r.error as StorageError).operation,
        'operation',
        'localData.deleteLmsData',
      ),
    );
    expect(
      await const CookieVault(FlutterSecureStorage()).readCredential(),
      const Ok<LmsCredential?>(null),
    );
    expect(webViewClears, 1);
  });

  test('상태를 쓰지 못하면 그 오류다', () async {
    // 한 번 쓴 뒤 닫은 DB는 쓰기가 StorageError다(데모를 끝낸 DB와 같음).
    final closed = AppDatabase.memory();
    await closed.customSelect('SELECT 1').get();
    await closed.close();
    final result = await LmsAccount(
      vault: const CookieVault(FlutterSecureStorage()),
      localData: LocalDataRepository(db),
      settings: SettingsRepository(closed),
      clearWebViewCookies: () async {},
    ).logout();
    expect(
      result,
      isA<Err<void>>().having(
        (r) => (r.error as StorageError).operation,
        'operation',
        'settings.write',
      ),
    );
  });
}
