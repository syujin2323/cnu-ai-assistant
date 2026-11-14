// 응답 판별기 테스트. docs/lms.md '응답 판별'.
//
// `test/lms/fixtures/`의 합성 응답과 합성 요청 상수의 테스트 전용 표식으로 일곱 가지 판별과 그 순서를 본다. 스키마는
// 이 파일의 합성 스키마(할 일 목록 꼴)이고, 실제 응답 파서는 따로 시험한다.

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lms_samples.dart';

void main() {
  final params = parseLmsRequestParams(
    syntheticRequestParamsJson,
    schoolDomain: syntheticSchoolDomain,
  ).params!;
  final classifier = LmsResponseClassifier.of(params);
  final dataUrl = Uri.parse('https://example.invalid/data');

  /// 합성 스키마: `body.todo_list`가 목록이면 맞고 항목 수는 그 길이다.
  LmsSchemaResult<List<Object?>> todoList(Object? json) {
    if (json is! Map) return const LmsSchemaMismatch('body');
    final body = json['body'];
    if (body is! Map) return const LmsSchemaMismatch('body');
    final list = body['todo_list'];
    if (list is! List) return const LmsSchemaMismatch('body.todo_list');
    return LmsSchemaMatch(list, itemCount: list.length);
  }

  LmsClassification<List<Object?>> classify(
    int? status, {
    String body = '',
    Uri? finalUrl,
    String? contentType,
    LmsSchema<List<Object?>>? schema,
  }) => classifier.classify(
    status == null
        ? const LmsRawResponse.noResponse()
        : LmsRawResponse(
            statusCode: status,
            finalUrl: finalUrl ?? dataUrl,
            contentType: contentType,
            body: body,
          ),
    schema ?? todoList,
  );

  void expectKind(
    LmsClassification<Object?> result,
    LmsOutcomeKind kind, {
    int? status,
    String? field,
  }) {
    expect(result.outcome, LmsOutcome(kind, statusCode: status));
    expect(result.kind, kind);
    expect(result.failedField, field);
    if (kind != LmsOutcomeKind.normal && kind != LmsOutcomeKind.empty) {
      expect(result.value, isNull);
    }
  }

  final normal = lmsFixture('normal_todo_list.json');
  final empty = lmsFixture('empty_todo_list.json');
  final authError = lmsFixture('restore_required_auth_error.json');
  final missingList = lmsFixture('parse_failure_missing_list.json');
  final loginPage = lmsFixture('relogin_required_login_page.html');
  final maintenance = lmsFixture('server_error_maintenance.html');
  final unknownPage = lmsFixture('parse_failure_unknown_page.html');

  test('① 응답을 받지 못하면 네트워크 실패이고 상태 코드가 없다', () {
    expectKind(classify(null), LmsOutcomeKind.networkFailure);
  });

  test('② 5xx·429와 점검 페이지는 서버 오류·점검이다', () {
    for (final status in [500, 502, 503, 599, 429]) {
      expectKind(
        classify(status, body: normal),
        LmsOutcomeKind.serverError,
        status: status,
      );
    }
    expectKind(
      classify(200, body: maintenance),
      LmsOutcomeKind.serverError,
      status: 200,
    );
  });

  test('② 점검 표식은 로그인 표식보다 먼저 본다', () {
    expectKind(
      classify(200, body: '$loginPage\n$maintenance'),
      LmsOutcomeKind.serverError,
      status: 200,
    );
    expectKind(
      classify(
        503,
        body: loginPage,
        finalUrl: Uri.parse('https://example.invalid/synthetic-login'),
      ),
      LmsOutcomeKind.serverError,
      status: 503,
    );
  });

  test('③ 로그인 주소로 넘어갔거나 로그인 페이지면 재로그인 필요다', () {
    expectKind(
      classify(200, body: loginPage),
      LmsOutcomeKind.reloginRequired,
      status: 200,
    );
    expectKind(
      classify(401, body: loginPage),
      LmsOutcomeKind.reloginRequired,
      status: 401,
    );
    // 본문이 정상 JSON이어도 최종 주소가 로그인 주소면 재로그인 필요다.
    expectKind(
      classify(
        200,
        body: normal,
        finalUrl: Uri.parse(
          'https://example.invalid/synthetic-login?next=elsewhere',
        ),
      ),
      LmsOutcomeKind.reloginRequired,
      status: 200,
    );
    expectKind(
      classify(
        200,
        body: unknownPage,
        finalUrl: Uri.parse('https://example.invalid/synthetic-login/form'),
      ),
      LmsOutcomeKind.reloginRequired,
      status: 200,
    );
  });

  test('③ 경로가 글자로만 겹치는 주소는 로그인 주소가 아니다', () {
    final result = classify(
      200,
      body: normal,
      finalUrl: Uri.parse('https://example.invalid/synthetic-login-help'),
    );
    expectKind(result, LmsOutcomeKind.normal, status: 200);
  });

  test('④ JSON 인증 오류 표식은 복원 필요다(상태 코드와 관계없이, 문자열·정수 값 모두)', () {
    expectKind(
      classify(200, body: authError),
      LmsOutcomeKind.restoreRequired,
      status: 200,
    );
    expectKind(
      classify(401, body: authError),
      LmsOutcomeKind.restoreRequired,
      status: 401,
    );
    expectKind(
      classify(200, body: '{"header": {"code": "9002"}}'),
      LmsOutcomeKind.restoreRequired,
      status: 200,
    );
  });

  test('⑤ 2xx JSON이 스키마에 맞으면 정상, 항목이 0개면 빈 목록이고 읽은 값을 담는다', () {
    final ok = classify(200, body: normal);
    expectKind(ok, LmsOutcomeKind.normal, status: 200);
    expect(ok.value, hasLength(2));

    final none = classify(204, body: empty);
    expectKind(none, LmsOutcomeKind.empty, status: 204);
    expect(none.value, isEmpty);
  });

  test('⑤ 앞의 BOM·공백과 JSON이라고 밝힌 Content-Type도 JSON으로 본다', () {
    expectKind(
      classify(200, body: '\uFEFF \n$normal'),
      LmsOutcomeKind.normal,
      status: 200,
    );
    // JSON이라고 밝혔지만 객체가 아니면 스키마가 맞지 않은 필드를 알린다.
    expectKind(
      classify(200, body: '"text"', contentType: 'application/json'),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'body',
    );
  });

  test('⑥ 스키마에 맞지 않으면 해석 실패이고 그 필드 이름을 담는다', () {
    expectKind(
      classify(200, body: missingList),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'body.todo_list',
    );
    expectKind(
      classify(200, body: '[1, 2]'),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'body',
    );
  });

  test('⑥ 2xx가 아닌 JSON, 표식 없는 HTML, 풀 수 없는 본문은 필드 없이 해석 실패다', () {
    for (final status in [404, 400, 302, 199]) {
      expectKind(
        classify(status, body: normal),
        LmsOutcomeKind.parseFailure,
        status: status,
      );
    }
    for (final body in [unknownPage, '', 'plain text', '{"broken": ']) {
      expectKind(
        classify(200, body: body),
        LmsOutcomeKind.parseFailure,
        status: 200,
      );
    }
    expectKind(
      classify(200, body: 'not json', contentType: 'application/json'),
      LmsOutcomeKind.parseFailure,
      status: 200,
    );
  });

  test('스키마가 알린 필드 이름이 이름 꼴이 아니거나 FormatException이면 unexpected로 남긴다', () {
    expectKind(
      classify(
        200,
        body: normal,
        schema: (_) => const LmsSchemaMismatch('body/todo list'),
      ),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'unexpected',
    );
    expectKind(
      classify(200, body: normal, schema: (_) => LmsSchemaMismatch('x' * 65)),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'unexpected',
    );
    expectKind(
      classify(
        200,
        body: normal,
        schema: (_) => throw const FormatException('합성'),
      ),
      LmsOutcomeKind.parseFailure,
      status: 200,
      field: 'unexpected',
    );
  });

  test('표식이 없는 설정에서는 HTML이 해석 실패, 인증 오류 JSON도 스키마로만 본다', () {
    final bare = LmsResponseClassifier(
      markers: const LmsMarkers(),
      isLoginUrl: params.isLoginUrl,
    );
    expect(
      bare
          .classify(LmsRawResponse(statusCode: 200, body: loginPage), todoList)
          .kind,
      LmsOutcomeKind.parseFailure,
    );
    expect(
      bare
          .classify(
            LmsRawResponse(statusCode: 200, body: maintenance),
            todoList,
          )
          .kind,
      LmsOutcomeKind.parseFailure,
    );
    expect(
      bare
          .classify(LmsRawResponse(statusCode: 200, body: authError), todoList)
          .failedField,
      'body.todo_list',
    );
  });
}
