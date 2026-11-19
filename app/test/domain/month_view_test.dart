// 08 월간의 달력 계산 테스트. docs/screens.md '08 월간'.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/month_view.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event(int id, DateTime start, DateTime end, {bool allDay = false}) =>
    Event(
      id: id,
      title: '일정 $id',
      startAt: start,
      endAt: end,
      allDay: allDay,
      source: EventSource.manual,
    );

void main() {
  final today = DateTime(2026, 11, 19);

  MonthView view({
    DateTime? month,
    DateTime? selected,
    List<Event> events = const [],
    List<ClassException> exceptions = const [],
  }) => monthView(
    month: month ?? today,
    today: today,
    selected: selected ?? today,
    events: events,
    exceptions: exceptions,
    dayBoundaryMin: 240,
  );

  test('달의 주마다 월요일부터 일곱 칸이고, 앞뒤 달의 날은 그 달이 아니다', () {
    final result = view();
    expect(result.label, '2026년 11월');
    expect(result.showToday, isFalse);
    expect(result.weeks, hasLength(6));
    expect(result.weeks.every((week) => week.length == 7), isTrue);
    expect(result.weeks.first.first.date, DateTime(2026, 10, 26));
    expect(result.weeks.first.first.inMonth, isFalse);
    expect(result.weeks.last.last.date, DateTime(2026, 12, 6));
    expect(monthGridStart(today), DateTime(2026, 10, 26));
    expect(monthGridEnd(today), DateTime(2026, 12, 7));
    final cells = result.weeks.expand((week) => week).toList();
    expect(cells.where((c) => c.today).single.date, today);
    expect(cells.where((c) => c.selected).single.date, today);
  });

  test('일정·종일 일정·시험이 있는 날에 점을 둔다. 휴강은 두지 않고, 새벽 일정은 전날이다', () {
    final result = view(
      events: [
        _event(1, DateTime(2026, 11, 20, 19), DateTime(2026, 11, 20, 20)),
        // 종일 일정 사흘(끝은 마지막 날 다음 날 0시).
        _event(2, DateTime(2026, 11, 10), DateTime(2026, 11, 13), allDay: true),
        // 하루 경계(04:00) 전 새벽은 전날로 본다.
        _event(3, DateTime(2026, 11, 28, 1), DateTime(2026, 11, 28, 2)),
      ],
      exceptions: const [
        ClassException(
          id: 1,
          classSlotId: 1,
          date: '2026-11-26',
          kind: ClassExceptionKind.exam,
          source: EntrySource.manual,
        ),
        ClassException(
          id: 2,
          classSlotId: 1,
          date: '2026-11-24',
          kind: ClassExceptionKind.cancelled,
          source: EntrySource.manual,
        ),
      ],
    );
    final dots = [
      for (final cell in result.weeks.expand((week) => week))
        if (cell.dot) cell.date.day,
    ];
    expect(dots, [10, 11, 12, 20, 26, 27]);
  });

  test('공휴일은 이름이 있고 붉게 쓴다. 다른 달을 보면 오늘로 돌아갈 수 있다', () {
    final result = view(
      month: DateTime(2026, 12),
      selected: DateTime(2026, 12),
    );
    expect(result.label, '2026년 12월');
    expect(result.showToday, isTrue);
    final christmas = result.weeks
        .expand((week) => week)
        .firstWhere((c) => c.date == DateTime(2026, 12, 25));
    expect(christmas.holiday, '성탄절');
    expect(christmas.red, isTrue);
  });
}
