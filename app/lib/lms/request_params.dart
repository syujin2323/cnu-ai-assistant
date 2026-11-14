// LMS 요청 상수(Remote Config `lms_request_params`)의 설정 파서. docs/lms.md '원격 스위치'·'응답 판별',
// docs/architecture.md '환경 변수'.
//
// 요청 상수의 값은 Remote Config 콘솔에만 있고 레포에는 두지 않는다. 이 파일은 키 이름과 형식만 정한다. 값이
// 비어 있거나, JSON 객체가 아니거나, `version`을 모르거나, 키가 빠졌거나 형이 다르거나, 주소가 학교 도메인
// (`lms_config.dart`의 `lmsSchoolDomain`) 밖이거나 https가 아니면 '설정 없음'이다. 모르는 키는 무시하므로 키를 더할 때는 `version`을
// 올리지 않는다. 키를 빼거나 뜻을 바꿀 때만 올리고, 새 `version`은 그것을 읽는 앱 빌드가 테스터에게 나간 뒤에만
// 콘솔에 넣는다.
//
// version 1의 키(값은 지어낸 예):
//
//   {
//     "version": 1,
//     "homeUrl": "https://example.invalid/",              세션 복원 1단계에서 여는 홈 주소
//     "loginUrl": "https://example.invalid/login",        로그인 주소. 응답의 최종 주소가 이 주소(같은 호스트의
//                                                         같은 경로나 그 아래 경로)면 재로그인 필요
//     "cookieDomains": ["example.invalid"],               쿠키 금고에 두는 쿠키의 도메인(하나 이상)
//     "markers": {
//       "loginPage": ["..."],                             본문에 있으면 로그인 페이지(재로그인 필요)
//       "maintenance": ["..."],                           본문에 있으면 점검 페이지(서버 오류·점검)
//       "authError": [{"path": "a.b", "anyOf": ["..."]}]  JSON의 그 자리 값이 이 가운데 하나면 인증 오류(복원 필요)
//     }
//   }
//
// 표식 목록은 비어 있어도 된다. 표식은 대소문자를 가리는 부분 문자열이고, `authError`의 `path`는 점으로 나눈
// 키(목록이면 0부터 세는 번호)이며, `anyOf`의 값은 문자열이나 정수다.

import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// 이 앱이 읽는 `version`.
const lmsRequestParamsVersions = {1};

/// 요청 상수를 해석하지 못한 이유. 로그에는 이름만 남긴다.
enum LmsConfigProblem {
  /// 값이 비어 있다(콘솔에 아직 넣지 않았거나 가져오지 못함).
  empty,

  /// JSON 객체가 아니다.
  notJson,

  /// `version`이 없거나 이 앱이 모르는 값이다.
  version,

  /// 필요한 키가 없거나 형이 다르다.
  field,

  /// 주소가 https가 아니거나 학교 도메인 밖이다.
  domain,
}

/// [parseLmsRequestParams]의 결과. [params]와 [problem] 가운데 하나만 null이 아니다.
typedef LmsRequestParamsParse = ({
  LmsRequestParams? params,
  LmsConfigProblem? problem,
});

/// Remote Config의 `lms_request_params` 문자열 [raw]를 해석한다. [schoolDomain]은 학교 도메인이고 주소는 모두
/// 그 도메인이나 하위 도메인의 https 주소여야 한다. 던지지 않는다.
LmsRequestParamsParse parseLmsRequestParams(
  String raw, {
  required String schoolDomain,
}) {
  if (raw.trim().isEmpty) {
    return (params: null, problem: LmsConfigProblem.empty);
  }
  final Object? json;
  try {
    json = jsonDecode(raw);
  } on FormatException {
    return (params: null, problem: LmsConfigProblem.notJson);
  }
  if (json is! Map<String, Object?>) {
    return (params: null, problem: LmsConfigProblem.notJson);
  }
  try {
    return (
      params: _readParams(json, schoolDomain.toLowerCase()),
      problem: null,
    );
  } on _Invalid catch (invalid) {
    return (params: null, problem: invalid.problem);
  }
}

