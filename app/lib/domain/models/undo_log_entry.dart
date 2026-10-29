/// 되돌릴 동작의 종류.
enum UndoAction { insert, update, delete }

/// 마지막 동작 하나를 되돌리기 위한 기록. `undo_log` 표의 한 행이고 [id]는 늘 1이다.
///
/// 저장소 층이 동작마다 직전 상태로 이 행을 덮어쓴다(docs/architecture.md '폰 DB'의
/// 되돌리기).
class UndoLogEntry {
  const UndoLogEntry({
    required this.id,
    required this.targetTable,
    required this.action,
    this.rowId,
    this.beforeJson,
    required this.createdAt,
  });

  final int id;

  /// 바뀐 표의 이름(예: `plan_blocks`). DB 열 이름은 `table_name`이다.
  final String targetTable;

  final UndoAction action;

  /// 바뀐 행의 id. 여러 행을 한 번에 바꾼 동작이면 null.
  final int? rowId;

  /// 바뀌기 전 상태의 JSON. 여러 행이면 행들의 배열이다.
  final String? beforeJson;

  final DateTime createdAt;
}
