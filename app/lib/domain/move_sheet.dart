// 옮기기 시트와 빈 시간에 놓기 시트에 보일 것. docs/screens.md '옮기기 시트'·'빈 시간에 놓기 시트'.
//
// 옮기기 시트의 후보는 배치 엔진의 `suggestSlots`가 고르고, 여기서는 그 문구('내일 14:00–15:00', 고른 이유,
// '14:00으로 옮기기')와 옮긴 뒤의 토스트를 만든다. 빈 시간에 놓기 시트의 후보(할 일 4개까지와 놓을 길이)는
// [freeSlotContent]가 정한다. 모양과 문구는 최종 프로토타입(02 홈의 두 시트)을 따르고, 문구는 디자인 전 임시
// 문구다. 시각 뒤 조사는 앱의 조사 규칙(숫자는 끝소리)대로 붙인다('14:00으로').

import 'dart:math' as math;

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/placement.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 빈 시간에 놓는 블록의 가장 긴 길이(분, 임시). docs/screens.md '빈 시간에 놓기 시트'.
const int freeSlotMaxMin = 120;

/// 빈 시간에 놓기 시트의 후보 수(최종 프로토타입).
const int freeSlotChoiceCount = 4;

/// 옮기기 시트의 후보 하나.
final class MoveChoice {
  const MoveChoice({
    required this.option,
    required this.when,
    required this.why,
    required this.cta,
  });

  final SlotOption option;

  /// 옮길 때('내일 14:00–15:00').
  final String when;

  /// 고른 이유 한 줄.
  final String why;

  /// 이 후보를 골랐을 때 버튼('14:00으로 옮기기').
  final String cta;
}

/// 옮기기 시트에 보일 것.
final class MoveSheetContent {
  const MoveSheetContent({
    required this.sub,
    required this.choices,
    required this.noneText,
  });

  /// 제목 아래 줄('{제목} · {길이} · {마감}').
  final String sub;

  /// 후보(좋은 순서). 비었으면 옮길 빈 시간이 없다.
  final List<MoveChoice> choices;

  /// 후보가 없을 때 안내. 마감이 있으면 '마감 전에 옮길 수 있는 빈 시간이 없어요'다.
  final String noneText;
}

