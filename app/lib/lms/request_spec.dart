// LMS 요청 틀. docs/lms.md '로그인'·'원격 스위치'.
//
// LMS·통합정보시스템에 보내는 요청의 주소·헤더·본문·암호화와 응답에서 값을 뽑는 규칙은 요청 상수
// (`lms_request_params`)에만 있고 코드에는 없다. 이 파일은 그 틀의 꼴(요청 하나, 문자열 틀, 값 뽑기)과 틀을 변수로
// 채우는 규칙만 둔다. 해석은 `request_params.dart`가, 보내기는 `request_runner.dart`가 한다.
//
// 문자열 틀의 `{이름}`은 변수 값으로 바뀐다. 이름은 영문자로 시작하는 영문·숫자·`_`이고, 이 꼴이 아닌 중괄호는 그대로
// 둔다. 변수 값은 앞 요청에서 뽑은 값, 요청마다 새로 만드는 값(`generate`), 학번·비밀번호(로그인 요청만)이다. JSON 틀의
// 값 자리에는 그 값만 따로 암호화하는 `{"$encrypt": {"cipher": 암호 이름, "text": 문자열 틀}}`을 둘 수 있다. 변수
// 값은 로그·폰 DB에 남기지 않는다.

import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;

/// 요청 방법.
enum LmsMethod { get, post }

/// 변수 이름 꼴.
final RegExp lmsVariableName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

/// `{이름}` 자리가 있는 문자열 틀.
@immutable
final class LmsTemplate {
  LmsTemplate(this.source)
    : names = {for (final m in _placeholder.allMatches(source)) m[1]!};

  final String source;

  /// 틀이 쓰는 변수 이름.
  final Set<String> names;

  /// 틀 전체가 변수 하나(`{이름}`)인지.
  bool get isSingleVariable =>
      names.length == 1 && source == '{${names.first}}';

  /// [vars]로 채운다. 틀이 쓰는 변수가 [vars]에 없으면 [LmsMissingVariable]을 던진다(요청 상수를 해석할 때 미리
  /// 막으므로 프로그래밍 오류다).
  String render(Map<String, String> vars) =>
      source.replaceAllMapped(_placeholder, (m) {
        final name = m[1]!;
        return vars[name] ?? (throw LmsMissingVariable(name));
      });

  @override
  bool operator ==(Object other) =>
      other is LmsTemplate && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

/// JSON 틀에서 값 하나를 따로 암호화하는 자리의 키. `{"$encrypt": {"cipher": 암호 이름, "text": 문자열 틀}}`은 틀을
/// 채워 그 암호로 암호화한 base64 글자가 된다. 꼴은 `request_params.dart`가 해석할 때 확인한다.
const lmsEncryptKey = r'$encrypt';

/// JSON 틀의 값 [node]가 값 암호화 자리면 그 암호 이름과 틀이다. 아니면 null이다.
({String cipher, LmsTemplate text})? lmsEncryptNode(Object? node) {
  if (node is! Map || node.length != 1) return null;
  final spec = node[lmsEncryptKey];
  if (spec is! Map) return null;
  final cipher = spec['cipher'];
  final text = spec['text'];
  if (cipher is! String || text is! String) return null;
  return (cipher: cipher, text: LmsTemplate(text));
}

/// 값 암호화 자리를 채우는 함수. 암호 [cipher]로 [plain]을 암호화한 글자이고, 키를 만들지 못하면 null이다.
typedef LmsValueEncrypter = String? Function(String cipher, String plain);

/// 값 암호화 자리의 암호로 암호화하지 못했다(키 변수가 없거나 길이가 맞지 않음).
final class LmsCipherUnavailable implements Exception {
  const LmsCipherUnavailable(this.cipher);

  final String cipher;
}

/// 틀이 쓰는 변수가 없다.
final class LmsMissingVariable implements Exception {
  const LmsMissingVariable(this.name);

