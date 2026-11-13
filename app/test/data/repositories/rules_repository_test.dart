// 내 규칙 저장소 테스트. docs/architecture.md '내 규칙'·'폰 DB'의 되돌리기.
//
// 하나만 두는 종류의 합치기, 같은 요일·같은 과목·종류의 이전 규칙 끄기, 켜기·고치기·지우기, 값 검사,
// 한 동작이 남기는 되돌리기 기록과 그 기록으로 한 번에 되돌리기를 메모리 DB로 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RulesRepository rules;
  late UndoRepository undo;
  final now = DateTime(2026, 11, 13, 9);
  final later = now.add(const Duration(seconds: 1));

  // 닫힌 DB 테스트가 AppDatabase를 한 번 더 연다.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.memory();
    rules = RulesRepository(db);
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Rule>> all() async => _ok(await rules.read());

  Future<UndoLogEntry?> log() => db.select(db.undoLog).getSingleOrNull();

  Future<Rule> save(
    RuleKind kind,
    RuleParams params, {
    List<int>? weekdays,
    DateTime? at,
    EntrySource source = EntrySource.manual,
    String? sentence,
  }) async => _ok(
    await rules.save(
      kind: kind,
      params: params,
      weekdays: weekdays,
      source: source,
      sentence: sentence,
      now: at ?? now,
    ),
  );

  const travel40 = RuleParams(minutes: 40, position: TravelPosition.dayEdges);
  const travel30 = RuleParams(minutes: 30, position: TravelPosition.dayEdges);

  group('save', () {
    test('하나만 두는 종류는 다시 저장해도 한 행에 합치고, 출처·문장·updatedAt만 새 값으로 바꾼다', () async {
      final first = await save(
        RuleKind.notify,
        const RuleParams(briefingMin: 420),
        source: EntrySource.ai,
        sentence: '브리핑은 7시에 줘',
      );
      final second = await save(
        RuleKind.notify,
        const RuleParams(briefingMin: 480),
        at: later,
      );

      final rows = await all();
      expect(rows, hasLength(1));
      expect(second.id, first.id);
      expect(second.params, const RuleParams(briefingMin: 480));
      expect(second.active, isTrue);
      expect(second.source, EntrySource.manual);
      expect(second.sentence, isNull);
      expect(second.createdAt, now);
      expect(second.updatedAt, later);
      expect(_snapshot(rows.single), _snapshot(second));
    });

    test('하나만 두는 종류는 꺼진 행에도 합쳐 다시 켠다', () async {
      final saved = await save(
        RuleKind.classBuffer,
        const RuleParams(minutes: 10),
      );
      _ok(await rules.setActive(saved.id, active: false, now: now));

      final again = await save(
        RuleKind.classBuffer,
        const RuleParams(minutes: 20),
        at: later,
      );
      expect(again.id, saved.id);
      expect(again.active, isTrue);
      expect(again.params, const RuleParams(minutes: 20));
      expect(await all(), hasLength(1));
    });

    test('같은 요일 집합의 이전 규칙을 끄고, 매일과 일곱 요일 목록·순서만 다른 목록은 같게 본다', () async {
      final everyDay = await save(RuleKind.travel, travel40);
      final allDays = await save(
        RuleKind.travel,
        travel30,
        weekdays: [7, 6, 5, 4, 3, 2, 1],
        at: later,
      );
      expect(allDays.weekdays, isNull, reason: '일곱 요일은 매일(null)로 둔다');

      final monWed = await save(RuleKind.travel, travel40, weekdays: [3, 1]);
      expect(monWed.weekdays, [1, 3]);

      final again = await save(
        RuleKind.travel,
        travel30,
        weekdays: [1, 3],
        at: later,
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[everyDay.id]!.active, isFalse);
      expect(byId[everyDay.id]!.updatedAt, later);
      expect(byId[allDays.id]!.active, isTrue);
      expect(byId[monWed.id]!.active, isFalse);
      expect(byId[again.id]!.active, isTrue);
    });

    test('예상 시간은 과목·종류가 같은 이전 규칙만 끈다', () async {
      final quiz = await save(
        RuleKind.estimate,
        const RuleParams(courseId: 1, taskKind: TaskKind.quiz, minutes: 30),
      );
      final course = await save(
        RuleKind.estimate,
        const RuleParams(courseId: 1, minutes: 60),
      );
      final again = await save(
        RuleKind.estimate,
        const RuleParams(courseId: 1, taskKind: TaskKind.quiz, minutes: 45),
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[quiz.id]!.active, isFalse);
      expect(byId[course.id]!.active, isTrue);
      expect(byId[again.id]!.active, isTrue);
    });

    test('피할 시간은 여러 개 둔다', () async {
      await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );
      await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );
      expect((await all()).where((rule) => rule.active), hasLength(2));
    });

    test('값 검사를 통과하지 못하거나 재설계 전 알림 값이면 ArgumentError이고 아무것도 바꾸지 않는다', () async {
      final kept = await save(RuleKind.travel, travel40);
      final before = (await all()).map(_snapshot).toList();
      final logBefore = await log();

      await expectLater(
        rules.save(
          kind: RuleKind.notify,
          params: const RuleParams(briefingMin: 480, notifyCap: 3),
          source: EntrySource.ai,
          now: later,
        ),
        throwsArgumentError,
      );
      // 같은 요일의 이전 규칙을 끄기 전에 검사한다.
      await expectLater(
        rules.save(
          kind: RuleKind.travel,
          params: const RuleParams(
            minutes: 999,
            position: TravelPosition.dayEdges,
          ),
          source: EntrySource.manual,
          now: later,
        ),
        throwsArgumentError,
      );
      await expectLater(
        rules.save(
          kind: RuleKind.notify,
          params: const RuleParams(briefingMin: 615),
          source: EntrySource.manual,
          now: later,
        ),
        throwsArgumentError,
      );

      expect((await all()).map(_snapshot).toList(), before);
      expect(_snapshotLog(await log()), _snapshotLog(logBefore));
      expect((await all()).single.id, kept.id);
    });
  });

  group('setActive', () {
    test('켜면 같은 요일의 켜진 규칙을 끄고 updatedAt을 지금으로 바꾼다', () async {
      final old = await save(RuleKind.travel, travel40);
      final current = await save(RuleKind.travel, travel30, at: later);
      expect(
        (await all()).firstWhere((rule) => rule.id == old.id).active,
        isFalse,
      );

      final turnOnAt = later.add(const Duration(seconds: 1));
      expect(
        _ok(await rules.setActive(old.id, active: true, now: turnOnAt)),
        isTrue,
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[old.id]!.active, isTrue);
      expect(byId[old.id]!.updatedAt, turnOnAt);
      expect(byId[current.id]!.active, isFalse);
    });

    test('끄기는 그 규칙만 끄고, 없는 규칙이면 false다', () async {
      final a = await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );
      final b = await save(
        RuleKind.blackout,
        const RuleParams(startMin: 700, endMin: 760),
      );
      expect(
        _ok(await rules.setActive(a.id, active: false, now: later)),
        isTrue,
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[a.id]!.active, isFalse);
      expect(byId[a.id]!.updatedAt, later);
      expect(byId[b.id]!.active, isTrue);
      expect(
        _ok(await rules.setActive(999, active: true, now: later)),
        isFalse,
      );
    });
  });

  group('edit', () {
    test('값과 요일을 바꾸고, 켜져 있으면 바뀐 요일의 다른 켜진 규칙을 끈다', () async {
      final monday = await save(RuleKind.travel, travel40, weekdays: [1]);
      final tuesday = await save(RuleKind.travel, travel40, weekdays: [2]);

      expect(
        _ok(
          await rules.edit(
            tuesday.id,
            params: travel30,
            weekdays: [1],
            source: EntrySource.manual,
            now: later,
          ),
        ),
        isTrue,
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[tuesday.id]!.params, travel30);
      expect(byId[tuesday.id]!.weekdays, [1]);
      expect(byId[tuesday.id]!.updatedAt, later);
      expect(byId[monday.id]!.active, isFalse);
    });

    test('꺼진 규칙을 고치면 다른 규칙은 그대로 둔다', () async {
      final monday = await save(RuleKind.travel, travel40, weekdays: [1]);
      final off = await save(RuleKind.travel, travel40, weekdays: [2]);
      _ok(await rules.setActive(off.id, active: false, now: now));

      _ok(
        await rules.edit(
          off.id,
          params: travel30,
          weekdays: [1],
          source: EntrySource.manual,
          now: later,
        ),
      );
      final byId = {for (final rule in await all()) rule.id: rule};
      expect(byId[monday.id]!.active, isTrue);
      expect(byId[off.id]!.active, isFalse);
    });

    test('값 검사를 통과하지 못하면 ArgumentError이고, 없는 규칙이면 false다', () async {
      final saved = await save(RuleKind.travel, travel40);
      await expectLater(
        rules.edit(
          saved.id,
          params: const RuleParams(minutes: 40),
          source: EntrySource.manual,
          now: later,
        ),
        throwsArgumentError,
      );
      expect((await all()).single.params, travel40);
      expect(
        _ok(
          await rules.edit(
            999,
            params: travel30,
            source: EntrySource.manual,
            now: later,
          ),
        ),
        isFalse,
      );
    });
  });

  group('delete', () {
    test('지우고, 없는 규칙이면 false다', () async {
      final saved = await save(RuleKind.travel, travel40);
      expect(_ok(await rules.delete(saved.id, now: later)), isTrue);
      expect(await all(), isEmpty);
      expect(_ok(await rules.delete(saved.id, now: later)), isFalse);
    });
  });

  group('되돌리기', () {
    test(
      '이전 규칙을 끄는 저장은 undo_log 한 행(rowId null)으로 남고, 끈 행과 새 행이 함께 되돌아간다',
      () async {
        final old = await save(RuleKind.travel, travel40);
        final before = (await all()).map(_snapshot).toList();

        final added = await save(RuleKind.travel, travel30, at: later);
        final entry = (await log())!;
        expect(entry.targetTable, 'rules');
        expect(entry.action, UndoAction.insert);
        expect(entry.rowId, isNull, reason: '두 행이 바뀜');
        expect(entry.createdAt, later);
        final steps = decodeUndoSteps(entry.beforeJson!);
        expect(steps.whereType<UndoRestore>().single.row['id'], old.id);
        expect(steps.whereType<UndoDelete>().single.id, added.id);

        expect(_ok(await undo.undoLast(now: later)), isTrue);
        expect((await all()).map(_snapshot).toList(), before);
        expect(await log(), isNull);
      },
    );

    test('한 행만 바꾼 동작은 rowId에 그 id를 적고, 합치기·켜기·고치기·지우기를 직전 값으로 되돌린다', () async {
      final notify = await save(
        RuleKind.notify,
        const RuleParams(briefingMin: 420),
        sentence: '7시에 줘',
      );
      final blackout = await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );

      Future<void> expectUndone(
        Future<void> Function() action,
        UndoAction kind,
        int rowId,
      ) async {
        final before = (await all()).map(_snapshot).toList();
        await action();
        final entry = (await log())!;
        expect(entry.action, kind);
        expect(entry.rowId, rowId);
        expect(_ok(await undo.undoLast(now: later)), isTrue);
        expect((await all()).map(_snapshot).toList(), before);
      }

      await expectUndone(
        () async => save(
          RuleKind.notify,
          const RuleParams(briefingMin: 540),
          at: later,
        ),
        UndoAction.update,
        notify.id,
      );
      await expectUndone(
        () async =>
            _ok(await rules.setActive(blackout.id, active: false, now: later)),
        UndoAction.update,
        blackout.id,
      );
      await expectUndone(
        () async => _ok(
          await rules.edit(
            blackout.id,
            params: const RuleParams(startMin: 700, endMin: 760),
            source: EntrySource.manual,
            now: later,
          ),
        ),
        UndoAction.update,
        blackout.id,
      );
      await expectUndone(
        () async => _ok(await rules.delete(blackout.id, now: later)),
        UndoAction.delete,
        blackout.id,
      );
    });

    test('다음 동작이 오면 이전 동작은 되돌리지 않는다', () async {
      await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );
      final second = await save(
        RuleKind.blackout,
        const RuleParams(startMin: 700, endMin: 760),
      );
      expect(_ok(await undo.undoLast(now: now)), isTrue);
      expect((await all()).map((rule) => rule.id), isNot(contains(second.id)));
      expect(await all(), hasLength(1));
      // 한 번 되돌리면 기록이 없다.
      expect(_ok(await undo.undoLast(now: now)), isFalse);
      expect(await all(), hasLength(1));
    });

    test('되돌리면 규칙 스트림이 다시 읽힌다', () async {
      await save(
        RuleKind.blackout,
        const RuleParams(startMin: 600, endMin: 660),
      );
      final updates = rules.watch().map((rows) => rows.length);
      final expectation = expectLater(updates, emitsInOrder([1, 0]));
      await Future<void>.delayed(Duration.zero);
      expect(_ok(await undo.undoLast(now: now)), isTrue);
      await expectation;
    });
  });

  test('폰 DB가 닫혀 있으면 StorageError를 돌려준다', () async {
    // 데모를 끝내며 닫은 DB를 받아 둔 저장소를 await 뒤에 쓰는 경우.
    final closed = AppDatabase.memory();
    final closedRules = RulesRepository(closed);
    expect(await closedRules.read(), isA<Ok<List<Rule>>>());
    await closed.close();

    final saved = await closedRules.save(
      kind: RuleKind.travel,
      params: travel40,
      source: EntrySource.manual,
      now: now,
    );
    expect(
      (saved as Err<Rule>).error,
      const StorageError('rules.save', causeType: 'StateError'),
    );
    expect(
      (await closedRules.read() as Err<List<Rule>>).error,
      const StorageError('rules.read', causeType: 'StateError'),
    );
    expect(
      (await UndoRepository(closed).undoLast(now: now) as Err<bool>).error,
      const StorageError('undo.read', causeType: 'StateError'),
    );
  });
}

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('저장소가 실패했다: $error'),
};

/// 규칙 행의 모든 값(같은지 견주기용).
String _snapshot(Rule rule) =>
    '${rule.id}|${rule.kind}|${rule.params}|${rule.weekdays}|${rule.active}|'
    '${rule.source}|${rule.sentence}|${rule.createdAt}|${rule.updatedAt}';

String? _snapshotLog(UndoLogEntry? entry) => entry == null
    ? null
    : '${entry.targetTable}|${entry.action}|${entry.rowId}|'
          '${entry.beforeJson}|${entry.createdAt}';
