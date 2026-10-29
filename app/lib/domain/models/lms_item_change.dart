/// 사캠 항목의 마감·제출·완료 값이 바뀐 기록. `lms_item_changes` 표의 한 행.
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

  /// 바뀐 열의 이름.
  final String field;

  final String? oldValue;

  final String? newValue;

  final DateTime changedAt;
}
