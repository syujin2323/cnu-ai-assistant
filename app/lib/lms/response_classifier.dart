// LMS 응답 판별. docs/lms.md '응답 판별'.
//
// 모든 LMS 조회 응답을 일곱 가지(정상, 빈 목록, 재로그인 필요, 복원 필요, 서버 오류·점검, 네트워크 실패, 해석
// 실패) 가운데 하나로 나눈다. 순서는 ① 응답 없음(연결 실패·시간 초과) → 네트워크 실패, ② 5xx·429나 본문의 점검
// 표식 → 서버 오류·점검, ③ 최종 주소가 로그인 주소로 넘어갔거나 본문의 로그인 페이지 표식 → 재로그인 필요,
// ④ JSON이고 인증 오류 표식 → 복원 필요, ⑤ 2xx JSON이고 스키마 통과 → 정상이나 빈 목록, ⑥ 나머지(그 밖의
// 상태 코드, 표식 없는 HTML, 스키마 실패) → 해석 실패다.
//
// 표식과 로그인 주소는 요청 상수(`request_params.dart`)에서 받고, 코드와 테스트에는 실제 표식을 적지 않는다.
// '스키마'는 응답 파서가 요구하는 필드 집합이다([LmsSchema]). 응답 원문은 메모리에서만 다루고 결과에는 판별
// 종류, 상태 코드, 파서가 읽은 값, 스키마에 맞지 않은 필드 이름만 담는다. 로그인 응답은 이 판별기가 아니라
// 로그인 흐름이 나눈다(docs/lms.md '로그인').

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:flutter/foundation.dart' show immutable;

/// 판별기에 넣는 LMS 응답. dio 응답을 이 꼴로 바꿔 넣는다. 원문은 로그·폰 DB·파일에 남기지 않는다.
@immutable
final class LmsRawResponse {
  const LmsRawResponse({
    required this.statusCode,
    this.finalUrl,
    this.contentType,
    this.body = '',
  });

  /// 응답을 받지 못했다(연결 실패, 시간 초과).
  const LmsRawResponse.noResponse()
    : statusCode = null,
      finalUrl = null,
      contentType = null,
      body = '';

  /// HTTP 상태 코드. 응답을 받지 못했으면 null.
  final int? statusCode;

  /// 리다이렉트를 따라간 뒤의 최종 주소.
  final Uri? finalUrl;

  /// `Content-Type` 헤더 값.
  final String? contentType;

  /// 본문(UTF-8로 푼 문자열).
  final String body;
}

/// 응답 스키마. 해석한 JSON을 읽어 파서의 값과 항목 수([LmsSchemaMatch])나, 맞지 않은 필드 이름
/// ([LmsSchemaMismatch])을 돌려준다. 필요한 필드만 읽고 모르는 필드는 무시하며, 던지지 않는다.
typedef LmsSchema<T> = LmsSchemaResult<T> Function(Object? json);

/// [LmsSchema]의 결과.
sealed class LmsSchemaResult<T> {
  const LmsSchemaResult();
}

/// 스키마에 맞음. [itemCount]가 0이면 빈 목록이다.
final class LmsSchemaMatch<T> extends LmsSchemaResult<T> {
  const LmsSchemaMatch(this.value, {required this.itemCount});

  final T value;

  final int itemCount;
}

/// 스키마에 맞지 않음. [field]는 없거나 형이 다른 필드의 이름이다(점으로 이은 키 이름. 값은 담지 않는다).
final class LmsSchemaMismatch<T> extends LmsSchemaResult<T> {
  const LmsSchemaMismatch(this.field);

  final String field;
}

/// 판별 결과.
@immutable
final class LmsClassification<T> {
  const LmsClassification._(this.outcome, {this.value, this.failedField});

  /// 판별 종류와 상태 코드.
  final LmsOutcome outcome;

  /// 정상·빈 목록일 때 파서가 읽은 값.
  final T? value;

  /// 스키마에 맞지 않아 해석 실패일 때 그 필드 이름. 이름 꼴(`^[A-Za-z0-9_.]+$`)이 아니면 `unexpected`다.
  /// `sync_runs.detail`에 그대로 남긴다.
  final String? failedField;

