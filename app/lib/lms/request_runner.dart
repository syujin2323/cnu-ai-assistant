// 요청 틀 실행. docs/lms.md '로그인'.
//
// 요청 틀([LmsRequestSpec])을 변수로 채워 요청을 만들고([buildLmsRequest]) 보낸 뒤, 응답에서 틀이 정한 값을 뽑는다.
// 틀이 새로 만들라고 한 값(`generate`)은 보내기 전에 만들어 변수에 더하고 뽑은 값과 함께 돌려준다. 주소가 변수이면 그
// 값을 앞 요청의 최종 주소 기준으로 풀고, 학교 도메인의 https 주소가 아니면 보내지 않는다. 변수 값(학번·비밀번호
// 포함)과 응답 원문은 로그에 남기지 않는다.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cnu_ai_assistant/lms/cipher.dart';
import 'package:cnu_ai_assistant/lms/lms_client.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/request_spec.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';

/// 요청 틀 하나를 보낸 결과.
sealed class LmsStepResult {
  const LmsStepResult();
}

/// 요청을 만들지 못해 보내지 않았다. [field]는 그 까닭(`url`, `cipher`, `variable`)이다. 요청 상수가 맞지 않는
/// 것이므로 해석 실패로 다룬다.
final class LmsStepNotSent extends LmsStepResult {
  const LmsStepNotSent(this.field);

  final String field;
}

/// 요청을 보냈다.
final class LmsStepSent extends LmsStepResult {
  const LmsStepSent({
    required this.response,
    required this.isJson,
    required this.json,
    required this.values,
    this.missing,
  });

  final LmsRawResponse response;

  /// 본문이 JSON인지([decodeLmsJson]).
  final bool isJson;

  /// JSON으로 푼 본문. JSON이 아니면 null이다.
  final Object? json;

  /// 뽑은 값(못 찾은 선택 값은 빈 문자열).
  final Map<String, String> values;

  /// 꼭 뽑아야 하는데 찾지 못한 변수 이름. 다 찾았으면 null이다.
  final String? missing;
}

/// 요청 틀을 [vars]로 채운 요청. [base]는 변수 주소가 상대 주소일 때 기준이다. 만들지 못하면 `request`가 null이고
/// `problem`에 까닭(`url`, `cipher`, `variable`)이 있다.
({LmsHttpRequest? request, String? problem}) buildLmsRequest(
  LmsRequestSpec spec,
  Map<String, String> vars, {
  required Map<String, LmsCipherSpec> ciphers,
  required String schoolDomain,
  Uri? base,
}) {
  try {
    final rendered = spec.url.render(vars);
    var url = Uri.tryParse(rendered);
    if (url != null && !url.hasScheme && base != null) {
      url = base.resolveUri(url);
    }
    if (url == null || !isSchoolUrl(url, domain: schoolDomain)) {
      return (request: null, problem: 'url');
    }
    String? encrypt(String cipher, String plain) => switch (ciphers[cipher]) {
      final spec? => lmsEncrypt(spec, vars, plain),
      null => null,
    };
    final headers = {
      for (final MapEntry(:key, :value) in spec.headers.entries)
        key: value.render(vars),
    };
    final hasContentType = headers.keys.any(
      (key) => key.toLowerCase() == 'content-type',
    );
    Uint8List? body;
    String? contentType;
    switch (spec.body) {
      case null:
        break;
      case LmsFormBody(:final fields):
        body = utf8.encode(
          _form({
            for (final MapEntry(:key, :value) in fields.entries)
              key: value.render(vars),
          }),
        );
        contentType = _formType;
      case LmsJsonBody(:final template):
        body = utf8.encode(
          jsonEncode(renderJsonTemplate(template, vars, encrypt: encrypt)),
        );
        contentType = 'application/json; charset=utf-8';
      case LmsEncryptedBody(:final cipher, :final field, :final template):
        final encrypted = lmsEncrypt(
          ciphers[cipher]!,
          vars,
          jsonEncode(renderJsonTemplate(template, vars, encrypt: encrypt)),
        );
        if (encrypted == null) return (request: null, problem: 'cipher');
        body = utf8.encode(_form({field: encrypted}));
        contentType = _formType;
    }
    return (
      request: LmsHttpRequest(
        method: spec.method,
        url: url,
        headers: {
          ...headers,
          if (contentType != null && !hasContentType)
            'content-type': contentType,
        },
        body: body,
      ),
      problem: null,
    );
  } on LmsMissingVariable {
    return (request: null, problem: 'variable');
  } on LmsCipherUnavailable {
    return (request: null, problem: 'cipher');
  }
}

const _formType = 'application/x-www-form-urlencoded; charset=UTF-8';

String _form(Map<String, String> fields) => [
  for (final MapEntry(:key, :value) in fields.entries)
    '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
].join('&');

/// 요청 틀을 보내고 값을 뽑는다.
class LmsRequestRunner {
  LmsRequestRunner({
    required this.client,
    required this.ciphers,
    required this.schoolDomain,
    Random? random,
  }) : _random = random ?? Random.secure();

  final LmsClient client;

  final Map<String, LmsCipherSpec> ciphers;

  final String schoolDomain;

  /// 새로 만드는 값의 무작위 근원. 테스트는 씨앗을 준 것으로 바꾼다.
  final Random _random;

  /// [spec]을 [vars]로 채워 보낸다. [base]는 변수 주소가 상대 주소일 때 기준이다.
  Future<LmsStepResult> run(
    LmsRequestSpec spec,
    Map<String, String> vars, {
    Uri? base,
  }) async {
    final generated = {
      for (final MapEntry(key: name, value: kind) in spec.generate.entries)
        name: _generate(kind),
    };
    final built = buildLmsRequest(
      spec,
      {...vars, ...generated},
      ciphers: ciphers,
      schoolDomain: schoolDomain,
      base: base,
    );
    final request = built.request;
    if (request == null) return LmsStepNotSent(built.problem!);
    final response = await client.send(request);
    final (:isJson, value: json) = decodeLmsJson(response);
    final values = <String, String>{...generated};
    String? missing;
    for (final MapEntry(key: name, value: extract) in spec.extract.entries) {
      final found = switch (extract) {
        LmsPatternExtract(:final pattern) => _firstGroup(
          pattern,
          response.body,
        ),
        LmsJsonExtract(:final path) =>
          isJson ? jsonScalarText(jsonAt(json, path)) : null,
      };
      if (found != null && found.isNotEmpty) {
        values[name] = found;
      } else if (extract.optional) {
        values[name] = '';
      } else {
        missing ??= name;
      }
    }
    return LmsStepSent(
      response: response,
      isJson: isJson,
      json: json,
      values: values,
      missing: missing,
    );
  }

  String _generate(LmsGenerator kind) => switch (kind) {
    LmsGenerator.hex32 => [
      for (var i = 0; i < 16; i++)
        _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join(),
  };

  static String? _firstGroup(RegExp pattern, String body) {
    final match = pattern.firstMatch(body);
    if (match == null || match.groupCount < 1) return null;
    return match.group(1);
  }
}
