// 시간표 새로 고침의 비교. docs/lms.md '시간표 (통합정보시스템)', docs/decisions.md 2026-11-15 '13 새로 고침은 새 수업을
// 바로 넣고 바뀌거나 없어진 수업은 묻는다'.
//
// 통합정보시스템에서 받은 과목별 수업 칸을 폰 DB의 불러온 수업(`source` `auto`)과 견준다. 수업은 불러온 원래 값
// (`imported*`)으로 맞춘다.
//
// - 원래 요일·시각이 같은 칸은 같은 수업이다. 학교 쪽 강의실이 바뀌었으면 반영할지 묻되, 사용자가 장소를 고쳤거나
//   실시간 온라인 수업이면 묻지 않는다. 사용자가 고친 요일·시각이 원래 값과 다르면 원래 값으로 맞출지 묻는다.
// - 남은 칸은 과목 안에서 요일·시작 순서로 짝지어 학교 쪽 시간이 바뀐 것으로 보고 반영할지 묻는다.
// - 그래도 남은 받은 칸은 새 수업이라 바로 넣고, 남은 옛 칸은 없어진 수업이라 지울지 묻는다. 과목 목록에서 빠진 이번
//   학기 과목의 수업도 지울지 묻는다.
// - 불러온 수업이 없는 과목(처음 불러오는 과목)은 받은 칸을 모두 넣는다.
//
// 받지 못한(실패한) 과목의 수업은 견주지 않는다. 같은 입력이면 늘 같은 결과다.

import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';

/// 새로 고침에서 반영할지 묻는 바뀜. [slot]은 견줄 때 폰 DB에 있던 수업 칸이다.
sealed class TimetableChange {
  const TimetableChange(this.slot);

  final ClassSlot slot;
}

/// 반영할지 묻는 까닭.
enum TimetableUpdateReason {
  /// 학교 쪽 요일·시각이 바뀌었다.
  schoolTime,

  /// 학교 쪽 강의실이 바뀌었다(사용자가 장소를 고치지 않았고 실시간 온라인이 아님).
  schoolPlace,

  /// 사용자가 고친 요일·시각이 불러온 원래 값과 다르다(원래 값으로 맞출지).
  userTime,
}

/// 수업 칸 하나를 고칠지 묻는다. 반영하면 [slot]의 요일·시각·장소를 [to]로, 불러온 원래 값을 [imported]로 바꾼다.
final class TimetableSlotUpdate extends TimetableChange {
  const TimetableSlotUpdate(
    super.slot, {
    required this.to,
    required this.imported,
    required this.reasons,
  });

  final ImportedClassSlot to;

  final ImportedClassSlot imported;

  final Set<TimetableUpdateReason> reasons;
}

/// 학교 시간표에서 없어진 수업 칸을 지울지 묻는다. 반영하면 [slot]과 그 수업 예외를 지운다.
final class TimetableSlotRemoval extends TimetableChange {
  const TimetableSlotRemoval(super.slot);
}

/// 새로 고침의 비교 결과.
final class TimetableDiff {
  const TimetableDiff({this.added = const {}, this.changes = const []});

  /// 바로 넣을 새 수업 칸(`courses.id` → 칸).
  final Map<int, List<ImportedClassSlot>> added;

  /// 반영할지 물을 바뀜.
  final List<TimetableChange> changes;

  /// 바로 넣을 칸 수.
  int get addedCount =>
      added.values.fold(0, (count, slots) => count + slots.length);
}

