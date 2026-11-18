// 03 할 일 목록에 보일 것. docs/screens.md '03 할 일'.
//
// 화면(`features/tasks/`)은 [taskListContent]의 결과를 그리기만 한다. 규칙은 최종 프로토타입(03 할 일)을 따른다.
// - 탭: 주간 할 일은 오늘부터 7일 뒤까지 마감인 일과 마감이 지났는데 안 끝낸 일([inWeeklyTasks]), 전체 할 일은 남은
//   할 일 전부다. 'LMS만'이면 탭 숫자·요약 줄·빈 화면을 LMS 할 일로만 센다. 개인 할 일 줄은 빼지 않고 접힌 줄
//   ([TaskRow.folded])로 남겨, 화면이 제자리에서 접고 끄면 그 자리에서 다시 편다.
// - 마감순은 마감이 이른 것부터(지난 마감이 맨 위, 같으면 영상이 뒤)이고 마감 없는 일은 맨 아래 '마감 없음' 묶음이다.
//   과목별은 그 순서에서 과목이 처음 나오는 차례로 묶고(급한 과목부터) 개인 할 일은 늘 마지막 '개인' 묶음이다.
// - 줄: 머리('{과목} · {종류}' 또는 '개인'), 제목, 마감, 해당하면 마감 변경·영상 길이·마감 지남·공개 전 안내와 계획 줄.
//   LMS 항목에는 번호가 없어 프로토타입의 '과제 3' 같은 번호는 붙이지 않는다(임시).
// 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_week.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 03 할 일의 정렬.
enum TaskListSort {
  /// 마감순.
  due,

  /// 과목별.
  course,
}

/// 목록이 비었을 때의 까닭.
enum TaskListEmpty {
  /// 이 탭에 보일 할 일이 없고, 다른 탭이나 'LMS만'을 끄면 보일 할 일도 없다.
  nothing,

  /// 주간 탭인데 7일 안에 마감인 할 일이 없다(전체 할 일에는 있음).
  notThisWeek,

  /// 'LMS만'인데 이 탭에 LMS 할 일이 없다(개인 할 일은 있음).
  noLmsTasks,
}

/// 묶음의 종류. 화면은 종류에 따라 머리를 그린다.
enum TaskGroupKind {
  /// 마감순의 마감 있는 할 일. 머리가 없다.
  due,

  /// 마감순 맨 아래의 '마감 없음'. 옅은 머리이고 수를 쓰지 않는다.
  noDue,

  /// 과목별의 과목 묶음. 머리에 과목 이름과 수를 쓴다.
  course,

  /// 과목별 맨 아래의 '개인' 묶음. 머리에 '개인'과 수를 쓴다.
  personal,
}

/// 줄의 안내(마감 지남·공개 전). 있으면 계획 줄을 두지 않는다.
enum TaskNoteKind { overdue, opens }

/// 계획 줄의 모양.
enum TaskPlanKind {
  /// 지금 하는 중인 확정 블록.
  now,

  /// 확정 블록(예상 시간만큼 한 일 포함).
  confirmed,

  /// 제안 블록.
  suggested,

  /// 놓인 블록이 없다(까닭만 적음).
  none,
}

/// 줄의 안내.
final class TaskNote {
  const TaskNote(this.kind, this.text);

  final TaskNoteKind kind;
  final String text;
}

/// 계획 줄.
final class TaskPlanLine {
  const TaskPlanLine(this.kind, this.text, {this.alert = false});

  final TaskPlanKind kind;
  final String text;

  /// 시간이 모자라 붉게 쓴다.
  final bool alert;
}

/// 목록의 줄 하나.
final class TaskRow {
  const TaskRow({
    required this.entry,
    required this.kicker,
    required this.due,
    required this.dueUrgent,
    this.dueChange,
    this.video,
    this.note,
    this.plan,
    this.folded = false,
  });

  final TaskEntry entry;

  /// 머리('{과목} · {종류}', '개인', 과목별 정렬에서는 '{종류}'·'직접 추가' 등).
  final String kicker;

  /// 마감 문구('내일 23:59 마감', '마감 없음').
  final String due;

  /// 마감이 오늘·내일이라 붉게 쓴다(지난 마감은 아님).
  final bool dueUrgent;

  /// 마감 변경('마감이 이틀 늦춰졌어요').
  final String? dueChange;

  /// 영상 길이('출석 인정 50분 · 영상 60분').
  final String? video;

  final TaskNote? note;
  final TaskPlanLine? plan;

  /// 'LMS만'이라 접힌 개인 할 일. 화면은 줄을 제자리에서 접는다.
  final bool folded;

