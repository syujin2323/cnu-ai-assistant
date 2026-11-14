// 재계산 서비스 테스트. docs/architecture.md '도메인 기본값과 배치 엔진' 4–5단계.
//
// 데모 시드로 연 폰 DB에서 계산해, 제안을 바꿔 끼우고 다시 돌리면 바뀌는 것이 없는지, 다음에 깰 때를 맞게
// 고르는지 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/demo/demo_seed.dart';
import 'package:cnu_ai_assistant/data/plan_recalculator.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_apply_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart' show TestClock;

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  // 2026-11-13(금) 09:00에 데모 시드를 넣는다. 오늘 확정 블록은 13:00–13:30이다.
  final seededAt = DateTime(2026, 11, 13, 9);

  Future<(AppDatabase, PlanRecalculator, TestClock)> open() async {
    final clock = TestClock(seededAt);
    final db = AppDatabase(
      NativeDatabase.memory(),
      demoSeeder: seedDemo,
      clock: clock,
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    return (
      db,
      PlanRecalculator(
        schedule: ScheduleRepository(db),
        tasks: TaskRepository(db),
        rules: RulesRepository(db),
        settings: SettingsRepository(db),
        apply: PlanApplyRepository(db),
        clock: clock,
      ),
      clock,
    );
  }

  test('계산한 제안을 폰 DB에 바꿔 끼우고, 다시 계산하면 바뀌는 것이 없다', () async {
    final (db, recalculator, _) = await open();
    final first = _ok(await recalculator.recalculate());
    expect(first.changed, isTrue);
    final suggested = await (db.select(
      db.planBlocks,
    )..where((b) => b.status.equalsValue(PlanBlockStatus.suggested))).get();
    expect(
      {for (final b in suggested) (b.taskId, b.startAt, b.endAt)},
      {for (final b in first.result.blocks) (b.taskId, b.startAt, b.endAt)},
    );
    expect(first.result.shortages, isEmpty);
    expect(first.result.ranked, isNotEmpty);

    final second = _ok(await recalculator.recalculate());
    expect(second.changed, isFalse);
  });

  test('다음에 깰 때는 15분 뒤, 확정 블록의 놓침 판정, 논리적 하루의 끝 가운데 가장 이른 때다', () async {
    final (_, recalculator, clock) = await open();
    expect(
      _ok(await recalculator.recalculate()).nextWake,
      seededAt.add(PlanRecalculator.recheckEvery),
    );
    // 오늘 확정 블록(13:00–13:30)은 14:00에 놓침이 된다.
    clock.current = DateTime(2026, 11, 13, 13, 50);
    expect(
      _ok(await recalculator.recalculate()).nextWake,
      DateTime(2026, 11, 13, 14),
    );
    // 하루 경계 04:00 직전에는 하루 끝에 깬다.
    clock.current = DateTime(2026, 11, 14, 3, 55);
    expect(
      _ok(await recalculator.recalculate()).nextWake,
      DateTime(2026, 11, 14, 4),
    );
  });

  test('놓침 판정 시각이 지나면 확정 블록을 놓침으로 바꾼다', () async {
    final (db, recalculator, clock) = await open();
    clock.current = DateTime(2026, 11, 13, 14);
    expect(_ok(await recalculator.recalculate()).changed, isTrue);
    final quiz = await (db.select(
      db.planBlocks,
    )..where((b) => b.source.equalsValue(BlockSource.manual))).getSingle();
    expect(quiz.status, PlanBlockStatus.missed);
  });

  test('닫힌 DB에서는 Err(StorageError)다', () async {
    final (db, recalculator, _) = await open();
    await db.close();
    final result = await recalculator.recalculate();
    expect(result, isA<Err<PlanRun>>());
    expect((result as Err).error, isA<StorageError>());
  });
}
