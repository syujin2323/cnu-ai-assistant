// 되돌리기 저장소 테스트. docs/architecture.md '폰 DB'의 되돌리기.
//
// 단계 목록(되살리기·지우기·일부 열 되돌리기)을 뒤에서부터 적용하는지, 10초가 지나거나 기록을 읽을 수
// 없으면 버리는지, 기록기가 한 행을 한 번만 담는지를 메모리 DB의 `rules` 표로 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late UndoRepository undo;
  final now = DateTime(2026, 11, 13, 9);

  setUp(() {
    db = AppDatabase.memory();
    undo = UndoRepository(db);
  });

  tearDown(() => db.close());

  Future<int> insertRule(int minutes, {bool active = true}) => db
      .into(db.rules)
      .insert(
        RulesCompanion.insert(
          kind: RuleKind.classBuffer,
          params: RuleParams(minutes: minutes),
          active: active,
          source: EntrySource.manual,
          sentence: const Value('여유 10분'),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<Rule?> ruleById(int id) => (db.select(
    db.rules,
  )..where((rule) => rule.id.equals(id))).getSingleOrNull();

  Future<UndoLogEntry?> log() => db.select(db.undoLog).getSingleOrNull();

  /// [action]을 한 트랜잭션에서 하며 기록기에 담고 기록을 남긴다(저장소가 하는 일과 같음).
  Future<void> record(
    Future<void> Function(UndoRecorder recorder) action, {
    DateTime? at,
  }) => db.transaction(() async {
    final recorder = UndoRecorder(db);
    await action(recorder);
    await recorder.write(
      table: 'rules',
      action: UndoAction.update,
      now: at ?? now,
    );
  });

  Future<void> writeLog(String beforeJson, {DateTime? at}) => db
      .into(db.undoLog)
      .insertOnConflictUpdate(
        UndoLogCompanion.insert(
          targetTable: 'rules',
          action: UndoAction.update,
          beforeJson: Value(beforeJson),
          createdAt: at ?? now,
        ),
      );

  test('되돌릴 수 있는 표는 docs/architecture.md의 되돌리기 대상과 같다', () {
    expect(undoableTables, {
      'courses',
      'events',
      'tasks',
      'fixed_blocks',
      'plan_blocks',
      'class_slots',
      'class_exceptions',
      'rules',
    });
    // 모두 이 DB에 있는 표다.
    final names = {for (final table in db.allTables) table.actualTableName};
    expect(names.containsAll(undoableTables), isTrue);
  });

  test('고친 행·지운 행은 직전 값으로 되살리고 새 행은 지운다', () async {
    final changed = await insertRule(10);
    final removed = await insertRule(20);
    final changedBefore = await ruleById(changed);
    final removedBefore = await ruleById(removed);

    late int added;
    await record((recorder) async {
      await recorder.before('rules', changed);
      await (db.update(
        db.rules,
      )..where((rule) => rule.id.equals(changed))).write(
        RulesCompanion(
          params: const Value(RuleParams(minutes: 30)),
          active: const Value(false),
          sentence: const Value(null),
        ),
      );
      await recorder.before('rules', removed);
      await (db.delete(
        db.rules,
      )..where((rule) => rule.id.equals(removed))).go();
      added = await insertRule(40);
      recorder.inserted('rules', added);
    });

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect('${await ruleById(changed)}', '$changedBefore');
    expect((await ruleById(changed))!.sentence, '여유 10분');
    expect('${await ruleById(removed)}', '$removedBefore');
    expect(await ruleById(added), isNull);
    expect(await log(), isNull);
  });

  test('단계는 기록한 순서의 반대로 적용해, 같은 행이면 처음 기록한 값이 남는다', () async {
    final id = await insertRule(10);
    await writeLog(
      encodeUndoSteps([
        UndoPatch('rules', id, const {'active': 1}),
        UndoPatch('rules', id, const {'active': 0}),
      ]),
    );
    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await ruleById(id))!.active, isTrue);
  });

  test('일부 열 되돌리기는 그 열만 바꾸고 나머지는 지금 값을 둔다', () async {
    final id = await insertRule(10);
    await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
      const RulesCompanion(
        params: Value(RuleParams(minutes: 30)),
        active: Value(false),
      ),
    );
    await writeLog(
      encodeUndoSteps([
        UndoPatch('rules', id, const {'active': 1}),
      ]),
    );

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    final rule = (await ruleById(id))!;
    expect(rule.active, isTrue);
    expect(rule.params, const RuleParams(minutes: 30));
  });

  test('beforeColumns는 그 열만 담아, 되돌리면 그 열만 직전 값이 되고 나머지는 지금 값을 둔다', () async {
    final id = await insertRule(10);
    await record((recorder) async {
      await recorder.beforeColumns('rules', id, const {'active'});
      await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
        const RulesCompanion(active: Value(false)),
      );
    });
    // 그사이 다른 쪽(동기화 등)이 담지 않은 열을 바꾼다.
    await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
      const RulesCompanion(params: Value(RuleParams(minutes: 40))),
    );
    final steps = decodeUndoSteps((await log())!.beforeJson!);
    expect(steps.single, isA<UndoPatch>());

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    final rule = (await ruleById(id))!;
    expect(rule.active, isTrue);
    expect(rule.params, const RuleParams(minutes: 40));
  });

  test('beforeColumns는 빈 열 목록·id 열이면 ArgumentError이고, 없는 행은 담지 않는다', () async {
    final id = await insertRule(10);
    final recorder = UndoRecorder(db);
    expect(
      () => recorder.beforeColumns('rules', id, const {}),
      throwsArgumentError,
    );
    expect(
      () => recorder.beforeColumns('rules', id, const {'id', 'active'}),
      throwsArgumentError,
    );
    await record(
      (recorder) async =>
          recorder.beforeColumns('rules', 999, const {'active'}),
    );
    expect(await log(), isNull);
  });

  test('한 행을 여러 번 담아도 처음 값만 남고, 바뀐 행이 하나면 rowId에 적는다', () async {
    final id = await insertRule(10);
    await record((recorder) async {
      await recorder.before('rules', id);
      await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
        const RulesCompanion(params: Value(RuleParams(minutes: 20))),
      );
      await recorder.before('rules', id);
      await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
        const RulesCompanion(params: Value(RuleParams(minutes: 30))),
      );
    });
    final entry = (await log())!;
    expect(entry.rowId, id);
    expect(decodeUndoSteps(entry.beforeJson!), hasLength(1));

    expect(_ok(await undo.undoLast(now: now)), isTrue);
    expect((await ruleById(id))!.params, const RuleParams(minutes: 10));
  });

  test('없는 행은 담지 않고, 담은 것이 없으면 이전 기록을 지운다', () async {
    final id = await insertRule(10);
    await record((recorder) async => recorder.before('rules', id));
    expect(await log(), isNotNull);

    await record((recorder) async => recorder.before('rules', 999));
    expect(await log(), isNull);
  });

  test('되돌릴 수 없는 표를 담으면 ArgumentError다', () async {
    final recorder = UndoRecorder(db);
    await expectLater(recorder.before('settings', 1), throwsArgumentError);
    expect(() => recorder.inserted('undo_log', 1), throwsArgumentError);
  });

  test('기록이 없으면 false다', () async {
    expect(_ok(await undo.undoLast(now: now)), isFalse);
  });

  test('되돌리기 시간이 지났거나 기기 시각이 기록보다 이르면 기록을 버리고 false다', () async {
    final id = await insertRule(10);
    Future<void> change() => record((recorder) async {
      await recorder.before('rules', id);
      await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
        const RulesCompanion(params: Value(RuleParams(minutes: 20))),
      );
    });

    await change();
    // 끝 시각에는 아직 받는다.
    expect(_ok(await undo.undoLast(now: now.add(Defaults.undoWindow))), isTrue);
    expect((await ruleById(id))!.params, const RuleParams(minutes: 10));

    await change();
    final late = now.add(Defaults.undoWindow + const Duration(milliseconds: 1));
    expect(_ok(await undo.undoLast(now: late)), isFalse);
    expect(await log(), isNull);
    expect((await ruleById(id))!.params, const RuleParams(minutes: 20));

    await change();
    final early = now.subtract(const Duration(seconds: 1));
    expect(_ok(await undo.undoLast(now: early)), isFalse);
    expect(await log(), isNull);
    expect((await ruleById(id))!.params, const RuleParams(minutes: 20));
  });

  test('읽을 수 없는 기록(모양·표·열이 맞지 않음)은 버리고 아무것도 바꾸지 않는다', () async {
    final id = await insertRule(10);
    final row =
        (await db
                .customSelect(
                  'SELECT * FROM "rules" WHERE "id" = ?',
                  variables: [Variable.withInt(id)],
                )
                .getSingle())
            .data;
    for (final bad in [
      'not json',
      encodeUndoSteps([UndoDelete('settings', id)]),
      encodeUndoSteps([
        UndoRestore('rules', {...row}..remove('sentence')),
      ]),
      encodeUndoSteps([
        UndoRestore('rules', {...row, 'extra': 1}),
      ]),
      encodeUndoSteps([
        UndoRestore('rules', {...row, 'id': '$id'}),
      ]),
      encodeUndoSteps([
        UndoPatch('rules', id, const {'id': 2}),
      ]),
      encodeUndoSteps([
        UndoPatch('rules', id, const {'unknown': 1}),
      ]),
    ]) {
      await writeLog(bad);
      expect(_ok(await undo.undoLast(now: now)), isFalse, reason: bad);
      expect(await log(), isNull, reason: bad);
      expect(await ruleById(id), isNotNull, reason: bad);
    }
  });

  test('discard는 기록을 버린다', () async {
    final id = await insertRule(10);
    await record((recorder) async => recorder.before('rules', id));
    _ok(await undo.discard());
    expect(await log(), isNull);
    expect(_ok(await undo.undoLast(now: now)), isFalse);
  });

  group('정한 동작만(02 홈 피드백 카드의 답)', () {
    late int id;
    Future<void> change({DateTime? at}) => record((recorder) async {
      await recorder.before('rules', id);
      await (db.update(db.rules)..where((rule) => rule.id.equals(id))).write(
        const RulesCompanion(params: Value(RuleParams(minutes: 20))),
      );
    }, at: at);

    setUp(() async => id = await insertRule(10));

    test('그 동작의 기록이면 시간이 지나도 되돌린다', () async {
      final at = DateTime(2026, 11, 13, 9, 0, 0, 123);
      await change(at: at);
      final later = at.add(const Duration(hours: 1));
      expect(
        _ok(await undo.undoLast(now: later, only: UndoMark('rules', at))),
        isTrue,
      );
      expect((await ruleById(id))!.params, const RuleParams(minutes: 10));
      expect(await log(), isNull);
    });

    test('다른 동작(표·시각이 다름)의 기록이면 되돌리지도 버리지도 않는다', () async {
      final at = DateTime(2026, 11, 13, 9, 0, 0, 123);
      await change(at: at);
      for (final other in [
        UndoMark('rules', at.add(const Duration(milliseconds: 1))),
        UndoMark('rules', at.subtract(const Duration(milliseconds: 1))),
        UndoMark('plan_blocks', at),
      ]) {
        expect(_ok(await undo.undoLast(now: at, only: other)), isFalse);
        expect(await log(), isNotNull);
        _ok(await undo.discard(only: other));
        expect(await log(), isNotNull);
      }
      expect((await ruleById(id))!.params, const RuleParams(minutes: 20));
      // 기록이 없으면 false다.
      _ok(await undo.discard());
      expect(
        _ok(await undo.undoLast(now: at, only: UndoMark('rules', at))),
        isFalse,
      );
    });

    test('그 동작의 기록만 버린다', () async {
      final at = DateTime(2026, 11, 13, 9, 0, 0, 123);
      await change(at: at);
      _ok(await undo.discard(only: UndoMark('rules', at)));
      expect(await log(), isNull);
      _ok(await undo.discard(only: UndoMark('rules', at)));
      expect(await log(), isNull);
    });
  });
}

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('저장소가 실패했다: $error'),
};
