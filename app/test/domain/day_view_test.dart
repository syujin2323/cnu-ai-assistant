// 09 일간의 시간표 밖 내용 테스트. docs/screens.md '09 일간'.
//
// 지금은 2026-11-19(목) 10:00이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/domain/day_view.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 19, 10);
const boundary = 240;

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

DayItem lesson(int day, int start, int end, {bool cancelled = false}) =>
    ClassItem(
      TimeSpan(at(day, start), at(day, end)),
      slot: const ClassSlot(
        id: 1,
        courseId: 1,
        weekday: DateTime.thursday,
        startMin: 600,
        endMin: 660,
        online: false,
        source: SlotSource.manual,
      ),
      cancelled: cancelled,
    );

Event event(int id, int day, {bool allDay = false, String? place}) => Event(
  id: id,
  title: '일정 $id',
  startAt: allDay ? at(day, 0) : at(day, 15),
  endAt: allDay ? at(day + 1, 0) : at(day, 16),
  allDay: allDay,
  place: place,
  source: EventSource.manual,
);

DayItem block(
  int id,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
}) => BlockItem(
  TimeSpan(start, end),
  block: PlanBlock(
    id: id,
    taskId: 1,
    startAt: start,
    endAt: end,
    status: status,
    source: BlockSource.auto,
  ),
);

TaskEntry task(
  int id, {
  DateTime? due,
  bool dueTimeUnknown = false,
  TaskStatus status = TaskStatus.todo,
  bool? submitted,
  bool? officiallyDone,
  int missCount = 0,
}) {
  final lms = submitted != null || officiallyDone != null || missCount > 0;
  final key = 'k$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: '할 일 $id',
      kind: TaskKind.assignment,
      dueAt: due,
      dueTimeUnknown: dueTimeUnknown,
      status: status,
      lmsKey: lms ? key : null,
    ),
    lmsItem: !lms
        ? null
        : LmsItem(
            id: id,
            remoteKey: key,
            courseId: 1,
            courseName: '자료구조',
            title: '할 일 $id',
            kind: LmsItemKind.assignment,
            dueAt: due,
            dueTimeUnknown: dueTimeUnknown,
            submitted: submitted,
            officiallyDone: officiallyDone,
            firstSeenAt: now,
            lastSeenAt: now,
            missCount: missCount,
            contentHash: key,
          ),
  );
}

DayView view(
  DateTime date, {
  List<DayItem> items = const [],
  List<Event> allDay = const [],
  List<TaskEntry> entries = const [],
  List<TimeSpan> free = const [],
}) => dayView(
  date: date,
  items: items,
  allDayEvents: allDay,
  entries: entries,
  free: free,
  now: now,
  dayBoundaryMin: boundary,
);

