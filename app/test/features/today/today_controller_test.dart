// 02 홈 provider 테스트. docs/screens.md '02 홈'·'되돌리기'.
//
// 2026-11-16(월)이고 하루 창 09:00–18:00, 수업 여유 10분, 점심 0분을 규칙으로 둔다. 자료구조 수업 13:00–14:00,
// 일정 15:00–15:30, 할 일 '과제 1'의 확정 블록 09:00–10:00(끝남, 답 없음)과 16:00–17:00이 있다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/event_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/home_feedback.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart' show TestClock;

/// 2026-11-[day] [hour]:[minute].
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const mon = 16;
const tue = 17;

class _Home {
  _Home(this.container, this.db, this.clock);

  final ProviderContainer container;
  final AppDatabase db;
  final TestClock clock;
  late final int taskId;
  late final int doneBlockId;
  late final int laterBlockId;

  HomeAnswerController get answers =>
      container.read(homeAnswerProvider.notifier);

  HomeAnswerState? get answer => container.read(homeAnswerProvider);

  ToastState? get toast => container.read(toastControllerProvider);

  /// 지금을 [now]로 옮긴다.
  void setNow(DateTime now) {
    clock.current = now;
    container.invalidate(minuteClockProvider);
  }

  /// [test]를 만족하는 02 홈을 기다린다.
  Future<TodayHome> home([bool Function(TodayHome home)? test]) async {
    for (var i = 0; i < 200; i++) {
      if (container.read(todayHomeProvider) case AsyncData(:final value)
          when test == null || test(value)) {
        return value;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('02 홈을 기다리다 끝남');
  }

  /// 오늘의 블록 [id].
  Future<BlockItem> block(int id) async =>
      (await home()).blocks.singleWhere((item) => item.block.id == id);

  Future<PlanBlock> stored(int id) => (db.select(
    db.planBlocks,
  )..where((block) => block.id.equals(id))).getSingle();

  Future<Task> storedTask() => (db.select(
    db.tasks,
  )..where((task) => task.id.equals(taskId))).getSingle();

  HomeFeedback feedback(TodayHome home) => homeFeedback(
    now: home.now,
    blocks: home.blocks,
    free: home.free,
    answer: answer?.answer,
  );
}

Future<_Home> _start({DateTime? now}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final db = AppDatabase.memory();
  final clock = TestClock(now ?? at(mon, 11, 2));
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
    ],
  );
  container
    ..listen(todayHomeProvider, (_, _) {})
    ..listen(homeAnswerProvider, (_, _) {})
    ..listen(toastControllerProvider, (_, _) {});
  final home = _Home(container, db, clock);

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
  final courseId = await db
      .into(db.courses)
      .insert(CoursesCompanion.insert(name: '자료구조'));
  await db
      .into(db.classSlots)
      .insert(
        ClassSlotsCompanion.insert(
          courseId: courseId,
          weekday: DateTime.monday,
          startMin: 780,
          endMin: 840,
          campus: Campus.daedeok,
          online: false,
          source: SlotSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '상담',
          startAt: at(mon, 15),
          endAt: at(mon, 15, 30),
          allDay: false,
          source: EventSource.manual,
        ),
      );
  home.taskId = await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: '과제 1',
          kind: TaskKind.assignment,
          dueAt: Value(at(20, 18)),
          dueTimeUnknown: false,
          status: TaskStatus.todo,
        ),
      );
  Future<int> confirmed(DateTime start, DateTime end) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: home.taskId,
          startAt: start,
          endAt: end,
          status: PlanBlockStatus.confirmed,
          source: BlockSource.manual,
        ),
      );
  home.doneBlockId = await confirmed(at(mon, 9), at(mon, 10));
  home.laterBlockId = await confirmed(at(mon, 16), at(mon, 17));
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  return home;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('오늘의 시간표 항목·빈 시간·하루 창 끝·과목 이름과 머리 숫자를 낸다', () async {
    final app = await _start();
    final home = await app.home();
    expect(home.date, DateTime(2026, 11, 16));
    expect(home.now, at(mon, 11, 2));
    expect(home.items.map((item) => item.runtimeType.toString()), [
      'BlockItem',
      'ClassItem',
      'EventItem',
      'BlockItem',
    ]);
    expect(home.free, [
      TimeSpan(at(mon, 10), at(mon, 12, 50)),
      TimeSpan(at(mon, 14, 10), at(mon, 15)),
      TimeSpan(at(mon, 15, 30), at(mon, 16)),
      TimeSpan(at(mon, 17), at(mon, 18)),
    ]);
    expect(home.windowEndMin, 1080);
    expect(home.courseNames.values, ['자료구조']);
    // 남은 일정: 수업·일정(끝난 것 빼고). 할 일: 지금 뒤에 끝나는 확정 블록.
    expect((home.eventsLeft, home.tasksLeft), (2, 1));
    app.setNow(at(mon, 13, 30));
    final later = await app.home((home) => home.now == at(mon, 13, 30));
    expect((later.eventsLeft, later.tasksLeft), (2, 1));
    app.setNow(at(mon, 16, 30));
    final evening = await app.home((home) => home.now == at(mon, 16, 30));
    expect((evening.eventsLeft, evening.tasksLeft), (0, 1));
  });

  test('남은 일정에는 휴강한 수업을 넣지 않고 고정 일정을 넣는다', () async {
    final app = await _start();
    final slot = await app.db.select(app.db.classSlots).getSingle();
    await app.db
        .into(app.db.classExceptions)
        .insert(
          ClassExceptionsCompanion.insert(
            date: '2026-11-16',
            classSlotId: slot.id,
            kind: ClassExceptionKind.cancelled,
            source: EntrySource.manual,
          ),
        );
    await app.db
        .into(app.db.fixedBlocks)
        .insert(
          FixedBlocksCompanion.insert(
            name: '알바',
            weekdays: const [DateTime.monday],
            startMin: 1140,
            endMin: 1260,
            bufferMin: 0,
            kind: FixedBlockKind.work,
            source: EntrySource.manual,
          ),
        );
    final home = await app.home(
      (home) =>
          home.items.any((item) => item is FixedItem) &&
          home.items.any((item) => item is ClassItem && item.cancelled),
    );
    // 일정 하나와 알바(고정 일정). 휴강한 수업은 세지 않는다.
    expect(home.eventsLeft, 2);
  });

  test('했어요로 답하면 완료·한 만큼·답한 시각을 적고, 카드 안 되돌리기로 시간이 지나도 돌린다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: true);
    expect(app.answer?.answer.did, isTrue);
    final stored = await app.stored(app.doneBlockId);
    expect(stored.status, PlanBlockStatus.done);
    expect(stored.answeredAt, isNotNull);
    expect((await app.storedTask()).spentMin, 60);
    final home = await app.home(
      (home) => home.blocks.any(
        (item) =>
            item.block.id == app.doneBlockId &&
            item.block.status == PlanBlockStatus.done,
      ),
    );
    expect(app.feedback(home), isA<FeedbackRecorded>());

    app.setNow(at(mon, 11, 30));
    await app.answers.undo();
    expect(app.answer, isNull);
    expect(app.toast, isNull);
    final undone = await app.stored(app.doneBlockId);
    expect(undone.status, PlanBlockStatus.confirmed);
    expect(undone.answeredAt, isNull);
    expect((await app.storedTask()).spentMin, isNull);
  });

  test('그 뒤 다른 동작이 있었으면 카드 안 되돌리기는 되돌리지 못했다고 알린다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: true);
    await EventRepository(app.db).add(
      title: '스터디',
      startAt: at(mon, 19),
      endAt: at(mon, 20),
      source: EventSource.manual,
      now: at(mon, 11, 3),
    );
    await app.answers.undo();
    expect(app.answer, isNull);
    expect(app.toast?.text, ToastController.undoFailedText);
    expect((await app.stored(app.doneBlockId)).status, PlanBlockStatus.done);
  });

  test('못 했어요로 답하면 놓침으로 두고 오늘 지금 뒤 가장 이른 자리를 찾아 둔다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: false);
    expect(app.answer?.answer.did, isFalse);
    expect(app.answer?.answer.slot, TimeSpan(at(mon, 11, 5), at(mon, 12, 5)));
    final stored = await app.stored(app.doneBlockId);
    expect(stored.status, PlanBlockStatus.missed);
    expect(stored.answeredAt, isNotNull);

    await app.answers.retry();
    expect(app.answer, isNull);
    expect(app.toast?.text, '과제 1을 11:05에 다시 놓았어요');
    expect(app.toast?.undoable, isTrue);
    final placed = await (app.db.select(
      app.db.planBlocks,
    )..where((block) => block.startAt.equalsValue(at(mon, 11, 5)))).getSingle();
    expect(placed.endAt, at(mon, 12, 5));
    expect(placed.status, PlanBlockStatus.confirmed);
    expect(placed.source, BlockSource.manual);
  });

  test('오늘 자리가 없으면 내일의 일정을 보고 내일 자리를 찾고, 다시 놓으면 내일이라고 알린다', () async {
    final app = await _start(now: at(mon, 17, 30));
    await app.db
        .into(app.db.events)
        .insert(
          EventsCompanion.insert(
            title: '면담',
            startAt: at(tue, 9),
            endAt: at(tue, 10),
            allDay: false,
            source: EventSource.manual,
          ),
        );
    await app.answers.answer(await app.block(app.doneBlockId), did: false);
    expect(app.answer?.answer.slot, TimeSpan(at(tue, 10), at(tue, 11)));
    await app.answers.retry();
    expect(app.toast?.text, '과제 1을 내일 10:00에 다시 놓았어요');
  });

  test('오늘은 괜찮아요와 확인은 답을 거두고, 오늘은 괜찮아요만 알린다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: false);
    app.answers.skipRetry();
    expect(app.answer, isNull);
    expect(app.toast?.text, '오늘은 다시 놓지 않을게요');
    expect(app.toast?.undoable, isFalse);
    expect((await app.stored(app.doneBlockId)).status, PlanBlockStatus.missed);

    final other = await _start();
    await other.answers.answer(
      await other.block(other.doneBlockId),
      did: false,
    );
    other.answers.dismiss();
    expect(other.answer, isNull);
    expect(other.toast, isNull);
  });

  test('화면을 떠나면 답과 그 되돌리기 기록을 버리지만 그 뒤 다른 동작의 기록은 둔다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: true);
    await app.answers.leave();
    expect(app.answer, isNull);
    expect(await app.db.select(app.db.undoLog).getSingleOrNull(), isNull);

    await app.answers.answer(await app.block(app.laterBlockId), did: true);
    await EventRepository(app.db).add(
      title: '스터디',
      startAt: at(mon, 19),
      endAt: at(mon, 20),
      source: EventSource.manual,
      now: at(mon, 11, 3),
    );
    await app.answers.leave();
    final log = await app.db.select(app.db.undoLog).getSingleOrNull();
    expect(log?.targetTable, 'events');
    // 답이 없으면 아무것도 하지 않는다.
    await app.answers.leave();
    expect(await app.db.select(app.db.undoLog).getSingleOrNull(), isNotNull);
  });

  test('시간표 블록 체크는 완료를 켜고 끄며 되돌리기 토스트를 띄우고 카드의 답을 거둔다', () async {
    final app = await _start();
    await app.answers.answer(await app.block(app.doneBlockId), did: true);
    await app.answers.toggleBlock(await app.block(app.laterBlockId));
    expect(app.answer, isNull);
    expect(app.toast?.text, '과제 1 · 1시간 끝냈어요');
    expect(app.toast?.undoable, isTrue);
    expect((await app.stored(app.laterBlockId)).status, PlanBlockStatus.done);

    final checked = await app.home(
      (home) => home.blocks.any(
        (item) =>
            item.block.id == app.laterBlockId &&
            item.block.status == PlanBlockStatus.done,
      ),
    );
    // 끝낸 블록은 머리의 할 일 수에 넣지 않는다.
    expect(checked.tasksLeft, 0);
    await app.answers.toggleBlock(await app.block(app.laterBlockId));
    expect(app.toast?.text, '과제 1을 다시 할 일로 돌렸어요');
    expect(
      (await app.stored(app.laterBlockId)).status,
      PlanBlockStatus.confirmed,
    );
  });

  test('폰 DB에 쓰지 못하면 저장하지 못했다고 알리고 답을 두지 않는다', () async {
    final app = await _start();
    final item = await app.block(app.doneBlockId);
    await app.db.close();
    await app.answers.answer(item, did: true);
    expect(app.answer, isNull);
    expect(app.toast?.text, AppStrings.saveFailed);
    await app.answers.toggleBlock(item);
    expect(app.toast?.text, AppStrings.saveFailed);
  });
}
