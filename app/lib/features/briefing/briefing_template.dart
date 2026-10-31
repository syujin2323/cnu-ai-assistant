// 브리핑 템플릿 문장. docs/architecture.md '데일리 브리핑과 중요 브리핑'.
//
// 서버(AI 게이트웨이)는 나중에 연결하므로(2026-10-31 결정) 지금은 이 문장만 보여 준다. 서버가 붙은
// 뒤에도 AI 실패·동의 안 함·한도 초과 때 쓴다. 시각은 12시간제, 길이는 아라비아 숫자로 쓰고 조사는
// `domain/text/josa.dart`로 받침에 맞춘다.

import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';

/// 데일리 브리핑 글(세 문장).
///
/// 1. 오늘 수업 수와 요일. 2. 여유도가 가장 작은 미배정 할 일. 3. 가장 가까운 마감.
/// 미배정과 마감이 모두 없으면 2·3 대신 "오늘은 할 일이 없어요."다.
String dailyBriefingText({
  required DateTime today,
  required List<CalendarItem> todayItems,
  required List<UnassignedTask> unassigned,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final classes = todayItems
      .where((i) => i.kind == CalendarItemKind.classSession)
      .length;
  final first = classes == 0
      ? '오늘은 수업이 없어요.'
      : '수업 $classes개가 있는 ${weekdayText(today.weekday)}요일이에요.';

  final second = switch (unassigned) {
    [] => null,
    [final only] =>
      '${withJosa(only.task.title, Josa.eunNeun)} 아직 시간을 정하지 않았어요.',
    [final top, ...] =>
      '${top.task.title} 등 ${unassigned.length}개는 아직 시간을 정하지 않았어요.',
  };

  final dues = [
    for (final u in unassigned)
      if (u.task.dueAt != null && !u.task.dueAt!.isBefore(now)) u.task,
  ]..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  final third = dues.isEmpty
      ? null
      : '${withJosa(dues.first.title, Josa.eunNeun)} '
            '${dueLabel(dues.first.dueAt!, today: today, dayBoundaryMin: dayBoundaryMin)} 마감이에요.';

  if (second == null && third == null) return '$first 오늘은 할 일이 없어요.';
  return [first, ?second, ?third].join(' ');
}

/// 중요 브리핑의 '지금까지 요약'(브리핑 시각 이후 지금까지).
String nowSummaryText({
  required DateTime now,
  required List<CalendarItem> todayItems,
  required int newAlertCount,
  required List<UnassignedTask> todayTodo,
}) {
  final timed = [
    for (final i in todayItems)
      if (i.start != null &&
          i.end != null &&
          i.kind != CalendarItemKind.deadline)
        i,
  ];
  final done = [
    for (final i in timed)
      if (!i.end!.isAfter(now)) i.title,
  ];
  final left = [
    for (final i in timed)
      if (i.end!.isAfter(now)) i,
  ];
  final minute = now.hour * 60 + now.minute;
  return [
    '지금(${clockText(minute)})까지 상황이에요.',
    if (done.isEmpty) '아직 끝난 일정은 없어요.' else '${done.join(', ')} 일정이 끝났어요.',
    if (left.isEmpty)
      '오늘 남은 일정은 없어요.'
    else
      '남은 일정은 ${left.map((i) => '${clockText(i.start!.hour * 60 + i.start!.minute)} ${i.title}').join(', ')}이에요.',
    if (newAlertCount > 0) '새로 생긴 일이 $newAlertCount건 있어요.',
    if (todayTodo.isEmpty)
      '오늘 시간을 정해야 할 할 일은 없어요.'
    else
      '오늘 챙길 미배정 할 일은 ${todayTodo.take(3).map((u) => u.task.title).join(', ')}'
          '${todayTodo.length > 3 ? ' 외 ${todayTodo.length - 3}개' : ''}예요.',
  ].join(' ');
}
