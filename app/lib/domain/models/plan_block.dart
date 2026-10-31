import 'package:cnu_ai_assistant/domain/models/value_codec.dart';

/// 블록의 상태. [dismissed]는 사용자가 지운 블록(R1 '미루기'로 뺀 블록 포함)이고
/// 그 논리적 하루가 끝나면 지운다.
enum PlanBlockStatus { suggested, confirmed, done, missed, dismissed }

/// 블록을 누가 놓았는지. [manual]은 직접 입력, [ai]는 말로 입력한 것이다. [auto](배치 엔진)는
/// 2026-10-31 결정으로 더 만들지 않고, 값 정리는 스키마를 고치는 PR에서 한다.
enum BlockSource { auto, manual, ai }

/// 배치 엔진이 이 자리를 고른 이유.
enum BlockFactor {
  /// 길이가 맞음.
  fit,

  /// 관련 수업과 가까움.
  nearClass,

  /// 할 일을 쪼개지 않음.
  unsplit,

  /// 선호 시간대.
  preferred,
}

/// 블록 근거. `plan_blocks.reason`의 JSON `{slackMin, dueAt, gapMin, rank, factor}`.
class BlockReason {
  const BlockReason({
    required this.slackMin,
    required this.dueAt,
    required this.gapMin,
    required this.rank,
    required this.factor,
  });

  /// 저장된 JSON에서 읽는다. 키가 없거나 형이 맞지 않으면 [FormatException]이다.
  factory BlockReason.fromJson(Map<String, Object?> json) {
    final slackMin = json['slackMin'];
    final dueAt = json['dueAt'];
    final gapMin = json['gapMin'];
    final rank = json['rank'];
    final factor = json['factor'];
    if (slackMin is! int ||
        dueAt is! String ||
        gapMin is! int ||
        rank is! int ||
        factor is! String) {
      throw const FormatException('Invalid plan_blocks.reason');
    }
    return BlockReason(
      slackMin: slackMin,
      dueAt: decodeDateTime(dueAt),
      gapMin: gapMin,
      rank: rank,
      factor: enumFromSnake(BlockFactor.values, factor),
    );
  }

  /// 여유도(분): 마감 전까지 남은 빈 시간의 합 − 배치할 시간.
  final int slackMin;

  /// 그 할 일의 마감.
  final DateTime dueAt;

  /// 이 블록이 들어간 빈 시간의 길이(분).
  final int gapMin;

  /// 그 계산에서 여유도 순으로 몇 번째인지(1부터).
  final int rank;

  /// 고른 이유.
  final BlockFactor factor;

  Map<String, Object?> toJson() => {
    'slackMin': slackMin,
    'dueAt': encodeDateTime(dueAt),
    'gapMin': gapMin,
    'rank': rank,
    'factor': snakeName(factor),
  };
}

/// 할 일을 하기로 한 시간 블록. `plan_blocks` 표의 한 행.
class PlanBlock {
  const PlanBlock({
    required this.id,
    required this.taskId,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.source,
    this.reason,
  });

  final int id;

  /// `tasks.id`.
  final int taskId;

  final DateTime startAt;

  final DateTime endAt;

  final PlanBlockStatus status;

  final BlockSource source;

  /// 블록 근거. 사용자가 직접 놓거나 옮긴 블록은 null.
  final BlockReason? reason;
}
