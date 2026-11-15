// 과목 목록 응답 해석. docs/lms.md '응답 해석', docs/architecture.md '폰 DB'의 `courses`.
//
// 응답에서 과목 ID·분반·과목명만 읽고 모르는 필드는 무시한다. 응답 원문과 그 밖의 필드(교수명 등)는 남기지 않는다.
// 필요한 필드가 없거나 형이 다르면 그 필드 이름으로 해석 실패다(판별기 `LmsSchema`). 과목의 원본 ID(`courses.remoteId`)는
// 과목 ID와 분반을 `/`로 이은 값이다(같은 과목의 분반을 가른다). 학기 값은 이 응답에 없어 동기화가 요청에 쓴 값을 붙인다.

import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:flutter/foundation.dart' show immutable;

/// 과목 목록의 과목 하나.
@immutable
final class LmsCourseRecord {
  const LmsCourseRecord({required this.remoteId, required this.name});

  /// 과목 ID와 분반을 `/`로 이은 원본 ID([lmsCourseRemoteId]).
  final String remoteId;

  final String name;

  @override
  bool operator ==(Object other) =>
      other is LmsCourseRecord &&
      other.remoteId == remoteId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(remoteId, name);
}

/// 과목 ID [courseId]와 분반 [classNo]로 만든 과목의 원본 ID.
String lmsCourseRemoteId(String courseId, String classNo) =>
    '$courseId/$classNo';

/// 원본 ID [remoteId]([lmsCourseRemoteId])를 과목 ID와 분반으로 나눈다. 꼴이 맞지 않으면 null이다.
({String courseId, String classNo})? lmsCourseIdParts(String remoteId) {
  final at = remoteId.lastIndexOf('/');
  if (at <= 0 || at == remoteId.length - 1) return null;
  return (
    courseId: remoteId.substring(0, at),
    classNo: remoteId.substring(at + 1),
  );
}

/// 응답 JSON에서 ID 꼴의 값(비어 있지 않은 문자열이나 정수)을 글자로 읽는다. 아니면 null이다.
String? lmsIdText(Object? value) => switch (value) {
  String() when value.trim().isNotEmpty => value.trim(),
  int() => '$value',
  _ => null,
};

/// 과목 목록 응답의 스키마. 항목 수는 과목 수다.
LmsSchemaResult<List<LmsCourseRecord>> courseListSchema(Object? json) {
  if (json is! Map) return const LmsSchemaMismatch('body');
  final body = json['body'];
  if (body is! Map) return const LmsSchemaMismatch('body');
  final list = body['course_list'];
  if (list is! List) return const LmsSchemaMismatch('body.course_list');
  final courses = <LmsCourseRecord>[];
  for (final item in list) {
    if (item is! Map) return const LmsSchemaMismatch('body.course_list');
    final courseId = lmsIdText(item['course_id']);
    if (courseId == null) {
      return const LmsSchemaMismatch('body.course_list.course_id');
    }
    final classNo = lmsIdText(item['class_no']);
    if (classNo == null) {
      return const LmsSchemaMismatch('body.course_list.class_no');
    }
    final name = item['course_nm'];
    if (name is! String || name.trim().isEmpty) {
      return const LmsSchemaMismatch('body.course_list.course_nm');
    }
    courses.add(
      LmsCourseRecord(
        remoteId: lmsCourseRemoteId(courseId, classNo),
        name: name.trim(),
      ),
    );
  }
  return LmsSchemaMatch(courses, itemCount: courses.length);
}
