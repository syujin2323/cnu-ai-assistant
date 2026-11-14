import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:drift/drift.dart';

/// Dart enum과 DB의 영문 snake_case 문자열을 오가는 공용 변환기.
///
/// enum 이름은 camelCase(`placeChange`), DB 값은 snake_case(`place_change`)다
/// (docs/architecture.md '폰 DB'). 표에 모르는 값(새 버전이 쓴 값 등)이 있으면 [fallback]으로 읽고,
/// [fallback]이 없으면 [FormatException]이다(그 표 읽기는 저장소에서 `StorageError`가 된다). [fallback]은
/// 그 값으로 읽어도 해가 없는 열에만 둔다(docs/decisions.md 2026-11-14 '모르는 값이 든 행은 안전한 열만
/// 대체값으로 읽는다').
class EnumConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumConverter(this.values, {this.fallback});

  final List<T> values;

  /// 모르는 값을 읽을 때 쓰는 값. null이면 모르는 값은 [FormatException]이다.
  final T? fallback;

  @override
  T fromSql(String fromDb) {
    final fallback = this.fallback;
    if (fallback == null) return enumFromSnake(values, fromDb);
    return tryEnumFromSnake(values, fromDb) ?? fallback;
  }

  @override
  String toSql(T value) => snakeName(value);
}
