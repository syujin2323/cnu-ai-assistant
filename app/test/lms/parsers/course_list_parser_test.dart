// 과목 목록 응답 해석 테스트. docs/lms.md '응답 해석'.
//
// 합성 응답(`test/lms/fixtures/`)을 판별기와 함께 읽어 과목 ID·분반·과목명만 꺼내는지, 필요한 필드가 없으면 그 필드 이름으로
// 해석 실패인지 본다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/request_params.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/lms_samples.dart';

void main() {
  final classifier = LmsResponseClassifier.of(
    parseLmsRequestParams(
      syntheticRequestParamsJson,
      schoolDomain: syntheticSchoolDomain,
    ).params!,
  );

  LmsClassification<List<LmsCourseRecord>> classify(String body) => classifier
      .classify(LmsRawResponse(statusCode: 200, body: body), courseListSchema);

  test('과목 ID·분반을 이은 원본 ID와 앞뒤 공백을 지운 과목명만 읽는다', () {
    final result = classify(lmsFixture('normal_course_list.json'));
    expect(result.kind, LmsOutcomeKind.normal);
    expect(result.value, const [
      LmsCourseRecord(remoteId: 'C1/1', name: '과목A'),
      LmsCourseRecord(remoteId: '2/2', name: '과목B'),
    ]);
  });

  test('과목이 없으면 빈 목록이다', () {
    final result = classify(lmsFixture('empty_course_list.json'));
    expect(result.kind, LmsOutcomeKind.empty);
    expect(result.value, isEmpty);
  });

  test('필요한 필드가 없거나 형이 다르면 그 필드 이름으로 해석 실패다', () {
    expect(
      classify(lmsFixture('parse_failure_course_missing_name.json'))
          .failedField,
      'body.course_list.course_nm',
    );
    Map<String, Object?> body(Object? list) => {
      'header': {'code': 200},
      'body': {'course_list': list},
    };
    for (final (list, field) in <(Object?, String)>[
      (null, 'body.course_list'),
      ('과목', 'body.course_list'),
      (['과목'], 'body.course_list'),
      (
        [
          {'class_no': '1', 'course_nm': '과목A'},
        ],
        'body.course_list.course_id',
      ),
      (
        [
          {'course_id': '', 'class_no': '1', 'course_nm': '과목A'},
        ],
        'body.course_list.course_id',
      ),
      (
        [
          {'course_id': 'C1', 'class_no': 1.5, 'course_nm': '과목A'},
        ],
        'body.course_list.class_no',
      ),
      (
        [
          {'course_id': 'C1', 'class_no': '1', 'course_nm': '  '},
        ],
        'body.course_list.course_nm',
      ),
    ]) {
      final result = classify(jsonEncode(body(list)));
      expect(result.kind, LmsOutcomeKind.parseFailure, reason: '$list');
      expect(result.failedField, field, reason: '$list');
    }
    expect(
      courseListSchema(const {'header': 1}),
      isA<LmsSchemaMismatch<List<LmsCourseRecord>>>().having(
        (m) => m.field,
        'field',
        'body',
      ),
    );
    expect(
      courseListSchema('x'),
      isA<LmsSchemaMismatch<List<LmsCourseRecord>>>(),
    );
  });

  test('lmsIdText는 비어 있지 않은 글자(앞뒤 공백 지움)와 정수만 읽는다', () {
    expect(lmsIdText(' C1 '), 'C1');
    expect(lmsIdText(7), '7');
    for (final value in <Object?>[null, '', '  ', 1.5, true, const <int>[]]) {
      expect(lmsIdText(value), isNull, reason: '$value');
    }
    expect(lmsCourseRemoteId('C1', '2'), 'C1/2');
  });
}