void main() {
  test('위 막대는 그 주 범위이고 날짜 줄은 월요일부터 일요일까지다', () {
    final result = view(DateTime(2026, 11, 21));

    expect(result.weekLabel, '11월 16일 – 22일');
    expect(
      [for (final d in result.strip) d.label],
      ['월', '화', '수', '오늘', '금', '토', '일'],
    );
    expect(
      [for (final d in result.strip) d.date.day],
      [16, 17, 18, 19, 20, 21, 22],
    );
    expect(
      [for (final d in result.strip) d.selected],
      [false, false, false, false, false, true, false],
    );
    expect(result.strip[3].today, isTrue);
    expect(result.strip.last.sunday, isTrue);
    expect(result.strip.first.sunday, isFalse);
    expect(result.showToday, isTrue);
    expect(result.title, '11월 21일 (토)');
    expect(result.today, DateTime(2026, 11, 19));
    expect(view(DateTime(2026, 11, 19)).showToday, isFalse);
  });

  test('머리 아래 줄은 날짜 말·수업·할 일·일정·빈 시간 수이고 휴강·놓침은 세지 않는다', () {
    final result = view(
      DateTime(2026, 11, 19),
      items: [
        lesson(19, 11, 12),
        lesson(19, 13, 14, cancelled: true),
        block(1, at(19, 14), at(19, 15)),
        block(2, at(19, 8), at(19, 9), status: PlanBlockStatus.missed),
        block(3, at(19, 16), at(19, 17), status: PlanBlockStatus.suggested),
        EventItem(TimeSpan(at(19, 15), at(19, 16)), event: event(1, 19)),
      ],
      allDay: [event(2, 19, allDay: true)],
      free: [TimeSpan(at(19, 9), at(19, 11)), TimeSpan(at(19, 16), at(19, 19))],
    );

    // 빈 시간: 지금(10:00) 뒤 1시간 + 16–19시에서 제안(16–17시)을 뺀 2시간.
    expect(result.sub, '오늘 · 수업 1개 · 할 일 2개 · 일정 2개 · 빈 시간 3시간');
  });

  test('빈 시간은 10분 단위로 반올림하고 30분이 안 되면 쓰지 않으며, 지난 날은 세지 않는다', () {
    String sub(DateTime date, List<TimeSpan> free) =>
        view(date, items: [lesson(date.day, 11, 12)], free: free).sub;

    expect(
      sub(DateTime(2026, 11, 20), [TimeSpan(at(20, 9), at(20, 10, 34))]),
      '내일 · 수업 1개 · 빈 시간 1시간 30분',
    );
    expect(
      sub(DateTime(2026, 11, 20), [TimeSpan(at(20, 9), at(20, 9, 29))]),
      '내일 · 수업 1개',
    );
    expect(
      sub(DateTime(2026, 11, 18), [TimeSpan(at(18, 9), at(18, 12))]),
      '어제 · 수업 1개',
    );
    expect(
      sub(DateTime(2026, 11, 23), [TimeSpan(at(23, 9), at(23, 12))]),
      '수업 1개 · 빈 시간 3시간',
    );
    expect(view(DateTime(2026, 11, 23)).sub, '일정 없음');
  });

  test('빈 시간 카드에 쓸 빈 구간은 제안 자리를 빼고, 지난 날은 비어 있다', () {
    final free = [TimeSpan(at(20, 9), at(20, 12))];
    final items = [
      block(1, at(20, 9), at(20, 10), status: PlanBlockStatus.suggested),
      block(2, at(20, 11), at(20, 11, 30)),
    ];

    // 확정 블록은 이미 빈 시간에서 빠져 있으므로 제안만 뺀다.
    expect(view(DateTime(2026, 11, 20), items: items, free: free).free, [
      TimeSpan(at(20, 10), at(20, 12)),
    ]);
    expect(
      view(
        DateTime(2026, 11, 18),
        free: [TimeSpan(at(18, 9), at(18, 12))],
      ).free,
      isEmpty,
    );
    // 오늘은 지금 전 빈 시간도 그대로 넘긴다(시간표가 지금부터 그림).
    expect(
      view(
        DateTime(2026, 11, 19),
        free: [TimeSpan(at(19, 9), at(19, 12))],
      ).free,
      [TimeSpan(at(19, 9), at(19, 12))],
    );
  });

  test('모두 확정은 그날 제안만이고 오늘은 지금 뒤에 끝나는 것만이다', () {
    final today = view(
      DateTime(2026, 11, 19),
      items: [
        block(1, at(19, 8), at(19, 9), status: PlanBlockStatus.suggested),
        block(
          2,
          at(19, 9, 30),
          at(19, 10, 30),
          status: PlanBlockStatus.suggested,
        ),
        block(3, at(19, 14), at(19, 15)),
      ],
    );
    expect([for (final b in today.confirmable) b.id], [2]);
    expect(today.confirmTitle, '제안 1개가 확정 전이에요');

    final tomorrow = view(
      DateTime(2026, 11, 20),
      items: [
        block(4, at(20, 8), at(20, 9), status: PlanBlockStatus.suggested),
      ],
    );
    expect([for (final b in tomorrow.confirmable) b.id], [4]);
    expect(today.confirmedToast, '오늘 제안 1개를 확정했어요');
    expect(tomorrow.confirmedToast, '내일 제안 1개를 확정했어요');
    expect(view(DateTime(2026, 11, 20)).confirmedToast, '');
  });

  test('수업·일정이 없는 날은 빈 날 카드를 보이고 지난 날·제안 있음에 따라 말이 다르다', () {
    expect(
      view(DateTime(2026, 11, 19), items: [lesson(19, 11, 12)]).empty,
      isNull,
    );
    expect(
      view(DateTime(2026, 11, 19), allDay: [event(1, 19, allDay: true)]).empty,
      isNull,
    );
    final empty = view(DateTime(2026, 11, 22)).empty!;
    expect(empty.title, '수업·일정이 없는 날이에요');
    expect(empty.body, '빈 시간을 눌러 할 일을 놓을 수 있어요');
    expect(
      view(
        DateTime(2026, 11, 22),
        items: [
          block(1, at(22, 9), at(22, 10), status: PlanBlockStatus.suggested),
        ],
      ).empty!.body,
      '제안 1개는 아래 시간표에 있어요. 빈 시간을 눌러 더 놓을 수도 있어요',
    );
    expect(
      view(DateTime(2026, 11, 17)).empty!.body,
      '지난 날이에요. 할 일은 오늘부터 놓을 수 있어요',
    );
  });

  test('공휴일은 날짜 줄에서 붉게 쓰고, 그날이면 이름과 안내를 카드로 둔다', () {
    // 2026-12-25(금)은 성탄절이다.
    final christmas = DateTime(2026, 12, 25);
    DayItem classAt(int hour, {bool cancelled = false}) => ClassItem(
      TimeSpan(DateTime(2026, 12, 25, hour), DateTime(2026, 12, 25, hour + 1)),
      slot: const ClassSlot(
        id: 1,
        courseId: 1,
        weekday: DateTime.friday,
        startMin: 600,
        endMin: 660,
        online: false,
        source: SlotSource.manual,
      ),
      cancelled: cancelled,
    );

    final week = view(christmas);
    expect(
      [for (final d in week.strip) d.holiday],
      [null, null, null, null, '성탄절', null, null],
    );
    expect(
      [for (final d in week.strip) d.red],
      [false, false, false, false, true, false, true],
    );
    expect(week.holiday!.name, '성탄절');
    expect(week.holiday!.meta, '공휴일');

    // 공휴일에도 수업은 그대로라, 수업이 있으면 휴강으로 바꾸는 길을 알린다(휴강한 수업은 세지 않음).
    expect(
      view(christmas, items: [classAt(10)]).holiday!.meta,
      '공휴일 · 쉬는 수업은 눌러서 휴강으로 바꿔요',
    );
    expect(
      view(christmas, items: [classAt(10, cancelled: true)]).holiday!.meta,
      '공휴일',
    );
    expect(view(DateTime(2026, 11, 19)).holiday, isNull);
  });

  test('종일 일정은 장소가 없으면 하루 종일이라고 쓴다', () {
    final result = view(
      DateTime(2026, 11, 19),
      allDay: [
        event(1, 19, allDay: true, place: ' 대전 '),
        event(2, 19, allDay: true),
      ],
    );

    expect([for (final a in result.allDay) a.meta], ['대전', '하루 종일']);
  });

  test('마감 줄은 그날 마감인 할 일을 시각 순서로 보이고 상태를 붙인다', () {
    final result = view(
      DateTime(2026, 11, 19),
      entries: [
        task(1, due: at(19, 23, 59)),
        task(2, due: at(19, 9)),
        task(3, due: at(19, 18), status: TaskStatus.done),
        task(4, due: at(19, 18), submitted: true),
        task(5, due: at(20, 0)),
        task(6, due: at(19, 12), status: TaskStatus.hidden),
        task(7, due: at(19, 12), missCount: 3),
        task(8, due: at(20, 9)),
        task(9, due: at(19, 23, 59), dueTimeUnknown: true),
      ],
    );

    expect([for (final r in result.dues) r.entry.task.id], [2, 3, 4, 1, 9, 5]);
    final byId = {for (final r in result.dues) r.entry.task.id: r};
    expect(byId[2]!.state, '마감 지남');
    expect(byId[2]!.urgent, isFalse);
    expect(byId[3]!.state, '완료');
    expect(byId[3]!.finished, isTrue);
    expect(byId[4]!.state, 'LMS 제출 확인');
    expect(byId[4]!.finished, isTrue);
    expect(byId[1]!.time, '23:59');
    expect(byId[1]!.urgent, isTrue);
    expect(byId[1]!.state, isNull);
    // 정확히 00:00인 마감은 전날 24:00이다.
    expect(byId[5]!.time, '24:00');
    expect(byId[9]!.time, '시각 미상');
    expect(byId[1]!.title, '할 일 1');
  });

  test('출석 인정은 따로 쓰고, 이틀 뒤 마감은 붉게 쓰지 않는다', () {
    final officially = view(
      DateTime(2026, 11, 19),
      entries: [task(1, due: at(19, 23), officiallyDone: true)],
    ).dues.single;
    expect(officially.state, 'LMS 출석 인정');

    expect(
      view(
        DateTime(2026, 11, 20),
        entries: [task(1, due: at(20, 23))],
      ).dues.single.urgent,
      isTrue,
    );
    expect(
      view(
        DateTime(2026, 11, 21),
        entries: [task(1, due: at(21, 23))],
      ).dues.single.urgent,
      isFalse,
    );
  });
}
