// 규칙을 바꾸면 빈 시간에서 빠지는 확정 블록 테스트. docs/screens.md '06 AI 비서'의 카드 4·'12 내 규칙'(겹치는
// 블록 시트), docs/architecture.md '도메인 기본값과 배치 엔진' 5단계.
//
// 지금은 2026-11-19(목) 10:30이고 하루 경계는 04:00이다. 수업은 없고 하루 창은 기본 08:00–23:00이다.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/rule_conflicts.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19, 10, 30);

PlanBlock _block(
  int id,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
}) => PlanBlock(
  id: id,
  taskId: 1,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.manual,
);

Rule _rule(RuleKind kind, RuleParams params) => Rule(
  id: 1,
  kind: kind,
  params: params,
  active: true,
  source: EntrySource.ai,
  createdAt: _now,
  updatedAt: _now,
);

Schedule _schedule(List<PlanBlock> blocks) => Schedule(
  classSlots: const [],
  classExceptions: const [],
  fixedBlocks: const [],
  events: const [],
  planBlocks: blocks,
);

List<int> _broken(List<PlanBlock> blocks, List<Rule> after) => [
  for (final block in blocksBrokenBy(
    _schedule(blocks),
    before: PlannerConfig.from(const []),
    after: PlannerConfig.from(after),
    now: _now,
    dayBoundaryMin: 240,
  ))
    block.id,
];

void main() {
  test('새 피할 시간에 걸리는 아직 끝나지 않은 확정 블록을 시작 순서로 고른다', () {
    final blocks = [
      _block(2, DateTime(2026, 11, 20, 20), DateTime(2026, 11, 20, 21)),
      _block(1, DateTime(2026, 11, 19, 20), DateTime(2026, 11, 19, 21)),
      // 피할 시간과 닿기만 하는 블록은 걸리지 않는다(앞뒤 모두).
      _block(3, DateTime(2026, 11, 19, 17), DateTime(2026, 11, 19, 19)),
      _block(6, DateTime(2026, 11, 19, 22), DateTime(2026, 11, 19, 23)),
      // 제안 블록은 보지 않는다.
      _block(
        4,
        DateTime(2026, 11, 19, 20),
        DateTime(2026, 11, 19, 21),
        status: PlanBlockStatus.suggested,
      ),
      // 이미 끝난 블록은 보지 않는다.
      _block(5, DateTime(2026, 11, 18, 20), DateTime(2026, 11, 18, 21)),
    ];
    final blackout = [
      _rule(
        RuleKind.blackout,
        const RuleParams(startMin: 19 * 60, endMin: 22 * 60),
      ),
    ];
    expect(_broken(blocks, blackout), [1, 2]);
  });

  test('원래 빈 시간 밖에 있던 블록은 새 규칙 때문이 아니므로 고르지 않는다', () {
    final late = [
      _block(1, DateTime(2026, 11, 19, 23), DateTime(2026, 11, 19, 23, 30)),
    ];
    expect(
      _broken(late, [
        _rule(
          RuleKind.blackout,
          const RuleParams(startMin: 22 * 60, endMin: 24 * 60),
        ),
      ]),
      isEmpty,
    );
  });

  test('한 번에 할 최대 시간을 줄이면 그보다 긴 블록이 걸린다(같은 길이는 괜찮음)', () {
    final blocks = [
      _block(1, DateTime(2026, 11, 19, 14), DateTime(2026, 11, 19, 15, 30)),
      _block(2, DateTime(2026, 11, 19, 16), DateTime(2026, 11, 19, 17)),
    ];
    expect(
      _broken(blocks, [
        _rule(RuleKind.maxBlock, const RuleParams(minutes: 60)),
      ]),
      [1],
    );
  });

  test('공부 가능한 시간대를 줄이면 그 밖의 블록이 걸리고, 바뀌지 않으면 아무것도 없다', () {
    final blocks = [
      _block(1, DateTime(2026, 11, 19, 21), DateTime(2026, 11, 19, 22)),
      _block(2, DateTime(2026, 11, 19, 14), DateTime(2026, 11, 19, 15)),
    ];
    expect(
      _broken(blocks, [
        _rule(
          RuleKind.workWindow,
          const RuleParams(startMin: 8 * 60, endMin: 20 * 60),
        ),
      ]),
      [1],
    );
    expect(_broken(blocks, const []), isEmpty);
  });
}
