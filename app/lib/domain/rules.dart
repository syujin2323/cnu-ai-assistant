// 내 규칙의 값 검사와, 기본값 위에 규칙을 덮은 설정. docs/architecture.md '내 규칙'.
//
// - 배치 엔진은 [PlannerConfig], 알림 예약은 [NotifyConfig]만 받고 `rules` 행을 직접 읽지 않는다.
//   둘 다 `domain/defaults.dart`의 기본값(임시값)에서 시작해 켜진 규칙을 덮어 만든다.
// - 같은 자리를 다투는 규칙이 여럿이면 나중에 저장한 것(`updatedAt`, 같으면 `id`가 큰 것)을 쓴다.
//   입력 순서와 상관없이 같은 규칙이면 같은 설정이 나온다.
// - 저장할 때 이전 규칙을 끄고 합치는 일은 저장소가 한다. 여기서는 그 결과가 어긋나 있어도
//   위 순서로 같은 답을 낸다.
// - [validateRule]을 통과하지 못한 규칙(범위가 좁아진 뒤 남은 옛 규칙 등)은 설정에 넣지 않는다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 규칙 값의 허용 범위. 팀이 정한 값이 아니라 임시값이다(사용자 테스트 뒤 정한다).
abstract final class RuleLimits {
  /// 분 값의 기본 범위.
  static const int minutesMin = 0;
  static const int minutesMax = 240;

  /// 하루 최대 공부량(`daily_cap`)의 분 범위.
  static const int dailyCapMin = 30;
  static const int dailyCapMax = 720;

  /// 한 번에 할 최대 시간(`max_block`)의 분 범위.
  static const int maxBlockMin = 25;
  static const int maxBlockMax = 240;

  /// 알림 하루 상한(`notifyCap`)의 범위.
  static const int notifyCapMin = 0;
  static const int notifyCapMax = 20;
}

/// 규칙 값 검사에서 걸린 이유.
enum RuleIssueKind {
  /// 그 종류에 필요한 값이 없다.
  missing,

  /// 그 종류가 쓰지 않는 값이 있다.
  notAllowed,

  /// 값이 허용 범위 밖이다.
  outOfRange,

  /// 끝이 시작보다 늦지 않거나, 시작에서 하루(1440분) 이상 떨어져 있다.
  badOrder,
}

/// 규칙 값 검사에서 걸린 값 하나. 앱은 이것으로 되묻기 문장을 고른다.
final class RuleIssue {
  const RuleIssue(this.field, this.kind);

  /// `rules.params`의 JSON 키(`minutes`, `startMin` 등) 또는 `weekdays`.
  final String field;

  final RuleIssueKind kind;

  @override
  bool operator ==(Object other) =>
      other is RuleIssue && other.field == field && other.kind == kind;

  @override
  int get hashCode => Object.hash(field, kind);

  @override
  String toString() => 'RuleIssue($field, ${kind.name})';
}

