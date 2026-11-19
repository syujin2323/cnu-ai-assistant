// 06 AI 비서 질문 답의 내용. docs/screens.md '06 AI 비서'의 카드 6(마감·하루 계획·빈 시간을 폰 안 데이터로 답함).
//
// 질문 문장은 뜻을 읽으려고 AI로 보내지만 답은 폰 DB로 만든다. 화면이 그때그때 읽은 할 일·블록·그날 시간표
// 항목·빈 구간을 넘기면 제목·한 줄·줄 목록을 만든다(데이터가 바뀌면 다시 계산됨). 문구는 최종 프로토타입 06의
// 문구를 따른 임시 문구다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 답의 줄 종류(줄 앞 점의 색).
enum AnswerRowKind {
  /// 수업.
  course,

  /// 할 일(마감·블록).
  task,

  /// 일정·고정 일정.
  personal,

  /// 빈 시간.
  free,
}

/// 답의 한 줄.
final class AnswerRow {
  const AnswerRow({
    required this.kind,
    required this.title,
    required this.sub,
    this.right,
    this.urgent = false,
    this.block,
    this.gap,
  });

  final AnswerRowKind kind;
  final String title;
  final String sub;

  /// 오른쪽 값('확정 내일 15:00', '수업').
  final String? right;

  /// 오늘·내일 마감이라 붉게 쓴다.
  final bool urgent;

  /// 누르면 근거 시트를 여는 할 일 블록.
  final PlanBlock? block;

  /// 누르면 빈 시간에 놓기 시트를 여는 빈 시간([놓기]).
  final TimeSpan? gap;
}

/// 답의 아래 링크가 여는 곳.
enum AnswerLink {
  /// 03 할 일의 전체 할 일.
  tasks,

  /// 02 홈.
  home,

  /// 09 일간(그날).
  day,
}

/// 질문 답 카드의 내용.
final class AnswerContent {
  const AnswerContent({
    required this.kicker,
    required this.title,
    this.sub,
    required this.rows,
    required this.emptyText,
    required this.link,
    required this.linkText,
  });

  final String kicker;
  final String title;
  final String? sub;

  /// 줄(마감은 8개, 하루 계획은 7개, 빈 시간은 6개까지).
  final List<AnswerRow> rows;

  /// 줄이 없을 때의 한 줄.
  final String emptyText;

  final AnswerLink link;
  final String linkText;
}

/// 빈 시간 답에 넣는 가장 짧은 빈 시간(분, 임시).
const answerFreeMinMinutes = 20;

