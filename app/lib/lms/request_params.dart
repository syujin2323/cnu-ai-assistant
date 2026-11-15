// LMS 요청 상수(Remote Config `lms_request_params`)의 설정 파서. docs/lms.md '원격 스위치'·'응답 판별'·'로그인',
// docs/architecture.md '환경 변수'.
//
// 요청 상수의 값은 Remote Config 콘솔에만 있고 레포에는 두지 않는다. 이 파일은 키 이름과 형식만 정한다. 값이
// 비어 있거나, JSON 객체가 아니거나, `version`을 모르거나, 키가 빠졌거나 형이 다르거나, 주소가 학교 도메인
// (`lms_config.dart`의 `lmsSchoolDomain`) 밖이거나 https가 아니면 '설정 없음'이다. 모르는 키는 무시하므로 키를 더할
// 때는 `version`을 올리지 않는다(앱이 새로 꼭 읽는 키를 더하면 그 앱 빌드가 나가기 전에 콘솔 값에 먼저 넣는다). 키를
// 빼거나 뜻을 바꿀 때만 `version`을 올리고, 새 `version`은 그것을 읽는 앱 빌드가 테스터에게 나간 뒤에만 콘솔에 넣는다.
//
// version 1의 키(값은 지어낸 예):
//
//   {
//     "version": 1,
//     "homeUrl": "https://example.invalid/",              세션 복원 1단계에서 여는 홈 주소
//     "loginUrl": "https://example.invalid/login",        로그인 주소. 응답의 최종 주소가 이 주소(같은 호스트의
//                                                         같은 경로나 그 아래 경로)면 재로그인 필요
//     "cookieDomains": ["example.invalid"],               쿠키 금고에 두는 쿠키가 쓰일 호스트(하나 이상)
//     "markers": {
//       "loginPage": ["..."],                             본문에 있으면 로그인 페이지(재로그인 필요)
//       "maintenance": ["..."],                           본문에 있으면 점검 페이지(서버 오류·점검)
//       "authError": [{"path": "a.b", "anyOf": ["..."]}]  JSON의 그 자리 값이 이 가운데 하나면 인증 오류(복원 필요)
//     },
//     "userAgent": "...",                                 네이티브 요청의 User-Agent(LMS 공식 앱의 값은 쓰지 않음)
//     "ciphers": {"이름": 암호},                          본문 암호화에 쓰는 이름 붙은 암호(쓸 때만)
//     "login": {
//       "steps": [요청, ...],                             로그인 전 준비 요청(차례대로. 뽑은 값은 뒤 요청의 변수)
//       "request": 요청,                                  로그인 요청. 변수 studentId·password를 쓸 수 있다
//       "results": [{"when": [조건, ...], "result": "success"}],  처음 맞는 규칙의 결과. 없으면 해석 실패
//       "handoff": 요청                                   성공 뒤 요청(세션 넘기기. 쓸 때만)
//     },
//     "parse": {"kindCodes": {...}, "timetable": {...}},  응답 해석 설정(`parsers/parse_config.dart`). sync가 있으면 꼭
//     "sync": {                                           동기화 요청(없으면 동기화하지 않음)
//       "vars": {"이름": "값"},                           학기마다 콘솔에서 바꾸는 값(학년도·학기 코드 등). 요청의 변수
//       "semester": "{이름}-{이름}",                      학기 값(과목의 학기, 원본 키의 앞부분) 틀. vars만 쓰고 `:` 없음
//       "steps": [요청, ...],                             조회 전 준비 요청(암호 키 뽑기 등. 쓸 때만)
//       "courses": 요청,                                  과목 목록 조회
//       "todos": 요청                                     할 일 목록 조회
//     },
//     "timetable": {                                      시간표 불러오기(통합정보시스템. 없으면 불러오지 않음, sync 필요)
//       "courseInfo": 요청,                               과목마다 LMS에 묻는 요청. 변수 courseId·classNo를 더 쓴다
//       "steps": [요청, ...],                             그 뒤 과목마다 차례로 보내는 요청
//       "slotText": "이름"                                과목의 시간표 글자를 담는 변수(steps가 뽑음)
//     }
//   }
//
// 요청: {"method": "GET"|"POST", "url": 주소, "headers": {이름: 틀}, "body": 본문, "extract": {변수: 뽑기},
//        "generate": {변수: "hex32"}}
//   - url은 학교 도메인의 https 주소이거나 `{변수}` 하나다(상대 주소면 앞 요청의 최종 주소 기준).
//   - body는 {"form": {필드: 틀}}, {"json": JSON 틀}, {"encrypted": {"cipher": 이름, "field": 필드, "json": JSON 틀}} 가운데
//     하나다. JSON 틀의 값 자리에는 그 값만 따로 암호화하는 {"$encrypt": {"cipher": 이름, "text": 틀}}을 둘 수 있다.
//     헤더 Cookie·User-Agent·Host·Content-Length는 넣을 수 없다(쿠키는 금고, User-Agent는 위 값).
//   - 뽑기는 {"pattern": 정규식(첫 묶음)} 또는 {"path": "a.b"}이고 "optional": true면 못 찾아도 빈 값이다.
//   - generate는 보내기 전에 새로 만드는 값이다(hex32: 무작위 16바이트의 16진수 32자). 이 요청과 뒤 요청의 변수다.
// 암호: {"key": {"var": 변수, "removeChars": "-", "takeBytes": 16}, "iv": "zero"|"key"} (AES-CBC, PKCS#7, base64)
// 조건: {"path": "a.b", "anyOf": [...]}, {"path": "a.b", "present": true}, {"contains": "본문 글자"}. 한 규칙의 조건은
//   모두 맞아야 한다. 결과는 success, wrongCredentials, parseFailure 가운데 하나이고 success 규칙이 하나 이상 있어야 한다.
// 각 요청은 앞 요청에서 뽑거나 만든 변수와 그 요청이 만드는 변수만 쓸 수 있고(로그인 요청만 studentId·password도, 동기화
// 요청은 sync.vars도, 시간표 요청은 sync.vars·sync.steps가 뽑은 값과 courseId·classNo도), 이 파일이 해석할 때 확인한다.
// 암호의 키 변수도 그 요청 앞에 뽑았거나 그 요청이 만드는 값이어야 한다. 뽑거나 만드는 변수 이름은 학번·비밀번호나
// sync.vars(시간표는 courseId·classNo도)의 이름과 겹칠 수 없다.
//
// 표식 목록은 비어 있어도 된다. 표식은 대소문자를 가리는 부분 문자열이고, `path`는 점으로 나눈 키(목록이면 0부터
// 세는 번호)이며, `anyOf`의 값은 문자열이나 정수다.