  final String name;
}

/// JSON 틀([LmsJsonBody]·[LmsEncryptedBody])이 쓰는 변수 이름. 문자열 값과 값 암호화 자리의 틀만 틀이다.
Set<String> jsonTemplateNames(Object? template) {
  if (lmsEncryptNode(template) case final node?) return node.text.names;
  return switch (template) {
    String() => LmsTemplate(template).names,
    Map() => {for (final value in template.values) ...jsonTemplateNames(value)},
    List() => {for (final value in template) ...jsonTemplateNames(value)},
    _ => const {},
  };
}

/// JSON 틀의 값 암호화 자리가 쓰는 암호 이름.
Set<String> jsonEncryptCiphers(Object? template) {
  if (lmsEncryptNode(template) case final node?) return {node.cipher};
  return switch (template) {
    Map() => {
      for (final value in template.values) ...jsonEncryptCiphers(value),
    },
    List() => {for (final value in template) ...jsonEncryptCiphers(value)},
    _ => const {},
  };
}

/// JSON 틀을 [vars]로 채운다. 문자열 값만 바꾸고 키 순서는 그대로 둔다. 값 암호화 자리는 [encrypt]로 채우고, 채우지
/// 못하면 [LmsCipherUnavailable]을 던진다.
Object? renderJsonTemplate(
  Object? template,
  Map<String, String> vars, {
  LmsValueEncrypter? encrypt,
}) {
  if (lmsEncryptNode(template) case final node?) {
    final plain = node.text.render(vars);
    return encrypt?.call(node.cipher, plain) ??
        (throw LmsCipherUnavailable(node.cipher));
  }
  return switch (template) {
    String() => LmsTemplate(template).render(vars),
    Map() => {
      for (final MapEntry(:key, :value) in template.entries)
        key as String: renderJsonTemplate(value, vars, encrypt: encrypt),
    },
    List() => [
      for (final value in template)
        renderJsonTemplate(value, vars, encrypt: encrypt),
    ],
    _ => template,
  };
}

/// 해석한 JSON [json]에서 [path](점으로 나눈 키. 목록이면 0부터 세는 번호) 자리의 값. 없으면 null이다.
Object? jsonAt(Object? json, List<String> path) {
  var node = json;
  for (final key in path) {
    switch (node) {
      case Map():
        node = node[key];
      case List():
        final index = int.tryParse(key);
        if (index == null || index < 0 || index >= node.length) return null;
        node = node[index];
      default:
        return null;
    }
  }
  return node;
}

/// JSON 값 [node]의 글자. 문자열은 그대로, 정수와 소수점 아래가 없는 수는 십진 정수, 그 밖의 수와 참거짓은
/// Dart 표기다. null·객체·목록이면 null이다.
String? jsonScalarText(Object? node) => switch (node) {
  String() => node,
  int() => '$node',
  double() when node.isFinite && node == node.truncateToDouble() =>
    '${node.toInt()}',
  double() || bool() => '$node',
  _ => null,
};

/// 요청 본문.
sealed class LmsBodySpec {
  const LmsBodySpec();

  /// 본문이 쓰는 변수 이름.
  Set<String> get names;

  /// 본문이 쓰는 암호 이름(본문 전체 암호화와 값 암호화 자리).
  Set<String> get ciphers;
}

/// 폼 본문(`application/x-www-form-urlencoded`). 필드 값이 틀이다.
final class LmsFormBody extends LmsBodySpec {
  const LmsFormBody(this.fields);

  final Map<String, LmsTemplate> fields;

  @override
  Set<String> get names => {for (final f in fields.values) ...f.names};

  @override
  Set<String> get ciphers => const {};

  @override
  bool operator ==(Object other) =>
      other is LmsFormBody && mapEquals(other.fields, fields);

  @override
  int get hashCode => Object.hashAllUnordered(fields.entries.map(_entryHash));
}

/// JSON 본문(`application/json`). 문자열 값이 틀이다.
final class LmsJsonBody extends LmsBodySpec {
  const LmsJsonBody(this.template);

  final Object? template;

  @override
  Set<String> get names => jsonTemplateNames(template);

  @override
  Set<String> get ciphers => jsonEncryptCiphers(template);

  @override
  bool operator ==(Object other) =>
      other is LmsJsonBody && _jsonEquals(other.template, template);

  @override
  int get hashCode => _jsonHash(template);
}

/// JSON을 암호화해 폼 필드 하나([field])에 담는 본문. 암호는 요청 상수의 이름 붙은 암호([cipher])다.
final class LmsEncryptedBody extends LmsBodySpec {
  const LmsEncryptedBody({
    required this.cipher,
    required this.field,
    required this.template,
  });

  final String cipher;

  final String field;

  final Object? template;

  @override
  Set<String> get names => jsonTemplateNames(template);

  @override
  Set<String> get ciphers => {cipher, ...jsonEncryptCiphers(template)};

  @override
  bool operator ==(Object other) =>
      other is LmsEncryptedBody &&
      other.cipher == cipher &&
      other.field == field &&
      _jsonEquals(other.template, template);

  @override
  int get hashCode => Object.hash(cipher, field, _jsonHash(template));
}

/// 응답에서 값 하나를 뽑는 규칙. [optional]이면 찾지 못했을 때 빈 문자열이고, 아니면 그 요청은 해석 실패다.
sealed class LmsExtract {
  const LmsExtract({this.optional = false});

  final bool optional;
}

/// 본문(UTF-8로 푼 글자)에서 [pattern]의 첫 일치의 첫 묶음.
final class LmsPatternExtract extends LmsExtract {
  const LmsPatternExtract(this.pattern, {super.optional});

