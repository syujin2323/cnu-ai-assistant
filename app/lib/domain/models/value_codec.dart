// 열거형과 시각을 폰 DB(JSON 값 포함)에 적는 형식. docs/architecture.md '폰 DB'의 공통 규칙.
//
// - 열거형은 Dart enum 이름(camelCase)이 아니라 영문 snake_case로 적는다
//   (`placeChange` → `place_change`). drift 열은 `data/db/enum_converter.dart`가,
//   JSON 값은 모델의 `fromJson`/`toJson`이 이 함수를 쓴다.
// - 시각은 drift의 `store_date_time_values_as_text`와 같은 형식이다. 로컬 시각 뒤에
//   UTC 오프셋을 붙이고(`2026-10-29T09:30:00.000 +09:00`), 읽을 때 로컬로 돌린다.

/// 열거형 값의 DB 표기(영문 snake_case).
String snakeName(Enum value) => value.name.replaceAllMapped(
  _upperCase,
  (match) => '_${match[0]!.toLowerCase()}',
);

/// [snakeName]의 반대. 모르는 값이면 [FormatException]을 던진다.
T enumFromSnake<T extends Enum>(List<T> values, String text) {
  final value = tryEnumFromSnake(values, text);
  if (value == null) {
    throw FormatException('Unknown $T value', text);
  }
  return value;
}

/// [enumFromSnake]와 같지만, 문자열이 아니거나 모르는 값이면 null을 돌려준다.
T? tryEnumFromSnake<T extends Enum>(List<T> values, Object? text) {
  if (text is! String) return null;
  for (final value in values) {
    if (snakeName(value) == text) return value;
  }
  return null;
}

/// 시각을 로컬 시각과 UTC 오프셋으로 적는다(`2026-10-29T09:30:00.000 +09:00`).
String encodeDateTime(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  final hh = (minutes ~/ 60).toString().padLeft(2, '0');
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '${local.toIso8601String()} $sign$hh:$mm';
}

/// [encodeDateTime]의 반대. 늘 로컬 시각으로 돌려준다.
/// 형식이 맞지 않으면 [FormatException]을 던진다.
DateTime decodeDateTime(String text) => DateTime.parse(text).toLocal();

/// [encodeDateTime]이 적은 시각을 읽어 로컬 시각으로 돌려준다. 문자열이 아니거나 형식이
/// 맞지 않으면 null이다. UTC 오프셋(`Z` 포함)이 없는 값('2026-10-29' 등)도 null로 본다.
/// 오프셋이 없으면 읽는 기기의 시간대에 따라 다른 시각이 되기 때문이다.
DateTime? tryDecodeDateTime(Object? text) {
  if (text is! String) return null;
  final parsed = DateTime.tryParse(text);
  // DateTime.tryParse는 오프셋이 있는 문자열만 UTC 값으로 돌려준다.
  if (parsed == null || !parsed.isUtc) return null;
  return parsed.toLocal();
}

final _upperCase = RegExp('[A-Z]');
