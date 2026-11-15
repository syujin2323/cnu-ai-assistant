// 시간표 글자 해석 테스트. docs/lms.md '시간표 (통합정보시스템)'. 글자 꼴과 정규식은 합성 값이다.

import 'package:cnu_ai_assistant/lms/parsers/timetable_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/lms_samples.dart';

void main() {
  final pattern = RegExp(syntheticTimetableSlotPattern);

  test('맞는 자리를 모두 수업 칸으로 읽고 강의실은 있으면 쓴다', () {
    expect(
      parseTimetableSlots(
        '월|09:00|10:15|합성관101; 수|9:00|10:15; 금|13:30|15:00| ',
        pattern,
      ),
      const [
        LmsImportedSlot(
          weekday: 1,
          startMin: 540,
          endMin: 615,
          place: '합성관101',
        ),
        LmsImportedSlot(weekday: 3, startMin: 540, endMin: 615),
        LmsImportedSlot(weekday: 5, startMin: 810, endMin: 900),
      ],
    );
  });

  test('일요일까지 요일을 읽고, 같은 칸이 두 번 나오면 한 번만 쓴다', () {
    expect(parseTimetableSlots('일|20:00|21:00; 일|20:00|21:00', pattern), const [
      LmsImportedSlot(weekday: 7, startMin: 1200, endMin: 1260),
    ]);
  });

  test('글자가 비었으면 수업 시간이 없는 과목이라 빈 목록이다', () {
    expect(parseTimetableSlots('', pattern), isEmpty);
    expect(parseTimetableSlots('   ', pattern), isEmpty);
  });

  test('맞는 자리가 없거나 시각을 읽지 못하거나 끝이 시작보다 이르면 해석 실패다', () {
    for (final text in [
      '수업 시간 미정',
      '월|24:00|25:00',
      '월|09:60|10:00',
      '월|10:00|10:00',
      '월|11:00|10:00',
    ]) {
      expect(parseTimetableSlots(text, pattern), isNull, reason: text);
    }
  });

  test('강의실 묶음이 없는 정규식도 읽는다', () {
    final noPlace = RegExp(
      r'(?<day>[월화수목금토일])\|(?<start>\d{1,2}:\d{2})\|(?<end>\d{1,2}:\d{2})',
    );
    expect(parseTimetableSlots('화|08:00|09:00|합성관', noPlace), const [
      LmsImportedSlot(weekday: 2, startMin: 480, endMin: 540),
    ]);
  });
}