  final RegExp pattern;

  @override
  bool operator ==(Object other) =>
      other is LmsPatternExtract &&
      other.pattern.pattern == pattern.pattern &&
      other.optional == optional;

  @override
  int get hashCode => Object.hash(pattern.pattern, optional);
}

/// JSON 본문의 [path] 자리 값([jsonScalarText]). 빈 문자열이면 찾지 못한 것으로 본다.
final class LmsJsonExtract extends LmsExtract {
  const LmsJsonExtract(this.path, {super.optional});

  final List<String> path;

  @override
  bool operator ==(Object other) =>
      other is LmsJsonExtract &&
      listEquals(other.path, path) &&
      other.optional == optional;

  @override
  int get hashCode => Object.hash(Object.hashAll(path), optional);
}

/// 요청마다 새로 만드는 값의 꼴.
enum LmsGenerator {
  /// 무작위 16바이트를 소문자 16진수 32자로 적은 값(하이픈 없는 UUID 꼴).
  hex32,
}

/// 요청 하나.
@immutable
final class LmsRequestSpec {
  const LmsRequestSpec({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.extract = const {},
    this.generate = const {},
  });

  final LmsMethod method;

  /// 주소. 틀 전체가 변수 하나(`{이름}`)이거나 학교 도메인의 https 주소다. 변수 주소가 상대 주소면 앞 요청의 최종
  /// 주소를 기준으로 푼다.
  final LmsTemplate url;

  final Map<String, LmsTemplate> headers;

  final LmsBodySpec? body;

  /// 응답에서 뽑아 다음 요청의 변수로 쓰는 값.
  final Map<String, LmsExtract> extract;

  /// 보내기 전에 새로 만들어 이 요청과 다음 요청의 변수로 쓰는 값.
  final Map<String, LmsGenerator> generate;

  /// 이 요청이 쓰는 변수 이름.
  Set<String> get names => {
    ...url.names,
    for (final h in headers.values) ...h.names,
    ...?body?.names,
  };

  /// 이 요청이 쓰는 암호 이름.
  Set<String> get ciphers => body?.ciphers ?? const {};

  @override
  bool operator ==(Object other) =>
      other is LmsRequestSpec &&
      other.method == method &&
      other.url == url &&
      mapEquals(other.headers, headers) &&
      other.body == body &&
      mapEquals(other.extract, extract) &&
      mapEquals(other.generate, generate);

  @override
  int get hashCode => Object.hash(
    method,
    url,
    Object.hashAllUnordered(headers.entries.map(_entryHash)),
    body,
    Object.hashAllUnordered(extract.entries.map(_entryHash)),
    Object.hashAllUnordered(generate.entries.map(_entryHash)),
  );
}

/// 암호의 초기 벡터.
enum LmsIv {
  /// 0으로 채운 16바이트.
  zero,

  /// 키의 앞 16바이트.
  key,
}

/// 이름 붙은 암호(AES-CBC, PKCS#7 채움, 결과는 base64). 키는 변수 [keyVar]의 글자에서 [removeChars]의 글자를
/// 지우고 UTF-8 바이트의 앞 [takeBytes]바이트(없으면 전부)를 쓰며, 16·24·32바이트여야 한다.
@immutable
final class LmsCipherSpec {
  const LmsCipherSpec({
    required this.keyVar,
    this.removeChars = '',
    this.takeBytes,
    this.iv = LmsIv.zero,
  });

  final String keyVar;

  final String removeChars;

  final int? takeBytes;

  final LmsIv iv;

  @override
  bool operator ==(Object other) =>
      other is LmsCipherSpec &&
      other.keyVar == keyVar &&
      other.removeChars == removeChars &&
      other.takeBytes == takeBytes &&
      other.iv == iv;

  @override
  int get hashCode => Object.hash(keyVar, removeChars, takeBytes, iv);
}

int _entryHash(MapEntry<Object?, Object?> e) => Object.hash(e.key, e.value);

bool _jsonEquals(Object? a, Object? b) => switch ((a, b)) {
  (final Map ma, final Map mb) =>
    ma.length == mb.length &&
        ma.entries.every(
          (e) => mb.containsKey(e.key) && _jsonEquals(e.value, mb[e.key]),
        ),
  (final List la, final List lb) =>
    la.length == lb.length &&
        Iterable<int>.generate(la.length)
            .every((i) => _jsonEquals(la[i], lb[i])),
  _ => a == b,
};

int _jsonHash(Object? value) => switch (value) {
  Map() => Object.hashAllUnordered(
    value.entries.map((e) => Object.hash(e.key, _jsonHash(e.value))),
  ),
  List() => Object.hashAll(value.map(_jsonHash)),
  _ => value.hashCode,
};
