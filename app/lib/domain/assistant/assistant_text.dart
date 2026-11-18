// 06 AI 비서 카드의 문구와 예상 시간. docs/screens.md '06 AI 비서'(카드 1·2·3·5), docs/architecture.md '도메인
// 기본값과 배치 엔진'(예상 시간의 순서).
//
// 저장한 카드에 적는 '다시 계산한 제안'은 저장 직전과 직후의 배치 결과([PlanResult])를 견줘 만든다. 문구는
// 디자인 전 임시 문구다(최종 프로토타입의 06 문구를 따름).

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 반복 요일 '매일'·'평일마다'·'주말마다'·'매주 월·수'. [weekdays]는 1–7 오름차순이다.
String repeatText(List<int> weekdays) {
  if (weekdays.length == 7) return '매일';
  if (_sameList(weekdays, const [1, 2, 3, 4, 5])) return '평일마다';
  if (_sameList(weekdays, const [6, 7])) return '주말마다';
  return '매주 ${weekdays.map(weekdayText).join('·')}';
}

/// 일정이 언제인지: 반복이면 '주말마다 14:00', 한 번뿐이면 '10월 15일 (목) 19:00'(시간 미정이면 '10월 15일
/// (목) · 시간 미정'). 토스트와 저장한 카드에 쓴다. [today]는 오늘의 달력 날짜다.
String eventWhenText(EventDraft draft, {required DateTime today}) {
  final start = draft.startMin;
  final weekdays = draft.weekdays;
  if (weekdays != null) {
    return start == null
        ? repeatText(weekdays)
        : '${repeatText(weekdays)} ${hhmmText(start)}';
  }
  final date = monthDayText(draft.date!, today: today);
  return start == null ? '$date · 시간 미정' : '$date ${hhmmText(start)}';
}

/// 날짜 말: 오늘·내일·모레, 6일 뒤까지는 '{요일}요일', 그 뒤는 'N일 뒤', 지난 날은 'N일 전'. 날은 [today]와 같은
/// 달력 날짜로 센다(요청의 today와 같고 하루 경계를 적용하지 않음).
String relativeDayText(DateTime date, {required DateTime today}) {
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (days) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    >= 3 && <= 6 => '${weekdayText(date.weekday)}요일',
    < 0 => '${-days}일 전',
    _ => '$days일 뒤',
  };
}

/// 시간 범위와 길이 '14:00–17:00 · 3시간'. 시간 미정이면 '시간 미정'.
String eventSpanText(EventDraft draft) {
  final start = draft.startMin;
  final end = draft.endMin;
  if (start == null || end == null) return '시간 미정';
  return '${timeRangeText(start, end)} · ${durationText(end - start)}';
}

/// 예상 시간을 어디서 정했는지.
enum EstimateSource {
  /// 카드의 칩으로 골랐다.
  picked,

  /// 문장에서 말했다.
  said,

  /// 그 과목·종류의 예상 시간 규칙.
  rule,

  /// 종류별 기본값(임시).
  kindDefault,

  /// 없다(토론·시험은 기본값이 없어 고르기 전에는 자동으로 놓지 않음).
  none,
}

/// 카드에 보일 예상 시간과 그 출처. 고른 값 → 말한 값 → 그 과목·종류의 예상 시간 규칙 → 종류별 기본값(임시)
/// 순서다(배치 엔진의 순서와 같음). [courseId]는 할 일의 과목, [config]는 지금 배치 설정이다(읽기 전이면 null이고
/// 규칙을 보지 않는다).
({int? minutes, EstimateSource source}) taskEstimateOf(
  TaskDraft draft, {
  required int? courseId,
  required PlannerConfig? config,
}) {
  if (draft.pickedEstimateMin case final picked?) {
    return (minutes: picked, source: EstimateSource.picked);
  }
  if (draft.saidEstimateMin case final said?) {
    return (minutes: said, source: EstimateSource.said);
  }
  if (config?.estimateMin(courseId: courseId, kind: draft.kind)
      case final rule?) {
    return (minutes: rule, source: EstimateSource.rule);
  }
  if (Defaults.estimateMinByKind[draft.kind] case final byKind?) {
    return (minutes: byKind, source: EstimateSource.kindDefault);
  }
  return (minutes: null, source: EstimateSource.none);
}

/// 예상 시간 칩(분, 임시). 지금 값이 칩에 없으면 더한다.
List<int> estimateChoices(int? current) => {
  ...const [30, 60, 120, 180],
  ?current,
}.toList()..sort();

/// 예상 시간 칩 아래의 안내(임시). 고른 값이면 null이다.
String? estimateNote(EstimateSource source, TaskKind kind) => switch (source) {
  EstimateSource.picked => null,
  EstimateSource.said => '말한 시간으로 잡았어요',
  EstimateSource.rule => '내 규칙의 예상 시간으로 잡았어요',
  EstimateSource.kindDefault =>
    '처음이라 ${taskKindText(kind)} 기본값으로 잡았어요. 맞게 골라 주세요',
  EstimateSource.none => '예상 시간을 고르면 빈 시간에 놓아요',
};

