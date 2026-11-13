// 내 규칙의 값 검사와, 기본값 위에 규칙을 덮은 설정. docs/architecture.md '내 규칙'.
//
// - 배치 엔진은 [PlannerConfig]만 받고 `rules` 행을 직접 읽지 않는다. [PlannerConfig]와 [NotifyConfig]는
//   `domain/defaults.dart`의 기본값(임시값)에서 시작해 켜진 규칙을 덮어 만든다.
// - 알림은 재설계 예정이다. `notify` 규칙은 브리핑 시각(`briefingMin`)만 12 내 규칙·10 나·14 온보딩
//   5단계가 보이고 저장한다([savableNotifyFields]). 나머지 알림 값의 검사와 [NotifyConfig]는 지우지 않고
//   재설계 때 다시 보며, 이 값들로 알림 기능을 새로 만들지 않는다.
// - 같은 자리를 다투는 규칙이 여럿이면 나중에 저장한 것(`updatedAt`, 같으면 `id`가 큰 것)을 쓴다.
//   입력 순서와 상관없이 같은 규칙이면 같은 설정이 나온다.
// - 저장할 때 이전 규칙을 끄고 합치는 일은 저장소가 한다. 여기서는 그 결과가 어긋나 있어도
//   위 순서로 같은 답을 낸다.
// - [validateRule]을 통과하지 못한 규칙(범위가 좁아진 뒤 남은 옛 규칙 등)은 설정에 넣지 않는다.
// - 설정의 목록은 바꿀 수 없다. 같은 설정을 여러 계산(날마다의 빈 시간, 배치)이 함께 쓴다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 규칙 값의 허용 범위(양끝 포함). 팀이 정한 값이 아니라 임시값이다(사용자 테스트 뒤 정한다).
///
/// 이 코드베이스에서 `...Min`은 분을 뜻하므로 범위의 양끝은 `low`·`high`로 적는다.
abstract final class RuleLimits {
  /// 분 값의 기본 범위.
  static const minutes = (low: 0, high: 240);

  /// 하루 최대 공부량(`daily_cap`)의 분 범위.
  static const dailyCap = (low: 30, high: 720);

  /// 한 번에 할 최대 시간(`max_block`)의 분 범위. 하한은 배치 최소 조각([Defaults.minChunkMin])과
  /// 같다. 배치 엔진은 그보다 짧은 조각을 만들지 않으므로 더 낮은 상한은 지킬 수 없다.
  static const maxBlock = (low: Defaults.minChunkMin, high: 240);

  /// 알림 하루 상한(`notifyCap`)의 범위. 알림은 재설계 예정이라 검사만 둔다.
  static const notifyCap = (low: 0, high: 20);

  /// 브리핑 시각(`briefingMin`)의 범위 06:00–12:00. [briefingStepMin] 단위만 받는다.
  static const briefing = (low: 360, high: 720);

  /// 브리핑 시각의 단위(분).
  static const int briefingStepMin = 30;

  /// 고를 수 있는 브리핑 시각(06:00, 06:30, …, 12:00의 13개). 14 온보딩 5단계·10 나·12 내 규칙의
  /// 칩이 함께 쓴다.
  static final List<int> briefingChoices = List.unmodifiable(<int>[
    for (
      var minute = briefing.low;
      minute <= briefing.high;
      minute += briefingStepMin
    )
      minute,
  ]);
}

/// 알림 재설계 전까지 `notify` 규칙에서 저장하는 값(브리핑 시각만). 06 AI 비서와 12 내 규칙 폼은 이 밖의
/// 알림 값(하루 상한·조용한 시간)을 저장하지 않고 '아직 그런 조건은 정할 수 없어요'로 답한다
/// (docs/architecture.md '내 규칙'). 그 값의 검사와 [NotifyConfig]는 지우지 않고 재설계 때 다시 본다.
const Set<RuleField> savableNotifyFields = {RuleField.briefingMin};

/// 규칙 값의 자리. 이름이 `rules.params`의 JSON 키와 같고, [weekdays]만 `rules` 표의 열이다.
/// [RuleIssue.field]는 이 이름을 쓴다.
enum RuleField {
  minutes,
  position,
  startMin,
  endMin,
  courseId,
  taskKind,
  briefingMin,
  notifyCap,
  quietStartMin,
  quietEndMin,
  weekdays;

