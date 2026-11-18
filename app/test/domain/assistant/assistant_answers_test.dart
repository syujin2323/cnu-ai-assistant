// 06 AI 비서 질문 답의 내용 테스트. docs/screens.md '06 AI 비서'의 카드 6(마감·하루 계획·빈 시간을 폰 안
// 데이터로 답함).
//
// 지금은 2026-11-19(목) 10:30이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_answers.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19, 10, 30);
const _boundary = 240;

DateTime _at(int day, int hour, [int minute = 0, int month = 11]) =>
    DateTime(2026, month, day, hour, minute);

AnswerCard _card(
  ParseQueryType type,
  DateTime from,
  DateTime to, {
  String? course,
}) => AnswerCard(1, type: type, from: from, to: to, courseName: course);

const _ds = Course(id: 1, name: '데이터구조');

var _nextTaskId = 0;

TaskEntry _entry(
  String title, {
  DateTime? due,
  TaskStatus status = TaskStatus.todo,
  Course? course,
  LmsItem? lms,
  int? id,
}) => TaskEntry(
  task: Task(
    id: id ?? ++_nextTaskId,
    title: title,
    kind: TaskKind.assignment,
    dueAt: due,
    dueTimeUnknown: false,
    status: status,
  ),
  course: course,
  lmsItem: lms,
);

LmsItem _lms({
  LmsItemKind kind = LmsItemKind.assignment,
  DateTime? openAt,
  bool? submitted,
  int missCount = 0,
}) => LmsItem(
  id: 1,
  remoteKey: 'k',
  courseId: 1,
  courseName: '데이터구조',
  title: 'x',
  kind: kind,
  dueTimeUnknown: false,
  openAt: openAt,
  submitted: submitted,
  firstSeenAt: _now,
  lastSeenAt: _now,
  missCount: missCount,
  contentHash: 'h',
);

PlanBlock _block(
  int taskId,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
  int id = 1,
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.auto,
);

ClassSlot _slot(int id, {int courseId = 1}) => ClassSlot(
  id: id,
  courseId: courseId,
  weekday: DateTime.thursday,
  startMin: 0,
  endMin: 60,
  online: false,
  source: SlotSource.auto,
);

