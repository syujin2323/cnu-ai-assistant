// 세로 하루 시간표 자리 계산 테스트. docs/screens.md '02 홈'·'09 일간'.

import 'package:cnu_ai_assistant/design/widgets/day_timeline_layout.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime at(int hour, [int minute = 0, int day = 16]) =>
    DateTime(2026, 11, day, hour, minute);

TimeSpan span(DateTime start, DateTime end) => TimeSpan(start, end);

final day = DateTime(2026, 11, 16);

ClassItem lesson(DateTime start, DateTime end, {bool cancelled = false}) =>
    ClassItem(
      span(start, end),
      slot: ClassSlot(
        id: start.hour,
        courseId: 1,
        weekday: 1,
        startMin: start.hour * 60 + start.minute,
        endMin: end.hour * 60 + end.minute,
        online: false,
        source: SlotSource.auto,
      ),
      cancelled: cancelled,
    );

BlockItem task(
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
}) => BlockItem(
  span(start, end),
  block: PlanBlock(
    id: start.hour * 100 + start.minute,
    taskId: 1,
    startAt: start,
    endAt: end,
    status: status,
    source: BlockSource.manual,
  ),
);

TimelineLayout layout(
  List<DayItem> items, {
  List<TimeSpan> free = const [],
  DateTime? now,
  bool today = true,
  bool showPast = false,
  bool showTravelMeal = true,
  int windowEndMin = 1380,
  bool slots = false,
}) => layoutDayTimeline(
  day: day,
  items: items,
  free: free,
  now: now ?? at(9),
  today: today,
  windowEndMin: windowEndMin,
  showPast: showPast,
  showTravelMeal: showTravelMeal,
  slots: slots,
);

/// 놓인 것을 '종류 top height 모양' 꼴로.
List<String> describe(TimelineLayout result) => [
  for (final entry in result.entries)
    switch (entry) {
      TimelineCard(:final mode, :final past, :final current) =>
        '카드 ${entry.top.round()} ${entry.height.round()} ${mode.name}'
            '${past ? ' 지남' : ''}${current ? ' 지금' : ''}',
      TimelineSoft() => '흐림 ${entry.top.round()} ${entry.height.round()}',
      TimelineFree() => '빈 ${entry.top.round()} ${entry.height.round()}',
      TimelineSlot(:final span) =>
        '칸 ${span.start.hour}시 ${entry.top.round()} ${entry.height.round()}',
    },
];

