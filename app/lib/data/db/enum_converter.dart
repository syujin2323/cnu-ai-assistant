import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:drift/drift.dart';

/// Dart enum과 DB의 영문 snake_case 문자열을 오가는 공용 변환기.
///
/// enum 이름은 camelCase(`placeChange`), DB 값은 snake_case(`place_change`)다
/// (docs/architecture.md '폰 DB'). 표에 모르는 값이 있으면 [FormatException]이다.
class EnumConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) => enumFromSnake(values, fromDb);

  @override
  String toSql(T value) => snakeName(value);
}