void main() {
  group('마감', () {
    final soon = _entry('자료구조 과제', due: _at(20, 23, 59), course: _ds, id: 1);
    final report = _entry('보고서', due: _at(22, 18), id: 2);
    final video = _entry(
      '강의 영상',
      due: _at(22, 23, 59),
      lms: _lms(kind: LmsItemKind.video, openAt: _at(21, 9)),
      id: 3,
    );
    final plain = _entry('계획 없는 일', due: _at(21, 12), id: 4);
    final tasks = [
      report,
      video,
      soon,
      plain,
      _entry('지난 퀴즈', due: _at(19, 9)),
      _entry('다음 주 팀플', due: _at(25, 12)),
      _entry('끝낸 일', due: _at(21, 12), status: TaskStatus.done),
      _entry('숨긴 일', due: _at(21, 12), status: TaskStatus.hidden),
      _entry('제출한 일', due: _at(21, 12), lms: _lms(submitted: true)),
      _entry('사라진 일', due: _at(21, 12), lms: _lms(missCount: 99)),
      _entry('마감 없는 일'),
    ];
    final blocks = [
      // 지난 확정 블록은 다음 계획이 아니다.
      _block(1, _at(19, 8), _at(19, 9), id: 1),
      _block(1, _at(20, 15), _at(20, 16), id: 2),
      _block(1, _at(19, 15), _at(19, 16), id: 3),
      _block(1, _at(19, 11), _at(19, 12), status: PlanBlockStatus.suggested),
      _block(2, _at(21, 10), _at(21, 11), status: PlanBlockStatus.suggested),
      _block(2, _at(21, 9), _at(21, 10), status: PlanBlockStatus.dismissed),
    ];

    test('남은 일 가운데 기간 안에 마감이고 아직 지나지 않은 것을 마감순으로, 다음 계획과 함께 보인다', () {
      final answer = deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, _at(19, 0), _at(22, 0)),
        tasks: tasks,
        blocks: blocks,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '이번 주 마감');
      expect(answer.title, '이번 주 마감은 4개예요');
      expect(answer.sub, '가장 가까운 건 내일 23:59 마감인 자료구조 과제예요');
      expect(
        [
          for (final row in answer.rows)
            (row.title, row.sub, row.right, row.urgent),
        ],
        [
          ('자료구조 과제', '내일 23:59 마감', '확정 오늘 15:00', true),
          ('계획 없는 일', '모레 12:00 마감', '계획 없음', false),
          ('보고서', '일요일 18:00 마감', '제안 모레 10:00', false),
          ('강의 영상', '일요일 23:59 마감', '공개 전', false),
        ],
      );
      expect(answer.rows.every((row) => row.kind == AnswerRowKind.task), true);
      expect(answer.rows.every((row) => row.block == null), true);
      expect(answer.link, AnswerLink.tasks);
      expect(answer.linkText, '할 일에서 보기');
    });

    test('공개된 영상은 공개 전이 아니다', () {
      final open = _entry(
        '열린 영상',
        due: _at(21, 12),
        lms: _lms(kind: LmsItemKind.video, openAt: _at(19, 9)),
      );
      final answer = deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, _at(19, 0), _at(22, 0)),
        tasks: [open],
        blocks: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.rows.single.right, '계획 없음');
    });

    test('과목을 말하면 그 과목만 보고, 머리에 과목을 붙인다', () {
      final answer = deadlineAnswer(
        _card(
          ParseQueryType.deadlinesThisWeek,
          _at(19, 0),
          _at(22, 0),
          course: '데이터구조',
        ),
        tasks: tasks,
        blocks: blocks,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '데이터구조 이번 주 마감');
      expect(answer.title, '데이터구조 이번 주 마감은 1개예요');
      expect(answer.rows.single.title, '자료구조 과제');
    });

    test('없으면 남은 마감이 없다고 하고, 다음 주 기간은 다음 주라고 부른다', () {
      final answer = deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, _at(23, 0), _at(29, 0)),
        tasks: [soon],
        blocks: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '다음 주 마감');
      expect(answer.title, '다음 주 남은 마감이 없어요');
      expect(answer.sub, isNull);
      expect(answer.rows, isEmpty);
      expect(answer.emptyText, '새로 생기면 계획과 홈에서 보여요');
    });

    test('기간의 이름은 이번 주·다음 주·하루의 날짜 말·날짜 범위다', () {
      String kicker(DateTime from, DateTime to) => deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, from, to),
        tasks: const [],
        blocks: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      ).kicker;
      expect(kicker(_at(16, 0), _at(22, 0)), '이번 주 마감');
      expect(kicker(_at(20, 0), _at(20, 0)), '내일 마감');
      expect(kicker(_at(19, 0), _at(19, 0)), '오늘 마감');
      expect(kicker(_at(21, 0), _at(21, 0)), '모레 마감');
      expect(kicker(_at(26, 0), _at(26, 0)), '11월 26일 마감');
      expect(kicker(_at(20, 0), _at(25, 0)), '11월 20일–11월 25일 마감');
    });

    test('기간 끝의 날까지 들고, 하루 경계 전 새벽 마감은 그 전날로 센다', () {
      final dawn = _entry('새벽 마감', due: _at(23, 2));
      final answer = deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, _at(19, 0), _at(22, 0)),
        tasks: [dawn],
        blocks: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.rows.single.title, '새벽 마감');
    });

    test('줄은 여덟 개까지 보이고 머리의 수는 모두 센다', () {
      final many = [
        for (var i = 0; i < 10; i++) _entry('일 $i', due: _at(21, 12, i)),
      ];
      final answer = deadlineAnswer(
        _card(ParseQueryType.deadlinesThisWeek, _at(19, 0), _at(22, 0)),
        tasks: many,
        blocks: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.title, '이번 주 마감은 10개예요');
      expect(answer.rows, hasLength(8));
    });
  });

  group('하루 계획', () {
    final report = _entry('보고서', due: _at(25, 12), id: 2);
    List<DayItem> items(int day) => [
      ClassItem(TimeSpan(_at(day, 9), _at(day, 10, 15)), slot: _slot(11)),
      BlockItem(
        TimeSpan(_at(day, 11), _at(day, 12)),
        block: _block(
          2,
          _at(day, 11),
          _at(day, 12),
          status: PlanBlockStatus.suggested,
        ),
        entry: report,
      ),
      MealItem(TimeSpan(_at(day, 12), _at(day, 12, 40))),
      ClassItem(
        TimeSpan(_at(day, 13), _at(day, 14, 30)),
        slot: _slot(12),
        place: '공대 5호관',
      ),
      ClassItem(
        TimeSpan(_at(day, 15), _at(day, 16)),
        slot: _slot(13),
        cancelled: true,
      ),
      TravelItem(TimeSpan(_at(day, 16), _at(day, 16, 20))),
      EventItem(
        TimeSpan(_at(day, 16, 30), _at(day, 17)),
        event: Event(
          id: 1,
          title: '스터디',
          startAt: _at(day, 16, 30),
          endAt: _at(day, 17),
          allDay: false,
          source: EventSource.manual,
        ),
      ),
      BlockItem(
        TimeSpan(_at(day, 17), _at(day, 18)),
        block: _block(2, _at(day, 17), _at(day, 18), id: 9),
        entry: report,
      ),
      BlockItem(
        TimeSpan(_at(day, 18), _at(day, 18, 30)),
        block: _block(
          2,
          _at(day, 18),
          _at(day, 18, 30),
          id: 8,
          status: PlanBlockStatus.done,
        ),
        entry: report,
      ),
      ClassItem(
        TimeSpan(_at(day, 19), _at(day, 20)),
        slot: _slot(14),
        makeup: true,
      ),
      FixedItem(
        TimeSpan(_at(day, 20), _at(day, 22)),
        block: const FixedBlock(
          id: 5,
          name: '알바',
          weekdays: [DateTime.thursday],
          startMin: 1200,
          endMin: 1320,
          bufferMin: 0,
          kind: FixedBlockKind.work,
          source: EntrySource.manual,
        ),
      ),
    ];
    const names = {1: '데이터구조'};

    test('오늘이면 지금 뒤에 끝나는 수업·일정·고정 일정·제안·확정 블록을 보인다', () {
      final answer = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(19, 0), _at(19, 0)),
        items: items(19),
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '오늘 계획');
      expect(answer.title, '남은 일정은 6개예요');
      expect(answer.sub, '할 일은 2개, 모두 2시간이에요');
      expect(
        [for (final row in answer.rows) (row.title, row.sub, row.right)],
        [
          ('보고서 · 제안', '11:00–12:00', '할 일'),
          ('데이터구조', '13:00–14:30 · 공대 5호관', '수업'),
          ('스터디', '16:30–17:00', '일정'),
          ('보고서', '17:00–18:00', '할 일'),
          ('데이터구조 보강', '19:00–20:00', '수업'),
          ('알바', '20:00–22:00', '고정 일정'),
        ],
      );
      expect(
        [for (final row in answer.rows) row.kind],
        [
          AnswerRowKind.task,
          AnswerRowKind.course,
          AnswerRowKind.personal,
          AnswerRowKind.task,
          AnswerRowKind.course,
          AnswerRowKind.personal,
        ],
      );
      expect(answer.rows.first.block?.status, PlanBlockStatus.suggested);
      expect(answer.rows[1].block, isNull);
      expect(answer.link, AnswerLink.home);
      expect(answer.linkText, '홈에서 보기');
    });

    test('다른 날이면 지난 시각도 보이고 일간으로 간다', () {
      final answer = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(20, 0), _at(20, 0)),
        items: items(20),
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '내일 계획');
      expect(answer.title, '내일 일정은 7개예요');
      expect(answer.rows, hasLength(7));
      expect(answer.rows.first.title, '데이터구조');
      expect(answer.link, AnswerLink.day);
      expect(answer.linkText, '일간에서 보기');
    });

    test('줄은 일곱 개까지이고 머리의 수는 모두 센다', () {
      final answer = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(20, 0), _at(20, 0)),
        items: [
          for (var hour = 8; hour < 17; hour++)
            ClassItem(
              TimeSpan(_at(20, hour), _at(20, hour, 50)),
              slot: _slot(hour),
            ),
        ],
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.title, '내일 일정은 9개예요');
      expect(answer.rows, hasLength(7));
    });

    test('과목 이름을 모르면 수업이라고 쓴다', () {
      final answer = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(20, 0), _at(20, 0)),
        items: [
          ClassItem(
            TimeSpan(_at(20, 9), _at(20, 10)),
            slot: _slot(1, courseId: 9),
          ),
        ],
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.rows.single.title, '수업');
      expect(answer.sub, '놓인 할 일이 없어요');
    });

    test('없으면 일정이 없다고 한다', () {
      final today = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(19, 0), _at(19, 0)),
        items: const [],
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(today.title, '오늘 남은 일정이 없어요');
      expect(today.emptyText, '놓인 일정이 없어요');
      final later = dayPlanAnswer(
        _card(ParseQueryType.todayPlan, _at(26, 0), _at(26, 0)),
        items: const [],
        courseNames: names,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(later.kicker, '11월 26일 계획');
      expect(later.title, '11월 26일은 일정이 없어요');
    });
  });

  group('빈 시간', () {
    final report = _entry('보고서', due: _at(25, 12), id: 2);
    final free = [
      TimeSpan(_at(19, 8), _at(19, 10)),
      TimeSpan(_at(19, 10), _at(19, 11)),
      TimeSpan(_at(19, 11, 30), _at(19, 11, 45)),
      TimeSpan(_at(19, 14, 30), _at(19, 16)),
      TimeSpan(_at(19, 23), _at(20, 1)),
    ];
    final items = [
      BlockItem(
        TimeSpan(_at(19, 15), _at(19, 15, 50)),
        block: _block(
          2,
          _at(19, 15),
          _at(19, 15, 50),
          status: PlanBlockStatus.suggested,
        ),
        entry: report,
      ),
      // 확정 블록은 빈 시간에 들지 않는다(제안만 적음).
      BlockItem(
        TimeSpan(_at(19, 23), _at(19, 23, 30)),
        block: _block(2, _at(19, 23), _at(19, 23, 30), id: 4),
        entry: report,
      ),
    ];

    test('오늘이면 지금 뒤의 20분 이상 빈 시간과 그 안의 제안을 보인다', () {
      final answer = freeTimeAnswer(
        _card(ParseQueryType.freeTime, _at(19, 0), _at(19, 0)),
        free: free,
        items: items,
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '오늘 빈 시간');
      expect(answer.title, '남은 빈 시간은 3곳, 모두 4시간이에요');
      expect(
        [for (final row in answer.rows) (row.title, row.sub)],
        [
          ('10:30–11:00', '30분'),
          ('14:30–16:00', '1시간 30분 · 제안: 보고서'),
          ('23:00–01:00', '2시간'),
        ],
      );
      expect(answer.rows.every((row) => row.kind == AnswerRowKind.free), true);
      expect(answer.link, AnswerLink.home);
    });

    test('다른 날이면 지난 시각을 자르지 않는다', () {
      final answer = freeTimeAnswer(
        _card(ParseQueryType.freeTime, _at(20, 0), _at(20, 0)),
        free: [TimeSpan(_at(20, 8), _at(20, 10))],
        items: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(answer.kicker, '내일 빈 시간');
      expect(answer.title, '빈 시간은 1곳, 모두 2시간이에요');
      expect(answer.link, AnswerLink.day);
    });

    test('줄은 여섯 개까지이고, 없으면 빈 시간이 없다고 한다', () {
      final many = freeTimeAnswer(
        _card(ParseQueryType.freeTime, _at(20, 0), _at(20, 0)),
        free: [
          for (var hour = 8; hour < 22; hour += 2)
            TimeSpan(_at(20, hour), _at(20, hour, 30)),
        ],
        items: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(many.title, '빈 시간은 7곳, 모두 3시간 30분이에요');
      expect(many.rows, hasLength(6));
      final none = freeTimeAnswer(
        _card(ParseQueryType.freeTime, _at(19, 0), _at(19, 0)),
        free: [TimeSpan(_at(19, 8), _at(19, 10))],
        items: const [],
        now: _now,
        dayBoundaryMin: _boundary,
      );
      expect(none.title, '빈 시간이 없어요');
      expect(none.rows, isEmpty);
      expect(none.emptyText, '수업과 일정으로 꽉 찼어요. 할 일은 다른 날 빈 시간에 놓아 둘게요');
    });
  });
}