/// 규칙 값을 검사한다. 빈 목록이면 저장할 수 있다.
///
/// 하나만 두는 종류(`class_buffer`, `max_block`, `notify`)는 기존 행과 합친 뒤의 값을 넣는다.
/// 범위는 [RuleLimits](임시값)이고, 시각은 하루 안(0–1439)에서 시작해 끝이 시작보다 늦고
/// 하루를 넘지 않아야 한다(자정을 넘으면 끝에 1440을 더한다).
List<RuleIssue> validateRule(
  RuleKind kind,
  RuleParams params, {
  List<int>? weekdays,
}) {
  final shape = _shapes[kind]!;
  final present = params.toJson().keys.toSet();
  final issues = <RuleIssue>[
    for (final field in present)
      if (!shape.required.contains(field) && !shape.optional.contains(field))
        RuleIssue(field, RuleIssueKind.notAllowed),
    for (final field in shape.required)
      if (!present.contains(field)) RuleIssue(field, RuleIssueKind.missing),
  ];

  // 선택 값이 있는 종류(`estimate`, `notify`)는 그중 하나는 있어야 한다.
  if (shape.optional.isNotEmpty &&
      present.intersection(shape.optional).isEmpty) {
    issues.add(RuleIssue(shape.optional.first, RuleIssueKind.missing));
  }
  // 조용한 시간은 시작과 끝을 함께 둔다. 한쪽만 기본값과 섞이면 하루를 넘는 구간이 생길 수 있다.
  if ((params.quietStartMin == null) != (params.quietEndMin == null)) {
    issues.add(
      RuleIssue(
        params.quietStartMin == null ? 'quietStartMin' : 'quietEndMin',
        RuleIssueKind.missing,
      ),
    );
  }

  final minutes = params.minutes;
  if (minutes != null) {
    final (min, max) = switch (kind) {
      RuleKind.dailyCap => (RuleLimits.dailyCapMin, RuleLimits.dailyCapMax),
      RuleKind.maxBlock => (RuleLimits.maxBlockMin, RuleLimits.maxBlockMax),
      _ => (RuleLimits.minutesMin, RuleLimits.minutesMax),
    };
    if (minutes < min || minutes > max) {
      issues.add(const RuleIssue('minutes', RuleIssueKind.outOfRange));
    }
  }

  _checkRange(issues, 'startMin', params.startMin, 'endMin', params.endMin);
  _checkRange(
    issues,
    'quietStartMin',
    params.quietStartMin,
    'quietEndMin',
    params.quietEndMin,
  );
  final briefingMin = params.briefingMin;
  if (briefingMin != null && !_isMinuteOfDay(briefingMin)) {
    issues.add(const RuleIssue('briefingMin', RuleIssueKind.outOfRange));
  }
  final notifyCap = params.notifyCap;
  if (notifyCap != null &&
      (notifyCap < RuleLimits.notifyCapMin ||
          notifyCap > RuleLimits.notifyCapMax)) {
    issues.add(const RuleIssue('notifyCap', RuleIssueKind.outOfRange));
  }

  // 식사 시간은 그 시간대 안에 들어가야 한다.
  final (start, end) = (params.startMin, params.endMin);
  if (kind == RuleKind.meal &&
      minutes != null &&
      start != null &&
      end != null &&
      minutes > end - start) {
    issues.add(const RuleIssue('minutes', RuleIssueKind.outOfRange));
  }

  if (weekdays != null) {
    if (!shape.weekdays) {
      issues.add(const RuleIssue('weekdays', RuleIssueKind.notAllowed));
    } else if (weekdays.isEmpty ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      issues.add(const RuleIssue('weekdays', RuleIssueKind.outOfRange));
    }
  }
  return issues;
}

/// 하루 안의 시각 구간. 자정 기준 분이고, 자정을 넘으면 [endMin]에 1440을 더한다.
final class MinuteRange {
  const MinuteRange(this.startMin, this.endMin);

  final int startMin;

  final int endMin;

  int get minutes => endMin - startMin;

  bool overlaps(MinuteRange other) =>
      startMin < other.endMin && other.startMin < endMin;

  @override
  bool operator ==(Object other) =>
      other is MinuteRange &&
      other.startMin == startMin &&
      other.endMin == endMin;

  @override
  int get hashCode => Object.hash(startMin, endMin);

  @override
  String toString() => 'MinuteRange($startMin, $endMin)';
}

/// 배치에서 보호하는 식사. [window] 안에 [minutes]만큼 비워 둔다.
final class MealGuard {
  const MealGuard({required this.window, required this.minutes});

  final MinuteRange window;

  final int minutes;
}

/// 이동 시간(`travel` 규칙). 실시간 비대면 수업만 있는 날에는 배치 엔진이 쓰지 않는다.
final class TravelTime {
  const TravelTime({required this.minutes, required this.position});

  final int minutes;

  final TravelPosition position;
}

/// 한 요일에 적용하는 배치 조건. 요일을 고를 수 있는 규칙만 여기에 둔다.
final class DayPlanRules {
  const DayPlanRules({
    required this.workWindow,
    required this.travel,
    required this.blackouts,
    required this.preferred,
    required this.dailyCapMin,
  });

  /// 공부 가능한 시간대(`work_window`, 기본은 하루 창).
  final MinuteRange workWindow;

  /// 이동 시간. 규칙이 없으면 null.
  final TravelTime? travel;

  /// 피할 시간. 시작 시각 순서.
  final List<MinuteRange> blackouts;

  /// 선호 시간대. 시작 시각 순서. 비어 있으면 점수에서 선호 요소를 세지 않는다.
  final List<MinuteRange> preferred;

  /// 하루 최대 공부량(분). 규칙이 없으면 null(상한 없음).
  final int? dailyCapMin;
}

/// 배치 엔진이 받는 설정. 기본값([Defaults]) 위에 켜진 규칙을 덮은 것이다.
///
/// 식사 고정 일정이 식사 보호를 대신하는 것, 비대면 수업만 있는 날 이동 시간을 빼는 것은
/// 그날의 일정을 아는 배치 엔진이 한다.
final class PlannerConfig {
  PlannerConfig._({
    required this.classBufferMin,
    required this.maxBlockMin,
    required this.meals,
    required this._days,
    required this._estimates,
  });

