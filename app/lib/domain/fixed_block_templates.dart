// 고정 일정 시트의 '자주 넣는 일정'과 14 온보딩 3단계 '빠르게 더하기'의 처음 값. docs/screens.md '13 시간표·
// 고정 일정', '14 온보딩'의 3단계. 값은 최종 프로토타입의 값이다(임시). 14 온보딩 3단계의 '통학'은 고정 일정이
// 아니라 내 규칙의 이동 시간이라 여기의 [FixedBlockKind.commute] 값을 쓰지 않는다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';

/// 고정 일정 시트가 고치는 값. 시각은 자정 기준 분이고, 자정을 넘으면 [endMin]에 1440을 더한다.
final class FixedBlockDraft {
  const FixedBlockDraft({
    required this.name,
    required this.kind,
    required this.weekdays,
    required this.startMin,
    required this.endMin,
    required this.bufferMin,
    this.prep = '',
    this.place,
  });

  /// [block]의 지금 값.
  factory FixedBlockDraft.of(FixedBlock block) => FixedBlockDraft(
    name: block.name,
    kind: block.kind,
    weekdays: {...block.weekdays},
    startMin: block.startMin,
    endMin: block.endMin,
    bufferMin: block.bufferMin,
    prep: block.prep ?? '',
    place: block.place,
  );

  final String name;

  final FixedBlockKind kind;

  /// 요일 1(월)–7(일).
  final Set<int> weekdays;

  final int startMin;

  final int endMin;

  final int bufferMin;

  /// 준비물. 없으면 빈 문자열이다.
  final String prep;

  /// 반복 일정의 장소. 13 시트에는 칸이 없어 그대로 둔다.
  final String? place;

  FixedBlockDraft copyWith({
    String? name,
    FixedBlockKind? kind,
    Set<int>? weekdays,
    int? startMin,
    int? endMin,
    int? bufferMin,
    String? prep,
  }) => FixedBlockDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    startMin: startMin ?? this.startMin,
    endMin: endMin ?? this.endMin,
    bufferMin: bufferMin ?? this.bufferMin,
    prep: prep ?? this.prep,
    place: place,
  );
}

/// [kind]를 골라 새로 넣을 때의 처음 값.
FixedBlockDraft fixedBlockTemplate(FixedBlockKind kind) => switch (kind) {
  FixedBlockKind.meal => const FixedBlockDraft(
    name: '점심',
    kind: FixedBlockKind.meal,
    weekdays: {1, 2, 3, 4, 5},
    startMin: 720,
    endMin: 780,
    bufferMin: 0,
  ),
  FixedBlockKind.work => const FixedBlockDraft(
    name: '알바',
    kind: FixedBlockKind.work,
    weekdays: {6, 7},
    startMin: 840,
    endMin: 1080,
    bufferMin: 20,
  ),
  FixedBlockKind.exercise => const FixedBlockDraft(
    name: '운동',
    kind: FixedBlockKind.exercise,
    weekdays: {2, 4},
    startMin: 1140,
    endMin: 1200,
    bufferMin: 10,
    prep: Defaults.exercisePrep,
  ),
  FixedBlockKind.commute => const FixedBlockDraft(
    name: '통학',
    kind: FixedBlockKind.commute,
    weekdays: {1, 2, 3, 4, 5},
    startMin: 480,
    endMin: 525,
    bufferMin: 0,
  ),
  FixedBlockKind.other => const FixedBlockDraft(
    name: '',
    kind: FixedBlockKind.other,
    weekdays: {},
    startMin: 1080,
    endMin: 1140,
    bufferMin: 0,
  ),
};

/// 고정 일정 종류의 이름(칩).
String fixedBlockKindText(FixedBlockKind kind) => switch (kind) {
  FixedBlockKind.meal => '식사',
  FixedBlockKind.work => '알바',
  FixedBlockKind.exercise => '운동',
  FixedBlockKind.commute => '통학',
  FixedBlockKind.other => '기타',
};
