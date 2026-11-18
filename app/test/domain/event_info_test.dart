// 일정 정보 시트의 내용. docs/screens.md '일정 정보 시트'.
//
// 지금은 2026-11-16(월) 09:00이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/domain/event_info.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 16, 9);
const boundary = 240;

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const lessonSlot = ClassSlot(
  id: 1,
  courseId: 1,
  weekday: DateTime.monday,
  startMin: 780,
  endMin: 855,
  place: '공학관 1',
  online: false,
  source: SlotSource.auto,
);

ClassItem lesson({
  int day = 16,
  int hour = 13,
  bool cancelled = false,
  bool exam = false,
  bool makeup = false,
  bool placeChanged = false,
  String? place = '공학관 1',
  ClassSlot slot = lessonSlot,
}) => ClassItem(
  TimeSpan(at(day, hour), at(day, hour, 75)),
  slot: slot,
  cancelled: cancelled,
  exam: exam,
  makeup: makeup,
  placeChanged: placeChanged,
  place: place,
);

EventInfoContent content(DayItem item, {DateTime? at}) => eventInfoContent(
  item,
  courseName: '자료구조',
  now: at ?? now,
  dayBoundaryMin: boundary,
);

Event event({
  required DateTime startAt,
  required DateTime endAt,
  bool allDay = false,
  String? place,
}) => Event(
  id: 7,
  title: '상담',
  startAt: startAt,
  endAt: endAt,
  allDay: allDay,
  place: place,
  source: EventSource.manual,
);