  factory PlannerConfig.from(Iterable<Rule> rules) {
    final usable = _usableLatestFirst(rules);
    List<Rule> ofKind(RuleKind kind) =>
        usable.where((rule) => rule.kind == kind).toList();

    const defaultMeal = MealGuard(
      window: MinuteRange(
        Defaults.mealWindowStartMin,
        Defaults.mealWindowEndMin,
      ),
      minutes: Defaults.mealMin,
    );
    final mealRules = [
      for (final rule in ofKind(RuleKind.meal))
        MealGuard(
          window: MinuteRange(rule.params.startMin!, rule.params.endMin!),
          minutes: rule.params.minutes!,
        ),
    ];
    // 기본 식사 시간대와 겹치는 규칙은 기본값을 바꾼 것이고, 겹치지 않으면 저녁처럼 더한 것이다.
    final replacesDefault = mealRules.any(
      (meal) => meal.window.overlaps(defaultMeal.window),
    );

    return PlannerConfig._(
      classBufferMin:
          ofKind(RuleKind.classBuffer).firstOrNull?.params.minutes ??
          Defaults.classBufferMin,
      maxBlockMin:
          ofKind(RuleKind.maxBlock).firstOrNull?.params.minutes ??
          Defaults.maxBlockMin,
      meals: [...mealRules, if (!replacesDefault) defaultMeal]
        ..sort((a, b) => a.window.startMin.compareTo(b.window.startMin)),
      days: [
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        )
          _dayRules(usable, weekday),
      ],
      estimates: ofKind(RuleKind.estimate),
    );
  }

  /// 수업 앞뒤 여유(분). 실시간 비대면 수업은 배치 엔진이 0으로 둔다.
  final int classBufferMin;

  /// 한 번에 할 최대 시간(분).
  final int maxBlockMin;

  /// 보호하는 식사. 시작 시각 순서.
  final List<MealGuard> meals;

  final List<DayPlanRules> _days;

  /// 나중에 저장한 것이 먼저다.
  final List<Rule> _estimates;

  /// [weekday](1 월 – 7 일)에 적용하는 조건. 블록이 시작하는 논리적 하루의 요일을 넣는다.
  DayPlanRules forWeekday(int weekday) {
    RangeError.checkValueInInterval(
      weekday,
      DateTime.monday,
      DateTime.sunday,
      'weekday',
    );
    return _days[weekday - DateTime.monday];
  }

  /// `estimate` 규칙의 예상 시간(분). 과목·종류가 모두 맞는 것, 과목만 맞는 것, 종류만 맞는 것
  /// 순서로 찾고, 없으면 null이다(배치 엔진이 종류별 기본값을 쓰고 한 번 묻는다).
  /// 할 일마다 사용자가 답한 값은 이것보다 우선하므로 부르는 쪽이 먼저 본다.
  int? estimateMin({required int? courseId, required TaskKind kind}) {
    bool courseMatches(Rule rule) =>
        courseId != null && rule.params.courseId == courseId;
    final tiers = <bool Function(Rule)>[
      (rule) => courseMatches(rule) && rule.params.taskKind == kind,
      (rule) => courseMatches(rule) && rule.params.taskKind == null,
      (rule) => rule.params.courseId == null && rule.params.taskKind == kind,
    ];
    for (final matches in tiers) {
      final rule = _estimates.where(matches).firstOrNull;
      if (rule != null) return rule.params.minutes;
    }
    return null;
  }
}

/// 알림 예약이 받는 설정. 기본값([Defaults]) 위에 `notify` 규칙을 덮은 것이다.
final class NotifyConfig {
  const NotifyConfig({
    required this.briefingMin,
    required this.notifyCap,
    required this.quietHours,
  });

  /// 값마다 그 값을 가진 가장 최근 `notify` 규칙을 쓰고, 없으면 기본값을 쓴다.
  factory NotifyConfig.from(Iterable<Rule> rules) {
    final notify = _usableLatestFirst(rules)
        .where((rule) => rule.kind == RuleKind.notify)
        .map((rule) => rule.params);
    final quiet = notify.where((params) => params.quietStartMin != null);
    return NotifyConfig(
      briefingMin:
          notify.map((params) => params.briefingMin).nonNulls.firstOrNull ??
          Defaults.briefingMin,
      notifyCap:
          notify.map((params) => params.notifyCap).nonNulls.firstOrNull ??
          Defaults.notifyCap,
      quietHours: quiet.isEmpty
          ? const MinuteRange(Defaults.quietStartMin, Defaults.quietEndMin)
          : MinuteRange(quiet.first.quietStartMin!, quiet.first.quietEndMin!),
    );
  }

  /// 브리핑 시각(자정 기준 분).
  final int briefingMin;