import 'dart:convert';

import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;

/// 이 앱이 읽는 `version`.
const lmsRequestParamsVersions = {1};

/// 로그인 요청만 쓸 수 있는 변수(학번·비밀번호).
const lmsCredentialVariables = {'studentId', 'password'};

/// 시간표 불러오기가 과목마다 주는 변수(과목 ID·분반).
const lmsTimetableCourseVariables = {'courseId', 'classNo'};

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
    required this.userAgent,
    this.ciphers = const {},
    required this.login,
    this.parse,
    this.sync,
    this.timetable,
  });

  final int version;

  /// 세션 복원 1단계에서 여는 홈 주소.
  final Uri homeUrl;

  /// 로그인 주소. 응답의 최종 주소가 이 주소로 넘어갔으면 재로그인 필요다([isLoginUrl]).
  final Uri loginUrl;

  /// 쿠키 금고에 두는 쿠키가 쓰일 호스트. 소문자이고 앞의 점은 뗐다. 이 가운데 하나에라도 보내지는 쿠키만 둔다.
  final List<String> cookieDomains;

  /// 응답 판별 표식.
  final LmsMarkers markers;

  /// 네이티브 요청의 User-Agent. 로그인할 때 쿠키와 함께 금고에 둔다.
  final String userAgent;

  /// 이름 붙은 암호.
  final Map<String, LmsCipherSpec> ciphers;

  /// 로그인 요청.
  final LmsLoginSpec login;

  /// 응답 해석 설정. [sync]가 있으면 늘 있다.
  final LmsParseConfig? parse;

  /// 동기화 요청. 없으면 동기화하지 않는다('설정 없음'으로 건너뜀).
  final LmsSyncSpec? sync;

  /// 시간표 불러오기 요청. 없으면 불러오지 않는다. 있으면 [sync]와 [parse]의 시간표 해석 설정도 늘 있다.
  final LmsTimetableSpec? timetable;

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
      other.markers == markers &&
      other.userAgent == userAgent &&
      mapEquals(other.ciphers, ciphers) &&
      other.login == login &&
      other.parse == parse &&
      other.sync == sync &&
      other.timetable == timetable;

  @override
  int get hashCode => Object.hash(
    version,
    homeUrl,
    loginUrl,
    Object.hashAll(cookieDomains),
    markers,
    userAgent,
    Object.hashAllUnordered(
      ciphers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    login,
    parse,
    sync,
    timetable,
  );
}

