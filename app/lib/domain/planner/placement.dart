// 배치 엔진과 자리 추천이 함께 쓰는 자리 계산. docs/architecture.md '도메인 기본값과 배치 엔진' 3·4단계.
//
// 제안 배치(`plan_range.dart`의 `planRange`)와 자리 추천(`suggest_slots.dart`의 옮기기 시트 다른 시간·02 홈
// [다시 놓기])이 같은 점수·조각 길이·블록 간격·5분 단위를 쓰게 한 곳에 둔다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/day_availability.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 자리 점수의 가중치(임시값). 모의 실험으로 고르고 테스트로 고정한다.
abstract final class PlanWeights {
  /// 할 일(옮기기는 그 블록)을 이 조각으로 끝냄(쪼개지 않음).
  static const double unsplit = 3;

  /// 조각이 그 빈 구간을 채우는 정도(조각 ÷ 빈 구간).
  static const double fit = 2;

  /// 그 과목 수업과 가까움([Defaults.nearClassMin] 안).
  static const double nearClass = 2;

  /// 조각이 선호 시간대 안에 드는 비율.
  static const double preferred = 2;

  /// 최소 조각보다 짧게 남는 빈 조각 하나마다 깎는 점수.
  static const double fragment = 1;

  /// 옮기기 시트의 다른 시간: 오늘에서 하루 멀어질 때마다 깎는 점수. 점수가 비슷하면 가까운 날을 먼저 보인다.
  static const double laterDay = 0.25;
}

/// [kind] 할 일의 가장 짧은 조각(분). 영상·퀴즈는 짧은 빈 시간에도 놓는 가벼운 일이라
/// [Defaults.minLightChunkMin], 그 밖에는 [Defaults.minChunkMin]이다.
int minChunkMinFor(TaskKind kind) => switch (kind) {
  TaskKind.video || TaskKind.quiz => Defaults.minLightChunkMin,
  _ => Defaults.minChunkMin,
};

/// 다음 5분 단위로 올린다(이미 5분 단위면 그대로). 자동으로 고르는 자리는 5분 단위에서 시작한다.
DateTime roundUpToFive(DateTime at) {
  final floored = roundDownToFive(at);
  return floored == at ? at : floored.add(const Duration(minutes: 5));
}

/// 5분 단위로 내린다(초 아래는 버림).
DateTime roundDownToFive(DateTime at) =>
    DateTime(at.year, at.month, at.day, at.hour, at.minute - at.minute % 5);

/// [spans]를 앞뒤로 [Defaults.blockGapMin]씩 늘린다. 자동으로 고르는 자리는 늘린 구간 밖에만 두어 블록을
/// 이어 붙이지 않는다(docs/decisions.md 2026-11-15 '배치 기본값과 간격(E1–E7)').
List<TimeSpan> withBlockGap(Iterable<TimeSpan> spans) {
  const gap = Duration(minutes: Defaults.blockGapMin);
  return [
    for (final span in spans)
      TimeSpan(span.start.subtract(gap), span.end.add(gap)),
  ];
}

/// 그날의 수업 구간을 과목 id별로 묶는다. [availability]의 수업 바쁜 구간(`BusyKind.classTime`)을 그 수업 칸
/// ([slots])의 과목으로 나눈다. 관련 수업과의 거리를 볼 때 쓴다.
Map<int, List<TimeSpan>> classesByCourse(
  DayAvailability availability,
  Iterable<ClassSlot> slots,
) {
  final courses = {for (final slot in slots) slot.id: slot.courseId};
  final classes = <int, List<TimeSpan>>{};
  for (final busy in availability.busy) {
    if (busy.kind != BusyKind.classTime) continue;
    final courseId = courses[busy.sourceId];
    if (courseId != null) (classes[courseId] ??= []).add(busy.span);
  }
  return classes;
}

