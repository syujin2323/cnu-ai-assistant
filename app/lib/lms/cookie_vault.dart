// 쿠키 금고와 저장된 학번·비밀번호. docs/lms.md '쿠키 금고'·'학번·비밀번호와 자동 재로그인'.
//
// - [LmsCookieJar]: 네이티브 요청 하나의 흐름(로그인, 동기화)이 쓰는 메모리의 쿠키 상자. 응답의 `Set-Cookie`를 받아
//   두고 요청에 `Cookie` 헤더를 붙인다.
// - [CookieVault]: 보안 저장소(`flutter_secure_storage`)의 쿠키 금고(`lms_cookie_vault`)와 학번·비밀번호
//   (`lms_credential`). 쿠키 값과 비밀번호는 이 두 키 밖(다른 키, 폰 DB, 로그)에 두지 않는다.
//
// 금고의 쿠키 레코드는 쿠키 브리지 채널의 레코드(`{name, value, domain, path, expiresAt, secure, httpOnly}`,
// docs/architecture.md '한눈에 보기')와 같고 `expiresAt`은 그 순간의 UTC ISO 8601 문자열(세션 쿠키는 null)이다. 레코드에는
// 호스트 전용 여부가 없어 금고에서 읽은 쿠키는 그 도메인과 하위 도메인에 보낸다.

import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:cnu_ai_assistant/data/secure_storage.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart' show isSchoolHost;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 쿠키 하나.
@immutable
final class LmsCookie {
  const LmsCookie({
    required this.name,
    required this.value,
    required this.domain,
    this.path = '/',
    this.expiresAt,
    this.secure = true,
    this.httpOnly = true,
    this.hostOnly = false,
  });

  final String name;

  final String value;

  /// 소문자 도메인(앞의 점 없음).
  final String domain;

  final String path;

  /// 만료 순간(UTC). 세션 쿠키는 null이다.
  final DateTime? expiresAt;

  final bool secure;

  final bool httpOnly;

  /// `Domain` 속성 없이 받은 쿠키라 [domain] 호스트에만 보내는지. 금고에는 남기지 않는다.
  final bool hostOnly;

  /// [nowUtc]에 만료됐는지.
  bool isExpiredAt(DateTime nowUtc) =>
      expiresAt != null && !expiresAt!.isAfter(nowUtc);

  /// [host]의 [path]로 가는 요청에 보내는지(만료는 따로 본다).
  bool appliesTo(String host, String path) {
    final h = host.toLowerCase();
    final domainMatches = hostOnly
        ? h == domain
        : h == domain || h.endsWith('.$domain');
    return domainMatches && _pathMatches(path.isEmpty ? '/' : path);
  }

  bool _pathMatches(String requestPath) {
    if (requestPath == path) return true;
    if (!requestPath.startsWith(path)) return false;
    return path.endsWith('/') || requestPath[path.length] == '/';
  }

  /// 금고·쿠키 브리지의 레코드.
  Map<String, Object?> toRecord() => {
    'name': name,
    'value': value,
    'domain': domain,
    'path': path,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'secure': secure,
    'httpOnly': httpOnly,
  };