/// [uri]가 학교 도메인([domain]이나 그 하위 도메인)의 https 주소인지. 사용자 정보가 붙었거나 443 밖의 포트면
/// 아니다.
bool isSchoolUrl(Uri uri, {required String domain}) =>
    uri.isScheme('https') &&
    uri.userInfo.isEmpty &&
    uri.port == 443 &&
    isSchoolHost(uri.host, domain: domain);

/// [host]가 학교 도메인 [domain]이거나 그 하위 도메인인지. 대소문자는 가리지 않는다.
bool isSchoolHost(String host, {required String domain}) {
  final h = host.toLowerCase();
  final d = domain.toLowerCase();
  return d.isNotEmpty && (h == d || h.endsWith('.$d'));
}

/// 해석한 요청 상수(version 1).
@immutable
final class LmsRequestParams {
  const LmsRequestParams({
    required this.version,
    required this.homeUrl,
    required this.loginUrl,
    required this.cookieDomains,
    required this.markers,
  });

  final int version;

  /// 세션 복원 1단계에서 여는 홈 주소.
  final Uri homeUrl;

  /// 로그인 주소. 응답의 최종 주소가 이 주소로 넘어갔으면 재로그인 필요다([isLoginUrl]).
  final Uri loginUrl;

  /// 쿠키 금고에 두는 쿠키의 도메인. 소문자이고 앞의 점은 뗐다.
  final List<String> cookieDomains;

  /// 응답 판별 표식.
  final LmsMarkers markers;

  /// [uri]가 로그인 주소로 넘어간 주소인지. 같은 호스트이고 경로가 로그인 주소의 경로와 같거나 그 아래다(쿼리는
  /// 보지 않는다). 경로는 마디 단위로 견줘 `/login`은 `/login/x`를 포함하지만 `/loginx`는 포함하지 않는다.
  bool isLoginUrl(Uri uri) {
    if (uri.host.toLowerCase() != loginUrl.host.toLowerCase()) return false;
    final loginPath = loginUrl.path;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == loginPath) return true;
    final prefix = loginPath.endsWith('/') ? loginPath : '$loginPath/';
    return path.startsWith(prefix);
  }

  @override
  bool operator ==(Object other) =>
      other is LmsRequestParams &&
      other.version == version &&
      other.homeUrl == homeUrl &&
      other.loginUrl == loginUrl &&
      listEquals(other.cookieDomains, cookieDomains) &&
      other.markers == markers;

  @override
  int get hashCode => Object.hash(
    version,
    homeUrl,
    loginUrl,
    Object.hashAll(cookieDomains),
    markers,
  );
}

/// 응답 판별 표식(docs/lms.md '응답 판별'). 실제 표식은 Remote Config에만 있다.
@immutable
final class LmsMarkers {
  const LmsMarkers({
    this.loginPage = const [],
    this.maintenance = const [],
    this.authError = const [],
  });

  /// 본문에 하나라도 있으면 로그인 페이지다(재로그인 필요).
  final List<String> loginPage;

  /// 본문에 하나라도 있으면 점검 페이지다(서버 오류·점검).
  final List<String> maintenance;

  /// JSON 응답에서 하나라도 맞으면 인증 오류다(복원 필요).
  final List<LmsJsonMarker> authError;

  @override
  bool operator ==(Object other) =>
      other is LmsMarkers &&
      listEquals(other.loginPage, loginPage) &&
      listEquals(other.maintenance, maintenance) &&
      listEquals(other.authError, authError);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(loginPage),
    Object.hashAll(maintenance),
    Object.hashAll(authError),
  );
}

/// JSON의 한 자리([path]) 값이 [anyOf] 가운데 하나인지 보는 표식.
@immutable
final class LmsJsonMarker {
  const LmsJsonMarker({required this.path, required this.anyOf});

  /// 키의 차례. 목록을 지날 때는 0부터 세는 번호다.
  final List<String> path;

