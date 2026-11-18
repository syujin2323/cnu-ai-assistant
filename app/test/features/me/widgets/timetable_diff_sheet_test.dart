// 13 '바뀐 수업' 시트의 줄 문구 테스트. docs/screens.md '13 시간표·고정 일정'. 수업 칸·강의실은 합성 값이다.

import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/features/me/widgets/timetable_diff_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

const _slot = ClassSlot(
  id: 1,
  courseId: 1,
  weekday: 1,
  startMin: 540,
  endMin: 615,
  place: '합성관101',
  online: false,
  source: SlotSource.auto,
);

TimetableSlotUpdate _update(
  ImportedClassSlot to,
  Set<TimetableUpdateReason> reasons,
) => TimetableSlotUpdate(_slot, to: to, imported: to, reasons: reasons);

void main() {
  test('학교 쪽 시간이 바뀌면 시간 전·후를 쓴다', () {
    expect(
      timetableChangeText(
        _update(
          const ImportedClassSlot(
            weekday: 2,
            startMin: 600,
            endMin: 675,
            place: '합성관101',
          ),
          {TimetableUpdateReason.schoolTime},
        ),
        '선형대수',
      ),
      (title: '선형대수 수업 시간이 바뀌었어요', from: '월 09:00–10:15', to: '화 10:00–11:15'),
    );
  });

  test('강의실만 바뀌면 강의실 전·후를 쓴다', () {
    expect(
      timetableChangeText(
        _update(
          const ImportedClassSlot(
            weekday: 1,
            startMin: 540,
            endMin: 615,
            place: '합성관202',
          ),
          {TimetableUpdateReason.schoolPlace},
        ),
        '선형대수',
      ),
      (title: '선형대수 강의실이 바뀌었어요', from: '합성관101', to: '합성관202'),
    );
  });

  test('시간과 강의실이 함께 바뀌면 둘 다 쓰고, 고친 시간을 맞출 때는 묻는 제목이다', () {
    expect(
      timetableChangeText(
        _update(
          const ImportedClassSlot(
            weekday: 3,
            startMin: 540,
            endMin: 615,
            place: null,
          ),
          {TimetableUpdateReason.userTime, TimetableUpdateReason.schoolPlace},
        ),
        '자료구조',
      ),
      (
        title: '자료구조 수업을 학교 시간으로 맞출까요?',
        from: '월 09:00–10:15 · 합성관101',
        to: '수 09:00–10:15 · 장소 없음',
      ),
    );
  });

  test('없어진 수업은 지움으로 쓴다', () {
    expect(timetableChangeText(const TimetableSlotRemoval(_slot), '선형대수'), (
      title: '선형대수 수업이 학교 시간표에서 없어졌어요',
      from: '월 09:00–10:15',
      to: '지움',
    ));
  });
}