/// 바꾸기·지우기 카드의 '지금': 일정은 '{M월 D일 (요)} HH:MM–HH:MM'(종일이면 '{날짜} · 종일'), 고정 일정은
/// '{반복} HH:MM–HH:MM'.
String targetWhenText(ChangeTarget target, {required DateTime today}) =>
    switch (target) {
      EventTarget(:final event) => _eventWhen(
        event.startAt,
        event.endAt,
        allDay: event.allDay,
        today: today,
      ),
      FixedTarget(:final block) =>
        '${repeatText(block.weekdays)} '
            '${timeRangeText(block.startMin, block.endMin)}',
    };

/// 바꾸기 카드의 '바꾼 뒤'([targetWhenText]와 같은 꼴).
String afterWhenText(ChangeAfter after, {required DateTime today}) =>
    switch (after) {
      EventAfter(:final startAt, :final endAt, :final allDay) => _eventWhen(
        startAt,
        endAt,
        allDay: allDay,
        today: today,
      ),
      FixedAfter(:final weekdays, :final startMin, :final endMin) =>
        '${repeatText(weekdays)} ${timeRangeText(startMin, endMin)}',
    };

String _eventWhen(
  DateTime startAt,
  DateTime endAt, {
  required bool allDay,
  required DateTime today,
}) {
  final date = monthDayText(
    DateTime(startAt.year, startAt.month, startAt.day),
    today: today,
  );
  if (allDay) return '$date · 종일';
  final start = startAt.hour * 60 + startAt.minute;
  final minutes = endAt.difference(startAt).inMinutes;
  if (minutes <= 0) return '$date ${hhmmText(start)}';
  // 하루를 넘는 일정은 하루 안의 끝까지만 적는다.
  final length = minutes < 1440 ? minutes : 1439;
  return '$date ${timeRangeText(start, start + length)}';
}

/// 수업 변경·일정 바꾸기·지우기 뒤 다시 계산한 제안. 직후([after])에 새로 놓인 제안이 있으면 '제안 N개를 다시
/// 놓았어요', 없이 빠지기만 했으면 '제안 N개를 뺐어요'이고, 그대로거나 결과를 모르면 null이다.
String? replanNote(PlanResult? before, PlanResult? after) {
  if (before == null || after == null) return null;
  Set<(int, DateTime, DateTime)> keys(PlanResult plan) => {
    for (final block in plan.blocks) (block.taskId, block.startAt, block.endAt),
  };
  final old = keys(before);
  final fresh = keys(after);
  final placed = fresh.difference(old).length;
  if (placed > 0) return '제안 $placed개를 다시 놓았어요';
  final removed = old.difference(fresh).length;
  return removed > 0 ? '제안 $removed개를 뺐어요' : null;
}

/// 일정을 넣은 뒤 다시 계산한 제안. 넣기 직전([before])에 있던 제안 가운데 직후([after])에 없는 것이 있으면
/// '겹치던 제안 N개를 다른 빈 시간으로 옮겼어요'이고, 없거나 결과를 모르면 null이다.
String? eventPlanNote(PlanResult? before, PlanResult? after) {
  if (before == null || after == null) return null;
  final kept = {
    for (final block in after.blocks)
      (block.taskId, block.startAt, block.endAt),
  };
  final moved = before.blocks
      .where(
        (block) => !kept.contains((block.taskId, block.startAt, block.endAt)),
      )
      .length;
  return moved == 0 ? null : '겹치던 제안 $moved개를 다른 빈 시간으로 옮겼어요';
}

/// 할 일을 넣은 뒤 놓인 자리. [plan]은 넣은 뒤의 배치 결과이고 모르면 null이다. [estimate]는 그 할 일의 예상
/// 시간(없으면 자동으로 놓지 않음), [hasTimetable]은 수업 칸이 하나라도 있는지다(없으면 배치 엔진이 아무것도
/// 놓지 않음). [now]에는 [Clock.now]의 값을 넘긴다.
String? taskPlanNote({
  required TaskDraft draft,
  required int taskId,
  required int? estimate,
  required PlanResult? plan,
  required bool hasTimetable,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final due = draft.dueAt;
  if (due == null) return '마감이 없어 자동으로 놓지 않아요';
  if (estimate == null) return '예상 시간을 몰라 자동으로 놓지 않아요';
  if (!hasTimetable) return '시간표가 없어 아직 자동으로 놓지 않아요';
  if (plan == null) return null;
  final blocks = plan.blocks.where((block) => block.taskId == taskId).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  if (blocks.isNotEmpty) {
    final first = blocks.first;
    final start = first.startAt.hour * 60 + first.startAt.minute;
    final end = start + first.endAt.difference(first.startAt).inMinutes;
    final day = dayWord(
      first.startAt,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    );
    final split = blocks.length > 1 ? '${blocks.length}번에 나눠 놓았어요. ' : '';
    return '$split먼저 $day ${timeRangeText(start, end)}에 놓았어요 · 확정 전 제안이에요';
  }
  if (plan.shortages.any((shortage) => shortage.taskId == taskId)) {
    return '마감 전 빈 시간이 모자라요 · 홈에서 방법을 골라 주세요';
  }
  if (due.isAfter(now.add(const Duration(days: Defaults.planHorizonDays)))) {
    return '마감 ${Defaults.planHorizonDays}일 전부터 빈 시간에 놓아요';
  }
  return '마감 전에 놓을 빈 시간을 찾지 못했어요';
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
