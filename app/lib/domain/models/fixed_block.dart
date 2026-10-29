import 'package:cnu_ai_assistant/domain/models/entry_source.dart';

/// 고정 일정의 종류.
enum FixedBlockKind { meal, work, exercise, commute, other }

/// 매주 되풀이하는 고정 일정(점심·알바·운동 등). `fixed_blocks` 표의 한 행.
///
/// 시각은 자정 기준 분이고, 자정을 넘으면 [endMin]에 1440을 더한다.
class FixedBlock {
  const FixedBlock({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.startMin,
    required this.endMin,
    required this.bufferMin,
    required this.kind,
    this.prep,
    required this.source,
  });

  final int id;

  final String name;

  /// 되풀이하는 요일. 1(월)–7(일). DB에는 JSON 배열로 둔다.
  final List<int> weekdays;

  /// 시작 시각(자정 기준 분, 0–1439).
  final int startMin;

  /// 끝 시각(자정 기준 분).
  final int endMin;

  /// 앞뒤로 비워 둘 시간(분).
  final int bufferMin;

  final FixedBlockKind kind;

  /// 준비물. 운동(`exercise`)이면 기본값은 `Defaults.exercisePrep`.
  final String? prep;

  final EntrySource source;
}
