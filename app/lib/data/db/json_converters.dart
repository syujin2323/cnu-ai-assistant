// 구조가 있는 값을 TEXT 열에 JSON 문자열로 두는 변환기(docs/architecture.md '폰 DB').
// JSON 모양은 도메인 모델의 `fromJson`/`toJson`이 정하고, 여기서는 문자열로만 바꾼다.
// null을 받는 열에 걸면 drift가 null을 그대로 넘기므로 null은 다루지 않는다([BlockReasonConverter]는 예외).
// 읽을 수 없는 값(깨진 JSON, 형이 틀린 값, 모르는 열거값)은 열마다 정한 대로 다룬다(docs/decisions.md
// 2026-11-14 '모르는 값이 든 행은 안전한 열만 대체값으로 읽는다'): 블록 근거는 null(근거 없음), 규칙 값은
// 그 행만 [UnreadableRuleParams], 정수 배열은 [FormatException](그 표 읽기가 `StorageError`가 됨).

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

/// `plan_blocks.reason` ↔ JSON 객체. 근거는 안내용이라 읽을 수 없으면 null(근거 없음)로 읽는다.
class BlockReasonConverter extends TypeConverter<BlockReason?, String?> {
  const BlockReasonConverter();

  @override
  BlockReason? fromSql(String? fromDb) {
    if (fromDb == null) return null;
    try {
      return BlockReason.fromJson(_decodeObject(fromDb));
    } on FormatException {
      return null;
    }
  }

  @override
  String? toSql(BlockReason? value) =>
      value == null ? null : jsonEncode(value.toJson());
}

/// `rules.params` ↔ JSON 객체. 읽을 수 없으면 그 행만 [UnreadableRuleParams]로 읽고(원래 문자열을 담음),
/// 다시 쓸 때도 그 문자열을 그대로 쓴다.
class RuleParamsConverter extends TypeConverter<RuleParams, String> {
  const RuleParamsConverter();

  @override
  RuleParams fromSql(String fromDb) {
    try {
      return RuleParams.fromJson(_decodeObject(fromDb));
    } on FormatException {
      return UnreadableRuleParams(fromDb);
    }
  }

  @override
  String toSql(RuleParams value) =>
      value is UnreadableRuleParams ? value.source : jsonEncode(value.toJson());
}

Map<String, Object?> _decodeObject(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return decoded;
}
