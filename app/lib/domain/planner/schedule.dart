// 배치 엔진이 읽는 일정 묶음. 저장소가 폰 DB에서 읽어 한 번에 넘긴다.

import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';

/// 배치 계산의 입력이 되는 일정. 계산하는 기간에 걸친 행을 넣는다.
final class Schedule {
  const Schedule({
    this.classSlots = const [],
    this.classExceptions = const [],
    this.fixedBlocks = const [],
    this.events = const [],
    this.planBlocks = const [],
  });

  final List<ClassSlot> classSlots;

  final List<ClassException> classExceptions;

  final List<FixedBlock> fixedBlocks;

  final List<Event> events;

  /// 모든 상태의 블록. 빈 시간 계산은 확정·완료 블록만 뺀다.
  final List<PlanBlock> planBlocks;
}