/// 논리적 하루 [date]의 선호 시간대 조각(`preferred` 규칙, [ruleSpansInLogicalDay]).
List<TimeSpan> preferredSpans(
  DateTime date, {
  required PlannerConfig config,
  required int dayBoundaryMin,
}) => ruleSpansInLogicalDay(
  date,
  dayBoundaryMin: dayBoundaryMin,
  rangesFor: (weekday) => config.forWeekday(weekday).preferred,
);

/// 할 일이 논리적 하루 [date]에 하루 창 끝을 늘린 빈 시간을 쓰는지. 시간 부족에서 '밤 시간 쓰기'를 고른 날
/// ([nightFrom], `YYYY-MM-DD`)부터 마감이 든 논리적 하루([dueDate])까지다.
bool usesNightWindowOn(
  DateTime date, {
  required String? nightFrom,
  required DateTime? dueDate,
}) =>
    nightFrom != null &&
    dueDate != null &&
    isoDate(date).compareTo(nightFrom) >= 0 &&
    !date.isAfter(dueDate);

/// [span]이 [lessons] 가운데 하나의 끝 뒤나 시작 앞 [Defaults.nearClassMin] 안인지(맞닿으면 0분).
bool isNearClass(TimeSpan span, Iterable<TimeSpan> lessons) {
  const near = Duration(minutes: Defaults.nearClassMin);
  for (final lesson in lessons) {
    final after = span.start.difference(lesson.end);
    final before = lesson.start.difference(span.end);
    if ((!after.isNegative && after <= near) ||
        (!before.isNegative && before <= near)) {
      return true;
    }
  }
  return false;
}

/// 한 자리의 점수와 그 자리의 가장 구체적인 이유.
final class SlotScore {
  const SlotScore(this.score, this.factor);

  final double score;

  /// 관련 수업과 가까움 → 선호 시간대(조각의 절반 이상) → 쪼개지 않음 → 길이 맞음 순서로 먼저 맞는 것.
  final BlockFactor factor;
}

/// 빈 구간 [segment] 안의 자리 [slot] 점수. [whole]이면 그 자리에 다 놓아 쪼개지 않는다(배치는 할 일의 남은
/// 시간, 옮기기는 그 블록 길이). [lessons]는 그날 그 할 일 과목의 수업(과목이 없으면 비움), [preferred]는 그날
/// 선호 시간대다.
///
/// 점수는 [PlanWeights]의 가중합이다: 쪼개지 않음, 길이 맞음(자리 ÷ 빈 구간), 관련 수업과 가까움, 선호 시간대에
/// 드는 비율, 자리 앞뒤로 최소 조각([Defaults.minChunkMin])보다 짧게 남는 빈 조각마다 깎는 점수.
SlotScore scoreSlot({
  required TimeSpan segment,
  required TimeSpan slot,
  required bool whole,
  required Iterable<TimeSpan> lessons,
  required Iterable<TimeSpan> preferred,
}) {
  final minutes = slot.minutes;
  final unsplit = whole ? PlanWeights.unsplit : 0.0;
  final fit = PlanWeights.fit * minutes / segment.minutes;
  final near = isNearClass(slot, lessons) ? PlanWeights.nearClass : 0.0;
  final inPreferred = [
    for (final window in preferred) ?window.intersection(slot),
  ].fold<int>(0, (sum, span) => sum + span.minutes);
  final preferredScore = PlanWeights.preferred * inPreferred / minutes;
  final leftovers = [
    slot.start.difference(segment.start).inMinutes,
    segment.end.difference(slot.end).inMinutes,
  ].where((left) => left > 0 && left < Defaults.minChunkMin).length;
  final factor = near > 0
      ? BlockFactor.nearClass
      : inPreferred * 2 >= minutes
      ? BlockFactor.preferred
      : unsplit > 0
      ? BlockFactor.unsplit
      : BlockFactor.fit;
  return SlotScore(
    unsplit + fit + near + preferredScore - PlanWeights.fragment * leftovers,
    factor,
  );
}