  int get taskId => entry.task.id;
  String get title => entry.task.title;
}

/// 묶음 하나.
final class TaskGroup {
  const TaskGroup({required this.kind, this.title, required this.rows});

  final TaskGroupKind kind;

  /// 머리의 이름(과목 이름, 'LMS', '개인', '마감 없음'). [TaskGroupKind.due]면 null이다.
  final String? title;

  final List<TaskRow> rows;

  /// 접히지 않은 줄의 수(머리의 'N개'). 0이면 화면은 머리도 접는다.
  int get shownCount => rows.where((row) => !row.folded).length;
}

/// 03 할 일에 보일 것.
final class TaskListContent {
  const TaskListContent({
    required this.weeklyCount,
    required this.allCount,
    required this.summary,
    required this.groups,
    this.empty,
    this.otherCount = 0,
  });

  /// 탭 숫자. 'LMS만'이면 LMS 할 일만 센다.
  final int weeklyCount;
  final int allCount;

  /// 요약 줄.
  final String summary;

  /// 이 탭의 묶음. 'LMS만'으로 접힌 줄도 들어 있어서, [empty]가 있어도 비지 않을 수 있다.
  final List<TaskGroup> groups;

  /// 보일 줄이 없으면 그 까닭.
  final TaskListEmpty? empty;

  /// 빈 화면의 둘째 줄에 쓰는 수: [TaskListEmpty.notThisWeek]면 전체 할 일의 수, [TaskListEmpty.noLmsTasks]면
  /// 이 탭의 개인 할 일 수.
  final int otherCount;
}

/// 마감 변경을 보이는 기간(임시). 이보다 오래된 변경은 보이지 않는다.
const Duration taskDueChangeShownFor = Duration(days: 7);

/// 03 할 일 목록을 만든다. [now]에는 `Clock.now`의 값을 넘긴다.
///
/// [blocks]는 앞으로의 블록이다(확정·제안이 아니거나 지난 것은 안에서 거른다). [shortages]는 배치 엔진의 마지막
/// 결과다. [dueChanges]는 LMS 항목마다 마지막 마감 변경 기록이다(`LmsItemChangeRepository.watchLatestDueChanges`).
/// [config]로 남은 작업 시간을 센다([remainingWorkMin]). [hasClassSlots]가 false면(시간표를 아직 받지 못함) 배치
/// 엔진이 제안을 만들지 않으므로 계획 줄이 그 까닭을 쓴다.
TaskListContent taskListContent({
  required List<TaskEntry> entries,
  required List<PlanBlock> blocks,
  required List<Shortage> shortages,
  required Map<String, LmsItemChange> dueChanges,
  required PlannerConfig config,
  required bool hasClassSlots,
  required DateTime now,
  required int dayBoundaryMin,
  required bool weekly,
  required bool lmsOnly,
  required TaskListSort sort,
}) {
  final remaining = entries.where((entry) => entry.isRemaining).toList()
    ..sort(_dueOrder);
  bool inWeek(TaskEntry entry) =>
      inWeeklyTasks(entry, now: now, dayBoundaryMin: dayBoundaryMin);
  bool shown(TaskEntry entry) => !lmsOnly || _isLms(entry);
  final shownRemaining = remaining.where(shown).toList();
  final inTab = [
    for (final entry in remaining)
      if (!weekly || inWeek(entry)) entry,
  ];
  final listedCount = inTab.where(shown).length;

  // 요약: 7일 안 마감(지난 마감 제외)과 그 일에 남은 시간.
  final soon = shownRemaining.where((entry) {
    final dueAt = entry.task.dueAt;
    if (dueAt == null || !dueAt.isAfter(now)) return false;
    final days = dueDayOffset(dueAt, now: now, dayBoundaryMin: dayBoundaryMin);
    return days >= 0 && days <= 7;
  }).toList();
  final soonMin = soon.fold<int>(
    0,
    (sum, entry) => sum + _positive(remainingWorkMin(entry, config)),
  );
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final weekEnd = DateTime(today.year, today.month, today.day + 7);
  final left = '남은 일 ${approxHoursText(soonMin)}';
  final summary = [
    if (lmsOnly) 'LMS 할 일 $listedCount개',
    if (weekly)
      '${monthDayText(weekEnd, today: today)}까지${soon.isEmpty ? '' : ' · $left'}'
    else if (soon.isEmpty)
      '7일 안 마감은 없어요'
    else
      '7일 안 마감 ${soon.length}개 · $left',
  ].join(' · ');

  TaskListEmpty? empty;
  var otherCount = 0;
  if (listedCount == 0) {
    final personalHere = inTab.length - listedCount;
    if (lmsOnly && personalHere > 0) {
      empty = TaskListEmpty.noLmsTasks;
      otherCount = personalHere;
    } else if (weekly && shownRemaining.isNotEmpty) {
      empty = TaskListEmpty.notThisWeek;
      otherCount = shownRemaining.length;
    } else {
      empty = TaskListEmpty.nothing;
    }
  }

  TaskRow row(TaskEntry entry) => _row(
    entry,
    folded: !shown(entry),
    courseSort: sort == TaskListSort.course,
    blocks: blocks,
    shortages: shortages,
    dueChanges: dueChanges,
    config: config,
    hasClassSlots: hasClassSlots,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
  );

  final groups = <TaskGroup>[];
  if (sort == TaskListSort.due) {
    final withDue = [
      for (final entry in inTab)
        if (entry.task.dueAt != null) row(entry),
    ];
    final noDue = [
      for (final entry in inTab)
        if (entry.task.dueAt == null) row(entry),
    ];
    if (withDue.isNotEmpty) {
      groups.add(TaskGroup(kind: TaskGroupKind.due, rows: withDue));
    }
    if (noDue.isNotEmpty) {
      groups.add(
        TaskGroup(kind: TaskGroupKind.noDue, title: '마감 없음', rows: noDue),
      );
    }
  } else {
    final order = <String>[];
    final byGroup = <String, List<TaskEntry>>{};
    for (final entry in inTab) {
      final key = _groupKey(entry);
      byGroup
          .putIfAbsent(key, () {
            order.add(key);
            return [];
          })
          .add(entry);
    }
    for (final key in order) {
      if (key == _personalGroup) continue;
      groups.add(
        TaskGroup(
          kind: TaskGroupKind.course,
          title: key,
          rows: [for (final entry in byGroup[key]!) row(entry)],
        ),
      );
    }
    final personal = byGroup[_personalGroup];
    if (personal != null) {
      groups.add(
        TaskGroup(
          kind: TaskGroupKind.personal,
          title: '개인',
          rows: [for (final entry in personal) row(entry)],
        ),
      );
    }
  }

  return TaskListContent(
    weeklyCount: remaining.where(inWeek).where(shown).length,
    allCount: shownRemaining.length,
    summary: summary,
    groups: groups,
    empty: empty,
    otherCount: otherCount,
  );
}

