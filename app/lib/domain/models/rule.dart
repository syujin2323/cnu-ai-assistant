import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/value_codec.dart';

/// 내 규칙의 종류 열 가지. docs/architecture.md '내 규칙'의 표.
enum RuleKind {
  /// 이동 시간.
  travel,

  /// 수업 앞뒤 여유.
  classBuffer,

  /// 공부 가능한 시간대.
  workWindow,

  /// 피할 시간.
  blackout,

  /// 선호 시간대.
  preferred,

  /// 한 번에 할 최대 시간.
  maxBlock,

  /// 하루 최대 공부량.
  dailyCap,

  /// 식사.
  meal,

  /// 예상 시간.
  estimate,

  /// 알림. 지금은 브리핑 시각만 쓰고, 하루 상한·조용한 시간은 재설계 예정이다.
  notify,
}

/// 이동 시간 규칙을 거는 위치.
enum TravelPosition {
  /// 하루 첫 수업 전과 마지막 수업 뒤.
  dayEdges,

  /// 매 수업 앞뒤.
  everyClass,
}

/// [RuleParams.copyWith]·[Rule.copyWith]에서 '그대로 둠'을 뜻하는 값. null을 주면 그 값을 비운다.
const Object _keep = Object();

/// 규칙 값. `rules.params`의 JSON이고, 그 종류가 쓰는 값만 채운다.
///
/// 시각은 자정 기준 분이다. 자정을 넘으면 끝에 1440을 더한다. 값의 범위 검사는
/// `domain/rules.dart`가 맡는다.
class RuleParams {
  const RuleParams({
    this.minutes,
    this.position,
    this.startMin,
    this.endMin,
    this.courseId,
    this.taskKind,
    this.briefingMin,
    this.notifyCap,
    this.quietStartMin,
    this.quietEndMin,
  });

  /// 저장된 JSON에서 읽는다. 모르는 키는 무시하고, 형이 맞지 않으면
  /// [FormatException]이다.
  factory RuleParams.fromJson(Map<String, Object?> json) {
    final position = json['position'];
    final taskKind = json['taskKind'];
    return RuleParams(
      minutes: _intOrNull(json, 'minutes'),
      position: position == null
          ? null
          : enumFromSnake(TravelPosition.values, _string(position)),
      startMin: _intOrNull(json, 'startMin'),
      endMin: _intOrNull(json, 'endMin'),
      courseId: _intOrNull(json, 'courseId'),
      taskKind: taskKind == null
          ? null
          : enumFromSnake(TaskKind.values, _string(taskKind)),
      briefingMin: _intOrNull(json, 'briefingMin'),
      notifyCap: _intOrNull(json, 'notifyCap'),
      quietStartMin: _intOrNull(json, 'quietStartMin'),
      quietEndMin: _intOrNull(json, 'quietEndMin'),
    );
  }

  /// 분(`travel`, `class_buffer`, `max_block`, `daily_cap`, `meal`, `estimate`).
  final int? minutes;

  /// 이동 시간 위치(`travel`).
  final TravelPosition? position;

  /// 시작 시각(`work_window`, `blackout`, `preferred`, `meal`).
  final int? startMin;

  /// 끝 시각(`work_window`, `blackout`, `preferred`, `meal`).
  final int? endMin;

  /// `courses.id`(`estimate`).
  final int? courseId;

  /// 할 일 종류(`estimate`).
  final TaskKind? taskKind;

  /// 브리핑 시각(`notify`).
  final int? briefingMin;

  /// 알림 하루 상한(`notify`).
  final int? notifyCap;

  /// 조용한 시간 시작(`notify`).
  final int? quietStartMin;

  /// 조용한 시간 끝(`notify`).
  final int? quietEndMin;

  /// 고친 사본. 주지 않은 값은 그대로 두고, null을 주면 그 값을 뺀다.
  RuleParams copyWith({
    Object? minutes = _keep,
    Object? position = _keep,
    Object? startMin = _keep,
    Object? endMin = _keep,
    Object? courseId = _keep,
    Object? taskKind = _keep,
    Object? briefingMin = _keep,
    Object? notifyCap = _keep,
    Object? quietStartMin = _keep,
    Object? quietEndMin = _keep,
  }) => RuleParams(
    minutes: identical(minutes, _keep) ? this.minutes : minutes as int?,
    position: identical(position, _keep)
        ? this.position
        : position as TravelPosition?,
    startMin: identical(startMin, _keep) ? this.startMin : startMin as int?,
    endMin: identical(endMin, _keep) ? this.endMin : endMin as int?,
    courseId: identical(courseId, _keep) ? this.courseId : courseId as int?,
    taskKind: identical(taskKind, _keep)
        ? this.taskKind
        : taskKind as TaskKind?,
    briefingMin: identical(briefingMin, _keep)
        ? this.briefingMin
        : briefingMin as int?,
    notifyCap: identical(notifyCap, _keep) ? this.notifyCap : notifyCap as int?,
    quietStartMin: identical(quietStartMin, _keep)
        ? this.quietStartMin
        : quietStartMin as int?,
    quietEndMin: identical(quietEndMin, _keep)
        ? this.quietEndMin
        : quietEndMin as int?,
  );