/// 시간표 불러오기 요청(docs/lms.md '시간표 (통합정보시스템)'). 과목마다 [courseInfo]를 LMS에 묻고 [steps]를 차례로 보낸
/// 뒤 [slotText] 변수의 글자를 시간표로 읽는다. 실제 주소와 값은 Remote Config에만 있다.
@immutable
final class LmsTimetableSpec {
  const LmsTimetableSpec({
    required this.courseInfo,
    required this.steps,
    required this.slotText,
  });

  /// 과목마다 LMS에 묻는 요청. 세션이 끊겼는지 이 응답으로 가린다.
  final LmsRequestSpec courseInfo;

  /// 그 뒤 과목마다 차례로 보내는 요청(통합정보시스템).
  final List<LmsRequestSpec> steps;

  /// 과목의 시간표 글자를 담는 변수 이름.
  final String slotText;

  @override
  bool operator ==(Object other) =>
      other is LmsTimetableSpec &&
      other.courseInfo == courseInfo &&
      listEquals(other.steps, steps) &&
      other.slotText == slotText;

  @override
  int get hashCode => Object.hash(courseInfo, Object.hashAll(steps), slotText);
}

/// 동기화 요청(docs/lms.md '동기화'). 실제 주소와 값은 Remote Config에만 있다.
@immutable
final class LmsSyncSpec {
  const LmsSyncSpec({
    this.vars = const {},
    required this.semester,
    this.steps = const [],
    required this.courses,
    required this.todos,
  });

  /// 학기마다 콘솔에서 바꾸는 값(학년도·학기 코드 등). 요청 틀의 변수로 쓴다.
  final Map<String, String> vars;

  /// 학기 값(`courses.semester`, 원본 키의 앞부분). `semester` 틀을 [vars]로 채운 것이다.
  final String semester;

  /// 조회 전 준비 요청(차례대로. 뽑은 값은 뒤 요청의 변수).
  final List<LmsRequestSpec> steps;

  /// 과목 목록 조회.
  final LmsRequestSpec courses;

  /// 할 일 목록 조회.
  final LmsRequestSpec todos;

  @override
  bool operator ==(Object other) =>
      other is LmsSyncSpec &&
      mapEquals(other.vars, vars) &&
      other.semester == semester &&
      listEquals(other.steps, steps) &&
      other.courses == courses &&
      other.todos == todos;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      vars.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    semester,
    Object.hashAll(steps),
    courses,
    todos,
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

/// 응답 하나에 대한 조건. [json]은 본문을 JSON으로 푼 값(JSON이 아니면 null), [body]는 본문 글자다.
sealed class LmsMatcher {
  const LmsMatcher();

  bool matches(Object? json, [String body = '']);
}

/// JSON의 한 자리([path]) 값이 [anyOf] 가운데 하나인지 보는 조건.
final class LmsJsonMarker extends LmsMatcher {
  const LmsJsonMarker({required this.path, required this.anyOf});

  /// 키의 차례. 목록을 지날 때는 0부터 세는 번호다.
  final List<String> path;

  /// 맞는 값. 글자로 견준다([jsonScalarText]. 정수는 십진 문자열).
  final List<String> anyOf;