  /// [params]에 이 값이 있는지. [weekdays]는 `params`에 없으므로 늘 false다.
  bool isSetIn(RuleParams params) => switch (this) {
    RuleField.minutes => params.minutes != null,
    RuleField.position => params.position != null,
    RuleField.startMin => params.startMin != null,
    RuleField.endMin => params.endMin != null,
    RuleField.courseId => params.courseId != null,
    RuleField.taskKind => params.taskKind != null,
    RuleField.briefingMin => params.briefingMin != null,
    RuleField.notifyCap => params.notifyCap != null,
    RuleField.quietStartMin => params.quietStartMin != null,
    RuleField.quietEndMin => params.quietEndMin != null,
    RuleField.weekdays => false,
  };
}

/// 규칙 값 검사에서 걸린 이유.
enum RuleIssueKind {
  /// 그 종류에 필요한 값이 없다.
  missing,

  /// 후보 가운데 하나 이상이 있어야 하는데 하나도 없다(`estimate`의 과목·종류, `notify`의 값).
  /// [RuleIssue.field]는 후보 이름을 [RuleField] 순서로 `|`로 이은 것이다(예: `courseId|taskKind`).
  missingOneOf,

  /// 그 종류가 쓰지 않는 값이 있다. 그 값은 범위를 검사하지 않는다.
  notAllowed,

  /// 값이 허용 범위 밖이다. 브리핑 시각은 단위가 맞지 않을 때도 이것이다.
  outOfRange,

  /// 끝이 시작보다 늦지 않거나, 시작에서 하루(1440분) 이상 떨어져 있다.
  badOrder,
}

/// 규칙 값 검사에서 걸린 값 하나. 앱은 이것으로 되묻기 문장을 고른다.
final class RuleIssue {
  const RuleIssue(this.field, this.kind);

