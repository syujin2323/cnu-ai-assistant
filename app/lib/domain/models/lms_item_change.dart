/// LMS 항목의 마감·제출·완료 값이 바뀐 기록. `lms_item_changes` 표의 한 행.
class LmsItemChange {
  const LmsItemChange({
    required this.id,
    required this.remoteKey,
    required this.field,
    this.oldValue,
    this.newValue,
    required this.changedAt,
  });

  final int id;

  /// `lms_items.remoteKey`.
  final String remoteKey;

  /// 바뀐 열의 이름([LmsItemChangeField]).
  final String field;

  final String? oldValue;

  final String? newValue;

  final DateTime changedAt;
}

/// `lms_item_changes.field`에 적는 값. 바뀐 `lms_items` 열의 SQL 이름이다(docs/lms.md '응답 해석':
/// 마감·제출·출석 인정이 바뀌면 남긴다). 동기화가 쓰고 03 할 일의 '마감 변경'이 읽는다.
abstract final class LmsItemChangeField {
  static const dueAt = 'due_at';
  static const submitted = 'submitted';
  static const officiallyDone = 'officially_done';
}
