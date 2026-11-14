// 설치 토큰. docs/architecture.md '앱과 서버 사이 약속 (API)'.
//
// 처음 쓸 때 32바이트 난수를 만들어 base64url(패딩 없음, 43자)로 보안 저장소의 `install_token` 키에 두고, 그
// 뒤에는 그 값을 쓴다. 학번·기기 정보와 연결하지 않고 서버에 따로 등록하지 않으며, 로그아웃해도 지우지 않는다.
// 서버는 설치마다 하루 AI 호출 수를 세는 데만 쓴다. 저장된 값이 꼴에 맞지 않을 때만 새로 만든다. 설치 표식이
// 없는 첫 실행(앱을 지웠다 다시 깐 경우 등)에는 시작 작업이 보안 저장소를 모두 비우므로 새 토큰이 된다.

import 'dart:convert';
import 'dart:math';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 서버가 받는 설치 토큰 꼴(32바이트를 base64url로 적은 43자).
final RegExp installTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// 32바이트 난수를 base64url(패딩 없음)로 적은 43자.
String newInstallToken(Random random) {
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// 보안 저장소의 설치 토큰을 읽고, 없거나 꼴이 깨졌으면 새로 만들어 둔다.
class InstallTokenStore {
  InstallTokenStore(this._storage, {Random? random})
    : _random = random ?? Random.secure();

  final FlutterSecureStorage _storage;
  final Random _random;
  String? _cached;
  Future<String?>? _pending;

  /// 설치 토큰. 보안 저장소를 읽지 못하면 null이다(그 요청은 토큰 없이 가고 서버가 401로 답한다). 읽지
  /// 못했을 때는 저장된 토큰을 덮어쓰지 않으려고 새로 만들지 않는다. 동시에 불러도 한 번만 읽고 만든다.
  Future<String?> read() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<String?> _load() async {
    final String? saved;
    try {
      saved = await _storage.read(key: SecureKeys.installToken);
    } on Exception catch (error) {
      appLog(
        'install_token_read_failed',
        area: 'api',
        data: {'error': errorKind(error)},
      );
      return null;
    }
    if (saved != null && installTokenPattern.hasMatch(saved)) {
      return _cached = saved;
    }
    final token = newInstallToken(_random);
    try {
      await _storage.write(key: SecureKeys.installToken, value: token);
    } on Exception catch (error) {
      // 저장하지 못해도 이번 실행에는 이 토큰을 쓴다. 다음 실행에 다시 만든다.
      appLog(
        'install_token_write_failed',
        area: 'api',
        data: {'error': errorKind(error)},
      );
    }
    return _cached = token;
  }
}