  /// 하나만 두는 종류를 저장할 때 기존 값(이것) 위에 [incoming]을 합친다. [incoming]에서 null인 값은
  /// 기존 값을 그대로 둔다(docs/architecture.md '내 규칙').
  RuleParams mergedWith(RuleParams incoming) => RuleParams(
    minutes: incoming.minutes ?? minutes,
    position: incoming.position ?? position,
    startMin: incoming.startMin ?? startMin,
    endMin: incoming.endMin ?? endMin,
    courseId: incoming.courseId ?? courseId,
    taskKind: incoming.taskKind ?? taskKind,
    briefingMin: incoming.briefingMin ?? briefingMin,
    notifyCap: incoming.notifyCap ?? notifyCap,
    quietStartMin: incoming.quietStartMin ?? quietStartMin,
    quietEndMin: incoming.quietEndMin ?? quietEndMin,
  );

  @override
  bool operator ==(Object other) =>
      other is RuleParams &&
      other.minutes == minutes &&
      other.position == position &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.courseId == courseId &&
      other.taskKind == taskKind &&
      other.briefingMin == briefingMin &&
      other.notifyCap == notifyCap &&
      other.quietStartMin == quietStartMin &&
      other.quietEndMin == quietEndMin;

  @override
  int get hashCode => Object.hash(
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
  );

  @override
  String toString() => 'RuleParams(${toJson()})';

  /// null인 값은 키째 뺀다.
  Map<String, Object?> toJson() => {
    'minutes': ?minutes,
    'position': ?_snakeOrNull(position),
    'startMin': ?startMin,
    'endMin': ?endMin,
    'courseId': ?courseId,
    'taskKind': ?_snakeOrNull(taskKind),
    'briefingMin': ?briefingMin,
    'notifyCap': ?notifyCap,
    'quietStartMin': ?quietStartMin,
    'quietEndMin': ?quietEndMin,
  };
}

/// 사용자가 말이나 폼으로 정한 배치 조건과 아침 브리핑 시각. `rules` 표의 한 행.
class Rule {
  const Rule({
    required this.id,
    required this.kind,
    required this.params,
    this.weekdays,
    required this.active,
    required this.source,
    this.sentence,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;

  final RuleKind kind;

  final RuleParams params;

  /// 적용하는 요일. 1(월)–7(일). null이면 매일이다. DB에는 JSON 배열로 둔다.
  final List<int>? weekdays;

  final bool active;

  final EntrySource source;

  /// 규칙을 만든 사용자 문장. 폰에만 둔다.
  final String? sentence;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// 고친 사본. 주지 않은 값은 그대로 두고, [weekdays]·[sentence]에 null을 주면 그 값을 비운다.
  Rule copyWith({
    int? id,
    RuleKind? kind,
    RuleParams? params,
    Object? weekdays = _keep,
    bool? active,
    EntrySource? source,
    Object? sentence = _keep,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Rule(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    params: params ?? this.params,
    weekdays: identical(weekdays, _keep)
        ? this.weekdays
        : weekdays as List<int>?,
    active: active ?? this.active,
    source: source ?? this.source,
    sentence: identical(sentence, _keep) ? this.sentence : sentence as String?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// 사용자 문장([sentence])은 넣지 않는다(docs/architecture.md '앱 코드 규약'의 로그 규칙).
  @override
  String toString() =>
      'Rule(id: $id, kind: ${kind.name}, params: $params, weekdays: $weekdays, '
      'active: $active, source: ${source.name}, createdAt: $createdAt, '
      'updatedAt: $updatedAt)';
}

int? _intOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('rules.params.$key must be an integer');
}

String _string(Object value) {
  if (value is String) return value;
  throw const FormatException('rules.params enum value must be a string');
}

String? _snakeOrNull(Enum? value) => value == null ? null : snakeName(value);