/// 개인 묶음의 열쇠(과목 이름과 겹치지 않는 값).
const String _personalGroup = '\u0000personal';

/// LMS에서 받은 할 일인지.
bool _isLms(TaskEntry entry) => entry.task.lmsKey != null;

/// 과목 이름. LMS 할 일은 원본의 과목, 06 AI 비서로 과목을 정해 만든 할 일은 그 과목이다.
String? _courseName(TaskEntry entry) =>
    entry.course?.name ?? entry.lmsItem?.courseName;

/// 과목별 묶음의 열쇠. 과목이 없는 할 일은 개인 묶음이고, 과목을 모르는 LMS 할 일은 'LMS'다.
String _groupKey(TaskEntry entry) {
  final course = _courseName(entry);
  if (course != null) return course;
  return _isLms(entry) ? 'LMS' : _personalGroup;
}

/// 마감순: 마감이 이른 것부터(마감 없는 일은 맨 뒤), 같으면 영상이 뒤, 그다음 id.
int _dueOrder(TaskEntry a, TaskEntry b) {
  final da = a.task.dueAt, db = b.task.dueAt;
  if (da != null && db != null) {
    final byDue = da.compareTo(db);
    if (byDue != 0) return byDue;
  } else if (da != null || db != null) {
    return da == null ? 1 : -1;
  }
  final video =
      (a.task.kind == TaskKind.video ? 1 : 0) -
      (b.task.kind == TaskKind.video ? 1 : 0);
  if (video != 0) return video;
  return a.task.id.compareTo(b.task.id);
}

int _positive(int? minutes) => minutes == null || minutes < 0 ? 0 : minutes;