  /// 알림 하루 상한(브리핑과 마감 당일 알림은 세지 않는다).
  final int notifyCap;

  /// 조용한 시간. 자정을 넘으면 끝에 1440을 더한 값이다.
  final MinuteRange quietHours;
}

/// 종류마다 쓰는 값. [optional]이 비어 있지 않으면 그 가운데 하나 이상이 있어야 한다.
typedef _Shape = ({Set<String> required, Set<String> optional, bool weekdays});

const Map<RuleKind, _Shape> _shapes = {
  RuleKind.travel: (
    required: {'minutes', 'position'},
    optional: {},
    weekdays: true,
  ),
  RuleKind.classBuffer: (required: {'minutes'}, optional: {}, weekdays: false),
  RuleKind.workWindow: (
    required: {'startMin', 'endMin'},
    optional: {},
    weekdays: true,
  ),
  RuleKind.blackout: (
    required: {'startMin', 'endMin'},
    optional: {},
    weekdays: true,
  ),
  RuleKind.preferred: (
    required: {'startMin', 'endMin'},
    optional: {},
    weekdays: true,
  ),
  RuleKind.maxBlock: (required: {'minutes'}, optional: {}, weekdays: false),
  RuleKind.dailyCap: (required: {'minutes'}, optional: {}, weekdays: true),
  RuleKind.meal: (
    required: {'startMin', 'endMin', 'minutes'},
    optional: {},
    weekdays: false,
  ),
  // 과목과 종류 가운데 하나는 있어야 한다. 둘 다 없는 '모든 할 일' 규칙은 두지 않는다.
  RuleKind.estimate: (
    required: {'minutes'},
    optional: {'courseId', 'taskKind'},
    weekdays: false,
  ),
  RuleKind.notify: (
    required: {},
    optional: {'briefingMin', 'notifyCap', 'quietStartMin', 'quietEndMin'},
    weekdays: false,
  ),
};

DayPlanRules _dayRules(List<Rule> usable, int weekday) {
  final today = usable
      .where((rule) => rule.weekdays?.contains(weekday) ?? true)
      .toList();
  Rule? latest(RuleKind kind) =>
      today.where((rule) => rule.kind == kind).firstOrNull;
  List<MinuteRange> ranges(RuleKind kind) => [
    for (final rule in today.where((rule) => rule.kind == kind))
      MinuteRange(rule.params.startMin!, rule.params.endMin!),
  ]..sort(_byStartThenEnd);

  final window = latest(RuleKind.workWindow)?.params;
  final travel = latest(RuleKind.travel)?.params;
  return DayPlanRules(
    workWindow: window == null
        ? const MinuteRange(
            Defaults.dayWindowStartMin,
            Defaults.dayWindowEndMin,
          )
        : MinuteRange(window.startMin!, window.endMin!),
    travel: travel == null
        ? null
        : TravelTime(minutes: travel.minutes!, position: travel.position!),
    blackouts: ranges(RuleKind.blackout),
    preferred: ranges(RuleKind.preferred),
    dailyCapMin: latest(RuleKind.dailyCap)?.params.minutes,
  );
}

/// 켜져 있고 값 검사를 통과한 규칙을 나중에 저장한 것부터 늘어놓는다.
List<Rule> _usableLatestFirst(Iterable<Rule> rules) =>
    rules
        .where(
          (rule) =>
              rule.active &&
              validateRule(
                rule.kind,
                rule.params,
                weekdays: rule.weekdays,
              ).isEmpty,
        )
        .toList()
      ..sort((a, b) {
        final byTime = b.updatedAt.compareTo(a.updatedAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });

/// [start]가 하루 안이고 [end]가 그보다 늦되 하루를 넘지 않는지 본다. 둘 중 하나가 없으면
/// 있는 쪽만 본다(없는 값은 필수 값 검사가 잡는다).
void _checkRange(
  List<RuleIssue> issues,
  String startField,
  int? start,
  String endField,
  int? end,
) {
  if (start != null && !_isMinuteOfDay(start)) {
    issues.add(RuleIssue(startField, RuleIssueKind.outOfRange));
    return;
  }
  if (start != null &&
      end != null &&
      (end <= start || end >= start + _minutesPerDay)) {
    issues.add(RuleIssue(endField, RuleIssueKind.badOrder));
  }
}

bool _isMinuteOfDay(int value) => value >= 0 && value < _minutesPerDay;

int _byStartThenEnd(MinuteRange a, MinuteRange b) {
  final byStart = a.startMin.compareTo(b.startMin);
  return byStart != 0 ? byStart : a.endMin.compareTo(b.endMin);
}

const int _minutesPerDay = 1440;
