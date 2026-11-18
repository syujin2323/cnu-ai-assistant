// 01 아침 브리핑의 내용과 체크·확정 provider 테스트. docs/screens.md '01 아침 브리핑'.
//
// 2026-11-16(월) 08:00이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다.
// - 어제(일) 10:00–11:00에 '어제 일'(A)의 블록을 놓쳤다.
// - 오늘 '과제 B'의 제안 10:00–11:00, 전에 브리핑에서 확정한 '과제 C' 14:00–15:00이 있다.
// - 배치 엔진의 마지막 결과(덮어씀)는 급한 순서 [D, B, A]와, A·D의 근거를 낸다.

import 'package:cnu_ai_assistant/app/plan_controller.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/briefing.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart' show TestClock;

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const sun = 15;
const mon = 16;
final today = DateTime(2026, 11, mon);

/// 배치 엔진을 돌리지 않고 정해 둔 결과를 내는 PlanController.
class _FixedPlan extends PlanController {
  _FixedPlan(this.result);

  final PlanResult result;

  @override
  PlanResult? build() => result;
}

class _Briefing {
  _Briefing(this.container, this.db, this.clock);

  final ProviderContainer container;
  final AppDatabase db;
  final TestClock clock;
  late final int a;
  late final int b;
  late final int c;
  late final int d;
  late final int missedBlock;
  late final int suggestionBlock;
  late final int confirmedBlock;

  BriefingSelectionController get selection =>
      container.read(briefingSelectionProvider(today).notifier);

  BriefingSelection get state =>
      container.read(briefingSelectionProvider(today));

  ToastState? get toast => container.read(toastControllerProvider);

