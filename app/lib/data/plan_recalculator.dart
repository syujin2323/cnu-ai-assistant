// 재계산 서비스. docs/architecture.md '도메인 기본값과 배치 엔진' 4–5단계.
//
// 폰 DB에서 오늘부터 배치 지평([Defaults.planHorizonDays]일)의 일정·할 일·규칙과 하루 경계를 읽어 배치 엔진
// ([planRange])을 돌리고, 결과를 [PlanApplyRepository]로 쓴다(제안 바꿔 끼우기, 놓침 판정, 지운 블록 정리).
// 언제 돌릴지는 앱의 `PlanController`(`app/plan_controller.dart`)가 정한다. 같은 상태면 같은 계획이므로 다시
// 돌려도 바뀌는 것이 없다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/repositories/plan_apply_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';

/// 재계산 한 번의 결과.
final class PlanRun {
  const PlanRun({
    required this.result,
    required this.changed,
    required this.nextWake,
  });

  /// 배치 엔진의 결과(시간 부족, 급한 순서).
  final PlanResult result;

  /// 폰 DB의 블록을 바꿨는지.
  final bool changed;

  /// 시간이 흘러 결과가 달라질 수 있는 가장 이른 때(확정 블록의 놓침 판정, 논리적 하루의 끝, 그 밖에는
  /// [PlanRecalculator.recheckEvery] 뒤). 그때 다시 돌린다.
  final DateTime nextWake;
}

/// 재계산 서비스.
class PlanRecalculator {
  PlanRecalculator({
    required this._schedule,
    required this._tasks,
    required this._rules,
    required this._settings,
    required this._apply,
    required this._clock,
  });

  /// 다른 까닭이 없어도 다시 계산하는 간격(지난 제안을 지금 뒤로 옮기려고, 임시).
  static const recheckEvery = Duration(minutes: 15);

  final ScheduleRepository _schedule;
  final TaskRepository _tasks;
  final RulesRepository _rules;
  final SettingsRepository _settings;
  final PlanApplyRepository _apply;
  final Clock _clock;

  /// 지금 상태로 다시 계산해 쓴다.
  Future<Result<PlanRun>> recalculate() async {
    final now = _clock.now();
    final int boundary;
    switch (await _settings.read()) {
      case Ok(:final value):
        boundary = value.dayBoundaryMin;
      case Err(:final error):
        return Err(error);
    }
    final today = logicalDate(now, dayBoundaryMin: boundary);
    final last = DateTime(
      today.year,
      today.month,
      today.day + Defaults.planHorizonDays - 1,
    );
    final Schedule schedule;
    switch (await _schedule.read(
      start: logicalDayStart(today, dayBoundaryMin: boundary),
      end: logicalDayEnd(last, dayBoundaryMin: boundary),
    )) {
      case Ok(:final value):
        schedule = value;
      case Err(:final error):
        return Err(error);
    }
    final List<TaskEntry> tasks;
    switch (await _tasks.read()) {
      case Ok(:final value):
        tasks = value;
      case Err(:final error):
        return Err(error);
    }
    final List<Rule> rules;
    switch (await _rules.read()) {
      case Ok(:final value):
        rules = value;
      case Err(:final error):
        return Err(error);
    }
    final result = planRange(
      now: now,
      from: today,
      schedule: schedule,
      tasks: tasks,
      config: PlannerConfig.from(rules),
      dayBoundaryMin: boundary,
    );
    final bool changed;
    switch (await _apply.apply(
      suggestions: result.blocks,
      doneTaskIds: {
        for (final entry in tasks)
          if (entry.isDone) entry.task.id,
      },
      now: now,
      dayBoundaryMin: boundary,
    )) {
      case Ok(:final value):
        changed = value;
      case Err(:final error):
        return Err(error);
    }

    var nextWake = now.add(recheckEvery);
    final dayEnd = logicalDayEnd(today, dayBoundaryMin: boundary);
    if (dayEnd.isBefore(nextWake)) nextWake = dayEnd;
    for (final block in schedule.planBlocks) {
      if (block.status != PlanBlockStatus.confirmed) continue;
      final due = block.endAt.add(
        const Duration(minutes: Defaults.missedAfterMin),
      );
      if (due.isAfter(now) && due.isBefore(nextWake)) nextWake = due;
    }
    return Ok(PlanRun(result: result, changed: changed, nextWake: nextWake));
  }
}
