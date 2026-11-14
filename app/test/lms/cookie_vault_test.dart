// 쿠키 금고 테스트. docs/lms.md '쿠키 금고'·'학번·비밀번호와 자동 재로그인'.
//
// 응답의 쿠키 설정 값 읽기, 메모리 쿠키 상자, 보안 저장소의 금고와 학번·비밀번호를 본다. 쿠키 이름·값과 학번·비밀번호는
// 모두 짧은 합성 값이다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/cookie_vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/failing_secure_storage.dart';

final _now = DateTime.utc(2026, 11, 15, 1);
final _page = Uri.parse('https://example.invalid/dir/page');
final _lms = Uri.parse('https://lms.example.invalid/');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseSetCookie', () {
    test('이름·값과 속성이 없으면 응답 호스트 전용, 주소의 디렉터리 경로, 세션 쿠키다', () {
      final parsed = parseSetCookie('a=v1', _page, _now)!;
      expect(parsed.name, 'a');
      expect(parsed.value, 'v1');
      expect(parsed.domain, 'example.invalid');
      expect(parsed.hostOnly, isTrue);
      expect(parsed.path, '/dir');
      expect(parsed.expiresAt, isNull);
      expect(parsed.secure, isFalse);
      expect(parsed.httpOnly, isFalse);
    });

    test('Domain·Path·Secure·HttpOnly 속성을 읽는다(대소문자 무시, 앞의 점은 뗌)', () {
      final parsed = parseSetCookie(
        'a=v1; domain=.Example.Invalid; PATH=/x; Secure; httponly',
        _lms,
        _now,
      )!;
      expect(parsed.domain, 'example.invalid');
      expect(parsed.hostOnly, isFalse);
      expect(parsed.path, '/x');
      expect(parsed.secure, isTrue);
      expect(parsed.httpOnly, isTrue);
    });

    test('Domain이 응답 호스트나 그 상위 도메인이 아니면 버린다', () {
      for (final header in [
        'a=v1; Domain=other.example.invalid',
        'a=v1; Domain=example.com',
        'a=v1; Domain=ms.example.invalid',
      ]) {
        expect(parseSetCookie(header, _lms, _now), isNull, reason: header);
      }
    });

    test('Expires는 HTTP 날짜이고, Max-Age가 앞서며, 0 이하는 지금 만료다', () {
      expect(
        parseSetCookie(
          'a=v1; Expires=Wed, 21 Oct 2026 07:28:00 GMT',
          _page,
          _now,
        )!.expiresAt,
        DateTime.utc(2026, 10, 21, 7, 28),
      );
      expect(
        parseSetCookie(
          'a=v1; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Max-Age=60',
          _page,
          _now,
        )!.expiresAt,
        _now.add(const Duration(seconds: 60)),
      );
      expect(
        parseSetCookie('a=v1; Max-Age=0', _page, _now)!.isExpiredAt(_now),
        isTrue,
      );
      expect(
        parseSetCookie('a=v1; Max-Age=-5', _page, _now)!.isExpiredAt(_now),
        isTrue,
      );
    });

    test('읽을 수 없는 Expires·Max-Age는 세션 쿠키로 본다', () {
      expect(
        parseSetCookie('a=v1; Expires=soon', _page, _now)!.expiresAt,
        isNull,
      );
      expect(parseSetCookie('a=v1; Max-Age=x', _page, _now)!.expiresAt, isNull);
    });

    test('따옴표로 감싼 값은 벗기고 값 안의 = 는 그대로 둔다', () {
      expect(parseSetCookie('a="v1"', _page, _now)!.value, 'v1');
      expect(parseSetCookie('a=b=c', _page, _now)!.value, 'b=c');
      expect(parseSetCookie('a=', _page, _now)!.value, '');
    });

    test('이름이 없으면 버리고, /로 시작하지 않는 Path는 기본 경로로 둔다', () {
      expect(parseSetCookie('novalue', _page, _now), isNull);
      expect(parseSetCookie('=v1', _page, _now), isNull);
      expect(parseSetCookie(' =v1', _page, _now), isNull);
      expect(parseSetCookie('a=v1; Path=rel', _page, _now)!.path, '/dir');
      expect(parseSetCookie('a=v1', _lms, _now)!.path, '/');
    });
  });

  group('LmsCookie', () {
    test('호스트 전용 쿠키는 그 호스트에만, 도메인 쿠키는 하위 도메인에도 간다', () {
      const hostOnly = LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
        hostOnly: true,
      );
      const domain = LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
      );
      expect(hostOnly.appliesTo('example.invalid', '/'), isTrue);
      expect(hostOnly.appliesTo('lms.example.invalid', '/'), isFalse);
      expect(domain.appliesTo('LMS.example.invalid', '/'), isTrue);
      expect(domain.appliesTo('notexample.invalid', '/'), isFalse);
    });

    test('경로는 같거나 그 아래 마디일 때만 맞는다', () {
      const x = LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
        path: '/x',
      );
      const xSlash = LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
        path: '/x/',
      );
      expect(x.appliesTo('example.invalid', '/x'), isTrue);
      expect(x.appliesTo('example.invalid', '/x/y'), isTrue);
      expect(x.appliesTo('example.invalid', '/xy'), isFalse);
      expect(x.appliesTo('example.invalid', '/'), isFalse);
      expect(xSlash.appliesTo('example.invalid', '/x/y'), isTrue);
      expect(xSlash.appliesTo('example.invalid', ''), isFalse);
    });

    test('레코드로 바꿨다 읽으면 호스트 전용 여부만 빼고 같다', () {
      final original = LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
        path: '/x',
        expiresAt: DateTime.utc(2026, 12, 1, 3),
        secure: false,
        httpOnly: true,
        hostOnly: true,
      );
      final record = original.toRecord();
      expect(record, {
        'name': 'a',
        'value': 'v1',
        'domain': 'example.invalid',
        'path': '/x',
        'expiresAt': '2026-12-01T03:00:00.000Z',
        'secure': false,
        'httpOnly': true,
      });
      final restored = LmsCookie.fromRecord(jsonDecode(jsonEncode(record)))!;
      expect(restored.name, 'a');
      expect(restored.expiresAt, DateTime.utc(2026, 12, 1, 3));
      expect(restored.hostOnly, isFalse);
    });

    test('꼴이 맞지 않는 레코드는 null이다', () {
      final good = const LmsCookie(
        name: 'a',
        value: 'v1',
        domain: 'example.invalid',
      ).toRecord();
      for (final (key, value) in <(String, Object?)>[
        ('name', ''),
        ('name', 1),
        ('value', null),
        ('domain', ''),
        ('path', null),
        ('expiresAt', 1),
        ('expiresAt', 'not a date'),
        ('secure', 'yes'),
        ('httpOnly', null),
      ]) {
        expect(
          LmsCookie.fromRecord({...good, key: value}),
          isNull,
          reason: '$key: $value',
        );
      }
      expect(LmsCookie.fromRecord('a=v1'), isNull);
    });
  });

  group('LmsCookieJar', () {
    LmsCookieJar jar() => LmsCookieJar(schoolDomain: 'example.invalid');

    test('같은 이름·도메인·경로는 새 값으로 바꾸고, 만료된 값을 받으면 뺀다', () {
      final box = jar();
      expect(
        box.storeFrom(_lms, ['a=v1; Domain=example.invalid'], _now),
        isTrue,
      );
      box.storeFrom(_lms, ['a=v2; Domain=example.invalid', 'b=v3'], _now);
      expect(
        {for (final c in box.cookies) c.name: c.value},
        {'a': 'v2', 'b': 'v3'},
      );
      box.storeFrom(_lms, ['a=; Domain=example.invalid; Max-Age=0'], _now);
      expect([for (final c in box.cookies) c.name], ['b']);
      expect(box.storeFrom(_lms, const [], _now), isFalse);
    });

    test('학교 도메인 밖의 쿠키와 읽을 수 없는 값은 받지 않는다', () {
      final box = LmsCookieJar(schoolDomain: 'lms.example.invalid');
      expect(
        box.storeFrom(_page, [
          'a=v1',
          'novalue',
          'c=v2; Domain=x.invalid',
        ], _now),
        isFalse,
      );
      expect(box.cookies, isEmpty);
    });

    test('요청에 맞는 쿠키를 경로가 긴 것부터 이어 붙이고, 만료된 쿠키는 버린다', () {
      final box = jar()
        ..storeFrom(_lms, [
          'a=v1; Domain=example.invalid; Path=/',
          'b=v2; Path=/x/y',
          'c=v3; Path=/x; Max-Age=60',
          'd=v4; Path=/other',
        ], _now);
      expect(
        box.headerFor(Uri.parse('https://lms.example.invalid/x/y/z'), _now),
        'b=v2; c=v3; a=v1',
      );
      final later = _now.add(const Duration(seconds: 61));
      expect(
        box.headerFor(Uri.parse('https://lms.example.invalid/x/y/z'), later),
        'b=v2; a=v1',
      );
      expect([for (final c in box.cookies) c.name], ['a', 'b', 'd']);
      expect(
        box.headerFor(Uri.parse('https://example.invalid/x'), later),
        'a=v1',
      );
      expect(jar().headerFor(_lms, _now), isNull);
    });

    test('금고에 둘 쿠키는 만료되지 않았고 주어진 호스트 가운데 하나에 가는 쿠키다', () {
      final box = jar()
        ..storeFrom(_page, ['h=v1', 'd=v2; Domain=example.invalid'], _now)
        ..storeFrom(_lms, ['l=v3', 'e=v4; Max-Age=60'], _now);
      final later = _now.add(const Duration(seconds: 61));
      expect(
        [
          for (final c in box.cookiesFor(['lms.example.invalid'], later))
            c.name,
        ],
        ['d', 'l'],
      );
      expect(
        [
          for (final c in box.cookiesFor([
            'example.invalid',
            'lms.example.invalid',
          ], _now))
            c.name,
        ],
        ['h', 'd', 'l', 'e'],
      );
    });

    test('금고에서 읽은 쿠키로 시작할 수 있다', () {
      final box = LmsCookieJar(
        schoolDomain: 'example.invalid',
        cookies: const [
          LmsCookie(name: 'a', value: 'v1', domain: 'example.invalid'),
        ],
      );
      expect(box.headerFor(_lms, _now), 'a=v1');
    });
  });

  group('CookieVault', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    const vault = CookieVault(FlutterSecureStorage());
    const storage = FlutterSecureStorage();

    test('학번·비밀번호를 쓰고 읽으며, 문자열로 드러내지 않는다', () async {
      expect(await vault.readCredential(), const Ok<LmsCredential?>(null));
      const credential = LmsCredential(studentId: '123456', password: 'pw-1');
      expect(await vault.writeCredential(credential), const Ok<void>(null));
      expect(
        await vault.readCredential(),
        const Ok<LmsCredential?>(credential),
      );
      expect('$credential', isNot(contains('pw-1')));
      expect('$credential', isNot(contains('123456')));
    });

    test('깨졌거나 꼴이 맞지 않는 학번·비밀번호는 없는 것으로 읽는다', () async {
      for (final raw in [
        'not json',
        '[]',
        '{"studentId": "", "password": "x"}',
        '{"studentId": "1"}',
      ]) {
        await storage.write(key: SecureKeys.lmsCredential, value: raw);
        expect(
          await vault.readCredential(),
          const Ok<LmsCredential?>(null),
          reason: raw,
        );
      }
    });

    test('세션(저장 시각, User-Agent, 쿠키)을 쓰고 읽는다', () async {
      expect(await vault.readSession(), const Ok<LmsSession?>(null));
      final session = LmsSession(
        savedAt: _now,
        userAgent: 'SyntheticAgent/1.0',
        cookies: [
          LmsCookie(
            name: 'a',
            value: 'v1',
            domain: 'example.invalid',
            expiresAt: _now.add(const Duration(days: 1)),
          ),
          const LmsCookie(name: 'b', value: 'v2', domain: 'example.invalid'),
        ],
      );
      expect(await vault.writeSession(session), const Ok<void>(null));
      final read = (await vault.readSession() as Ok<LmsSession?>).value!;
      expect(read.savedAt, _now);
      expect(read.userAgent, 'SyntheticAgent/1.0');
      expect(read.cookies, session.cookies);
      expect('$read', isNot(contains('v1')));
    });

    test('세션의 깨진 쿠키 레코드는 빼고, 저장 시각이나 쿠키 목록이 없으면 세션이 없다', () async {
      await storage.write(
        key: SecureKeys.lmsCookieVault,
        value: jsonEncode({
          'savedAt': '2026-11-15T01:00:00.000Z',
          'userAgent': 1,
          'cookies': [
            {'name': 'a'},
            const LmsCookie(
              name: 'b',
              value: 'v2',
              domain: 'example.invalid',
            ).toRecord(),
          ],
        }),
      );
      final read = (await vault.readSession() as Ok<LmsSession?>).value!;
      expect(read.userAgent, '');
      expect([for (final c in read.cookies) c.name], ['b']);

      for (final raw in [
        'not json',
        '{"cookies": []}',
        '{"savedAt": "x", "cookies": []}',
        '{"savedAt": "2026-11-15T01:00:00.000Z", "cookies": {}}',
      ]) {
        await storage.write(key: SecureKeys.lmsCookieVault, value: raw);
        expect(
          await vault.readSession(),
          const Ok<LmsSession?>(null),
          reason: raw,
        );
      }
    });

    test('clear는 학번·비밀번호와 쿠키 금고만 지운다', () async {
      await vault.writeCredential(
        const LmsCredential(studentId: '1', password: '2'),
      );
      await vault.writeSession(
        LmsSession(savedAt: _now, userAgent: 'x', cookies: const []),
      );
      await storage.write(key: SecureKeys.installToken, value: 'token');
      expect(await vault.clear(), const Ok<void>(null));
      expect(await storage.read(key: SecureKeys.lmsCredential), isNull);
      expect(await storage.read(key: SecureKeys.lmsCookieVault), isNull);
      expect(await storage.read(key: SecureKeys.installToken), 'token');
    });

    test('보안 저장소 오류는 던지지 않고 StorageError다', () async {
      final failing = CookieVault(
        FailingSecureStorage(
          failReads: true,
          failWrites: true,
          failDeletes: true,
        ),
      );
      StorageError error(Result<Object?> result) =>
          (result as Err).error as StorageError;
      expect(
        error(await failing.readCredential()),
        const StorageError(
          'vault.readCredential',
          causeType: 'PlatformException',
        ),
      );
      expect(error(await failing.readSession()).operation, 'vault.readSession');
      expect(
        error(
          await failing.writeCredential(
            const LmsCredential(studentId: '1', password: '2'),
          ),
        ).operation,
        'vault.writeCredential',
      );
      expect(
        error(
          await failing.writeSession(
            LmsSession(savedAt: _now, userAgent: 'x', cookies: const []),
          ),
        ).operation,
        'vault.writeSession',
      );
      expect(error(await failing.clear()).operation, 'vault.clear');
    });
  });
}
