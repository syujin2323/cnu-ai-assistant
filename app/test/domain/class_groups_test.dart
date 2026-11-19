// 시간표 수업 묶음·격자 배치·겹침 테스트. docs/screens.md '13 시간표·고정 일정'. 과목·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course(int id, String name) => Course(id: id, name: name);

ClassSlotEntry _entry(
  int id, {
  Course? course,
  int weekday = 1,
  int start = 540,
  int end = 615,
  String? place = '합성관101',
  bool online = false,
  bool recorded = false,
  SlotSource source = SlotSource.auto,
}) {
  final c = course ?? _course(1, '과목A');
  return ClassSlotEntry(
    slot: ClassSlot(
      id: id,
      courseId: c.id,
      weekday: weekday,
      startMin: start,
      endMin: end,
      place: place,
      online: online || recorded,
      recorded: recorded,
      source: source,
    ),
    course: c,
  );
}

void main() {
  group('groupClassSlots', () {
    test('과목·시각·장소·실시간 온라인·출처가 같은 칸을 한 수업으로 묶는다', () {
      final a = _course(1, '과목A');
      final b = _course(2, '과목B');
      final groups = groupClassSlots([
        _entry(4, course: a, weekday: 3),
        _entry(1, course: a, weekday: 1),
        _entry(2, course: a, weekday: 2, place: '합성관202'),
        _entry(3, course: b, weekday: 1, start: 600, end: 690),
        _entry(5, course: a, weekday: 5, source: SlotSource.manual),
        _entry(6, course: a, weekday: 4, online: true),
      ]);

      expect(
        groups.map(
          (g) =>
              '${g.course.name} ${g.weekdays.join(',')} ${g.slotIds.join(',')}',
        ),
        ['과목A 1,3 1,4', '과목B 1 3', '과목A 2 2', '과목A 4 6', '과목A 5 5'],
      );
      expect(groups.first.whenText, '월·수 09:00–10:15');
      expect(groups.first.place, '합성관101');
      expect(groups.first.source, SlotSource.auto);
    });

    test('녹화 강의로 바꾼 칸은 다른 수업으로 묶는다', () {
      final groups = groupClassSlots([
        _entry(1, weekday: 1),
        _entry(2, weekday: 3, recorded: true),
      ]);
      expect(groups.map((g) => (g.slotIds.single, g.recorded)), [
        (1, false),
        (2, true),
      ]);
    });

    test('같은 첫 요일·시각이면 과목 이름, 그다음 첫 칸 id 순서다', () {
      final groups = groupClassSlots([
        _entry(9, course: _course(2, '나과목')),
        _entry(8, course: _course(1, '가과목')),
        _entry(7, course: _course(3, '가과목')),
      ]);

      expect(groups.map((g) => g.slotIds.first), [7, 8, 9]);
    });
  });

  test('weekdaysText는 겹침 없이 요일 순서로 잇고, 비었으면 요일 없음이다', () {
    expect(weekdaysText([5, 1, 3, 1]), '월·수·금');
    expect(weekdaysText(const []), '요일 없음');
  });

  group('timetableGridLayout', () {
    test('수업이 없으면 월–금, 9–18시다', () {
      final layout = timetableGridLayout(const []);

      expect(layout.days, [1, 2, 3, 4, 5]);
      expect((layout.firstHour, layout.lastHour), (9, 18));
      expect(layout.spanMin, 540);
      expect(layout.byDay, isEmpty);
    });

    test('이르거나 늦은 수업에 맞춰 시간대를 늘리고, 토·일 수업이 있으면 월–일이다', () {
      final layout = timetableGridLayout([
        _entry(2, weekday: 6, start: 450, end: 540),
        _entry(1, weekday: 1, start: 1140, end: 1230),
        _entry(3, weekday: 1, start: 540, end: 615),
      ]);

      expect(layout.days, [1, 2, 3, 4, 5, 6, 7]);
      expect((layout.firstHour, layout.lastHour), (7, 21));
      expect(layout.byDay[1]!.map((e) => e.slot.id), [3, 1]);
      expect(layout.byDay[6]!.map((e) => e.slot.id), [2]);
    });

    test('녹화 강의는 격자에 두지 않고, 시간대와 요일 열도 늘리지 않는다', () {
      final layout = timetableGridLayout([
        _entry(1),
        _entry(2, weekday: 6, start: 420, end: 1320, recorded: true),
      ]);
      expect(layout.days, [1, 2, 3, 4, 5]);
      expect((layout.firstHour, layout.lastHour), (9, 18));
      expect(layout.byDay.keys, [1]);
    });

    test('자정을 넘는 칸은 24시에서 자른다', () {
      final layout = timetableGridLayout([_entry(1, start: 1320, end: 1500)]);

      expect(layout.lastHour, 24);
    });
  });

  group('overlappingClasses', () {
    final entries = [
      _entry(1, weekday: 1, start: 540, end: 615),
      _entry(2, weekday: 3, start: 540, end: 615),
      _entry(3, weekday: 1, start: 615, end: 690),
    ];

    test('고른 요일에서 시간이 겹치는 칸만 주고, 끝과 시작이 닿기만 하면 겹치지 않는다', () {
      expect(
        overlappingClasses(
          entries,
          weekdays: {1, 2},
          startMin: 600,
          endMin: 615,
        ).map((e) => e.slot.id),
        [1],
      );
      expect(
        overlappingClasses(
          entries,
          weekdays: {1},
          startMin: 600,
          endMin: 630,
        ).map((e) => e.slot.id),
        [1, 3],
      );
    });

    test('녹화 강의는 시간을 차지하지 않으므로 겹침으로 보지 않는다', () {
      expect(
        overlappingClasses(
          [_entry(1, recorded: true), _entry(2)],
          weekdays: {1},
          startMin: 540,
          endMin: 615,
        ).map((e) => e.slot.id),
        [2],
      );
    });

    test('고치는 수업의 칸은 뺀다', () {
      expect(
        overlappingClasses(
          entries,
          weekdays: {1, 3},
          startMin: 540,
          endMin: 615,
          exceptIds: {1, 2},
        ),
        isEmpty,
      );
    });
  });
}
