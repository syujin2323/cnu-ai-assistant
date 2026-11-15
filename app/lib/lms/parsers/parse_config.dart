// 응답 해석 설정(`lms_request_params`의 `parse`). docs/lms.md '응답 해석'.
//
// 할 일 목록 응답의 종류 코드를 앱의 종류([LmsItemKind])로 바꾸는 대응은 LMS가 정한 값이라 레포에 두지 않고 요청 상수에서
// 받는다. 꼴(값은 지어낸 예): `{"kindCodes": {"video": ["K1"], "assignment": ["K2", "K3"]}}`. 키는 [LmsItemKind]의 이름,
// 값은 비어 있지 않은 코드 목록이고, 한 코드는 한 종류에만 둔다. 대응에 없는 코드는 할 일로 만들지 않는
// [LmsItemKind.material]로 읽는다. 요청 상수 전체를 읽는 `request_params.dart`가 동기화를 붙일 때 이 값을 함께 읽는다.
//
// 시간표 불러오기를 쓰면 과목의 시간표 글자에서 수업 칸 하나를 찾는 정규식도 받는다: `{"timetable": {"slot": 정규식}}`.
// 이름 붙은 묶음 `day`(월–일 한 글자), `start`·`end`(`H:MM`·`HH:MM`)가 있어야 하고 `place`(강의실)는 있으면 쓴다.

import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:flutter/foundation.dart' show immutable, mapEquals;

/// 응답 해석 설정.
@immutable
final class LmsParseConfig {
  const LmsParseConfig({required this.kindCodes, this.timetableSlot});

  /// 종류 코드 → 앱의 종류.
  final Map<String, LmsItemKind> kindCodes;

  /// 시간표 글자에서 수업 칸 하나를 찾는 정규식(`day`·`start`·`end`, 있으면 `place`). 시간표를 불러오지 않으면 null이다.
  final RegExp? timetableSlot;

  /// 종류 코드 [code]의 앱 종류. 모르는 코드면 [LmsItemKind.material]이다.
  LmsItemKind kindOf(String code) => kindCodes[code] ?? LmsItemKind.material;

  /// 요청 상수의 `parse` 값 [json]을 읽는다. 꼴이 맞지 않으면 null이다.
  static LmsParseConfig? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final raw = json['kindCodes'];
    if (raw is! Map<String, Object?> || raw.isEmpty) return null;
    final kindCodes = <String, LmsItemKind>{};
    for (final MapEntry(key: name, value: codes) in raw.entries) {
      final kind = LmsItemKind.values.asNameMap()[name];
      if (kind == null || codes is! List || codes.isEmpty) return null;
      for (final code in codes) {
        if (code is! String || code.isEmpty || kindCodes.containsKey(code)) {
          return null;
        }
        kindCodes[code] = kind;
      }
    }
    final rawTimetable = json['timetable'];
    RegExp? timetableSlot;
    if (rawTimetable != null) {
      if (rawTimetable is! Map<String, Object?>) return null;
      final source = rawTimetable['slot'];
      if (source is! String ||
          !_slotGroups.every((group) => source.contains('(?<$group>'))) {
        return null;
      }
      try {
        timetableSlot = RegExp(source);
      } on FormatException {
        return null;
      }
    }
    return LmsParseConfig(kindCodes: kindCodes, timetableSlot: timetableSlot);
  }

  static const _slotGroups = ['day', 'start', 'end'];

  @override
  bool operator ==(Object other) =>
      other is LmsParseConfig &&
      mapEquals(other.kindCodes, kindCodes) &&
      other.timetableSlot?.pattern == timetableSlot?.pattern;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(
      kindCodes.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    timetableSlot?.pattern,
  );
}
