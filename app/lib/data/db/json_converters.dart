// 구조가 있는 값을 TEXT 열에 JSON 문자열로 두는 변환기(docs/architecture.md '폰 DB').
// JSON 모양은 도메인 모델의 `fromJson`/`toJson`이 정하고, 여기서는 문자열로만 바꾼다.
// null을 받는 열에 걸면 drift가 null을 그대로 넘기므로 null은 다루지 않는다.

import 'dart:convert';

import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:drift/drift.dart';

/// 정수 배열(요일 1–7, 과목 id 등) ↔ JSON 배열.
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! List || !decoded.every((element) => element is int)) {
      throw const FormatException('Expected a JSON array of integers');
    }
    return List<int>.unmodifiable(decoded.cast<int>());
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

/// `plan_blocks.reason` ↔ JSON 객체.
class BlockReasonConverter extends TypeConverter<BlockReason, String> {
  const BlockReasonConverter();

  @override
  BlockReason fromSql(String fromDb) =>
      BlockReason.fromJson(_decodeObject(fromDb));

  @override
  String toSql(BlockReason value) => jsonEncode(value.toJson());
}

/// `rules.params` ↔ JSON 객체.
class RuleParamsConverter extends TypeConverter<RuleParams, String> {
  const RuleParamsConverter();

  @override
  RuleParams fromSql(String fromDb) =>
      RuleParams.fromJson(_decodeObject(fromDb));

  @override
  String toSql(RuleParams value) => jsonEncode(value.toJson());
}

Map<String, Object?> _decodeObject(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return decoded;
}