TaskRow _row(
  TaskEntry entry, {
  required bool folded,
  required bool courseSort,
  required List<PlanBlock> blocks,
  required List<Shortage> shortages,
  required Map<String, LmsItemChange> dueChanges,
  required PlannerConfig config,
  required bool hasClassSlots,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final task = entry.task;
  final dueAt = task.dueAt;
  final overdue = dueAt != null && dueAt.isBefore(now);
  final due = dueText(
    dueAt,
    dueTimeUnknown: task.dueTimeUnknown,
    now: now,
    dayBoundaryMin: dayBoundaryMin,
    farAsDate: true,
  );
  // 지난 마감은 붉게 쓰지 않는다(아래 마감 지남 줄의 dueUrgent).
  final urgent =
      dueAt != null &&
      isDueSoon(dueDayOffset(dueAt, now: now, dayBoundaryMin: dayBoundaryMin));
  final lms = _isLms(entry);
  final kicker = taskKicker(entry, courseSort: courseSort);
  final dueChange = lms
      ? _dueChange(entry, dueChanges, now: now, dayBoundaryMin: dayBoundaryMin)
      : null;

  if (overdue) {
    return TaskRow(
      entry: entry,
      kicker: kicker,
      due: due,
      dueUrgent: false,
      dueChange: dueChange,
      folded: folded,
      note: TaskNote(
        TaskNoteKind.overdue,
        lms ? '마감이 지났어요 · LMS에서 확인해 주세요' : '마감이 지났어요 · 끝냈다면 체크해 주세요',
      ),
    );
  }
  final openAt = entry.lmsItem?.openAt;
  if (lms && openAt != null && openAt.isAfter(now)) {
    return TaskRow(
      entry: entry,
      kicker: kicker,
      due: due,
      dueUrgent: urgent,
      dueChange: dueChange,
      folded: folded,
      note: TaskNote(
        TaskNoteKind.opens,
        opensText(openAt, now: now, dayBoundaryMin: dayBoundaryMin),
      ),
    );
  }
  return TaskRow(
    entry: entry,
    kicker: kicker,
    due: due,
    dueUrgent: urgent,
    dueChange: dueChange,
    folded: folded,
    video: task.kind == TaskKind.video ? taskVideoText(entry) : null,
    plan: _planLine(
      entry,
      blocks: blocks,
      shortages: shortages,
      config: config,
      hasClassSlots: hasClassSlots,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    ),
  );
}

/// 줄 머리('{과목} · {종류}', '개인'). 과목별 정렬에서는 묶음 이름이 과목이므로 과목을 빼고 쓴다. 작은 할 일 시트도 쓴다.
String taskKicker(TaskEntry entry, {bool courseSort = false}) {
  final task = entry.task;
  final course = _courseName(entry);
  if (!_isLms(entry) && course == null) {
    final ai = task.source == EntrySource.ai;
    if (courseSort) return ai ? 'AI 비서로 추가' : '직접 추가';
    return ai ? '개인 · AI 비서로 추가' : '개인';
  }
  final kind = taskKindText(task.kind);
  if (course == null) return courseSort ? kind : 'LMS 할 일';
  return courseSort ? kind : '$course · $kind';
}

/// 마감 변경 문구. 마감 날짜가 바뀐 변경만(시각만 바뀌면 쓰지 않음), [taskDueChangeShownFor] 안의 것만 보인다.
/// 날짜는 마감 문구와 같은 규칙([dueDayOffset]: 정확히 00:00인 마감은 전날)으로 센다.
String? _dueChange(
  TaskEntry entry,
  Map<String, LmsItemChange> dueChanges, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final key = entry.task.lmsKey;
  final dueAt = entry.task.dueAt;
  if (key == null || dueAt == null) return null;
  final change = dueChanges[key];
  if (change == null ||
      now.difference(change.changedAt) > taskDueChangeShownFor) {
    return null;
  }
  final before = tryDecodeDateTime(change.oldValue);
  if (before == null) return null;
  final days =
      dueDayOffset(dueAt, now: now, dayBoundaryMin: dayBoundaryMin) -
      dueDayOffset(before, now: now, dayBoundaryMin: dayBoundaryMin);
  if (days == 0) return null;
  final amount = switch (days.abs()) {
    1 => '하루',
    2 => '이틀',
    final n => '$n일',
  };
  return '마감이 $amount ${days > 0 ? '늦춰졌어요' : '당겨졌어요'}';
}

/// 영상 길이. LMS는 본 시간을 알려 주지 않아 길이와 출석 인정 시간만 적는다. 작은 할 일 시트도 쓴다.
String taskVideoText(TaskEntry entry) {
  final item = entry.lmsItem;
  final required = item?.requiredMin;
  final video = item?.videoMin;
  if (required != null) {
    return '출석 인정 $required분${video != null && video != required ? ' · 영상 $video분' : ''}';
  }
  if (video != null) return '영상 $video분';
  return '영상 길이는 아직 몰라요';
}

/// 계획 줄: 이 할 일의 다음 확정·제안 블록, 없으면 그 까닭.
TaskPlanLine _planLine(
  TaskEntry entry, {
  required List<PlanBlock> blocks,
  required List<Shortage> shortages,
  required PlannerConfig config,
  required bool hasClassSlots,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final task = entry.task;
  final mine =
      [
        for (final block in blocks)
          if (block.taskId == task.id &&
              block.endAt.isAfter(now) &&
              (block.status == PlanBlockStatus.confirmed ||
                  block.status == PlanBlockStatus.suggested))
            block,
      ]..sort((a, b) {
        final byStart = a.startAt.compareTo(b.startAt);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
  final shortage = shortages.where((s) => s.taskId == task.id).firstOrNull;
  if (mine.isEmpty) {
    return _noBlockLine(
      entry,
      shortage: shortage,
      config: config,
      hasClassSlots: hasClassSlots,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    );
  }
  final first = mine.first;
  if (first.status == PlanBlockStatus.confirmed &&
      !first.startAt.isAfter(now)) {
    return TaskPlanLine(
      TaskPlanKind.now,
      '지금 하는 중 · ${hhmmText(_minuteOfDay(first.endAt))}까지',
    );
  }
  final day = dayWord(first.startAt, now: now, dayBoundaryMin: dayBoundaryMin);
  final times = mine.length > 1 ? '부터 ${mine.length}번' : '';
  final kind = first.status == PlanBlockStatus.suggested
      ? TaskPlanKind.suggested
      : TaskPlanKind.confirmed;
  final short = shortage == null
      ? ''
      : ' · ${durationText(shortage.missingMin)} 모자라요';
  return TaskPlanLine(
    kind,
    '$day ${hhmmText(first.startAt.hour * 60 + first.startAt.minute)}$times · '
    '${kind == TaskPlanKind.suggested ? '제안' : '확정'}$short',
    alert: shortage != null,
  );
}

/// 놓인 블록이 없는 할 일의 계획 줄(그 까닭).
TaskPlanLine _noBlockLine(
  TaskEntry entry, {
  required Shortage? shortage,
  required PlannerConfig config,
  required bool hasClassSlots,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final task = entry.task;
  final work = remainingWorkMin(entry, config);
  if (work == null) {
    return const TaskPlanLine(TaskPlanKind.none, '예상 시간을 정하면 빈 시간에 놓아요');
  }
  if (work <= 0) {
    return const TaskPlanLine(
      TaskPlanKind.confirmed,
      '예상 시간만큼 했어요 · 끝냈다면 체크해 주세요',
    );
  }
  final dueAt = task.dueAt;
  if (dueAt == null) {
    return const TaskPlanLine(TaskPlanKind.none, '마감이 없어 직접 고른 시간에만 놓아요');
  }
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final deferred = DateTime.tryParse(task.deferredUntil ?? '');
  if (deferred != null && deferred.isAfter(today)) {
    return const TaskPlanLine(TaskPlanKind.none, '이번 계획에서 뺐어요');
  }
  // 배치 엔진은 오늘부터 배치 지평 안에 마감인 할 일만 놓는다(`planRange`의 지평 끝은 마지막 날의 하루 끝).
  final horizonEnd = logicalDayEnd(
    DateTime(today.year, today.month, today.day + Defaults.planHorizonDays - 1),
    dayBoundaryMin: dayBoundaryMin,
  );
  if (dueAt.isAfter(horizonEnd)) {
    // 마감이 지평 끝 안에 드는 첫날. 마감이 하루 경계 시각이면 그 전날의 하루 끝이다.
    final last = logicalDate(
      dueAt.subtract(const Duration(microseconds: 1)),
      dayBoundaryMin: dayBoundaryMin,
    );
    final from = DateTime(
      last.year,
      last.month,
      last.day - (Defaults.planHorizonDays - 1),
    );
    final day = taskDayText(
      logicalDayStart(from, dayBoundaryMin: dayBoundaryMin),
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    );
    return TaskPlanLine(TaskPlanKind.none, '$day부터 빈 시간에 놓아요');
  }
  if (!hasClassSlots) {
    return const TaskPlanLine(TaskPlanKind.none, '시간표를 받으면 빈 시간에 놓아요');
  }
  if (shortage != null) {
    return const TaskPlanLine(
      TaskPlanKind.none,
      '마감 전 빈 시간이 모자라요',
      alert: true,
    );
  }
  return const TaskPlanLine(TaskPlanKind.none, '아직 놓을 시간이 없어요');
}

/// 끝 시각의 하루 안 분. 정확히 자정이면 24:00으로 쓴다.
int _minuteOfDay(DateTime at) {
  final minute = at.hour * 60 + at.minute;
  return minute == 0 ? 1440 : minute;
}
