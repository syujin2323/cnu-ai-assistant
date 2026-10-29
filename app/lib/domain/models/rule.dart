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

  /// 알림(브리핑 시각·하루 상한·조용한 시간).
  notify,
}

/// 이동 시간 규칙을 거는 위치.
enum TravelPosition {
  /// 하루 첫 수업 전과 마지막 수업 뒤.
  dayEdges,

  /// 매 수업 앞뒤.
  everyClass,
}

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

/// 사용자가 말이나 폼으로 정한 배치·알림 조건. `rules` 표의 한 행.
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
