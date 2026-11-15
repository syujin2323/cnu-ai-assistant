// 할 일 목록 응답 해석. docs/lms.md '응답 해석'.
//
// 응답에서 종류 코드·과목 ID·분반·과목명·제목·마감·항목 ID만 읽고 모르는 필드는 무시한다. 응답 원문은 남기지 않는다.
// 필요한 필드가 없거나 형이 다르면 그 필드 이름으로 해석 실패다(판별기 `LmsSchema`).
//
// - 종류: 종류 코드를 요청 상수의 대응([LmsParseConfig])으로 바꾼다. 모르는 코드는 할 일로 만들지 않는 '자료'다.
// - 마감: 화면에 보이는 마감(지각 제출 마감이 아님)을 [parseLmsDateTime]으로 읽는다. 없거나 비었으면 마감 없음이고,
//   글자가 있는데 읽을 수 없으면 꼴이 바뀐 것으로 보고 해석 실패다(마감이 조용히 사라지지 않게).
// - 항목 ID: 항목 ID, 없으면 콘텐츠 ID, 그것도 없으면 주차·차시다(임시. 실제 계정 확인 때 겹치지 않는지 본다).
// - 원본 키(`lms_items.remoteKey`): 학기·과목 원본 ID·종류 코드·항목 ID를 `:`로 잇는다. 종류는 LMS가 준 코드 그대로라 요청
//   상수의 대응을 고쳐도 키가 바뀌지 않는다. 학기 값은 응답에 없어 동기화가 요청에 쓴 값을 넘긴다.
// - 영상 길이·인정 시간·시청 시간·제출·출석 인정·공개일은 이 응답에 없다(과목별 상세에서 받음).

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/lms/parsers/course_list_parser.dart';
import 'package:cnu_ai_assistant/lms/parsers/lms_date_time.dart';
import 'package:cnu_ai_assistant/lms/parsers/parse_config.dart';
import 'package:cnu_ai_assistant/lms/response_classifier.dart';
import 'package:flutter/foundation.dart' show immutable;

/// 할 일 목록의 항목 하나.
@immutable
final class LmsTodoRecord {
  const LmsTodoRecord({
    required this.kindCode,
    required this.kind,
    required this.courseRemoteId,
    required this.courseName,
    required this.title,
    required this.itemId,
    this.dueAt,
    this.dueTimeUnknown = false,
  });

  /// LMS가 준 종류 코드.
  final String kindCode;

  /// 앱의 종류([LmsParseConfig.kindOf]).
  final LmsItemKind kind;

  /// 과목의 원본 ID([lmsCourseRemoteId]).
  final String courseRemoteId;

  final String courseName;

  final String title;

  final String itemId;

  /// 마감(한국 시각). 날짜만 있으면 그날 23:59이고 [dueTimeUnknown]이 true다.
  final DateTime? dueAt;

  final bool dueTimeUnknown;

  /// 학기 값 [semester]를 붙인 원본 키.
  String remoteKey(String semester) =>
      '$semester:$courseRemoteId:$kindCode:$itemId';

  @override
  bool operator ==(Object other) =>
      other is LmsTodoRecord &&
      other.kindCode == kindCode &&
      other.kind == kind &&
      other.courseRemoteId == courseRemoteId &&
      other.courseName == courseName &&
      other.title == title &&
      other.itemId == itemId &&
      other.dueAt == dueAt &&
      other.dueTimeUnknown == dueTimeUnknown;

  @override
  int get hashCode => Object.hash(
    kindCode,
    kind,
    courseRemoteId,
    courseName,
    title,
    itemId,
    dueAt,
    dueTimeUnknown,
  );
}

/// 종류 대응 [config]로 할 일 목록 응답을 읽는 스키마. 항목 수는 할 일 수다.
LmsSchema<List<LmsTodoRecord>> todoListSchema(LmsParseConfig config) => (json) {
  if (json is! Map) return const LmsSchemaMismatch('body');
  final body = json['body'];
  if (body is! Map) return const LmsSchemaMismatch('body');
  final list = body['todo_list'];
  if (list is! List) return const LmsSchemaMismatch('body.todo_list');
  final todos = <LmsTodoRecord>[];
  for (final item in list) {
    if (item is! Map) return const LmsSchemaMismatch('body.todo_list');
    final read = _todo(item, config);
    switch (read) {
      case LmsTodoRecord():
        todos.add(read);
      case String():
        return LmsSchemaMismatch('body.todo_list.$read');
    }
  }
  return LmsSchemaMatch(todos, itemCount: todos.length);
};

/// 항목 하나를 읽는다. 읽지 못하면 맞지 않은 필드 이름이다.
Object _todo(Map<Object?, Object?> item, LmsParseConfig config) {
  final kindCode = lmsIdText(item['module_type']);
  if (kindCode == null) return 'module_type';
  final courseId = lmsIdText(item['course_id']);
  if (courseId == null) return 'course_id';
  final classNo = lmsIdText(item['class_no']);
  if (classNo == null) return 'class_no';
  final courseName = item['course_nm'];
  if (courseName is! String || courseName.trim().isEmpty) return 'course_nm';
  final title = item['item_title_temp'];
  if (title is! String || title.trim().isEmpty) return 'item_title_temp';
  final itemId = _itemId(item);
  if (itemId == null) return 'item_id';
  final due = item['info'];
  if (due != null && due is! String) return 'info';
  final parsedDue = parseLmsDateTime(due as String?);
  // 비어 있지 않은데 읽을 수 없으면 꼴이 바뀐 것으로 보고 해석 실패다(마감이 조용히 사라지지 않게).
  if (parsedDue == null && (due?.trim().isNotEmpty ?? false)) return 'info';
  return LmsTodoRecord(
    kindCode: kindCode,
    kind: config.kindOf(kindCode),
    courseRemoteId: lmsCourseRemoteId(courseId, classNo),
    courseName: courseName.trim(),
    title: title.trim(),
    itemId: itemId,
    dueAt: parsedDue?.at,
    dueTimeUnknown: parsedDue?.timeUnknown ?? false,
  );
}

/// 항목 ID. 항목 ID, 콘텐츠 ID, 주차·차시 순서로 처음 있는 값이다.
String? _itemId(Map<Object?, Object?> item) {
  if (lmsIdText(item['item_id']) case final id?) return id;
  if (lmsIdText(item['contents_id']) case final id?) return id;
  final week = lmsIdText(item['week_no']);
  final seq = lmsIdText(item['seq_no']);
  return week != null && seq != null ? 'w$week-s$seq' : null;
}
