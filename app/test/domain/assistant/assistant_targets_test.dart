// 06 AI 비서의 수업 찾기·일정 대상 찾기·바꾼 뒤 값 테스트. docs/screens.md '06 AI 비서'의 카드 3·5.
//
// 오늘은 2026-11-19(목)이다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 19);

const _ds = Course(id: 1, name: '데이터구조');
const _os = Course(id: 2, name: '운영체제');

ClassSlotEntry _slot(int id, Course course, int weekday, int start, int end) =>
    ClassSlotEntry(
      slot: ClassSlot(
        id: id,
        courseId: course.id,
        weekday: weekday,
        startMin: start,
        endMin: end,
        place: '공대 5호관',
        online: false,
        source: SlotSource.auto,
      ),
      course: course,
    );

FixedBlock _fixed(
  int id,
  String name,
  List<int> weekdays,
  int start,
  int end,
) => FixedBlock(
  id: id,
  name: name,
  weekdays: weekdays,
  startMin: start,
  endMin: end,
  bufferMin: 0,
  kind: FixedBlockKind.other,
  source: EntrySource.manual,
);

Event _event(
  int id,
  String title,
  DateTime startAt,
  DateTime endAt, {
  bool allDay = false,
}) => Event(
  id: id,
  title: title,
  startAt: startAt,
  endAt: endAt,
  allDay: allDay,
  source: EventSource.manual,
);

