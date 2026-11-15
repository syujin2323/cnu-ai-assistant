// 할 일 목록 응답 해석 테스트. docs/lms.md '응답 해석'.
//
// 합성 응답(`test/lms/fixtures/`)과 지어낸 종류 코드로, 종류 대응·마감 읽기·항목 ID 고르기·원본 키를 보고, 필요한 필드가
// 없으면 그 필드 이름으로 해석 실패인지 본다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:cnu_ai_assistant/lms/parsers/todo_list_parser.dart';
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
  final config = LmsParseConfig.fromJson({
    'kindCodes': {
      'video': ['K1'],
      'assignment': ['K2'],
      'quiz': ['K3'],
    },
  })!;

  LmsClassification<List<LmsTodoRecord>> classify(String body) =>
      classifier.classify(
        LmsRawResponse(statusCode: 200, body: body),
        todoListSchema(config),
      );

  Map<String, Object?> item([Map<String, Object?> changes = const {}]) => {
    'module_type': 'K3',
    'course_id': 'C1',
    'class_no': '1',
    'course_nm': '과목A',
    'item_title_temp': '퀴즈 1',
    'info': '2026-11-25 18:00:00',
    'item_id': 'Q1',
    ...changes,
  };

  String body(List<Object?> items) => jsonEncode({
    'header': {'code': 200},
    'body': {'todo_list': items},
  });

  test('종류·과목·제목·마감·항목 ID를 읽고 원본 키를 만든다', () {
    final result = classify(lmsFixture('normal_todo_list.json'));
    expect(result.kind, LmsOutcomeKind.normal);
    final [assignment, video] = result.value!;
    expect(
      assignment,
      LmsTodoRecord(
        kindCode: 'K2',
        kind: LmsItemKind.assignment,
        courseRemoteId: 'C1/1',
        courseName: '과목A',
        title: '과제 1',
        itemId: 'R1',
        dueAt: DateTime(2026, 11, 20, 23, 59),
      ),
    );
    expect(assignment.remoteKey('S1'), 'S1:C1/1:K2:R1');
    // 날짜만 있는 마감은 그날 23:59이고 시각을 모른다. 항목 ID가 없으면 콘텐츠 ID다.
    expect(video.kind, LmsItemKind.video);
    expect(video.courseRemoteId, 'C2/2');
    expect(video.itemId, 'V1');
    expect(video.dueAt, DateTime(2026, 11, 22, 23, 59));
    expect(video.dueTimeUnknown, isTrue);
  });

  test('모르는 종류 코드는 자료이고, 원본 키에는 LMS가 준 코드를 그대로 쓴다', () {
    final [record] = classify(
      body([
        item({'module_type': 'K9'}),
      ]),
    ).value!;
    expect(record.kind, LmsItemKind.material);
    expect(record.remoteKey('S1'), 'S1:C1/1:K9:Q1');
  });

  test('항목 ID는 항목 ID, 콘텐츠 ID, 주차·차시 순서로 고른다', () {
    final [byItem, byContents, byWeek] = classify(
      body([
        item({'item_id': 'I1', 'contents_id': 'X1'}),
        item({'item_id': '', 'contents_id': 'X2'}),
        item({'item_id': null, 'week_no': 3, 'seq_no': '4'}),
      ]),
    ).value!;
    expect(byItem.itemId, 'I1');
    expect(byContents.itemId, 'X2');
    expect(byWeek.itemId, 'w3-s4');
  });

  test('마감이 없거나 비었으면 마감 없음이다', () {
    final records = classify(
      body([
        item({'info': null}),
        item({'info': ''}),
        item({'info': '  '}),
      ]),
    ).value!;
    for (final record in records) {
      expect(record.dueAt, isNull);
      expect(record.dueTimeUnknown, isFalse);
    }
  });

  test('할 일이 없으면 빈 목록이다', () {
    final result = classify(lmsFixture('empty_todo_list.json'));
    expect(result.kind, LmsOutcomeKind.empty);
    expect(result.value, isEmpty);
  });

  test('필요한 필드가 없거나 형이 다르면 그 필드 이름으로 해석 실패다', () {
    expect(
      classify(lmsFixture('parse_failure_todo_missing_id.json')).failedField,
      'body.todo_list.item_id',
    );
    for (final (changes, field) in <(Map<String, Object?>, String)>[
      ({'module_type': null}, 'module_type'),
      ({'module_type': ''}, 'module_type'),
      ({'course_id': null}, 'course_id'),
      ({'class_no': true}, 'class_no'),
      ({'course_nm': 1}, 'course_nm'),
      ({'item_title_temp': ' '}, 'item_title_temp'),
      ({'item_id': null, 'week_no': 3}, 'item_id'),
      ({'info': 20261125}, 'info'),
      ({'info': '상시'}, 'info'),
      ({'info': '2026-02-30 10:00'}, 'info'),
    ]) {
      final result = classify(body([item(changes)]));
      expect(result.kind, LmsOutcomeKind.parseFailure, reason: '$changes');
      expect(result.failedField, 'body.todo_list.$field', reason: '$changes');
    }
    expect(classify(body(['할 일'])).failedField, 'body.todo_list');
    expect(
      classify(
        jsonEncode({
          'body': {'todo_list': {}},
        }),
      ).failedField,
      'body.todo_list',
    );
    expect(classify(jsonEncode({'body': 1})).failedField, 'body');
  });
}
