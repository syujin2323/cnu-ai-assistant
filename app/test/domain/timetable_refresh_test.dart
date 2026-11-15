// 시간표 새로 고침의 비교 테스트. docs/lms.md '시간표 (통합정보시스템)'. 수업 칸은 모두 합성 값이다.

import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

/// 불러온 수업 칸. 원래 값은 따로 주지 않으면 지금 값과 같다.
ClassSlot _slot(
  int id, {
  int course = 1,
  int weekday = 1,
  int start = 540,
  int end = 615,
  String? place = '합성관101',
  int? importedWeekday,
  int? importedStart,
  int? importedEnd,
  String? importedPlace = '합성관101',
  bool placeEdited = false,
  bool online = false,
  SlotSource source = SlotSource.auto,
}) => ClassSlot(
  id: id,
  courseId: course,
  weekday: weekday,
  startMin: start,
  endMin: end,
  place: place,
  campus: Campus.daedeok,
  online: online,
  source: source,
  importedWeekday: source == SlotSource.auto
      ? importedWeekday ?? weekday
      : null,
  importedStartMin: source == SlotSource.auto ? importedStart ?? start : null,
  importedEndMin: source == SlotSource.auto ? importedEnd ?? end : null,
  importedPlace: source == SlotSource.auto ? importedPlace : null,
  placeEdited: placeEdited,
);

ImportedClassSlot _at(
  int weekday, {
  int start = 540,
  int end = 615,
  String? place = '합성관101',
}) => ImportedClassSlot(
  weekday: weekday,
  startMin: start,
  endMin: end,
  place: place,
);

void main() {
  test('불러온 수업이 없는 과목은 받은 칸을 모두 바로 넣는다', () {
    final diff = compareTimetable(
      existing: [_slot(1, course: 2, source: SlotSource.manual)],
      fetched: {
        2: [_at(3), _at(1)],
        3: const [],
      },
    );

    expect(diff.added, {
      2: [_at(1), _at(3)],
    });
    expect(diff.addedCount, 2);
    expect(diff.changes, isEmpty);
  });

  test('원래 요일·시각과 강의실이 그대로면 아무것도 하지 않는다', () {
    final diff = compareTimetable(
      existing: [_slot(1), _slot(2, weekday: 3)],
      fetched: {
        1: [_at(3), _at(1)],
      },
    );

    expect(diff.added, isEmpty);
    expect(diff.changes, isEmpty);
  });

  test('학교 쪽 강의실이 바뀌면 묻고, 장소를 고쳤거나 실시간 온라인이면 묻지 않는다', () {
    final moved = compareTimetable(
      existing: [_slot(1)],
      fetched: {
        1: [_at(1, place: '합성관202')],
      },
    );
    final update = moved.changes.single as TimetableSlotUpdate;
    expect(update.slot.id, 1);
    expect(update.reasons, {TimetableUpdateReason.schoolPlace});
    expect(update.to, _at(1, place: '합성관202'));
    expect(update.imported, _at(1, place: '합성관202'));

    for (final slot in [
      _slot(1, place: '내가 고친 곳', placeEdited: true),
      _slot(1, online: true),
    ]) {
      expect(
        compareTimetable(
          existing: [slot],
          fetched: {
            1: [_at(1, place: '합성관202')],
          },
        ).changes,
        isEmpty,
      );
    }
  });

  test('사용자가 고친 요일·시각이 원래 값과 다르면 원래 값으로 맞출지 묻고 장소는 둔다', () {
    final diff = compareTimetable(
      existing: [
        _slot(
          1,
          weekday: 2,
          start: 600,
          end: 675,
          importedWeekday: 1,
          importedStart: 540,
          importedEnd: 615,
        ),
      ],
      fetched: {
        1: [_at(1)],
      },
    );

    final update = diff.changes.single as TimetableSlotUpdate;
    expect(update.reasons, {TimetableUpdateReason.userTime});
    expect(update.to, _at(1));
    expect(update.imported, _at(1));
  });

  test('남은 칸은 요일·시작 순서로 짝지어 학교 쪽 시간이 바뀐 것으로 묻고, 장소를 고쳤으면 장소는 둔다', () {
    final diff = compareTimetable(
      existing: [
        _slot(1, weekday: 1),
        _slot(2, weekday: 3, place: '내가 고친 곳', placeEdited: true),
      ],
      fetched: {
        1: [_at(4, start: 600, end: 690), _at(2, place: '합성관303')],
      },
    );

    final updates = diff.changes.cast<TimetableSlotUpdate>();
    expect(updates.map((u) => u.slot.id), [1, 2]);
    expect(updates.first.reasons, {
      TimetableUpdateReason.schoolTime,
      TimetableUpdateReason.schoolPlace,
    });
    expect(updates.first.to, _at(2, place: '합성관303'));
    expect(updates.last.reasons, {TimetableUpdateReason.schoolTime});
    expect(updates.last.to, _at(4, start: 600, end: 690, place: '내가 고친 곳'));
    expect(updates.last.imported, _at(4, start: 600, end: 690));
    expect(diff.added, isEmpty);
  });

  test('남은 받은 칸은 새 수업이라 바로 넣고, 남은 옛 칸은 없어진 수업이라 지울지 묻는다', () {
    final added = compareTimetable(
      existing: [_slot(1)],
      fetched: {
        1: [_at(1), _at(5)],
      },
    );
    expect(added.added, {
      1: [_at(5)],
    });
    expect(added.changes, isEmpty);

    final removed = compareTimetable(
      existing: [_slot(1), _slot(2, weekday: 5)],
      fetched: {
        1: [_at(1)],
      },
    );
    expect(removed.added, isEmpty);
    expect(removed.changes.map((c) => (c.runtimeType, c.slot.id)), [
      (TimetableSlotRemoval, 2),
    ]);
  });

  test('과목 목록에서 빠진 과목의 불러온 수업은 지울지 묻고, 받지 못한 과목과 직접 넣은 수업은 견주지 않는다', () {
    final diff = compareTimetable(
      existing: [
        _slot(1, course: 1),
        _slot(2, course: 2),
        _slot(3, course: 3),
        _slot(4, course: 2, weekday: 4, source: SlotSource.manual),
      ],
      fetched: {
        1: [_at(1)],
      },
      dropped: {2},
    );

    expect(diff.changes.map((c) => (c.runtimeType, c.slot.id)), [
      (TimetableSlotRemoval, 2),
    ]);
    expect(diff.added, isEmpty);
  });

  test('원래 값이 없는 불러온 칸은 지금 값을 원래 값으로 본다', () {
    final slot = ClassSlot(
      id: 9,
      courseId: 1,
      weekday: 1,
      startMin: 540,
      endMin: 615,
      place: '합성관101',
      campus: Campus.daedeok,
      online: false,
      source: SlotSource.auto,
    );

    expect(
      compareTimetable(
        existing: [slot],
        fetched: {
          1: [_at(1)],
        },
      ).changes,
      isEmpty,
    );
  });
}