  /// 읽어 낸 브리핑을 기다린다.
  Future<BriefingData> data() async {
    for (var i = 0; i < 200; i++) {
      if (container.read(briefingDataProvider(today)) case AsyncData(
        :final value,
      )) {
        if (state.ready) return value;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('브리핑을 기다리다 끝남');
  }

  /// [test]를 만족하는 브리핑을 기다린다.
  Future<BriefingData> dataWhere(bool Function(BriefingData data) test) async {
    for (var i = 0; i < 200; i++) {
      if (container.read(briefingDataProvider(today))
          case AsyncData(:final value) when test(value)) {
        return value;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('브리핑을 기다리다 끝남');
  }

  Future<List<PlanBlock>> blocks() => (db.select(
    db.planBlocks,
  )..orderBy([(b) => OrderingTerm.asc(b.id)])).get();
}

Future<_Briefing> _start({bool fillDay = false}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final clock = TestClock(at(mon, 8));
  final made = DateTime(2026, 11, 1);
  for (final (kind, params) in [
    (RuleKind.workWindow, const RuleParams(startMin: 540, endMin: 1080)),
    (RuleKind.classBuffer, const RuleParams(minutes: 10)),
    (RuleKind.meal, const RuleParams(startMin: 690, endMin: 810, minutes: 0)),
  ]) {
    await db
        .into(db.rules)
        .insert(
          RulesCompanion.insert(
            kind: kind,
            params: params,
            active: true,
            source: EntrySource.manual,
            createdAt: made,
            updatedAt: made,
          ),
        );
  }
  Future<int> task(String title) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: title,
          kind: TaskKind.assignment,
          dueAt: Value(at(20, 18)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
  final a = await task('어제 일');
  final b = await task('과제 B');
  final c = await task('과제 C');
  final d = await task('과제 D');
  BlockReason reason(int rank) => BlockReason(
    slackMin: 600 + rank,
    dueAt: at(20, 18),
    gapMin: 60,
    rank: rank,
    factor: BlockFactor.fit,
  );
  Future<int> addBlock(
    int taskId,
    DateTime start,
    DateTime end,
    PlanBlockStatus status, {
    bool fromBriefing = false,
    BlockReason? reason,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: taskId,
          startAt: start,
          endAt: end,
          status: status,
          source: BlockSource.auto,
          fromBriefing: Value(fromBriefing),
          reason: Value(reason),
        ),
      );
  final missedBlock = await addBlock(
    a,
    at(sun, 10),
    at(sun, 11),
    PlanBlockStatus.missed,
  );
  final suggestionBlock = await addBlock(
    b,
    at(mon, 10),
    at(mon, 11),
    PlanBlockStatus.suggested,
    reason: reason(2),
  );
  final confirmedBlock = await addBlock(
    c,
    at(mon, 14),
    at(mon, 15),
    PlanBlockStatus.confirmed,
    fromBriefing: true,
  );
  if (fillDay) {
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            title: '하루 종일 실습',
            startAt: at(mon, 9),
            endAt: at(mon, 18),
            allDay: false,
            source: EventSource.manual,
          ),
        );
  }

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
      planControllerProvider.overrideWith(
        () => _FixedPlan(
          PlanResult(
            blocks: [
              BlockDraft(
                taskId: d,
                startAt: at(17, 9),
                endAt: at(17, 10),
                reason: reason(1),
              ),
              BlockDraft(
                taskId: a,
                startAt: at(17, 13),
                endAt: at(17, 14),
                reason: reason(3),
              ),
            ],
            shortages: const [],
            ranked: [d, b, a],
          ),
        ),
      ),
    ],
  );
  container
    ..listen(briefingSelectionProvider(today), (_, _) {})
    ..listen(briefingDataProvider(today), (_, _) {})
    ..listen(toastControllerProvider, (_, _) {});
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  return _Briefing(container, db, clock)
    ..a = a
    ..b = b
    ..c = c
    ..d = d
    ..missedBlock = missedBlock
    ..suggestionBlock = suggestionBlock
    ..confirmedBlock = confirmedBlock;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test(
    '어제 못 한 일과 오늘 할 일(② 전 확정 → ③ 제안 → ④ 급한 순)을 내고, 전 확정은 체크된 채로 시작한다',
    () async {
      final app = await _start();
      final data = await app.data();

      expect(
        [for (final m in data.content.missed) m.block.id],
        [app.missedBlock],
      );
      expect(
        [for (final t in data.content.tasks) (t.taskId, t.kind)],
        [
          (app.c, BriefingTaskKind.confirmed),
          (app.b, BriefingTaskKind.suggested),
          (app.d, BriefingTaskKind.urgent),
        ],
      );
      expect(data.content.remainingCount, 4);
      expect(data.reasons.keys.toSet(), {app.a, app.b, app.d});
      expect(data.dailyCapMin, isNull);

      final picks = app.state.picks;
      expect(picks.keys, [BriefingSelection.taskKey(app.c)]);
      final kept = picks.values.single;
      expect(
        (kept.taskId, kept.startAt, kept.endAt),
        (app.c, at(mon, 14), at(mon, 15)),
      );
      expect(app.state.edits, 0);
      expect(
        briefingAction(picks: picks.values, previous: data.content.previous),
        BriefingActionKind.start,
      );
    },
  );

  test('체크하면 제안 자리나 빈 자리에 놓고, 끄면 거두며, 켜고 끈 횟수를 센다', () async {
    final app = await _start();
    final data = await app.data();
    final [_, suggested, _] = data.content.tasks;

    app.selection.toggleTask(suggested);
    final placedB = app.state.picks[BriefingSelection.taskKey(app.b)]!;
    expect((placedB.startAt, placedB.endAt), (at(mon, 10), at(mon, 11)));
    expect(placedB.reason?.rank, 2);

    // 어제 일(1시간)은 체크한 B(10–11)·C(14–15)와 15분을 띄운 가장 이른 자리.
    app.selection.toggleMissed(data.content.missed.single);
    final placedA =
        app.state.picks[BriefingSelection.missedKey(app.missedBlock)]!;
    expect(
      (placedA.startAt, placedA.endAt),
      (at(mon, 11, 15), at(mon, 12, 15)),
    );
    expect(placedA.source, BlockSource.auto);
    expect(
      (placedA.reason?.slackMin, placedA.reason?.rank, placedA.reason?.gapMin),
      (603, 3, 150),
    );

    app.selection.toggleTask(data.content.tasks.first);
    expect(
      app.state.picks.containsKey(BriefingSelection.taskKey(app.c)),
      isFalse,
    );
    expect(app.state.edits, 3);

    // 다시 계산돼도(지금이 바뀜) 체크는 그대로다.
    app.clock.current = at(mon, 8, 1);
    app.container.invalidate(minuteClockProvider);
    await app.dataWhere((data) => data.now == at(mon, 8, 1));
    expect(app.state.picks.length, 2);

    app.selection.setSort(BriefingSort.time);
    expect(app.state.sort, BriefingSort.time);
    expect(app.state.edits, 3);
  });

  test('확정하면 전 브리핑 확정을 바꿔 끼우고 수정 횟수를 기록하며 되돌리기 토스트를 띄운다', () async {
    final app = await _start();
    final data = await app.data();
    app.selection
      ..toggleTask(data.content.tasks[1])
      ..toggleTask(data.content.tasks[0]);

    expect(await app.selection.confirm(), isTrue);

    final blocks = await app.blocks();
    expect(blocks.where((b) => b.id == app.confirmedBlock), isEmpty);
    final inserted = blocks.where((b) => b.fromBriefing).single;
    expect(
      (inserted.taskId, inserted.startAt, inserted.endAt, inserted.status),
      (app.b, at(mon, 10), at(mon, 11), PlanBlockStatus.confirmed),
    );
    final [briefing] = await app.db.select(app.db.briefings).get();
    expect(briefing.date, '2026-11-16');
    expect(briefing.editCount, 2);
    expect(briefing.confirmedAt, at(mon, 8));
    expect(app.state.edits, 0);
    expect(app.toast?.text, '할 일 1개를 확정했어요');
    expect(app.toast?.undoable, isTrue);
  });

  test('체크가 전 확정과 같으면 오늘 시작하기라 아무것도 쓰지 않고, 모두 풀면 확정한 할 일을 뺀다', () async {
    final app = await _start();
    final data = await app.data();
    final before = await app.blocks();

    expect(await app.selection.confirm(), isTrue);
    expect((await app.blocks()).length, before.length);
    expect(await app.db.select(app.db.briefings).get(), isEmpty);
    expect(app.toast, isNull);

    app.selection.toggleTask(data.content.tasks.first);
    expect(await app.selection.confirm(), isTrue);
    expect(
      (await app.blocks()).where((b) => b.id == app.confirmedBlock),
      isEmpty,
    );
    expect(app.toast?.text, '확정한 할 일을 뺐어요');
  });

  test('놓을 빈 자리가 없으면 체크하지 않고 알린다', () async {
    final app = await _start(fillDay: true);
    final data = await app.data();

    app.selection.toggleTask(data.content.tasks.last);

    expect(
      app.state.picks.containsKey(BriefingSelection.taskKey(app.d)),
      isFalse,
    );
    expect(app.state.edits, 0);
    expect(app.toast?.text, BriefingSelectionController.noFreeTimeText);
  });

  test('어제 못 한 일의 [했어요]는 어제 블록을 완료로 적고 그 줄의 체크를 거두며 알린다', () async {
    final app = await _start();
    final data = await app.data();
    final missed = data.content.missed.single;
    app.selection.toggleMissed(missed);

    await app.selection.didYesterday(missed);

    final stored = (await app.blocks()).singleWhere(
      (b) => b.id == app.missedBlock,
    );
    expect(stored.status, PlanBlockStatus.done);
    expect(
      app.state.picks.containsKey(BriefingSelection.missedKey(app.missedBlock)),
      isFalse,
    );
    expect(app.toast?.text, '어제 일을 어제 한 것으로 기록했어요');
    expect(app.toast?.undoable, isTrue);
    await app.dataWhere((data) => data.content.missed.isEmpty);
  });
}