void main() {
  test('한 시간은 60pt이고, 카드 높이는 길이에서 간격 4를 뺀 값(최소 44)이며 높이로 모양이 정해진다', () {
    final result = layout([
      lesson(at(9), at(10, 15)),
      task(at(10, 30), at(11)),
      task(at(11, 15), at(12, 15)),
      task(at(13), at(13, 20)),
      task(at(14), at(16)),
    ], now: at(8, 30));
    // 지금 08:30 → 08시 줄부터.
    expect(describe(result), [
      '카드 60 71 mid',
      // 30분 블록도 최소 44pt라 다음 카드를 민다.
      '카드 150 44 short',
      '카드 198 53 short',
      '카드 300 44 short',
      // 2시간 블록은 높이 116pt라 tall이다.
      '카드 360 116 tall',
    ]);
  });

  test('겹치면 앞 카드 아래로 4pt 띄워 민다', () {
    final result = layout([
      lesson(at(9), at(10)),
      task(at(9, 30), at(11)),
    ], now: at(9));
    final cards = result.entries.cast<TimelineCard>();
    expect(cards.first.top, 0);
    expect(cards.last.top, cards.first.top + cards.first.height + 4);
  });

  test('15분 미만 이동은 그리지 않고, 표시를 끄면 이동·점심을 그리지 않는다', () {
    final items = [
      TravelItem(span(at(9, 50), at(10))),
      lesson(at(10), at(11)),
      TravelItem(span(at(11), at(11, 30))),
      MealItem(span(at(11, 40), at(12, 20))),
    ];
    expect(describe(layout(items, now: at(9))), [
      '카드 60 56 short',
      '흐림 120 30',
      '흐림 160 36',
    ]);
    expect(describe(layout(items, now: at(9), showTravelMeal: false)), [
      '카드 60 56 short',
    ]);
  });

  test('빈 시간 카드는 45분 이상만이고, 오늘은 지금 뒤만 센다', () {
    final result = layout(
      [lesson(at(9), at(10))],
      free: [
        span(at(10, 10), at(10, 40)),
        span(at(12), at(13)),
        span(at(13, 30), at(18)),
        // 지금 뒤지만 45분이 안 된다.
        span(at(19), at(19, 40)),
      ],
      now: at(13, 50),
      showPast: true,
    );
    final frees = result.entries.whereType<TimelineFree>().toList();
    expect(frees.map((f) => (f.span.start, f.span.end)), [
      (at(13, 50), at(18)),
    ]);
  });

  test('오늘은 끝난 항목을 접어 세고(이동·점심은 세지 않음), 펼치면 08시부터 보인다', () {
    final items = [
      lesson(at(9), at(10)),
      MealItem(span(at(12), at(12, 40))),
      task(at(13), at(14)),
      task(at(15), at(16)),
    ];
    final folded = layout(items, now: at(14, 30));
    expect(folded.pastCount, 2);
    expect(describe(folded), ['카드 60 56 short']);
    expect(folded.hours.first.hour, 14);

    final open = layout(items, now: at(14, 30), showPast: true);
    expect(open.pastCount, 0);
    expect(open.hours.first.hour, 8);
    expect(describe(open).where((d) => d.contains('지남')), hasLength(2));
  });

  test('시 글자는 지금과 첫 남은 항목 가운데 이른 시부터 하루 창 끝과 마지막 항목 가운데 늦은 쪽(최대 01시)까지다', () {
    final late = layout([lesson(at(22), at(1, 30, 17))], now: at(20, 10));
    expect(late.hours.first.hour, 20);
    expect(late.hours.last.hour, 1);
    expect(late.height, (25 - 20) * 60 + 14);

    final normal = layout([lesson(at(10), at(11))], now: at(9, 30));
    expect(normal.hours.first.hour, 9);
    expect(normal.hours.last.hour, 23);
  });

  test('지금 선은 오늘에만 그리고, 가리는 시 글자는 숨긴다', () {
    final result = layout([lesson(at(10), at(11))], now: at(10, 10));
    expect(result.nowTop, 10);
    expect(result.hours.first.visible, isFalse);
    expect(result.hours[1].visible, isTrue);

    final other = layout([lesson(at(10), at(11))], today: false);
    expect(other.nowTop, isNull);
    expect(other.pastCount, 0);
    expect(other.hours.first.hour, 8);
  });

  test('지금 하는 것은 하나만 표시하고 할 일 블록을 먼저 고른다', () {
    final result = layout(
      [
        // 블록이 수업보다 먼저 놓여도(마지막 것이 아니어도) 블록을 고른다.
        task(at(9, 50), at(10, 50)),
        lesson(at(10), at(11)),
        task(at(9), at(9, 30), status: PlanBlockStatus.done),
      ],
      now: at(10, 20),
      showPast: true,
    );
    final current = result.entries
        .whereType<TimelineCard>()
        .where((c) => c.current)
        .toList();
    expect(current, hasLength(1));
    expect(current.single.item, isA<BlockItem>());
  });

  test('수업·일정·고정 일정이 없으면 empty다(휴강한 수업만 있어도)', () {
    expect(layout([task(at(10), at(11))]).empty, isTrue);
    expect(layout([lesson(at(10), at(11), cancelled: true)]).empty, isTrue);
    expect(layout([lesson(at(10), at(11))]).empty, isFalse);
  });

  group('09 일간의 HH:MM에 놓기 칸', () {
    test('빈 시간 카드는 112pt까지이고 그 아래 정시마다 칸을 둔다', () {
      // 08시부터 그리므로 09:00은 60pt. 카드는 63–175pt이고 그 아래 첫 정시는 12시다.
      // 빈 시간 뒤에 오는 수업은 칸을 줄이지 않는다.
      final result = layout(
        [lesson(at(14), at(15))],
        free: [TimeSpan(at(9), at(13, 30))],
        today: false,
        slots: true,
      );

      expect(describe(result), [
        '빈 63 112',
        '칸 12시 243 54',
        '칸 13시 303 24',
        '카드 360 56 short',
      ]);
      final slots = result.entries.whereType<TimelineSlot>().toList();
      expect(slots.first.span, TimeSpan(at(12), at(13, 30)));
      expect(slots.last.span, TimeSpan(at(13), at(13, 30)));
    });

    test('30분이 안 남은 시나 카드 아래 남은 높이가 40pt 이하면 칸을 두지 않는다', () {
      String shape(TimeSpan span) =>
          describe(layout(const [], free: [span], today: false, slots: true))
              .join(', ');

      // 13:29까지: 13시 칸은 30분이 안 남는다.
      expect(shape(TimeSpan(at(9), at(13, 29))), '빈 63 112, 칸 12시 243 54');
      // 카드 아래 남은 높이가 40pt 이하면, 정시가 바로 아래라 30분이 들어가도 두지 않는다.
      expect(shape(TimeSpan(at(9), at(11, 40))), '빈 63 112');
      expect(shape(TimeSpan(at(9, 57), at(12, 35))), '빈 120 112');
      expect(shape(TimeSpan(at(9, 57), at(12, 36))), '빈 120 112, 칸 12시 243 30');
      // 빈 시간 안의 휴강 수업(시간을 막지 않음)은 줄인 카드 아래로 오므로, 그 수업이 시작하기 전까지만 둔다.
      expect(
        describe(
          layout(
            [lesson(at(13), at(14), cancelled: true)],
            free: [TimeSpan(at(9), at(15))],
            today: false,
            slots: true,
          ),
        ),
        ['빈 63 112', '칸 12시 243 54', '카드 300 56 short'],
      );
      expect(
        describe(
          layout(
            [lesson(at(10, 30), at(11, 30), cancelled: true)],
            free: [TimeSpan(at(9), at(14))],
            today: false,
            slots: true,
          ),
        ),
        ['빈 63 112', '카드 179 44 short'],
      );
      // 칸을 두지 않으면(02 홈) 카드가 빈 시간을 다 차지한다.
      expect(
        describe(
          layout(const [], free: [TimeSpan(at(9), at(13, 30))], today: false),
        ),
        ['빈 63 264'],
      );
    });
  });
}