  LmsOutcomeKind get kind => outcome.kind;
}

/// LMS 응답 판별기. 표식과 로그인 주소를 생성자로 받는다.
final class LmsResponseClassifier {
  const LmsResponseClassifier({
    required this.markers,
    required this.isLoginUrl,
  });

  /// 요청 상수의 표식과 로그인 주소로 만든다.
  LmsResponseClassifier.of(LmsRequestParams params)
    : this(markers: params.markers, isLoginUrl: params.isLoginUrl);

  final LmsMarkers markers;

  /// 최종 주소가 로그인 주소로 넘어간 주소인지([LmsRequestParams.isLoginUrl]).
  final bool Function(Uri finalUrl) isLoginUrl;

  /// [response]를 판별한다. 2xx JSON이고 인증 오류가 아니면 [schema]로 읽는다. 던지지 않는다.
  LmsClassification<T> classify<T>(
    LmsRawResponse response,
    LmsSchema<T> schema,
  ) {
    final status = response.statusCode;
    LmsClassification<T> result(LmsOutcomeKind kind) =>
        LmsClassification._(LmsOutcome(kind, statusCode: status));

    if (status == null) return result(LmsOutcomeKind.networkFailure);
    final body = response.body;
    if (status >= 500 || status == 429 || _hasAny(body, markers.maintenance)) {
      return result(LmsOutcomeKind.serverError);
    }
    final finalUrl = response.finalUrl;
    if ((finalUrl != null && isLoginUrl(finalUrl)) ||
        _hasAny(body, markers.loginPage)) {
      return result(LmsOutcomeKind.reloginRequired);
    }
    final json = _decodeJson(response);
    if (identical(json, _notJson)) return result(LmsOutcomeKind.parseFailure);
    if (markers.authError.any((marker) => marker.matches(json))) {
      return result(LmsOutcomeKind.restoreRequired);
    }
    if (status < 200 || status >= 300) {
      return result(LmsOutcomeKind.parseFailure);
    }
    final LmsSchemaResult<T> read;
    try {
      read = schema(json);
    } on FormatException {
      return LmsClassification._(
        LmsOutcome(LmsOutcomeKind.parseFailure, statusCode: status),
        failedField: _unexpectedField,
      );
    }
    return switch (read) {
      LmsSchemaMatch(:final value, :final itemCount) => LmsClassification._(
        LmsOutcome(
          itemCount > 0 ? LmsOutcomeKind.normal : LmsOutcomeKind.empty,
          statusCode: status,
        ),
        value: value,
      ),
      LmsSchemaMismatch(:final field) => LmsClassification._(
        LmsOutcome(LmsOutcomeKind.parseFailure, statusCode: status),
        failedField: _fieldName.hasMatch(field) ? field : _unexpectedField,
      ),
    };
  }

  static bool _hasAny(String body, List<String> markers) =>
      markers.any(body.contains);
}

/// 로그에 남겨도 되는 필드 이름 꼴(docs/architecture.md '앱 코드 규약'의 로그 규칙).
final _fieldName = RegExp(r'^[A-Za-z0-9_.]{1,64}$');

const _unexpectedField = 'unexpected';

/// JSON이 아님을 나타내는 값(JSON의 null과 가르기 위해 따로 둔다).
const Object _notJson = Object();

/// 본문을 JSON으로 푼다. 앞뒤 공백과 BOM은 무시하고(`String.trim`은 BOM도 지운다), 본문이 `{`·`[`로 시작하거나
/// `Content-Type`이 JSON일 때만 풀어 본다. 풀지 못하면 [_notJson]이다.
Object? _decodeJson(LmsRawResponse response) {
  final text = response.body.trim();
  final looksJson = text.startsWith('{') || text.startsWith('[');
  final saysJson =
      response.contentType?.toLowerCase().contains('json') ?? false;
  if (!looksJson && !saysJson) return _notJson;
  try {
    return jsonDecode(text);
  } on FormatException {
    return _notJson;
  }
}
