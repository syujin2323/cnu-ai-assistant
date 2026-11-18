// 작은 할 일 시트에 보일 것. docs/screens.md '할 일 시트', docs/decisions.md 2026-11-19 '할 일을 누르면 작은 할 일
// 시트를 연다'.
//
// 04 할 일 상세를 다시 설계하기 전까지 쓰는 1.0용 시트다. 근거 시트 모양으로 머리(과목·종류)·제목·마감, 예상 시간
// 칩(고치면 다시 배치), 이 할 일의 앞으로의 블록(누르면 근거 시트), [끝내기]와 [지우기](직접 넣은 할 일)·
// [숨기기](LMS 할 일)를 보인다. 화면(`features/tasks/widgets/task_sheet.dart`)은 [taskSheetContent]의 결과를
// 그리기만 한다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_list.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 예상 시간 칩(분, 임시). 06 AI 비서의 할 일 카드와 같은 값이고, 지금 값이 칩에 없으면 더한다.
List<int> taskSheetEstimateChoices(int? current) => {
  ...const [30, 60, 120, 180],
  ?current,
}.toList()..sort();

/// 블록 줄의 모양.
enum TaskSheetBlockKind {
  /// 지금 하는 중인 확정 블록.
  now,

  /// 확정 블록.
  confirmed,

  /// 제안 블록.
  suggested,
}

/// 이 할 일의 블록 한 줄.
final class TaskSheetBlock {
  const TaskSheetBlock({
    required this.block,
    required this.kind,
    required this.text,
  });

  final PlanBlock block;
  final TaskSheetBlockKind kind;

  /// '내일 14:00–15:00 · 제안', '지금 하는 중 · 15:00까지'.
  final String text;
}

/// 작은 할 일 시트에 보일 것.
final class TaskSheetContent {
  const TaskSheetContent({
    required this.kicker,
    required this.title,
    required this.due,
    required this.dueUrgent,
    this.video,
    this.estimate,
    this.estimateChoices = const [],
    this.estimateNote,
    required this.blocks,
    required this.lms,
    required this.remaining,
  });

  /// 머리('자료구조 · 과제', '개인').
  final String kicker;
  final String title;

  /// 마감 문구('내일 23:59 마감', '마감 없음').
  final String due;

  /// 마감이 오늘·내일이라 붉게 쓴다(지난 마감은 아님).
  final bool dueUrgent;

  /// 영상 길이(영상만).
  final String? video;

  /// 지금 예상 시간(분). 모르면 null이다.
  final int? estimate;

  /// 예상 시간 칩. 영상이면 빈 목록이다(출석 인정 시간을 씀).
  final List<int> estimateChoices;

  /// 칩 아래 안내. 사용자가 고른 값이면 null이다.
  final String? estimateNote;

  /// 이 할 일의 앞으로의 확정·제안 블록(시작 순서).
  final List<TaskSheetBlock> blocks;

  /// LMS 할 일이면 [숨기기], 아니면 [지우기]를 둔다.
  final bool lms;

  /// 남은 할 일이면 [끝내기]를 둔다(끝냈거나 LMS가 제출·출석 인정을 알려 준 일은 아님).
  final bool remaining;
}

/// [entry]의 작은 할 일 시트. [blocks]는 앞으로의 블록이다(이 할 일이 아니거나 확정·제안이 아니거나 지난 것은 안에서
/// 거른다). [now]에는 `Clock.now`의 값을 넘긴다.
TaskSheetContent taskSheetContent(
  TaskEntry entry, {
  required List<PlanBlock> blocks,
  required PlannerConfig config,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final task = entry.task;
  final dueAt = task.dueAt;
  final video = task.kind == TaskKind.video;
  final rule = config.estimateMin(
    courseId: task.courseIdWith(entry.lmsItem),
    kind: task.kind,
  );
  final byKind = Defaults.estimateMinByKind[task.kind];
  final estimate = video ? null : task.estimateMin ?? rule ?? byKind;
  final String? note;
  if (video || task.estimateMin != null) {
    note = null;
  } else if (rule != null) {
    note = '내 규칙의 예상 시간이에요';
  } else if (byKind != null) {
    note = '${taskKindText(task.kind)} 기본 예상 시간이에요. 맞게 골라 주세요';
  } else {
    note = '예상 시간을 고르면 빈 시간에 놓아요';
  }
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
  return TaskSheetContent(
    kicker: taskKicker(entry),
    title: task.title,
    due: dueText(
      dueAt,
      dueTimeUnknown: task.dueTimeUnknown,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
      farAsDate: true,
    ),
    dueUrgent:
        dueAt != null &&
        !dueAt.isBefore(now) &&
        isDueSoon(
          dueDayOffset(dueAt, now: now, dayBoundaryMin: dayBoundaryMin),
        ),
    video: video ? taskVideoText(entry) : null,
    estimate: estimate,
    estimateChoices: video ? const [] : taskSheetEstimateChoices(estimate),
    estimateNote: note,
    blocks: [
      for (final block in mine)
        _blockLine(block, now: now, dayBoundaryMin: dayBoundaryMin),
    ],
    lms: task.lmsKey != null,
    remaining: entry.isRemaining,
  );
}

TaskSheetBlock _blockLine(
  PlanBlock block, {
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final start = block.startAt.hour * 60 + block.startAt.minute;
  final end = start + block.endAt.difference(block.startAt).inMinutes;
  if (block.status == PlanBlockStatus.confirmed &&
      !block.startAt.isAfter(now)) {
    return TaskSheetBlock(
      block: block,
      kind: TaskSheetBlockKind.now,
      text: '지금 하는 중 · ${hhmmText(end == 1440 ? 1440 : end % 1440)}까지',
    );
  }
  final suggested = block.status == PlanBlockStatus.suggested;
  return TaskSheetBlock(
    block: block,
    kind: suggested
        ? TaskSheetBlockKind.suggested
        : TaskSheetBlockKind.confirmed,
    text:
        '${dayWord(block.startAt, now: now, dayBoundaryMin: dayBoundaryMin)} '
        '${timeRangeText(start, end)} · ${suggested ? '제안' : '확정'}',
  );
}
