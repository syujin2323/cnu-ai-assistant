// 읽기·쓰기·지우기가 실패하는 보안 저장소. 보안 저장소 오류(Keychain·Keystore)를 흉내 낸다.

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [failReads]·[failWrites]·[failDeletes]가 켜진 동작에서 `PlatformException`을 던지고, 나머지는 [inner]에 맡긴다.
class FailingSecureStorage extends FlutterSecureStorage {
  FailingSecureStorage({
    this.inner = const FlutterSecureStorage(),
    this.failReads = false,
    this.failWrites = false,
    this.failDeletes = false,
  });

  final FlutterSecureStorage inner;
  final bool failReads;
  final bool failWrites;
  final bool failDeletes;

  static Never _fail() => throw PlatformException(code: 'synthetic');

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => failReads ? _fail() : inner.read(key: key);

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
  }) async => failWrites ? _fail() : inner.write(key: key, value: value);

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => failDeletes ? _fail() : inner.delete(key: key);
}
