// 설치 토큰 테스트. docs/architecture.md '앱과 서버 사이 약속 (API)'.
//
// 보안 저장소는 flutter_secure_storage의 모의 값이나 읽기·쓰기를 세는 가짜로 바꾼다.

import 'dart:math';

import 'package:cnu_ai_assistant/data/api/install_token.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('32바이트 난수를 패딩 없는 base64url 43자로 적는다', () {
    final random = Random(7);
    for (var i = 0; i < 50; i++) {
      final token = newInstallToken(random);
      expect(token, hasLength(43));
      expect(token, matches(installTokenPattern));
      expect(token, isNot(contains('=')));
    }
  });

  test('저장된 토큰이 없으면 새로 만들어 install_token에 두고, 다음에는 그 값을 쓴다', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();

    final first = await InstallTokenStore(storage).read();

    expect(first, matches(installTokenPattern));
    expect(await storage.read(key: SecureKeys.installToken), first);
    // 새 저장소(다음 실행)도 저장된 값을 읽는다.
    expect(await InstallTokenStore(storage).read(), first);
  });

  test('저장된 토큰이 꼴에 맞으면 그대로 쓰고 다시 쓰지 않는다', () async {
    final saved = 'A' * 43;
    final storage = _FakeStorage({SecureKeys.installToken: saved});

    final store = InstallTokenStore(storage);
    expect(await store.read(), saved);
    expect(await store.read(), saved);
    expect(storage.writes, 0);
    // 한 번 읽은 값은 기억해 보안 저장소를 다시 읽지 않는다.
    expect(storage.reads, 1);
  });

  test('저장된 토큰의 꼴이 깨졌으면 새로 만들어 덮어쓴다', () async {
    for (final broken in [
      '',
      'short',
      '${'A' * 42}=',
      '${'A' * 42}+',
      'A' * 44,
    ]) {
      final storage = _FakeStorage({SecureKeys.installToken: broken});

      final token = await InstallTokenStore(storage).read();

      expect(token, matches(installTokenPattern), reason: broken);
      expect(storage.values[SecureKeys.installToken], token, reason: broken);
    }
  });

  test('동시에 불러도 한 번만 만들고 같은 값을 돌려준다', () async {
    final storage = _FakeStorage({});
    final store = InstallTokenStore(storage);

    final tokens = await Future.wait([
      store.read(),
      store.read(),
      store.read(),
    ]);

    expect(tokens.toSet(), hasLength(1));
    expect(storage.reads, 1);
    expect(storage.writes, 1);
    // 한 번 읽은 뒤에는 보안 저장소를 다시 읽지 않는다.
    await store.read();
    expect(storage.reads, 1);
  });

  test('보안 저장소를 읽지 못하면 null이고, 저장된 값을 덮어쓰지 않으며 다음에 다시 읽는다', () async {
    final saved = 'B' * 43;
    final storage = _FakeStorage({SecureKeys.installToken: saved})
      ..failReads = true;
    final store = InstallTokenStore(storage);

    expect(await store.read(), isNull);
    expect(storage.writes, 0);

    storage.failReads = false;
    expect(await store.read(), saved);
  });

  test('저장하지 못해도 이번 실행에는 만든 토큰을 쓴다', () async {
    final storage = _FakeStorage({})..failWrites = true;
    final store = InstallTokenStore(storage);

    final token = await store.read();

    expect(token, matches(installTokenPattern));
    expect(await store.read(), token);
    expect(storage.values, isEmpty);
  });
}

/// 읽기·쓰기 횟수를 세고 실패를 흉내 내는 보안 저장소.
class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage(this.values);

  final Map<String, String> values;
  int reads = 0;
  int writes = 0;
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    if (failReads) throw PlatformException(code: 'read_failed');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes++;
    if (failWrites) throw PlatformException(code: 'write_failed');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