/// 마감 답: [tasks] 가운데 남은 일(끝내지 않았고 LMS에서 사라지지 않음)로, 마감의 논리적 날짜가 질문의 기간
/// 안이고(과목을 말했으면 그 과목) 마감이 지나지 않은 것(마감순). 오른쪽에는 그 할 일의 다음 확정·제안 블록이나
/// 공개 전을 적는다. [blocks]는 오늘부터의 블록(모든 상태)이다.
AnswerContent deadlineAnswer(
  AnswerCard card, {
  required List<TaskEntry> tasks,
  required List<PlanBlock> blocks,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final label = _periodLabel(card.from, card.to, today);
  final course = card.courseName;
  final list = [
    for (final entry in tasks)
      if (entry.task.dueAt case final due?
          when entry.isRemaining &&
              due.isAfter(now) &&
              !_beforeDay(
                logicalDate(due, dayBoundaryMin: dayBoundaryMin),
                card.from,
              ) &&
              !_afterDay(
                logicalDate(due, dayBoundaryMin: dayBoundaryMin),
                card.to,
              ) &&
              (course == null || entry.course?.name == course))
        entry,
  ]..sort((a, b) => a.task.dueAt!.compareTo(b.task.dueAt!));
  final subject = [?course, label].join(' ');
  String dueOf(TaskEntry entry) => dueText(
    entry.task.dueAt,
    dueTimeUnknown: entry.task.dueTimeUnknown,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
  );
  return AnswerContent(
    kicker: '$subject 마감',
    title: list.isEmpty
        ? '$subject 남은 마감이 없어요'
        : '$subject 마감은 ${list.length}개예요',
    sub: list.isEmpty
        ? null
        : '가장 가까운 건 ${dueOf(list.first)}인 '
              '${withJosa(list.first.task.title, Josa.ieyoYeyo)}',
    rows: [
      for (final entry in list.take(8))
        AnswerRow(
          kind: AnswerRowKind.task,
          title: entry.task.title,
          sub: dueOf(entry),
          urgent: isDueSoon(
            dueDayOffset(
              entry.task.dueAt!,
              now: now,
              dayBoundaryMin: dayBoundaryMin,
            ),
          ),
          right: _planOf(
            entry,
            blocks,
            now: now,
            dayBoundaryMin: dayBoundaryMin,
          ),
        ),
    ],
    emptyText: '새로 생기면 계획과 홈에서 보여요',
    link: AnswerLink.tasks,
    linkText: '할 일에서 보기',
  );
}

/// 하루 계획 답: 그날 시간표 항목 가운데 수업(휴강 제외)·일정·고정 일정·할 일 블록(제안·확정). 오늘이면 지금
/// 뒤에 끝나는 것만이다. [items]는 그 논리적 하루의 시간표 항목(제안 포함)이다.
AnswerContent dayPlanAnswer(
  AnswerCard card, {
  required List<DayItem> items,
  required Map<int, String> courseNames,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final day = card.from;
  final isToday = !_beforeDay(day, today) && !_afterDay(day, today);
  final shown = [
    for (final item in items)
      if ((!isToday || item.span.end.isAfter(now)) &&
          switch (item) {
            ClassItem(:final cancelled) => !cancelled,
            EventItem() || FixedItem() => true,
            BlockItem(:final block) =>
              block.status == PlanBlockStatus.suggested ||
                  block.status == PlanBlockStatus.confirmed,
            TravelItem() || MealItem() => false,
          })
        item,
  ];
  final blocks = shown.whereType<BlockItem>().toList();
  final blockMinutes = blocks.fold(0, (sum, item) => sum + item.span.minutes);
  final dayName = isToday ? '오늘' : _dayLabel(day, today);
  return AnswerContent(
    kicker: '$dayName 계획',
    title: shown.isEmpty
        ? (isToday
              ? '오늘 남은 일정이 없어요'
              : '${withJosa(dayName, Josa.eunNeun)} 일정이 없어요')
        : (isToday
              ? '남은 일정은 ${shown.length}개예요'
              : '$dayName 일정은 ${shown.length}개예요'),
    sub: blocks.isEmpty
        ? '놓인 할 일이 없어요'
        : '할 일은 ${blocks.length}개, 모두 '
              '${withJosa(durationText(blockMinutes), Josa.ieyoYeyo)}',
    rows: [
      for (final item in shown.take(7))
        AnswerRow(
          kind: switch (item) {
            ClassItem() => AnswerRowKind.course,
            BlockItem() => AnswerRowKind.task,
            _ => AnswerRowKind.personal,
          },
          title: switch (item) {
            ClassItem(:final slot, :final makeup) =>
              '${courseNames[slot.courseId] ?? '수업'}${makeup ? ' 보강' : ''}',
            EventItem(:final event) => event.title,
            FixedItem(:final block) => block.name,
            BlockItem(:final block, :final entry) =>
              '${entry?.task.title ?? '할 일'}'
                  '${block.status == PlanBlockStatus.suggested ? ' · 제안' : ''}',
            TravelItem() || MealItem() => '',
          },
          sub: [
            _spanText(item.span),
            if (item case ClassItem(:final place?)) place,
          ].join(' · '),
          right: switch (item) {
            ClassItem() => '수업',
            EventItem() => '일정',
            FixedItem() => '고정 일정',
            BlockItem() => '할 일',
            TravelItem() || MealItem() => null,
          },
          block: item is BlockItem ? item.block : null,
        ),
    ],
    emptyText: '놓인 일정이 없어요',
    link: isToday ? AnswerLink.home : AnswerLink.day,
    linkText: isToday ? '홈에서 보기' : '일간에서 보기',
  );
}

/// 빈 시간 답: 그날의 빈 구간 가운데 [answerFreeMinMinutes]분 이상인 것(오늘이면 지금 뒤만). 빈 구간 안에
/// 제안 블록이 있으면 그 할 일을 적는다. [free]는 그 논리적 하루의 빈 구간, [items]는 그날 시간표 항목(제안 포함)이다.
AnswerContent freeTimeAnswer(
  AnswerCard card, {
  required List<TimeSpan> free,
  required List<DayItem> items,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final day = card.from;
  final isToday = !_beforeDay(day, today) && !_afterDay(day, today);
  final spans = [
    for (final span in isToday ? spansFrom(free, now) : free)
      if (span.minutes >= answerFreeMinMinutes) span,
  ];
  final total = spans.fold(0, (sum, span) => sum + span.minutes);
  final suggested = [
    for (final item in items)
      if (item case BlockItem(:final block, :final entry)
          when block.status == PlanBlockStatus.suggested)
        (item.span, entry?.task.title),
  ];
  final dayName = isToday ? '오늘' : _dayLabel(day, today);
  return AnswerContent(
    kicker: '$dayName 빈 시간',
    title: spans.isEmpty
        ? '빈 시간이 없어요'
        : '${isToday ? '남은 빈 시간은' : '빈 시간은'} ${spans.length}곳, 모두 '
              '${withJosa(durationText(total), Josa.ieyoYeyo)}',
    sub: null,
    rows: [
      for (final span in spans.take(6))
        AnswerRow(
          kind: AnswerRowKind.free,
          title: _spanText(span),
          sub: [
            durationText(span.minutes),
            if (suggested
                    .where(
                      (pair) =>
                          !pair.$1.start.isBefore(span.start) &&
                          !pair.$1.end.isAfter(span.end),
                    )
                    .firstOrNull
                case (_, final title?))
              '제안: $title',
          ].join(' · '),
          gap: span,
        ),
    ],
    emptyText: '수업과 일정으로 꽉 찼어요. 할 일은 다른 날 빈 시간에 놓아 둘게요',
    link: isToday ? AnswerLink.home : AnswerLink.day,
    linkText: isToday ? '홈에서 보기' : '일간에서 보기',
  );
}

/// [entry]의 다음 계획: 끝나지 않은 확정 블록 → 제안 블록 → 공개 전 영상 → 계획 없음.
String _planOf(
  TaskEntry entry,
  List<PlanBlock> blocks, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  String at(PlanBlock block) =>
      '${dayWord(block.startAt, now: now, dayBoundaryMin: dayBoundaryMin)} '
      '${hhmmText(block.startAt.hour * 60 + block.startAt.minute)}';
  final own = [
    for (final block in blocks)
      if (block.taskId == entry.task.id && block.endAt.isAfter(now)) block,
  ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  final confirmed = own
      .where((block) => block.status == PlanBlockStatus.confirmed)
      .firstOrNull;
  if (confirmed != null) return '확정 ${at(confirmed)}';
  final suggested = own
      .where((block) => block.status == PlanBlockStatus.suggested)
      .firstOrNull;
  if (suggested != null) return '제안 ${at(suggested)}';
  final item = entry.lmsItem;
  if (item != null &&
      item.kind == LmsItemKind.video &&
      (item.openAt?.isAfter(now) ?? false)) {
    return '공개 전';
  }
  return '계획 없음';
}

/// 기간의 이름: 오늘부터 이번 주 일요일까지면 '이번 주', 다음 주 월–일이면 '다음 주', 하루면 날짜 말, 그 밖에는
/// '{M월 D일}–{M월 D일}'.
String _periodLabel(DateTime from, DateTime to, DateTime today) {
  final monday = _mondayOf(today);
  final sunday = _addDays(monday, 6);
  if (_same(from, today) && _same(to, sunday)) return '이번 주';
  if (_same(from, monday) && _same(to, sunday)) return '이번 주';
  if (_same(from, _addDays(monday, 7)) && _same(to, _addDays(monday, 13))) {
    return '다음 주';
  }
  if (_same(from, to)) return _dayLabel(from, today);
  return '${from.month}월 ${from.day}일–${to.month}월 ${to.day}일';
}

/// 하루의 이름: 오늘·내일·모레, 그 밖에는 '{M월 D일}'.
String _dayLabel(DateTime day, DateTime today) {
  final days = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (days) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    _ => '${day.month}월 ${day.day}일',
  };
}

/// 'HH:MM–HH:MM'(자정을 넘는 끝은 실제 시각).
String _spanText(TimeSpan span) {
  final start = span.start.hour * 60 + span.start.minute;
  return timeRangeText(start, start + span.minutes);
}

bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _beforeDay(DateTime a, DateTime b) =>
    DateTime(a.year, a.month, a.day).isBefore(DateTime(b.year, b.month, b.day));

bool _afterDay(DateTime a, DateTime b) =>
    DateTime(a.year, a.month, a.day).isAfter(DateTime(b.year, b.month, b.day));

DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime _mondayOf(DateTime date) => _addDays(date, 1 - date.weekday);