  /// [RuleField]의 이름(`minutes`, `startMin`, `weekdays` 등). [RuleIssueKind.missingOneOf]이면 후보
  /// 이름을 `|`로 이은 것이다.
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
/// 하루를 넘지 않아야 한다(자정을 넘으면 끝에 1440을 더한다). 그 종류가 쓰지 않는 값은
/// [RuleIssueKind.notAllowed]만 내고 범위·짝을 검사하지 않는다. 식사 길이는 시간대와 분이 맞을 때만 본다.
List<RuleIssue> validateRule(
  RuleKind kind,
  RuleParams params, {
  List<int>? weekdays,
}) {
  final shape = _shapeOf(kind);
  bool allowed(RuleField field) =>
      shape.required.contains(field) || shape.oneOf.contains(field);
  final issues = <RuleIssue>[
    for (final field in RuleField.values)
      if (field.isSetIn(params) && !allowed(field))
        RuleIssue(field.name, RuleIssueKind.notAllowed),
    for (final field in shape.required)
      if (!field.isSetIn(params)) RuleIssue(field.name, RuleIssueKind.missing),
    if (shape.oneOf.isNotEmpty &&
        !shape.oneOf.any((field) => field.isSetIn(params)))
      RuleIssue(_joinedNames(shape.oneOf), RuleIssueKind.missingOneOf),
  ];

  // 아래는 그 종류가 쓰는 값만 본다.
  int? used(RuleField field, int? value) => allowed(field) ? value : null;

  final minutes = used(RuleField.minutes, params.minutes);
  final minutesOk = minutes != null && _within(minutes, _minutesLimit(kind));
  if (minutes != null && !minutesOk) {
    issues.add(const RuleIssue('minutes', RuleIssueKind.outOfRange));
  }

  final windowMinutes = _checkRange(
    issues,
    RuleField.startMin,
    used(RuleField.startMin, params.startMin),
    RuleField.endMin,
    used(RuleField.endMin, params.endMin),
  );

  // 조용한 시간은 시작과 끝을 함께 둔다. 한쪽만 기본값과 섞이면 하루를 넘는 구간이 생길 수 있다.
  final quietStart = used(RuleField.quietStartMin, params.quietStartMin);
  final quietEnd = used(RuleField.quietEndMin, params.quietEndMin);
  if ((quietStart == null) != (quietEnd == null)) {
    issues.add(
      RuleIssue(
        (quietStart == null ? RuleField.quietStartMin : RuleField.quietEndMin)
            .name,
        RuleIssueKind.missing,
      ),
    );
  }
  _checkRange(
    issues,
    RuleField.quietStartMin,
    quietStart,
    RuleField.quietEndMin,
    quietEnd,
  );

  final briefingMin = used(RuleField.briefingMin, params.briefingMin);
  if (briefingMin != null &&
      (!_within(briefingMin, RuleLimits.briefing) ||
          briefingMin % RuleLimits.briefingStepMin != 0)) {
    issues.add(const RuleIssue('briefingMin', RuleIssueKind.outOfRange));
  }
  final notifyCap = used(RuleField.notifyCap, params.notifyCap);
  if (notifyCap != null && !_within(notifyCap, RuleLimits.notifyCap)) {
    issues.add(const RuleIssue('notifyCap', RuleIssueKind.outOfRange));
  }

  // 식사 시간은 그 시간대 안에 들어가야 한다. 분과 시간대가 맞을 때만 본다.
  if (kind == RuleKind.meal &&
      minutes != null &&
      minutesOk &&
      windowMinutes != null &&
      minutes > windowMinutes) {
    issues.add(const RuleIssue('minutes', RuleIssueKind.outOfRange));
  }

  if (weekdays != null) {
    if (!shape.weekdays) {
      issues.add(RuleIssue(RuleField.weekdays.name, RuleIssueKind.notAllowed));
    } else if (weekdays.isEmpty ||
        weekdays.toSet().length != weekdays.length ||
        weekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      issues.add(RuleIssue(RuleField.weekdays.name, RuleIssueKind.outOfRange));
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

  @override
  bool operator ==(Object other) =>
      other is MealGuard && other.window == window && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(window, minutes);

  @override
  String toString() => 'MealGuard($window, minutes: $minutes)';
}

/// 이동 시간(`travel` 규칙). 실시간 비대면 수업만 있는 날에는 배치 엔진이 쓰지 않는다.
final class TravelTime {
  const TravelTime({required this.minutes, required this.position});

  final int minutes;

  final TravelPosition position;

  @override
  bool operator ==(Object other) =>
      other is TravelTime &&
      other.minutes == minutes &&
      other.position == position;

  @override
  int get hashCode => Object.hash(minutes, position);

  @override
  String toString() => 'TravelTime($minutes, ${position.name})';
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

  @override
  bool operator ==(Object other) =>
      other is DayPlanRules &&
      other.workWindow == workWindow &&
      other.travel == travel &&
      _listEquals(other.blackouts, blackouts) &&
      _listEquals(other.preferred, preferred) &&
      other.dailyCapMin == dailyCapMin;

  @override
  int get hashCode => Object.hash(
    workWindow,
    travel,
    Object.hashAll(blackouts),
    Object.hashAll(preferred),
    dailyCapMin,
  );

  @override
  String toString() =>
      'DayPlanRules(workWindow: $workWindow, travel: $travel, '
      'blackouts: $blackouts, preferred: $preferred, dailyCapMin: $dailyCapMin)';
}

/// 배치 엔진이 받는 설정. 기본값([Defaults]) 위에 켜진 규칙을 덮은 것이다.
///
/// 식사 고정 일정이 식사 보호를 대신하는 것, 비대면 수업만 있는 날 이동 시간을 빼는 것,
/// 같은 수업 앞뒤에 이동 시간과 수업 앞뒤 여유가 함께 걸리면 `position`과 관계없이 큰 값만 쓰는 것은
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
      meals: List.unmodifiable(
        <MealGuard>[...mealRules, if (!replacesDefault) defaultMeal]
          ..sort((a, b) => a.window.startMin.compareTo(b.window.startMin)),
      ),
      days: List.unmodifiable(<DayPlanRules>[
        for (
          var weekday = DateTime.monday;
          weekday <= DateTime.sunday;
          weekday++
        )
          _dayRules(usable, weekday),
      ]),
      estimates: List.unmodifiable(ofKind(RuleKind.estimate)),
    );
  }

  /// 수업 앞뒤 여유(분). 실시간 비대면 수업은 배치 엔진이 0으로 둔다.
  final int classBufferMin;

  /// 한 번에 할 최대 시간(분).
  final int maxBlockMin;

  /// 보호하는 식사. 시작 시각 순서이고 바꿀 수 없다.
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

/// 알림 설정. 기본값([Defaults]) 위에 `notify` 규칙을 덮은 것이다.
///
/// 알림은 재설계 예정이다. 지금 쓰는 값은 [briefingMin]뿐이고(12 내 규칙·10 나·14 온보딩 5단계가 보이고
/// 저장한다), [notifyCap]·[quietHours]와 이 클래스는 재설계 때 다시 본다. 이 값들로 알림 기능을 새로
/// 만들지 않는다. `notify` 행에서 값 하나가 검사를 통과하지 못하면 그 행 전체를 버리는데, 값마다 따로
/// 무시할지도 재설계 때 정한다.
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

  /// 알림 하루 상한(재설계 대상).
  final int notifyCap;