void main() {
  group('sessionsOf', () {
    final snapshot = AssistantSnapshot(
      slots: [
        _slot(12, _ds, DateTime.thursday, 780, 870),
        _slot(11, _ds, DateTime.tuesday, 630, 720),
        _slot(13, _ds, DateTime.thursday, 540, 600),
        _slot(21, _os, DateTime.friday, 540, 630),
      ],
      exceptions: const [
        ClassException(
          id: 1,
          date: '2026-11-24',
          classSlotId: 11,
          kind: ClassExceptionKind.cancelled,
          source: EntrySource.manual,
        ),
        ClassException(
          id: 2,
          date: '2026-11-26',
          classSlotId: 12,
          kind: ClassExceptionKind.placeChange,
          place: '공대 2호관',
          source: EntrySource.manual,
        ),
        // 다른 날의 강의실 변경은 그날만 바꾼다.
        ClassException(
          id: 3,
          date: '2026-11-27',
          classSlotId: 12,
          kind: ClassExceptionKind.placeChange,
          place: '도서관',
          source: EntrySource.manual,
        ),
        ClassException(
          id: 4,
          date: '2026-11-19',
          classSlotId: 13,
          kind: ClassExceptionKind.makeup,
          startMin: 1200,
          endMin: 1260,
          source: EntrySource.manual,
        ),
      ],
    );

    test('오늘부터 2주 안의 그 과목 수업을 날짜·시작 순서로 주고, 휴강한 수업은 뺀다', () {
      final sessions = sessionsOf('데이터구조', snapshot, today: _today);
      expect(
        [
          for (final session in sessions)
            (session.date.day, session.slot.id, session.place),
        ],
        [
          (19, 13, '공대 5호관'),
          (19, 12, '공대 5호관'),
          (26, 13, '공대 5호관'),
          (26, 12, '공대 2호관'),
          (1, 11, '공대 5호관'),
        ],
      );
      expect(sessions.first.courseName, '데이터구조');
      expect((sessions.first.startMin, sessions.first.endMin), (540, 600));
    });

    test('날 수를 줄이면 그 안만 본다', () {
      final sessions = sessionsOf('데이터구조', snapshot, today: _today, days: 1);
      expect([for (final session in sessions) session.slot.id], [13, 12]);
      expect(sessionsOf('없는 과목', snapshot, today: _today), isEmpty);
    });

    test('보강을 넣을 칸은 요일·시작이 가장 이른 칸이고, 없으면 null이다', () {
      expect(anySlotOf('데이터구조', snapshot)?.id, 11);
      expect(anySlotOf('운영체제', snapshot)?.id, 21);
      expect(anySlotOf('없는 과목', snapshot), isNull);
    });
  });

  group('findTargets', () {
    final snapshot = AssistantSnapshot(
      fixedBlocks: [
        _fixed(5, '알바', [DateTime.saturday, DateTime.sunday], 840, 1020),
        _fixed(6, '스터디 모임', [DateTime.friday], 1140, 1260),
      ],
      events: [
        _event(
          8,
          '스터디',
          DateTime(2026, 11, 27, 15),
          DateTime(2026, 11, 27, 16),
        ),
        _event(
          7,
          '스터디',
          DateTime(2026, 11, 20, 15),
          DateTime(2026, 11, 20, 16),
        ),
        _event(
          9,
          '독서 모임',
          DateTime(2026, 11, 21),
          DateTime(2026, 11, 22),
          allDay: true,
        ),
      ],
    );

    List<int> ids(List<ChangeTarget> targets) => [
      for (final target in targets)
        switch (target) {
          EventTarget(:final event) => event.id,
          FixedTarget(:final block) => block.id,
        },
    ];

    test('두 글자 이상인 말이 제목에 들어 있는 수가 가장 많은 것을 고정 일정 먼저, 시작 순서로 준다', () {
      expect(ids(findTargets('스터디', null, snapshot)), [6, 7, 8]);
      expect(ids(findTargets('스터디 모임', null, snapshot)), [6]);
      expect(ids(findTargets('주말 알바', null, snapshot)), [5]);
    });

    test('세 글자 이상인 말은 제목이 그 말에 들어 있어도 맞고, 한 글자 말은 보지 않는다', () {
      expect(ids(findTargets('알바가', null, snapshot)), [5]);
      // 두 글자 말에 든 한 글자 제목은 맞지 않는다.
      final meal = AssistantSnapshot(
        fixedBlocks: [
          _fixed(9, '밥', [DateTime.monday], 720, 780),
        ],
      );
      expect(ids(findTargets('밥약', null, meal)), isEmpty);
      expect(ids(findTargets('밥약속', null, meal)), [9]);
      expect(ids(findTargets('알 바', null, snapshot)), isEmpty);
      expect(ids(findTargets(null, null, snapshot)), isEmpty);
      expect(ids(findTargets('  ', null, snapshot)), isEmpty);
    });

    test('대상의 날짜가 있으면 그날 일정과 그 요일 고정 일정에서 먼저 찾고, 없으면 날짜 없이 찾는다', () {
      expect(ids(findTargets('스터디', DateTime(2026, 11, 20), snapshot)), [6, 7]);
      expect(ids(findTargets('스터디', DateTime(2026, 11, 27), snapshot)), [6, 8]);
      expect(ids(findTargets('알바', DateTime(2026, 11, 22), snapshot)), [5]);
      expect(ids(findTargets('알바', DateTime(2026, 11, 23), snapshot)), [5]);
      expect(ids(findTargets('독서 모임', DateTime(2026, 11, 21), snapshot)), [9]);
    });
  });

  group('changedAfter', () {
    final study = EventTarget(
      _event(7, '스터디', DateTime(2026, 11, 20, 15), DateTime(2026, 11, 20, 16)),
    );
    final allDay = EventTarget(
      _event(
        9,
        '독서 모임',
        DateTime(2026, 11, 21),
        DateTime(2026, 11, 22),
        allDay: true,
      ),
    );
    final alba = FixedTarget(
      _fixed(5, '알바', [DateTime.saturday, DateTime.sunday], 840, 1020),
    );
    final club = FixedTarget(_fixed(6, '동아리', [DateTime.thursday], 1140, 1260));

    test('옮긴 분은 시작과 끝을 함께 옮긴다', () {
      final after =
          changedAfter(study, const ParseItem(shiftMinutes: -30))!
              as EventAfter;
      expect(after.startAt, DateTime(2026, 11, 20, 14, 30));
      expect(after.endAt, DateTime(2026, 11, 20, 15, 30));
      expect(after.allDay, isFalse);
    });

    test('새 시작만 말하면 길이를 두고, 끝도 말하면 그 끝이며 이르면 자정을 넘는다', () {
      final same =
          changedAfter(study, const ParseItem(startMin: 1080))! as EventAfter;
      expect(same.startAt, DateTime(2026, 11, 20, 18));
      expect(same.endAt, DateTime(2026, 11, 20, 19));
      final ended =
          changedAfter(study, const ParseItem(startMin: 1380, endMin: 60))!
              as EventAfter;
      expect(ended.endAt, DateTime(2026, 11, 21, 1));
      // 같은 시각을 끝으로 말하면 길이를 둔다(하루짜리 일정을 만들지 않음).
      final looped =
          changedAfter(study, const ParseItem(startMin: 1080, endMin: 1080))!
              as EventAfter;
      expect(looped.endAt, DateTime(2026, 11, 20, 19));
    });

    test('새 날짜로 옮기면 시각을 두고, 시각도 말하면 그 시각이다', () {
      final moved =
          changedAfter(study, ParseItem(date: DateTime(2026, 11, 23)))!
              as EventAfter;
      expect(moved.startAt, DateTime(2026, 11, 23, 15));
      expect(moved.endAt, DateTime(2026, 11, 23, 16));
      final both =
          changedAfter(
                study,
                ParseItem(date: DateTime(2026, 11, 23), startMin: 600),
              )!
              as EventAfter;
      expect(both.startAt, DateTime(2026, 11, 23, 10));
    });

    test('종일 일정은 날짜만 옮기고, 시각을 말하면 그 시각의 한 시간 일정이 된다', () {
      final moved =
          changedAfter(allDay, ParseItem(date: DateTime(2026, 11, 28)))!
              as EventAfter;
      expect(moved.allDay, isTrue);
      expect(moved.startAt, DateTime(2026, 11, 28));
      expect(moved.endAt, DateTime(2026, 11, 29));
      expect(changedAfter(allDay, const ParseItem(shiftMinutes: 60)), isNull);
      final timed =
          changedAfter(allDay, const ParseItem(startMin: 1140))! as EventAfter;
      expect(timed.allDay, isFalse);
      expect(timed.startAt, DateTime(2026, 11, 21, 19));
      expect(timed.endAt, DateTime(2026, 11, 21, 20));
    });

    test('바꿀 값이 없으면 null이다', () {
      expect(changedAfter(study, const ParseItem()), isNull);
      expect(changedAfter(alba, const ParseItem()), isNull);
      expect(
        changedAfter(
          alba,
          const ParseItem(
            repeat: ParseRepeat(
              freq: ParseRepeatFreq.weekly,
              weekdays: [DateTime.sunday, DateTime.saturday],
            ),
          ),
        ),
        isNull,
      );
    });

    test('고정 일정은 반복 요일로 옮기고, 요일이 하나뿐이면 말한 요일로 옮긴다', () {
      final days =
          changedAfter(
                alba,
                const ParseItem(
                  repeat: ParseRepeat(
                    freq: ParseRepeatFreq.weekly,
                    weekdays: [
                      DateTime.sunday,
                      DateTime.friday,
                      DateTime.friday,
                    ],
                  ),
                ),
              )!
              as FixedAfter;
      expect(days.weekdays, [DateTime.friday, DateTime.sunday]);
      expect((days.startMin, days.endMin), (840, 1020));
      final one =
          changedAfter(club, const ParseItem(weekday: DateTime.tuesday))!
              as FixedAfter;
      expect(one.weekdays, [DateTime.tuesday]);
      // 요일이 둘 이상이면 말한 요일 하나로 줄이지 않는다.
      expect(
        changedAfter(alba, const ParseItem(weekday: DateTime.monday)),
        isNull,
      );
    });

    test('고정 일정의 시각을 옮기고, 하루 밖으로 나가면 하루 안으로 되돌린다', () {
      final later =
          changedAfter(alba, const ParseItem(shiftMinutes: 60))! as FixedAfter;
      expect((later.startMin, later.endMin), (900, 1080));
      final start =
          changedAfter(alba, const ParseItem(startMin: 600, endMin: 720))!
              as FixedAfter;
      expect((start.startMin, start.endMin), (600, 720));
      final wrapped =
          changedAfter(club, const ParseItem(shiftMinutes: 300))! as FixedAfter;
      expect((wrapped.startMin, wrapped.endMin), (0, 120));
      final early = FixedTarget(_fixed(8, '아침 운동', [DateTime.monday], 60, 120));
      final back =
          changedAfter(early, const ParseItem(shiftMinutes: -120))!
              as FixedAfter;
      expect((back.startMin, back.endMin), (1380, 1440));
    });

    test('대상의 이름은 일정 제목이나 고정 일정 이름이다', () {
      expect(study.title, '스터디');
      expect(alba.title, '알바');
    });
  });
}
