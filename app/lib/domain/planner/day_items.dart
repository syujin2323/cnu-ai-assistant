// 하루 시간표에 그리는 항목. docs/screens.md '02 홈'의 오늘 시간표·'09 일간'의 시간표, docs/architecture.md
// '도메인 기본값과 배치 엔진' 1단계.
//
// 02 홈과 09 일간이 같은 목록을 그린다. 이동·점심·고정 일정의 자리는 빈 시간 계산([DayAvailability])과 같은
// 값을 써서 화면과 배치가 어긋나지 않게 하고, 수업은 휴강·시험·장소 변경·보강을 보이려고 수업 예외와 함께 따로
// 센다(빈 시간 계산은 휴강한 수업을 빼므로). 종일 일정은 시간표 칸이 아니라 위의 따로 된 줄에 보이므로 여기에
// 넣지 않는다. 지운 블록은 넣지 않고, 제안 블록은 [includeSuggested]일 때만 넣는다(09 일간은 넣고 02 홈은 뺌,
// docs/screens.md '제안과 확정'). 목록은 시작 순서이고, 같으면 수업 → 일정 → 고정 일정 → 이동 → 점심 → 블록,
// 그다음 id 순서다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';

/// 하루 시간표의 항목 하나.
sealed class DayItem {
  const DayItem(this.span);

  /// 그 논리적 하루 안으로 자른 시각.
  final TimeSpan span;

  /// 같은 시각일 때의 순서.
  int get _order;

  /// 같은 시각·같은 종류일 때의 순서.
  int get _id;
}

/// 수업 한 번. 휴강한 수업도 [cancelled]로 넣는다(시간표에서 흐리게 그림).
final class ClassItem extends DayItem {
  const ClassItem(
    super.span, {
    required this.slot,
    this.cancelled = false,
    this.exam = false,
    this.makeup = false,
    this.placeChanged = false,
    this.place,
    this._date,
  });

  final ClassSlot slot;

  final DateTime? _date;

  /// 수업(보강이면 그 보강)이 열리는 달력 날짜의 0시. 수업 예외(`class_exceptions.date`)는 이 날짜에 둔다.
  /// [span]은 논리적 하루로 자른 시각이라, 하루 경계를 걸친 수업이면 [span]이 시작하는 날짜와 다를 수 있다.
  /// 넘기지 않았으면 [span]이 시작하는 날짜다.
  DateTime get date =>
      _date ?? DateTime(span.start.year, span.start.month, span.start.day);

  /// 그날 휴강이다. 시간을 막지 않는다.
  final bool cancelled;

  /// 그날 이 수업 시간이 시험이다.
  final bool exam;

  /// 보강으로 여는 수업이다.
  final bool makeup;

  /// 그날만 장소를 바꾼 수업이다([place]가 바뀐 장소).
  final bool placeChanged;

  /// 그날의 강의실(장소 변경·시험 장소·보강 장소가 있으면 그 값, 없으면 수업 칸의 값).
  final String? place;

  @override
  int get _order => 0;

  @override
  int get _id => slot.id;
}

/// 일정(종일 일정은 빼고).
final class EventItem extends DayItem {
  const EventItem(super.span, {required this.event});

  final Event event;

  @override
  int get _order => 1;

  @override
  int get _id => event.id;
}

/// 고정 일정 한 번(앞뒤 여유는 빼고).
final class FixedItem extends DayItem {
  const FixedItem(super.span, {required this.block});

  final FixedBlock block;

  @override
  int get _order => 2;

  @override
  int get _id => block.id;
}

/// 이동 시간. 화면은 15분 미만을 그리지 않는다.
final class TravelItem extends DayItem {
  const TravelItem(super.span);

  @override
  int get _order => 3;

  @override
  int get _id => 0;
}

/// 식사로 비운 시간.
final class MealItem extends DayItem {
  const MealItem(super.span);

  @override
  int get _order => 4;

  @override
  int get _id => 0;
}

/// 할 일 블록.
final class BlockItem extends DayItem {
  const BlockItem(super.span, {required this.block, this.entry});

  final PlanBlock block;

  /// 블록의 할 일(목록에 없으면 null. 숨긴 LMS 할 일 등).
  final TaskEntry? entry;

  /// '부분 목표'로 줄인 할 일의 블록이다.
  bool get partial => entry?.task.partialGoalMin != null;

  /// LMS에서 사라진 할 일의 블록이다(흐리게 그림).
  bool get gone => entry?.isGone ?? false;

  @override
  int get _order => 5;

  @override
  int get _id => block.id;
}