/// [block]의 옮기기 시트. [options]는 `suggestSlots`의 결과다. [courseName]은 그 할 일의 과목 이름이다.
MoveSheetContent moveSheetContent({
  required PlanBlock block,
  required TaskEntry entry,
  required List<SlotOption> options,
  String? courseName,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final task = entry.task;
  return MoveSheetContent(
    sub: [
      task.title,
      durationText(block.endAt.difference(block.startAt).inMinutes),
      dueText(
        task.dueAt,
        dueTimeUnknown: task.dueTimeUnknown,
        now: now,
        dayBoundaryMin: dayBoundaryMin,
      ),
    ].join(' · '),
    choices: [
      for (final option in options)
        MoveChoice(
          option: option,
          when:
              '${dayWord(option.span.start, now: now, dayBoundaryMin: dayBoundaryMin)} '
              '${_range(option.span)}',
          why: _why(option, courseName),
          cta: '${withJosa(_hhmm(option.span.start), Josa.euroRo)} 옮기기',
        ),
    ],
    noneText: task.dueAt == null
        ? '옮길 수 있는 빈 시간이 없어요'
        : '마감 전에 옮길 수 있는 빈 시간이 없어요',
  );
}

/// 옮긴 뒤 토스트('{제목}을 내일 14:00으로 옮겼어요').
String movedToast(
  String title,
  DateTime start, {
  required DateTime now,
  required int dayBoundaryMin,
}) =>
    '${withJosa(title, Josa.eulReul)} '
    '${dayWord(start, now: now, dayBoundaryMin: dayBoundaryMin)} '
    '${withJosa(_hhmm(start), Josa.euroRo)} 옮겼어요';

/// 후보를 고른 이유(근거 시트의 이유와 같은 뜻, 최종 프로토타입).
String _why(SlotOption option, String? courseName) => switch (option.factor) {
  BlockFactor.nearClass =>
    '${courseName == null ? '관련' : courseName.trim()} 수업과 가까워 내용이 이어져요',
  BlockFactor.preferred => '평소 집중하는 시간이에요',
  BlockFactor.unsplit => '${durationText(option.gapMin)} 비어 있어 한 번에 끝낼 수 있어요',
  BlockFactor.fit => '${durationText(option.gapMin)} 비어 있어 한 조각을 끝낼 수 있어요',
};

/// 빈 시간에 놓기 시트의 후보 하나.
final class FreeSlotChoice {
  const FreeSlotChoice({
    required this.entry,
    required this.sub,
    required this.minutes,
  });

  final TaskEntry entry;

  /// 제목 아래 줄('과제 · 내일 23:59 마감').
  final String sub;

  /// 놓을 길이(분). 빈 시간의 시작부터 놓는다.
  final int minutes;

  int get taskId => entry.task.id;
  String get title => entry.task.title;
}

/// 빈 시간에 놓기 시트에 보일 것.
final class FreeSlotContent {
  const FreeSlotContent({
    required this.span,
    required this.title,
    required this.choices,
  });

  /// 놓을 빈 시간. 지금이나 그 전에 시작했으면 지금 뒤(5분 단위로 올림)부터다.
  final TimeSpan span;

  /// 제목('15:00–16:30 · 1시간 30분 비어 있어요', 오늘이 아니면 날짜 말을 앞에).
  final String title;

  final List<FreeSlotChoice> choices;
}

/// [gap] 빈 시간에 놓기 시트. 빈 시간이 지금 지났으면(남은 빈 시간이 5분 단위로 올린 지금 뒤에 없으면)
/// null이다.
///
/// - 빈 시간이 지금이나 그 전에 시작했으면 지금 뒤(5분 단위로 올림)부터 센다([FreeSlotContent.span]). 오늘 시간표의
///   빈 시간 카드는 지금부터 그리므로 그 카드를 누르면 늘 이렇다.
/// - 후보는 남은 할 일 가운데 그 빈 시간이 시작하고 1분 뒤부터 마감이거나 마감이 없고, 그때 공개된 할 일을 급한
///   순서([ranked], 배치 엔진의 급한 순서. 없는 할 일은 뒤), 같으면 마감 순서로 [freeSlotChoiceCount]개까지다.
///   남은 작업이 없는 할 일은 뺀다.
/// - 길이는 빈 시간·남은 작업 시간·[freeSlotMaxMin]·마감까지 가운데 가장 짧은 것이다. 남은 작업 시간을 모르면
///   (예상 시간이 없는 토론·시험) 그것만 빼고 견준다.
FreeSlotContent? freeSlotContent({
  required TimeSpan gap,
  required List<TaskEntry> entries,
  required List<int> ranked,
  required PlannerConfig config,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final from = gap.start.isAfter(now) ? gap.start : roundUpToFive(now);
  if (!from.isBefore(gap.end)) return null;
  final span = TimeSpan(from, gap.end);
  final start = span.start;

  int order(TaskEntry entry) {
    final index = ranked.indexOf(entry.task.id);
    return index < 0 ? ranked.length : index;
  }

  int byDue(TaskEntry a, TaskEntry b) {
    final da = a.task.dueAt, db = b.task.dueAt;
    if (da == null || db == null) {
      return (da == null ? 1 : 0) - (db == null ? 1 : 0);
    }
    return da.compareTo(db);
  }

  final open =
      entries.where((entry) {
        if (!entry.isRemaining) return false;
        final dueAt = entry.task.dueAt;
        if (dueAt != null && dueAt.difference(start).inMinutes < 1) {
          return false;
        }
        final openAt = entry.lmsItem?.openAt;
        if (openAt != null && openAt.isAfter(start)) return false;
        final work = remainingWorkMin(entry, config);
        return work == null || work > 0;
      }).toList()..sort((a, b) {
        final byRank = order(a).compareTo(order(b));
        if (byRank != 0) return byRank;
        final due = byDue(a, b);
        return due != 0 ? due : a.task.id.compareTo(b.task.id);
      });
  return FreeSlotContent(
    span: span,
    title:
        '${_dayPrefix(start, now: now, dayBoundaryMin: dayBoundaryMin)}'
        '${_range(span)} · ${durationText(span.minutes)} 비어 있어요',
    choices: [
      for (final entry in open.take(freeSlotChoiceCount))
        FreeSlotChoice(
          entry: entry,
          sub:
              '${taskKindText(entry.task.kind)} · '
              '${dueText(entry.task.dueAt, dueTimeUnknown: entry.task.dueTimeUnknown, now: now, dayBoundaryMin: dayBoundaryMin)}',
          minutes: [
            span.minutes,
            freeSlotMaxMin,
            ?remainingWorkMin(entry, config),
            if (entry.task.dueAt case final dueAt?)
              dueAt.difference(start).inMinutes,
          ].reduce(math.min),
        ),
    ],
  );
}

/// 놓은 뒤 토스트('{제목}을 15:00–16:00에 놓았어요', 오늘이 아니면 날짜 말을 앞에).
String placedToast(
  String title,
  TimeSpan span, {
  required DateTime now,
  required int dayBoundaryMin,
}) =>
    '${withJosa(title, Josa.eulReul)} '
    '${_dayPrefix(span.start, now: now, dayBoundaryMin: dayBoundaryMin)}'
    '${_range(span)}에 놓았어요';

/// 오늘(논리적 하루)이 아니면 '{날짜 말} ', 오늘이면 빈 글자.
String _dayPrefix(
  DateTime at, {
  required DateTime now,
  required int dayBoundaryMin,
}) =>
    logicalDate(at, dayBoundaryMin: dayBoundaryMin) ==
        logicalDate(now, dayBoundaryMin: dayBoundaryMin)
    ? ''
    : '${dayWord(at, now: now, dayBoundaryMin: dayBoundaryMin)} ';

/// 'HH:MM–HH:MM'. 끝이 정확히 자정이면 24:00, 자정을 넘으면 실제 시각이다.
String _range(TimeSpan span) {
  final start = span.start.hour * 60 + span.start.minute;
  return timeRangeText(start, start + span.minutes);
}

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);