  /// 금고의 레코드에서 읽는다. 꼴이 맞지 않으면 null이다.
  static LmsCookie? fromRecord(Object? record) {
    if (record is! Map) return null;
    final name = record['name'];
    final value = record['value'];
    final domain = record['domain'];
    final path = record['path'];
    final expiresAt = record['expiresAt'];
    final secure = record['secure'];
    final httpOnly = record['httpOnly'];
    if (name is! String ||
        name.isEmpty ||
        value is! String ||
        domain is! String ||
        domain.isEmpty ||
        path is! String ||
        (expiresAt != null && expiresAt is! String) ||
        secure is! bool ||
        httpOnly is! bool) {
      return null;
    }
    final DateTime? expires;
    if (expiresAt is String) {
      expires = DateTime.tryParse(expiresAt)?.toUtc();
      if (expires == null) return null;
    } else {
      expires = null;
    }
    return LmsCookie(
      name: name,
      value: value,
      domain: domain.toLowerCase(),
      path: path.isEmpty ? '/' : path,
      expiresAt: expires,
      secure: secure,
      httpOnly: httpOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LmsCookie &&
      other.name == name &&
      other.value == value &&
      other.domain == domain &&
      other.path == path &&
      other.expiresAt == expiresAt &&
      other.secure == secure &&
      other.httpOnly == httpOnly &&
      other.hostOnly == hostOnly;

  @override
  int get hashCode => Object.hash(
    name,
    value,
    domain,
    path,
    expiresAt,
    secure,
    httpOnly,
    hostOnly,
  );
}

/// 메모리의 쿠키 상자. 같은 이름·도메인·경로의 쿠키는 새 값으로 바꾸고, 이미 만료된 쿠키(지우라는 쿠키)를 받으면
/// 그 쿠키를 뺀다.
class LmsCookieJar {
  LmsCookieJar({
    required this.schoolDomain,
    Iterable<LmsCookie> cookies = const [],
  }) {
    for (final cookie in cookies) {
      _put(cookie);
    }
  }

  /// 학교 도메인. 쿠키의 `Domain` 속성은 이 도메인 안이어야 받는다.
  final String schoolDomain;

  final List<LmsCookie> _cookies = [];

  /// 지금 든 쿠키(넣은 차례).
  List<LmsCookie> get cookies => List.unmodifiable(_cookies);

  /// [url]로 받은 응답의 `Set-Cookie` 값들을 받는다. [nowUtc]는 지금 순간이다. 꼴이 맞지 않거나, `Domain` 속성이
  /// 응답 호스트나 그 상위 도메인이 아니거나, 학교 도메인 밖이면 버린다. 받은 쿠키가 있으면 true다.
  bool storeFrom(Uri url, Iterable<String> setCookies, DateTime nowUtc) {
    var changed = false;
    for (final header in setCookies) {
      final cookie = parseSetCookie(header, url, nowUtc);
      if (cookie == null ||
          !isSchoolHost(cookie.domain, domain: schoolDomain)) {
        continue;
      }
      _put(cookie, nowUtc: nowUtc);
      changed = true;
    }
    return changed;
  }

  /// [url]로 보내는 `Cookie` 헤더 값. 보낼 쿠키가 없으면 null이다. 경로가 긴 쿠키를 앞에 둔다.
  String? headerFor(Uri url, DateTime nowUtc) {
    _cookies.removeWhere((cookie) => cookie.isExpiredAt(nowUtc));
    final matching =
        _cookies
            .where(
              (cookie) =>
                  cookie.appliesTo(url.host, url.path) &&
                  (!cookie.secure || url.isScheme('https')),
            )
            .toList()
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
    if (matching.isEmpty) return null;
    return matching
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  /// 금고에 둘 쿠키. 만료되지 않았고 [hosts] 가운데 하나에라도 보내지는 쿠키다.
  List<LmsCookie> cookiesFor(List<String> hosts, DateTime nowUtc) => [
    for (final cookie in _cookies)
      if (!cookie.isExpiredAt(nowUtc) &&
          hosts.any((host) => cookie.appliesTo(host, cookie.path)))
        cookie,
  ];

  /// 같은 이름·도메인·경로의 쿠키를 [cookie]로 바꾼다. [nowUtc]에 이미 만료됐으면 빼기만 한다.
  void _put(LmsCookie cookie, {DateTime? nowUtc}) {
    _cookies.removeWhere(
      (old) =>
          old.name == cookie.name &&
          old.domain == cookie.domain &&
          old.path == cookie.path,
    );
    if (nowUtc == null || !cookie.isExpiredAt(nowUtc)) _cookies.add(cookie);
  }
}

/// `Set-Cookie` 값 하나를 [url]의 응답으로 읽는다. 이름이 없거나, `Domain` 속성이 응답 호스트나 그 상위 도메인이
/// 아니면 null이다. `Max-Age`가 0 이하면 지금 만료된 쿠키(지우라는 쿠키)이고, 읽을 수 없는 `Expires`는 세션
/// 쿠키로 본다. `Max-Age`가 `Expires`보다 앞선다.
LmsCookie? parseSetCookie(String header, Uri url, DateTime nowUtc) {
  final parts = header.split(';');
  final pair = parts.first;
  final eq = pair.indexOf('=');
  if (eq <= 0) return null;
  final name = pair.substring(0, eq).trim();
  final value = _unquote(pair.substring(eq + 1).trim());
  if (name.isEmpty) return null;

  final host = url.host.toLowerCase();
  var domain = host;
  var hostOnly = true;
  var path = _defaultPath(url.path);
  DateTime? expires;
  DateTime? maxAgeExpires;
  var secure = false;
  var httpOnly = false;
  for (final attribute in parts.skip(1)) {
    final at = attribute.indexOf('=');
    final key = (at < 0 ? attribute : attribute.substring(0, at))
        .trim()
        .toLowerCase();
    final raw = at < 0 ? '' : attribute.substring(at + 1).trim();
    switch (key) {
      case 'domain':
        final d = (raw.startsWith('.') ? raw.substring(1) : raw).toLowerCase();
        if (d.isEmpty) continue;
        if (!(host == d || host.endsWith('.$d'))) return null;
        domain = d;
        hostOnly = false;
      case 'path':
        if (raw.startsWith('/')) path = raw;
      case 'expires':
        try {
          expires = HttpDate.parse(raw);
        } on Exception {
          expires = null;
        }
      case 'max-age':
        final seconds = int.tryParse(raw);
        if (seconds != null) {
          maxAgeExpires = seconds <= 0
              ? nowUtc
              : nowUtc.add(Duration(seconds: seconds));
        }
      case 'secure':
        secure = true;
      case 'httponly':
        httpOnly = true;
    }
  }
  final expiresAt = maxAgeExpires ?? expires;
  return LmsCookie(
    name: name,
    value: value,
    domain: domain,
    path: path,
    expiresAt: expiresAt?.toUtc(),
    secure: secure,
    httpOnly: httpOnly,
    hostOnly: hostOnly,
  );
}

String _unquote(String value) =>
    value.length >= 2 && value.startsWith('"') && value.endsWith('"')
    ? value.substring(1, value.length - 1)
    : value;

/// 응답 주소의 경로에서 쿠키의 기본 경로(마지막 `/` 앞까지).
String _defaultPath(String path) {
  if (!path.startsWith('/')) return '/';
  final last = path.lastIndexOf('/');
  return last <= 0 ? '/' : path.substring(0, last);
}

/// 저장된 학번·비밀번호.
@immutable
final class LmsCredential {
  const LmsCredential({required this.studentId, required this.password});

  final String studentId;

  final String password;

  @override
  bool operator ==(Object other) =>
      other is LmsCredential &&
      other.studentId == studentId &&
      other.password == password;

  @override
  int get hashCode => Object.hash(studentId, password);

  /// 값을 드러내지 않는다(로그·오류 문구에 섞이지 않게).
  @override
  String toString() => 'LmsCredential(***)';
}

/// 금고에 둔 세션: 쿠키와 그 쿠키를 받을 때 쓴 User-Agent.
@immutable
final class LmsSession {
  const LmsSession({
    required this.savedAt,
    required this.userAgent,
    required this.cookies,
  });

  /// 저장한 순간(UTC).
  final DateTime savedAt;

  final String userAgent;

  final List<LmsCookie> cookies;

  @override
  String toString() =>
      'LmsSession(savedAt: $savedAt, cookies: ${cookies.length})';
}

/// 보안 저장소의 쿠키 금고와 학번·비밀번호. 읽기·쓰기는 던지지 않고 [Result]다(실패는 [StorageError]).
class CookieVault {
  const CookieVault(this._storage);

  final FlutterSecureStorage _storage;

  /// 저장된 학번·비밀번호. 없거나 꼴이 깨졌으면 null이다.
  Future<Result<LmsCredential?>> readCredential() =>
      _guard('vault.readCredential', () async {
        final raw = await _storage.read(key: SecureKeys.lmsCredential);
        final json = _decode(raw);
        if (json is! Map) return null;
        final id = json['studentId'];
        final password = json['password'];
        if (id is! String || id.isEmpty || password is! String) return null;
        return LmsCredential(studentId: id, password: password);
      });

  Future<Result<void>> writeCredential(LmsCredential credential) => _guard(
    'vault.writeCredential',
    () => _storage.write(
      key: SecureKeys.lmsCredential,
      value: jsonEncode({
        'studentId': credential.studentId,
        'password': credential.password,
      }),
    ),
  );

  /// 금고의 세션. 없거나 꼴이 깨졌으면 null이고, 꼴이 깨진 쿠키 레코드는 뺀다.
  Future<Result<LmsSession?>> readSession() => _guard(
    'vault.readSession',
    () async {
      final json = _decode(await _storage.read(key: SecureKeys.lmsCookieVault));
      if (json is! Map) return null;
      final savedAt = json['savedAt'];
      final userAgent = json['userAgent'];
      final cookies = json['cookies'];
      final saved = savedAt is String ? DateTime.tryParse(savedAt) : null;
      if (saved == null || cookies is! List) return null;
      return LmsSession(
        savedAt: saved.toUtc(),
        userAgent: userAgent is String ? userAgent : '',
        cookies: [for (final record in cookies) ?LmsCookie.fromRecord(record)],
      );
    },
  );

  Future<Result<void>> writeSession(LmsSession session) => _guard(
    'vault.writeSession',
    () => _storage.write(
      key: SecureKeys.lmsCookieVault,
      value: jsonEncode({
        'savedAt': session.savedAt.toUtc().toIso8601String(),
        'userAgent': session.userAgent,
        'cookies': [for (final cookie in session.cookies) cookie.toRecord()],
      }),
    ),
  );

  /// 학번·비밀번호와 쿠키 금고를 지운다(로그아웃).
  Future<Result<void>> clear() => _guard('vault.clear', () async {
    await _storage.delete(key: SecureKeys.lmsCredential);
    await _storage.delete(key: SecureKeys.lmsCookieVault);
  });

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static Future<Result<T>> _guard<T>(
    String operation,
    Future<T> Function() body,
  ) async {
    try {
      return Ok(await body());
    } on PlatformException {
      return Err(StorageError(operation, causeType: 'PlatformException'));
    }
  }
}

/// LMS가 쓰는 보안 저장소. 테스트는 실패하는 저장소로 덮어쓴다.
final lmsSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => appSecureStorage,
);

/// 쿠키 금고와 저장된 학번·비밀번호.
final cookieVaultProvider = Provider<CookieVault>(
  (ref) => CookieVault(ref.watch(lmsSecureStorageProvider)),
);