  /// 해석한 JSON [json]의 [path] 자리 값이 [anyOf] 가운데 하나인지. 그 자리가 없거나 객체·목록이면 아니다.
  @override
  bool matches(Object? json, [String body = '']) {
    final text = jsonScalarText(jsonAt(json, path));
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

/// JSON의 한 자리([path])에 비어 있지 않은 값(문자열·수·참거짓)이 있는지 보는 조건.
final class LmsJsonPresent extends LmsMatcher {
  const LmsJsonPresent(this.path);

  final List<String> path;

  @override
  bool matches(Object? json, [String body = '']) {
    final text = jsonScalarText(jsonAt(json, path));
    return text != null && text.isNotEmpty;
  }

  @override
  bool operator ==(Object other) =>
      other is LmsJsonPresent && listEquals(other.path, path);

  @override
  int get hashCode => Object.hashAll(path);
}

/// 본문에 [text]가 들어 있는지 보는 조건(대소문자를 가린다).
final class LmsBodyContains extends LmsMatcher {
  const LmsBodyContains(this.text);

  final String text;

  @override
  bool matches(Object? json, [String body = '']) => body.contains(text);

  @override
  bool operator ==(Object other) =>
      other is LmsBodyContains && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// 로그인 응답의 결과(docs/lms.md '로그인'의 결과 종류).
enum LmsLoginResult { success, wrongCredentials, parseFailure }

/// 로그인 결과 규칙. [when]이 모두 맞으면 [result]다.
@immutable
final class LmsLoginRule {
  const LmsLoginRule({required this.when, required this.result});

  final List<LmsMatcher> when;

  final LmsLoginResult result;

  bool matches(Object? json, String body) =>
      when.every((matcher) => matcher.matches(json, body));

  @override
  bool operator ==(Object other) =>
      other is LmsLoginRule &&
      listEquals(other.when, when) &&
      other.result == result;

  @override
  int get hashCode => Object.hash(Object.hashAll(when), result);
}

/// 로그인 요청들.
@immutable
final class LmsLoginSpec {
  const LmsLoginSpec({
    this.steps = const [],
    required this.request,
    required this.results,
    this.handoff,
  });

  /// 로그인 전 준비 요청(차례대로).
  final List<LmsRequestSpec> steps;

  /// 로그인 요청.
  final LmsRequestSpec request;

  /// 결과 규칙(차례대로, 처음 맞는 규칙).
  final List<LmsLoginRule> results;

  /// 성공 뒤 요청(세션 넘기기).
  final LmsRequestSpec? handoff;

  /// 로그인 응답의 결과. 맞는 규칙이 없으면 해석 실패다.
  LmsLoginResult resultOf(Object? json, String body) =>
      results.where((rule) => rule.matches(json, body)).firstOrNull?.result ??
      LmsLoginResult.parseFailure;

  @override
  bool operator ==(Object other) =>
      other is LmsLoginSpec &&
      listEquals(other.steps, steps) &&
      other.request == request &&
      listEquals(other.results, results) &&
      other.handoff == handoff;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(steps),
    request,
    Object.hashAll(results),
    handoff,
  );
}

/// 해석을 멈추는 이유. 이 파일 안에서만 던지고 [parseLmsRequestParams]가 잡는다.
final class _Invalid implements Exception {
  const _Invalid(this.problem);

  final LmsConfigProblem problem;
}

const _field = _Invalid(LmsConfigProblem.field);
const _domain = _Invalid(LmsConfigProblem.domain);

/// 요청 상수에 넣을 수 없는 헤더(소문자). 쿠키는 금고에서, User-Agent는 [LmsRequestParams.userAgent]에서 붙인다.
const _reservedHeaders = {'cookie', 'user-agent', 'host', 'content-length'};

final _headerName = RegExp(r'^[A-Za-z0-9-]+$');

/// 헤더 값으로 쓸 수 없는 글자(줄바꿈 등 제어 문자).
final _controlChar = RegExp(r'[\x00-\x1F\x7F]');

LmsRequestParams _readParams(Map<String, Object?> json, String domain) {
  final version = json['version'];
  if (version is! int || !lmsRequestParamsVersions.contains(version)) {
    throw const _Invalid(LmsConfigProblem.version);
  }
  final markers = json['markers'];
  if (markers is! Map<String, Object?>) throw _field;
  final userAgent = json['userAgent'];
  if (userAgent is! String ||
      userAgent.trim().isEmpty ||
      _controlChar.hasMatch(userAgent)) {
    throw _field;
  }
  final ciphers = _ciphers(json['ciphers']);
  final sync = json['sync'] == null
      ? null
      : _sync(json['sync'], domain, ciphers);
  final parse = json['parse'] == null
      ? null
      : LmsParseConfig.fromJson(json['parse']) ?? (throw _field);
  if (sync != null && parse == null) throw _field;
  final timetable = json['timetable'] == null
      ? null
      : _timetable(json['timetable'], domain, ciphers, sync ?? (throw _field));
  if (timetable != null && parse?.timetableSlot == null) throw _field;
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
    userAgent: userAgent,
    ciphers: ciphers,
    login: _login(json['login'], domain, ciphers),
    parse: parse,
    sync: sync,
    timetable: timetable,
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

Map<String, Object?> _object(Object? value) =>
    value is Map<String, Object?> ? value : throw _field;

/// 비어 있지 않은 문자열의 목록.
List<String> _texts(Object? value) {
  final texts = <String>[];
  for (final item in _list(value)) {
    if (item is! String || item.isEmpty) throw _field;
    texts.add(item);
  }
  return texts;
}

String _name(Object? value) =>
    value is String && lmsVariableName.hasMatch(value) ? value : throw _field;

List<String> _path(Object? value) {
  if (value is! String) throw _field;
  final keys = value.split('.');
  if (keys.any((key) => key.isEmpty)) throw _field;
  return keys;
}

LmsJsonMarker _jsonMarker(Object? value) {
  final object = _object(value);
  final anyOf = [
    for (final item in _list(object['anyOf']))
      switch (item) {
        String() when item.isNotEmpty => item,
        int() => '$item',
        _ => throw _field,
      },
  ];
  if (anyOf.isEmpty) throw _field;
  return LmsJsonMarker(path: _path(object['path']), anyOf: anyOf);
}

LmsMatcher _matcher(Object? value) {
  final object = _object(value);
  if (object.containsKey('contains')) {
    final text = object['contains'];
    if (object.length != 1 || text is! String || text.isEmpty) throw _field;
    return LmsBodyContains(text);
  }
  if (object.containsKey('present')) {
    if (object.length != 2 || object['present'] != true) throw _field;
    return LmsJsonPresent(_path(object['path']));
  }
  if (object.length != 2) throw _field;
  return _jsonMarker(object);
}

Map<String, LmsCipherSpec> _ciphers(Object? value) {
  if (value == null) return const {};
  return {
    for (final MapEntry(:key, :value) in _object(value).entries)
      _name(key): _cipher(value),
  };
}

LmsCipherSpec _cipher(Object? value) {
  final object = _object(value);
  final key = _object(object['key']);
  final removeChars = key['removeChars'] ?? '';
  final takeBytes = key['takeBytes'];
  if (removeChars is! String) throw _field;
  if (takeBytes != null &&
      (takeBytes is! int || !const {16, 24, 32}.contains(takeBytes))) {
    throw _field;
  }
  return LmsCipherSpec(
    keyVar: _name(key['var']),
    removeChars: removeChars,
    takeBytes: takeBytes as int?,
    iv: switch (object['iv']) {
      'zero' => LmsIv.zero,
      'key' => LmsIv.key,
      _ => throw _field,
    },
  );
}

LmsRequestSpec _request(
  Object? value,
  String domain,
  Map<String, LmsCipherSpec> ciphers,
) {
  final object = _object(value);
  final rawUrl = object['url'];
  if (rawUrl is! String) throw _field;
  final url = LmsTemplate(rawUrl);
  if (url.names.isEmpty) {
    _schoolUrl(url.source, domain);
  } else if (!url.isSingleVariable) {
    throw _field;
  }
  return LmsRequestSpec(
    method: switch (object['method']) {
      'GET' => LmsMethod.get,
      'POST' => LmsMethod.post,
      _ => throw _field,
    },
    url: url,
    headers: _headers(object['headers']),
    body: _body(object['body'], ciphers),
    extract: _extracts(object['extract']),
    generate: _generators(object['generate']),
  );
}

Map<String, LmsGenerator> _generators(Object? value) {
  if (value == null) return const {};
  return {
    for (final MapEntry(:key, :value) in _object(value).entries)
      if (lmsCredentialVariables.contains(_name(key)))
        key: throw _field
      else
        key: switch (value) {
          'hex32' => LmsGenerator.hex32,
          _ => throw _field,
        },
  };
}

/// JSON 틀의 값 암호화 자리가 꼴에 맞고 있는 암호를 쓰는지 본다. `$encrypt` 키가 있는 객체는 그 키 하나만 둔다.
void _checkJsonTemplate(Object? template, Map<String, LmsCipherSpec> ciphers) {
  switch (template) {
    case Map() when template.containsKey(lmsEncryptKey):
      final spec = template[lmsEncryptKey];
      if (template.length != 1 ||
          spec is! Map ||
          spec.length != 2 ||
          spec['text'] is! String ||
          !ciphers.containsKey(spec['cipher'])) {
        throw _field;
      }
    case Map():
      for (final value in template.values) {
        _checkJsonTemplate(value, ciphers);
      }
    case List():
      for (final value in template) {
        _checkJsonTemplate(value, ciphers);
      }
  }
}

/// 요청 [spec]이 쓰는 변수가 [known]·[extra]·그 요청이 만드는 값 안에 있고, 암호 키 변수가 [known]이나 그 요청이
/// 만드는 값인지 본다. 뽑거나 만드는 이름은 [reserved]와 겹칠 수 없다. 통과하면 [known]에 뽑고 만드는 이름을 더한다.
void _checkSpec(
  LmsRequestSpec spec,
  Set<String> known,
  Map<String, LmsCipherSpec> ciphers, {
  Set<String> extra = const {},
  Set<String> reserved = const {},
}) {
  final generated = spec.generate.keys.toSet();
  final keys = {for (final cipher in spec.ciphers) ciphers[cipher]!.keyVar};
  final produced = {...spec.extract.keys, ...generated};
  if (!{...known, ...extra, ...generated}.containsAll(spec.names) ||
      !{...known, ...generated}.containsAll(keys) ||
      produced.any(reserved.contains) ||
      spec.extract.keys.any(generated.contains)) {
    throw _field;
  }
  known.addAll(produced);
}

Map<String, LmsTemplate> _headers(Object? value) {
  if (value == null) return const {};
  return {
    for (final MapEntry(:key, :value) in _object(value).entries)
      if (!_headerName.hasMatch(key) ||
          _reservedHeaders.contains(key.toLowerCase()) ||
          value is! String ||
          _controlChar.hasMatch(value))
        key: throw _field
      else
        key: LmsTemplate(value),
  };
}

LmsBodySpec? _body(Object? value, Map<String, LmsCipherSpec> ciphers) {
  if (value == null) return null;
  final object = _object(value);
  if (object.length != 1) throw _field;
  final MapEntry(:key, value: content) = object.entries.single;
  switch (key) {
    case 'form':
      return LmsFormBody({
        for (final MapEntry(:key, :value) in _object(content).entries)
          if (key.isEmpty || value is! String)
            key: throw _field
          else
            key: LmsTemplate(value),
      });
    case 'json':
      _checkJsonTemplate(content, ciphers);
      return LmsJsonBody(content);
    case 'encrypted':
      final encrypted = _object(content);
      final cipher = encrypted['cipher'];
      final field = encrypted['field'];
      if (cipher is! String || !ciphers.containsKey(cipher)) throw _field;
      if (field is! String || field.isEmpty) throw _field;
      if (!encrypted.containsKey('json')) throw _field;
      _checkJsonTemplate(encrypted['json'], ciphers);
      return LmsEncryptedBody(
        cipher: cipher,
        field: field,
        template: encrypted['json'],
      );
    default:
      throw _field;
  }
}

Map<String, LmsExtract> _extracts(Object? value) {
  if (value == null) return const {};
  final extracts = <String, LmsExtract>{};
  for (final MapEntry(:key, :value) in _object(value).entries) {
    if (lmsCredentialVariables.contains(_name(key))) throw _field;
    final object = _object(value);
    final optional = object['optional'] ?? false;
    if (optional is! bool) throw _field;
    if (object.containsKey('pattern') == object.containsKey('path')) {
      throw _field;
    }
    if (object.containsKey('pattern')) {
      final source = object['pattern'];
      if (source is! String || source.isEmpty) throw _field;
      final RegExp pattern;
      try {
        pattern = RegExp(source);
      } on FormatException {
        throw _field;
      }
      extracts[key] = LmsPatternExtract(pattern, optional: optional);
    } else {
      extracts[key] = LmsJsonExtract(_path(object['path']), optional: optional);
    }
  }
  return extracts;
}

/// 동기화 요청들. 요청마다 쓰는 변수가 `vars`이거나 그 앞에서 뽑은 변수인지, 학기 틀이 `vars`만 쓰는지 확인한다.
LmsSyncSpec _sync(
  Object? value,
  String domain,
  Map<String, LmsCipherSpec> ciphers,
) {
  final object = _object(value);
  final vars = <String, String>{};
  final rawVars = object['vars'];
  if (rawVars != null) {
    for (final MapEntry(:key, :value) in _object(rawVars).entries) {
      if (value is! String ||
          _controlChar.hasMatch(value) ||
          lmsCredentialVariables.contains(_name(key))) {
        throw _field;
      }
      vars[key] = value;
    }
  }
  final rawSemester = object['semester'];
  if (rawSemester is! String) throw _field;
  final semesterTemplate = LmsTemplate(rawSemester);
  if (!vars.keys.toSet().containsAll(semesterTemplate.names)) throw _field;
  final semester = semesterTemplate.render(vars);
  if (semester.trim().isEmpty || semester.contains(':')) throw _field;

  final steps = [
    for (final step in _list(object['steps'] ?? const <Object?>[]))
      _request(step, domain, ciphers),
  ];
  final courses = _request(object['courses'], domain, ciphers);
  final todos = _request(object['todos'], domain, ciphers);

  final known = vars.keys.toSet();
  final reserved = vars.keys.toSet();
  for (final spec in [...steps, courses, todos]) {
    _checkSpec(spec, known, ciphers, reserved: reserved);
  }
  return LmsSyncSpec(
    vars: vars,
    semester: semester,
    steps: steps,
    courses: courses,
    todos: todos,
  );
}

/// 시간표 불러오기 요청들. 과목마다 `courseId`·`classNo`를 주고 [sync]의 `vars`와 준비 요청이 뽑은 값을 쓴다. 요청마다
/// 쓰는 변수가 그 앞에서 뽑거나 만든 변수인지, 시간표 글자 변수를 어느 요청이 뽑는지 확인한다.
LmsTimetableSpec _timetable(
  Object? value,
  String domain,
  Map<String, LmsCipherSpec> ciphers,
  LmsSyncSpec sync,
) {
  final object = _object(value);
  final courseInfo = _request(object['courseInfo'], domain, ciphers);
  final steps = [
    for (final step in _list(object['steps'])) _request(step, domain, ciphers),
  ];
  final slotText = _name(object['slotText']);
  final known = {
    ...sync.vars.keys,
    for (final step in sync.steps) ...step.extract.keys,
    for (final step in sync.steps) ...step.generate.keys,
    ...lmsTimetableCourseVariables,
  };
  final reserved = {...sync.vars.keys, ...lmsTimetableCourseVariables};
  final before = known.toSet();
  for (final spec in [courseInfo, ...steps]) {
    _checkSpec(spec, known, ciphers, reserved: reserved);
  }
  if (!known.difference(before).contains(slotText)) throw _field;
  return LmsTimetableSpec(
    courseInfo: courseInfo,
    steps: steps,
    slotText: slotText,
  );
}

/// 로그인 요청들. 요청마다 쓰는 변수가 그 앞에서 뽑은 변수(로그인 요청은 학번·비밀번호도)인지 확인한다.
LmsLoginSpec _login(
  Object? value,
  String domain,
  Map<String, LmsCipherSpec> ciphers,
) {
  final object = _object(value);
  final steps = [
    for (final step in _list(object['steps'] ?? const <Object?>[]))
      _request(step, domain, ciphers),
  ];
  final request = _request(object['request'], domain, ciphers);
  final handoff = object['handoff'] == null
      ? null
      : _request(object['handoff'], domain, ciphers);
  final results = [
    for (final rule in _list(object['results'])) _loginRule(_object(rule)),
  ];
  if (!results.any((rule) => rule.result == LmsLoginResult.success)) {
    throw _field;
  }

  final known = <String>{};
  for (final step in steps) {
    _checkSpec(step, known, ciphers);
  }
  _checkSpec(request, known, ciphers, extra: lmsCredentialVariables);
  if (handoff != null) _checkSpec(handoff, known, ciphers);
  return LmsLoginSpec(
    steps: steps,
    request: request,
    results: results,
    handoff: handoff,
  );
}

LmsLoginRule _loginRule(Map<String, Object?> object) {
  final when = [for (final m in _list(object['when'])) _matcher(m)];
  if (when.isEmpty) throw _field;
  return LmsLoginRule(
    when: when,
    result: switch (object['result']) {
      'success' => LmsLoginResult.success,
      'wrongCredentials' => LmsLoginResult.wrongCredentials,
      'parseFailure' => LmsLoginResult.parseFailure,
      _ => throw _field,
    },
  );
}