  /// 맞는 값. 문자열로 견준다(정수는 십진 문자열).
  final List<String> anyOf;

  /// 해석한 JSON [json]의 [path] 자리 값이 [anyOf] 가운데 하나인지. 그 자리가 없거나 객체·목록이면 아니다.
  bool matches(Object? json) {
    var node = json;
    for (final key in path) {
      switch (node) {
        case Map():
          node = node[key];
        case List():
          final index = int.tryParse(key);
          if (index == null || index < 0 || index >= node.length) return false;
          node = node[index];
        default:
          return false;
      }
    }
    final text = switch (node) {
      String() => node,
      int() => '$node',
      double() when node.isFinite && node == node.truncateToDouble() =>
        '${node.toInt()}',
      double() || bool() => '$node',
      _ => null,
    };
    return text != null && anyOf.contains(text);
  }

  @override
  bool operator ==(Object other) =>
      other is LmsJsonMarker &&
      listEquals(other.path, path) &&
      listEquals(other.anyOf, anyOf);

  @override
  int get hashCode => Object.hash(Object.hashAll(path), Object.hashAll(anyOf));
}

/// 해석을 멈추는 이유. 이 파일 안에서만 던지고 [parseLmsRequestParams]가 잡는다.
final class _Invalid implements Exception {
  const _Invalid(this.problem);

  final LmsConfigProblem problem;
}

const _field = _Invalid(LmsConfigProblem.field);
const _domain = _Invalid(LmsConfigProblem.domain);

LmsRequestParams _readParams(Map<String, Object?> json, String domain) {
  final version = json['version'];
  if (version is! int || !lmsRequestParamsVersions.contains(version)) {
    throw const _Invalid(LmsConfigProblem.version);
  }
  final markers = json['markers'];
  if (markers is! Map<String, Object?>) throw _field;
  return LmsRequestParams(
    version: version,
    homeUrl: _schoolUrl(json['homeUrl'], domain),
    loginUrl: _schoolUrl(json['loginUrl'], domain),
    cookieDomains: _cookieDomains(json['cookieDomains'], domain),
    markers: LmsMarkers(
      loginPage: _texts(markers['loginPage']),
      maintenance: _texts(markers['maintenance']),
      authError: [
        for (final marker in _list(markers['authError'])) _jsonMarker(marker),
      ],
    ),
  );
}

Uri _schoolUrl(Object? value, String domain) {
  if (value is! String) throw _field;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) throw _field;
  if (!isSchoolUrl(uri, domain: domain)) throw _domain;
  return uri;
}

/// 쿠키 도메인 목록. 소문자로 바꾸고 앞의 점(`.example.invalid`)은 뗀다.
List<String> _cookieDomains(Object? value, String domain) {
  final domains = [
    for (final raw in _texts(value))
      (raw.startsWith('.') ? raw.substring(1) : raw).toLowerCase(),
  ];
  if (domains.isEmpty) throw _field;
  if (!domains.every((host) => isSchoolHost(host, domain: domain))) {
    throw _domain;
  }
  return domains;
}

List<Object?> _list(Object? value) => value is List ? value : throw _field;

/// 비어 있지 않은 문자열의 목록.
List<String> _texts(Object? value) {
  final texts = <String>[];
  for (final item in _list(value)) {
    if (item is! String || item.isEmpty) throw _field;
    texts.add(item);
  }
  return texts;
}

LmsJsonMarker _jsonMarker(Object? value) {
  if (value is! Map<String, Object?>) throw _field;
  final path = value['path'];
  if (path is! String) throw _field;
  final keys = path.split('.');
  if (keys.any((key) => key.isEmpty)) throw _field;
  final anyOf = [
    for (final item in _list(value['anyOf']))
      switch (item) {
        String() when item.isNotEmpty => item,
        int() => '$item',
        _ => throw _field,
      },
  ];
  if (anyOf.isEmpty) throw _field;
  return LmsJsonMarker(path: keys, anyOf: anyOf);
}
