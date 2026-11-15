// 시간표 글자 해석. docs/lms.md '시간표 (통합정보시스템)'.
//
// 과목의 시간표 글자에서 요청 상수의 정규식(`parse.timetable.slot`)에 맞는 자리를 모두 찾아 수업 칸으로 읽는다. 요일은
// 월–일 한 글자, 시각은 `H:MM`·`HH:MM`이고 강의실은 있으면 쓴다. 글자가 비었으면 수업 시간이 없는 과목(온라인 등)이라
// 빈 목록이다. 글자가 있는데 맞는 자리가 없거나, 요일·시각을 읽지 못하거나, 끝이 시작보다 이르면 해석 실패(null)다.
// 같은 칸이 두 번 나오면 한 번만 쓴다. 원문은 남기지 않는다.

import 'package:flutter/foundation.dart' show immutable;

/// 통합정보시스템에서 불러온 수업 칸 하나.
@immutable
final class LmsImportedSlot {
  const LmsImportedSlot({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.place,
  });

  /// 요일 1(월)–7(일).
  final int weekday;

  /// 시작·끝(자정 기준 분).
  final int startMin;
  final int endMin;

  /// 강의실. 없으면 null이다.
  final String? place;

  @override
  bool operator ==(Object other) =>
      other is LmsImportedSlot &&
      other.weekday == weekday &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.place == place;

  @override
  int get hashCode => Object.hash(weekday, startMin, endMin, place);
}

/// 시간표 글자 [text]를 [pattern](이름 붙은 묶음 `day`·`start`·`end`, 있으면 `place`)으로 읽는다. 해석하지 못하면
/// null이다.
List<LmsImportedSlot>? parseTimetableSlots(String text, RegExp pattern) {
  if (text.trim().isEmpty) return const [];
  final slots = <LmsImportedSlot>[];
  for (final match in pattern.allMatches(text)) {
    final weekday = _weekdays[match.namedGroup('day')];
    final start = _minuteOfDay(match.namedGroup('start'));
    final end = _minuteOfDay(match.namedGroup('end'));
    if (weekday == null || start == null || end == null || end <= start) {
      return null;
    }
    final place = match.groupNames.contains('place')
        ? match.namedGroup('place')?.trim()
        : null;
    final slot = LmsImportedSlot(
      weekday: weekday,
      startMin: start,
      endMin: end,
      place: place == null || place.isEmpty ? null : place,
    );
    if (!slots.contains(slot)) slots.add(slot);
  }
  return slots.isEmpty ? null : slots;
}

const _weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');

int? _minuteOfDay(String? text) {
  final match = _clock.firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
