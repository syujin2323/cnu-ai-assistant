// 재계산 계기 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 5단계.
//
// 실제 시간으로 돈다(기다림이 짧음). 표가 바뀌면 잠깐 뒤 다시 계산하고, 재계산이 쓴 블록 변경으로 다시 불려도
// 바꿀 것이 없어 거기서 멈추는지 본다.

import 'package:cnu_ai_assistant/app/plan_controller.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/plan_recalculator.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_apply_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart' show TestClock;

/// 몇 번 계산했는지 세는 재계산 서비스.
class _CountingRecalculator extends PlanRecalculator {
  _CountingRecalculator(AppDatabase db, TestClock clock)
    : super(
        schedule: ScheduleRepository(db),
        tasks: TaskRepository(db),
        rules: RulesRepository(db),
        settings: SettingsRepository(db),
        apply: PlanApplyRepository(db),
        clock: clock,
      );

  int calls = 0;
  final changes = <bool>[];

  @override
  Future<Result<PlanRun>> recalculate() async {
    calls++;
    final result = await super.recalculate();
    if (result case Ok(:final value)) changes.add(value.changed);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // 2026-11-16(월) 08:00.
  final now = DateTime(2026, 11, 16, 8);

  Future<(ProviderContainer, AppDatabase, _CountingRecalculator)>
  start() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final db = AppDatabase.memory();
    addTearDown(db.close);
    // 시간표가 있어야 배치한다.
    final course = await db
        .into(db.courses)
        .insert(CoursesCompanion.insert(name: '자료구조'));
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: course,
            weekday: DateTime.sunday,
            startMin: 540,
            endMin: 600,
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.manual,
          ),
        );
    final clock = TestClock(now);
    final recalculator = _CountingRecalculator(db, clock);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        planRecalculatorProvider.overrideWithValue(recalculator),
      ],
    );
    addTearDown(container.dispose);
    container.listen(planControllerProvider, (_, _) {});
    return (container, db, recalculator);
  }

  Future<void> settle() => Future<void>.delayed(
    PlanController.debounce * 2 + const Duration(milliseconds: 200),
  );

  test('처음 만들 때 계산해 결과를 내놓는다', () async {
    final (container, _, recalculator) = await start();
    await settle();
    expect(recalculator.calls, 1);
    expect(container.read(planControllerProvider), isNotNull);
  });

  test('표가 바뀌면 잠깐 뒤 다시 계산하고, 자기가 쓴 블록 때문에 한 번 더 돌면 바꿀 것이 없어 멈춘다', () async {
    final (container, db, recalculator) = await start();
    await settle();
    expect(recalculator.calls, 1);

    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: '보고서',
            kind: TaskKind.personal,
            dueAt: Value(DateTime(2026, 11, 18, 23, 59)),
            dueTimeUnknown: false,
            estimateMin: const Value(60),
            status: TaskStatus.todo,
          ),
        );
    await settle();
    await settle();
    // 할 일을 넣어 한 번(제안을 씀), 그 제안 쓰기 때문에 한 번(바꿀 것 없음) 더 돌고 멈춘다.
    expect(recalculator.calls, 3);
    expect(recalculator.changes, [false, true, false]);
    expect(container.read(planControllerProvider)!.blocks, hasLength(1));
    await settle();
    expect(recalculator.calls, 3);
  });

  test('잇따라 바뀌면 한 번만 다시 계산한다', () async {
    final (_, db, recalculator) = await start();
    await settle();
    for (var i = 0; i < 5; i++) {
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: '일정 $i',
              startAt: DateTime(2026, 11, 20, 9 + i),
              endAt: DateTime(2026, 11, 20, 10 + i),
              allDay: false,
              source: EventSource.manual,
            ),
          );
    }
    await settle();
    expect(recalculator.calls, 2);
  });
}
