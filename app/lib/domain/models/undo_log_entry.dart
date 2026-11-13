import 'dart:convert';

/// 되돌릴 동작의 종류.
enum UndoAction { insert, update, delete }

/// 마지막 동작 하나를 되돌리기 위한 기록. `undo_log` 표의 한 행이고 [id]는 늘 1이다.
///
/// 저장소 층이 동작마다 이 행을 덮어쓴다(docs/architecture.md '폰 DB'의 되돌리기). [targetTable]·
/// [action]·[rowId]는 그 동작의 요약(토스트 문구 등)이고, 되돌리는 방법은 [beforeJson]의 단계
/// 목록([UndoStep])이 정한다.
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

  /// 그 동작이 주로 바꾼 표의 이름(예: `rules`). DB 열 이름은 `table_name`이다.
  final String targetTable;

  /// 그 동작의 종류(새로 넣음·고침·지움).
  final UndoAction action;

  /// 바뀐 행의 id. 여러 행을 한 번에 바꾼 동작이면 null.
  final int? rowId;

  /// 되돌리기 단계 목록의 JSON 배열([encodeUndoSteps]). 되돌릴 때는 뒤에서부터 적용한다.
  final String? beforeJson;

  final DateTime createdAt;
}

/// 되돌리기 한 단계. 동작이 행을 바꾸기 전에 기록하고, 되돌릴 때는 기록한 순서의 반대로 적용한다.
/// [table]은 SQL 표 이름이고, 행 값은 폰 DB에 저장된 그대로(열 이름과 SQL 값)다.
sealed class UndoStep {
  const UndoStep(this.table);

  /// 표 이름(예: `rules`).
  final String table;

  Map<String, Object?> toJson();

  /// [json]에서 읽는다. 모양이 맞지 않으면 [FormatException]이다.
  static UndoStep fromJson(Map<String, Object?> json) {
    final table = json['table'];
    if (table is! String) throw const FormatException('undo step table');
    return switch (json['op']) {
      'delete' => UndoDelete(table, _id(json)),
      'restore' => UndoRestore(table, _values(json, 'row')),
      'patch' => UndoPatch(table, _id(json), _values(json, 'values')),
      _ => throw const FormatException('undo step op'),
    };
  }
}

/// 그 동작이 새로 넣은 행을 지운다.
final class UndoDelete extends UndoStep {
  const UndoDelete(super.table, this.id);

  final int id;

  @override
  Map<String, Object?> toJson() => {'table': table, 'op': 'delete', 'id': id};
}

/// 그 동작이 고치거나 지운 행을 직전 값 그대로 되살린다. 행이 없으면 넣고, 있으면 모든 열을 덮어쓴다.
/// [row]는 그 행의 모든 열(`id` 포함)이다.
final class UndoRestore extends UndoStep {
  const UndoRestore(super.table, this.row);

  final Map<String, Object?> row;

  @override
  Map<String, Object?> toJson() => {
    'table': table,
    'op': 'restore',
    'row': row,
  };
}

/// 행의 일부 열만 직전 값으로 되돌린다. 동기화가 바꾸는 열이 있는 표(`tasks`의 복사 열)는 사용자 열만
/// 이것으로 담아, 그사이 동기화가 바꾼 값을 되돌리지 않는다.
final class UndoPatch extends UndoStep {
  const UndoPatch(super.table, this.id, this.values);

  final int id;

  /// 되돌릴 열과 직전 값(`id` 제외).
  final Map<String, Object?> values;

  @override
  Map<String, Object?> toJson() => {
    'table': table,
    'op': 'patch',
    'id': id,
    'values': values,
  };
}

/// 단계 목록을 [UndoLogEntry.beforeJson]에 넣을 JSON 문자열로 바꾼다.
String encodeUndoSteps(List<UndoStep> steps) =>
    jsonEncode([for (final step in steps) step.toJson()]);

/// [encodeUndoSteps]의 결과를 읽는다. 모양이 맞지 않으면 [FormatException]이다.
List<UndoStep> decodeUndoSteps(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) throw const FormatException('undo steps');
  return [
    for (final step in decoded)
      if (step is Map<String, Object?>)
        UndoStep.fromJson(step)
      else
        throw const FormatException('undo step'),
  ];
}

int _id(Map<String, Object?> json) {
  final id = json['id'];
  if (id is! int) throw const FormatException('undo step id');
  return id;
}

Map<String, Object?> _values(Map<String, Object?> json, String key) {
  final values = json[key];
  if (values is! Map<String, Object?> || values.isEmpty) {
    throw FormatException('undo step $key');
  }
  return values;
}