  /// 조용한 시간(재설계 대상). 자정을 넘으면 끝에 1440을 더한 값이다.
  final MinuteRange quietHours;
}

/// 종류마다 쓰는 값. [oneOf]가 비어 있지 않으면 그 가운데 하나 이상이 있어야 한다.
typedef _Shape = ({
  List<RuleField> required,
  List<RuleField> oneOf,
  bool weekdays,
});

/// 종류마다 쓰는 값. 종류를 더하고 여기를 빠뜨리면 컴파일 오류가 난다. 목록은 [RuleField] 순서로 적는다.
_Shape _shapeOf(RuleKind kind) => switch (kind) {
  RuleKind.travel => (
    required: const [RuleField.minutes, RuleField.position],
    oneOf: const [],
    weekdays: true,
  ),
  RuleKind.classBuffer => (
    required: const [RuleField.minutes],
    oneOf: const [],
    weekdays: false,
  ),
  RuleKind.workWindow || RuleKind.blackout || RuleKind.preferred => (
    required: const [RuleField.startMin, RuleField.endMin],
    oneOf: const [],
    weekdays: true,
  ),
  RuleKind.maxBlock => (
    required: const [RuleField.minutes],
    oneOf: const [],
    weekdays: false,
  ),
  RuleKind.dailyCap => (
    required: const [RuleField.minutes],
    oneOf: const [],
    weekdays: true,
  ),
  RuleKind.meal => (
    required: const [RuleField.startMin, RuleField.endMin, RuleField.minutes],
    oneOf: const [],
    weekdays: false,
  ),
  // 과목과 종류 가운데 하나는 있어야 한다. 둘 다 없는 '모든 할 일' 규칙은 두지 않는다.
  RuleKind.estimate => (
    required: const [RuleField.minutes],
    oneOf: const [RuleField.courseId, RuleField.taskKind],
    weekdays: false,
  ),
  RuleKind.notify => (
    required: const [],
    oneOf: const [
      RuleField.briefingMin,
      RuleField.notifyCap,
      RuleField.quietStartMin,
      RuleField.quietEndMin,
    ],
    weekdays: false,
  ),
};

/// 그 종류의 분 범위.
({int low, int high}) _minutesLimit(RuleKind kind) => switch (kind) {
  RuleKind.dailyCap => RuleLimits.dailyCap,
  RuleKind.maxBlock => RuleLimits.maxBlock,
  _ => RuleLimits.minutes,
};

/// 후보 이름을 `|`로 잇는다. [_shapeOf]의 `oneOf`는 [RuleField] 순서로 적는다(테스트가 본다).
String _joinedNames(List<RuleField> fields) =>
    fields.map((field) => field.name).join('|');

DayPlanRules _dayRules(List<Rule> usable, int weekday) {
  final today = usable
      .where((rule) => rule.weekdays?.contains(weekday) ?? true)
      .toList();
  Rule? latest(RuleKind kind) =>
      today.where((rule) => rule.kind == kind).firstOrNull;
  List<MinuteRange> ranges(RuleKind kind) => List.unmodifiable(
    <MinuteRange>[
      for (final rule in today.where((rule) => rule.kind == kind))
        MinuteRange(rule.params.startMin!, rule.params.endMin!),
    ]..sort(_byStartThenEnd),
  );

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

/// [start]가 하루 안이고 [end]가 그보다 늦되 하루를 넘지 않는지 본다. 둘 다 있고 맞으면 구간 길이(분),
/// 아니면 null이다. 둘 중 하나가 없으면 있는 쪽만 본다(없는 값은 필수 값 검사가 잡는다).
int? _checkRange(
  List<RuleIssue> issues,
  RuleField startField,
  int? start,
  RuleField endField,
  int? end,
) {
  if (start != null && !_isMinuteOfDay(start)) {
    issues.add(RuleIssue(startField.name, RuleIssueKind.outOfRange));
    return null;
  }
  if (start == null || end == null) return null;
  if (end <= start || end >= start + _minutesPerDay) {
    issues.add(RuleIssue(endField.name, RuleIssueKind.badOrder));
    return null;
  }
  return end - start;
}

bool _isMinuteOfDay(int value) => value >= 0 && value < _minutesPerDay;

bool _within(int value, ({int low, int high}) limit) =>
    value >= limit.low && value <= limit.high;

int _byStartThenEnd(MinuteRange a, MinuteRange b) {
  final byStart = a.startMin.compareTo(b.startMin);
  return byStart != 0 ? byStart : a.endMin.compareTo(b.endMin);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

const int _minutesPerDay = 1440;