/// 논리적 하루 [day]의 시간표 항목을 시작 순서로 돌려준다. [availability]는 같은 날의 빈 시간 계산이다
/// ([dayAvailability]. 이동·점심·고정 일정의 자리를 여기서 읽음). [tasks]는 블록의 할 일을 찾는 데 쓴다.
List<DayItem> dayItems(
  DateTime day, {
  required Schedule schedule,
  required DayAvailability availability,
  required List<TaskEntry> tasks,
  required int dayBoundaryMin,
  bool includeSuggested = false,
}) {
  final date = DateTime(day.year, day.month, day.day);
  final logical = TimeSpan(
    logicalDayStart(date, dayBoundaryMin: dayBoundaryMin),
    logicalDayEnd(date, dayBoundaryMin: dayBoundaryMin),
  );
  final fixedById = {for (final block in schedule.fixedBlocks) block.id: block};
  final taskById = {for (final entry in tasks) entry.task.id: entry};
  final items = <DayItem>[
    ..._classItems(date, logical, schedule),
    for (final event in schedule.events)
      if (!event.allDay)
        if (TimeSpan(event.startAt, event.endAt).intersection(logical)
            case final span?)
          EventItem(span, event: event),
    for (final busy in availability.busy)
      if (busy.kind == BusyKind.fixedBlock && fixedById[busy.sourceId] != null)
        FixedItem(busy.span, block: fixedById[busy.sourceId]!),
    for (final span in availability.travel) TravelItem(span),
    for (final span in availability.meals) MealItem(span),
    for (final block in schedule.planBlocks)
      if (block.status != PlanBlockStatus.dismissed &&
          (includeSuggested || block.status != PlanBlockStatus.suggested))
        if (TimeSpan(block.startAt, block.endAt).intersection(logical)
            case final span?)
          BlockItem(span, block: block, entry: taskById[block.taskId]),
  ];
  items.sort((a, b) {
    for (final order in [
      a.span.start.compareTo(b.span.start),
      a._order.compareTo(b._order),
      a.span.end.compareTo(b.span.end),
      a._id.compareTo(b._id),
    ]) {
      if (order != 0) return order;
    }
    return 0;
  });
  return items;
}

/// 그 논리적 하루의 수업. 평소 요일의 수업은 그날의 휴강·시험·장소 변경을 붙여 넣고, 보강은 저장된 보강
/// 시각(없으면 평소 시각)에 넣는다. 자정을 넘는 수업을 위해 전날·그날·다음 날을 본다.
List<ClassItem> _classItems(
  DateTime date,
  TimeSpan logical,
  Schedule schedule,
) {
  final exceptions = <(String, int), List<ClassException>>{};
  for (final exception in schedule.classExceptions) {
    (exceptions[(exception.date, exception.classSlotId)] ??= []).add(exception);
  }
  ClassException? kind(List<ClassException> list, ClassExceptionKind kind) {
    for (final exception in list) {
      if (exception.kind == kind) return exception;
    }
    return null;
  }

  final items = <ClassItem>[];
  for (var offset = -1; offset <= 1; offset++) {
    final on = DateTime(date.year, date.month, date.day + offset);
    for (final slot in schedule.classSlots) {
      final list = exceptions[(isoDate(on), slot.id)] ?? const [];
      if (slot.weekday == on.weekday) {
        final span = _span(
          on,
          slot.startMin,
          slot.endMin,
        ).intersection(logical);
        if (span != null) {
          final cancelled = kind(list, ClassExceptionKind.cancelled);
          final exam = kind(list, ClassExceptionKind.exam);
          final moved = kind(list, ClassExceptionKind.placeChange);
          items.add(
            ClassItem(
              span,
              slot: slot,
              cancelled: cancelled != null,
              exam: exam != null,
              placeChanged: moved != null,
              place: moved?.place ?? exam?.place ?? slot.place,
              date: on,
            ),
          );
        }
      }
      for (final makeup in list) {
        if (makeup.kind != ClassExceptionKind.makeup) continue;
        final span = _span(
          on,
          makeup.startMin ?? slot.startMin,
          makeup.endMin ?? slot.endMin,
        ).intersection(logical);
        if (span == null) continue;
        items.add(
          ClassItem(
            span,
            slot: slot,
            makeup: true,
            place: makeup.place ?? slot.place,
            date: on,
          ),
        );
      }
    }
  }
  return items;
}

TimeSpan _span(DateTime date, int startMin, int endMin) => TimeSpan(
  DateTime(date.year, date.month, date.day, 0, startMin),
  DateTime(date.year, date.month, date.day, 0, endMin),
);