/// [fetched](`courses.id` → 이번에 받은 칸. 받지 못한 과목은 없음)를 [existing](폰 DB의 수업 칸)과 견준다. [dropped]는
/// 과목 목록에서 빠진 이번 학기 과목이다. [existing]에서 불러온 수업(`source` `auto`)만 본다.
TimetableDiff compareTimetable({
  required List<ClassSlot> existing,
  required Map<int, List<ImportedClassSlot>> fetched,
  Set<int> dropped = const {},
}) {
  final added = <int, List<ImportedClassSlot>>{};
  final changes = <TimetableChange>[];
  final imported = [
    for (final slot in existing)
      if (slot.source == SlotSource.auto) slot,
  ]..sort(_byImportedTime);

  for (final MapEntry(key: courseId, value: received)
      in fetched.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final news = [...received]..sort(_byTime);
    final olds = [
      for (final slot in imported)
        if (slot.courseId == courseId) slot,
    ];
    if (olds.isEmpty) {
      if (news.isNotEmpty) added[courseId] = news;
      continue;
    }
    final unmatchedOld = <ClassSlot>[];
    for (final old in olds) {
      final original = _importedOf(old);
      final at = news.indexWhere(original.sameTime);
      if (at < 0) {
        unmatchedOld.add(old);
        continue;
      }
      final school = news.removeAt(at);
      final reasons = <TimetableUpdateReason>{};
      if (!_currentOf(old).sameTime(original)) {
        reasons.add(TimetableUpdateReason.userTime);
      }
      final placeFollows = !old.placeEdited && !old.online;
      if (placeFollows && school.place != original.place) {
        reasons.add(TimetableUpdateReason.schoolPlace);
      }
      if (reasons.isEmpty) continue;
      changes.add(
        TimetableSlotUpdate(
          old,
          to: ImportedClassSlot(
            weekday: school.weekday,
            startMin: school.startMin,
            endMin: school.endMin,
            place: reasons.contains(TimetableUpdateReason.schoolPlace)
                ? school.place
                : old.place,
          ),
          imported: school,
          reasons: reasons,
        ),
      );
    }
    final paired = unmatchedOld.length < news.length
        ? unmatchedOld.length
        : news.length;
    for (var i = 0; i < paired; i++) {
      final old = unmatchedOld[i];
      final school = news[i];
      final placeFollows = !old.placeEdited && !old.online;
      changes.add(
        TimetableSlotUpdate(
          old,
          to: ImportedClassSlot(
            weekday: school.weekday,
            startMin: school.startMin,
            endMin: school.endMin,
            place: placeFollows ? school.place : old.place,
          ),
          imported: school,
          reasons: {
            TimetableUpdateReason.schoolTime,
            if (placeFollows && school.place != _importedOf(old).place)
              TimetableUpdateReason.schoolPlace,
          },
        ),
      );
    }
    if (news.length > paired) added[courseId] = news.sublist(paired);
    for (final old in unmatchedOld.skip(paired)) {
      changes.add(TimetableSlotRemoval(old));
    }
  }

  for (final slot in imported) {
    if (dropped.contains(slot.courseId) &&
        !fetched.containsKey(slot.courseId)) {
      changes.add(TimetableSlotRemoval(slot));
    }
  }
  return TimetableDiff(added: added, changes: changes);
}

/// 수업 칸의 지금 요일·시각·장소.
ImportedClassSlot _currentOf(ClassSlot slot) => ImportedClassSlot(
  weekday: slot.weekday,
  startMin: slot.startMin,
  endMin: slot.endMin,
  place: slot.place,
);

/// 수업 칸의 불러온 원래 값. 없으면(셋이 함께 없음) 지금 값이다.
ImportedClassSlot _importedOf(ClassSlot slot) => switch ((
  slot.importedWeekday,
  slot.importedStartMin,
  slot.importedEndMin,
)) {
  (final weekday?, final start?, final end?) => ImportedClassSlot(
    weekday: weekday,
    startMin: start,
    endMin: end,
    place: slot.importedPlace,
  ),
  _ => _currentOf(slot),
};

int _byTime(ImportedClassSlot a, ImportedClassSlot b) {
  final day = a.weekday.compareTo(b.weekday);
  if (day != 0) return day;
  final start = a.startMin.compareTo(b.startMin);
  return start != 0 ? start : a.endMin.compareTo(b.endMin);
}

int _byImportedTime(ClassSlot a, ClassSlot b) {
  final time = _byTime(_importedOf(a), _importedOf(b));
  return time != 0 ? time : a.id.compareTo(b.id);
}