void main() {
  group('수업', () {
    test('머리에 과목·날짜·시각·장소를 쓰고 그날만 바꿀 수 있다', () {
      final c = content(lesson());
      expect(c.kind, EventInfoKind.classItem);
      expect(c.kicker, '수업');
      expect(c.title, '자료구조');
      expect(c.time, '11월 16일 (월) · 13:00–14:15 · 공학관 1');
      expect(c.dayWord, '오늘');
      expect(c.date, DateTime(2026, 11, 16));
      expect(c.change, isNull);
      expect(c.changeLabel, '오늘 수업만 바꾸기');
      expect(c.canChange, isTrue);
      expect(c.lockText, isNull);
    });

    test('지금 바뀐 것과 머리 띠는 휴강·시험·장소 변경을 따른다', () {
      final cancelled = content(lesson(cancelled: true));
      expect(
        (cancelled.change, cancelled.kicker),
        (ClassDayChange.cancelled, '휴강'),
      );
      final exam = content(lesson(exam: true, place: '대강당'));
      expect((exam.change, exam.kicker), (ClassDayChange.exam, '시험'));
      expect(exam.time, endsWith('· 대강당'));
      final moved = content(lesson(placeChanged: true, place: '공대 5호관 101'));
      expect(
        (moved.change, moved.kicker),
        (ClassDayChange.placeChange, '장소 변경'),
      );
      expect(moved.time, endsWith('· 공대 5호관 101'));
    });

    test('바꿈은 저장할 수업 예외 종류로 바뀐다', () {
      expect(
        [for (final change in ClassDayChange.values) change.kind],
        [
          ClassExceptionKind.cancelled,
          ClassExceptionKind.exam,
          ClassExceptionKind.placeChange,
        ],
      );
    });

    test('실시간 온라인 수업은 장소 대신 실시간 온라인을 쓰고, 장소가 없으면 쓰지 않는다', () {
      const online = ClassSlot(
        id: 2,
        courseId: 1,
        weekday: DateTime.monday,
        startMin: 780,
        endMin: 855,
        online: true,
        source: SlotSource.manual,
      );
      expect(
        content(lesson(slot: online, place: null)).time,
        '11월 16일 (월) · 13:00–14:15 · 실시간 온라인',
      );
      for (final place in [null, '']) {
        expect(content(lesson(place: place)).time, '11월 16일 (월) · 13:00–14:15');
      }
    });

    test('내일 수업은 내일 수업만 바꾸고, 지난 수업은 바꾸지 못한다', () {
      expect(content(lesson(day: 17)).changeLabel, '내일 수업만 바꾸기');
      final past = content(lesson(day: 15));
      expect(past.changeLabel, isNull);
      expect(past.canChange, isFalse);
      expect(past.lockText, '지난 수업은 바꿀 수 없어요');
      // 오늘 이미 끝난 수업은 바꿀 수 있다.
      expect(
        content(lesson(hour: 7), at: at(16, 20)).changeLabel,
        '오늘 수업만 바꾸기',
      );
    });

    test('보강은 바꾸지 않고 안내만 둔다', () {
      final c = content(lesson(makeup: true));
      expect(c.kicker, '보강');
      expect(c.changeLabel, isNull);
      expect(c.lockText, '보강 수업이에요. 시간표에는 넣지 않았어요');
    });

    test('하루 경계 전 새벽 수업은 그 논리적 하루의 날짜로 쓴다', () {
      // 화요일 01:00 수업은 월요일 논리적 하루의 끝이다.
      final c = content(lesson(day: 17, hour: 1), at: at(16, 23));
      expect(c.time, '11월 16일 (월) · 01:00–02:15 · 공학관 1');
      expect(c.date, DateTime(2026, 11, 16));
      expect(c.changeLabel, '오늘 수업만 바꾸기');
    });
  });

  group('일정', () {
    test('개인 일정은 머리에 제목·날짜·시각·장소를 쓰고 바꿀 칩이 없다', () {
      final c = content(
        EventItem(
          TimeSpan(at(16, 15), at(16, 15, 30)),
          event: event(
            startAt: at(16, 15),
            endAt: at(16, 15, 30),
            place: '학생회관',
          ),
        ),
      );
      expect(c.kind, EventInfoKind.event);
      expect(c.kicker, '개인 일정');
      expect(c.title, '상담');
      expect(c.time, '11월 16일 (월) · 15:00–15:30 · 학생회관');
      expect(c.date, DateTime(2026, 11, 16));
      expect(c.changeLabel, isNull);
      expect(c.lockText, isNull);
    });

    test('종일 일정은 달력 날짜와 종일로 쓰고, 여러 날이면 첫날과 끝날을 쓴다', () {
      EventInfoContent allDay(DateTime start, DateTime end, {String? place}) =>
          content(
            EventItem(
              TimeSpan(start, end),
              event: event(
                startAt: start,
                endAt: end,
                allDay: true,
                place: place,
              ),
            ),
          );
      final one = allDay(DateTime(2026, 11, 18), DateTime(2026, 11, 19));
      expect(one.time, '11월 18일 (수) · 종일');
      expect(one.dayWord, '모레');
      expect(one.date, DateTime(2026, 11, 18));
      expect(
        allDay(DateTime(2026, 11, 18), DateTime(2026, 11, 20)).time,
        '11월 18일 (수) – 11월 19일 (목) · 종일',
      );
      expect(
        allDay(
          DateTime(2026, 11, 18),
          DateTime(2026, 11, 19),
          place: '학생회관',
        ).time,
        '11월 18일 (수) · 종일 · 학생회관',
      );
      expect(
        allDay(DateTime(2026, 11, 18), DateTime(2026, 11, 19), place: '').time,
        '11월 18일 (수) · 종일',
      );
      // 오늘 종일 일정은 하루 경계 전(0시)에 시작해도 오늘이다.
      expect(
        allDay(DateTime(2026, 11, 16), DateTime(2026, 11, 17)).dayWord,
        '오늘',
      );
    });

    test('논리적 하루를 꽉 채운 일정도 시간 범위로 쓴다', () {
      final c = content(
        EventItem(
          TimeSpan(at(16, 4), at(17, 4)),
          event: event(startAt: at(15, 12), endAt: at(18, 12)),
        ),
      );
      expect(c.time, '11월 16일 (월) · 04:00–03:59');
    });
  });

  test('고정 일정은 이름과 장소를 쓴다', () {
    final c = content(
      FixedItem(
        TimeSpan(at(16, 18), at(16, 22)),
        block: const FixedBlock(
          id: 3,
          name: '알바',
          weekdays: [DateTime.monday],
          startMin: 1080,
          endMin: 1320,
          bufferMin: 20,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
          place: '카페',
        ),
      ),
    );
    expect(c.kind, EventInfoKind.fixed);
    expect(c.kicker, '고정 일정');
    expect(c.title, '알바');
    expect(c.time, '11월 16일 (월) · 18:00–22:00 · 카페');
    expect(c.changeLabel, isNull);
  });

  test('이동·점심·할 일 블록은 받지 않는다', () {
    final span = TimeSpan(at(16, 12), at(16, 13));
    for (final item in <DayItem>[TravelItem(span), MealItem(span)]) {
      expect(() => content(item), throwsArgumentError);
    }
  });
}
