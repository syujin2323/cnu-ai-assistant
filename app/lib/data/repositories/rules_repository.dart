// 내 규칙 저장소(`rules` 표). docs/architecture.md '내 규칙'.
//
// 14 온보딩 3·5단계, 12 내 규칙, 10 나, 06 AI 비서가 함께 쓴다. 저장 정책은 `domain/rules.dart`의 순수
// 함수를 따른다. 요일은 [canonicalWeekdays]로 정리해 두고, 하나만 두는 종류는 그 종류의 행 하나에 새 값을
// 합쳐 켜며, 같은 요일을 대신하는 종류와 과목·종류가 같은 예상 시간은 이전 규칙을 끈다([rulesReplacedBy]).
// 규칙을 켜거나 끄거나 고치면 `updatedAt`을 지금으로 바꾼다. 한 동작의 쓰기와 되돌리기 기록(`undo_log`
// 한 행)은 한 트랜잭션이다. 값 검사를 통과하지 못한 값이나 알림 재설계 전에 저장하지 않는 알림 값
// ([savableNotifyFields] 밖)을 넣으면 [ArgumentError]다. 부르는 쪽은 [paramsToStore]와 [validateRule]로
// 먼저 보고 되묻는다. 폰 DB를 읽거나 쓰지 못하면 [StorageError]를 담은 [Err]다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/guard_storage.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/undo_log_entry.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:drift/drift.dart';

/// 내 규칙 저장소.
class RulesRepository {
  RulesRepository(this._db);

  final AppDatabase _db;

  static const _table = 'rules';

  /// 모든 규칙(꺼진 것도). id 순서.
  Stream<List<Rule>> watch() => _all().watch();

  /// 모든 규칙(꺼진 것도)을 한 번 읽는다. id 순서.
  Future<Result<List<Rule>>> read() =>
      guardStorage('rules.read', () => _all().get());

  /// 새 규칙을 저장하고 저장된 행을 돌려준다. 하나만 두는 종류는 그 종류의 행에 합쳐 켜고(행이 없으면
  /// 새로 넣음), 그 밖에는 새 행을 넣고 대신하는 규칙을 끈다.
  Future<Result<Rule>> save({
    required RuleKind kind,
    required RuleParams params,
    List<int>? weekdays,
    required EntrySource source,
    String? sentence,
    required DateTime now,
  }) async {
    _checkSavable(kind, params);
    final days = canonicalWeekdays(weekdays);
    return guardStorage(
      'rules.save',
      () => _db.transaction(() async {
        final existing = await _ofKind(kind);
        final toStore = paramsToStore(kind, params, existing);
        _checkValid(kind, toStore, days);
        final replaced = rulesReplacedBy(kind, params, days, existing);
        final undo = UndoRecorder(_db);
        final int id;
        final UndoAction action;
        if (kind.singleRow && replaced.isNotEmpty) {
          id = replaced.first.id;
          await undo.before(_table, id);
          await _update(
            id,
            RulesCompanion(
              params: Value(toStore),
              weekdays: const Value(null),
              active: const Value(true),
              source: Value(source),
              sentence: Value(sentence),
              updatedAt: Value(now),
            ),
          );
          await _turnOff(replaced.skip(1), undo, now);
          action = UndoAction.update;
        } else {
          await _turnOff(replaced, undo, now);
          id = await _db
              .into(_db.rules)
              .insert(
                RulesCompanion.insert(
                  kind: kind,
                  params: toStore,
                  weekdays: Value(days),
                  active: true,
                  source: source,
                  sentence: Value(sentence),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          undo.inserted(_table, id);
          action = UndoAction.insert;
        }
        await undo.write(table: _table, action: action, now: now);
        return (await _byId(id))!;
      }),
    );
  }

  /// 규칙을 켜거나 끈다. 켜면 그 규칙이 대신하는 다른 켜진 규칙을 끈다. 규칙이 없으면 false다.
  Future<Result<bool>> setActive(
    int id, {
    required bool active,
    required DateTime now,
  }) async {
    return guardStorage(
      'rules.setActive',
      () => _db.transaction(() async {
        final rule = await _byId(id);
        if (rule == null) return false;
        final undo = UndoRecorder(_db);
        if (active) {
          await _turnOff(
            rulesReplacedBy(
              rule.kind,
              rule.params,
              rule.weekdays,
              (await _ofKind(rule.kind)).where((other) => other.id != id),
            ),
            undo,
            now,
          );
        }
        await undo.before(_table, id);
        await _update(
          id,
          RulesCompanion(active: Value(active), updatedAt: Value(now)),
        );
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 규칙의 값과 요일을 고친다(합치지 않고 바꿈). 켜져 있으면 그 규칙이 대신하는 다른 켜진 규칙을 끈다.
  /// 규칙이 없으면 false다.
  Future<Result<bool>> edit(
    int id, {
    required RuleParams params,
    List<int>? weekdays,
    required EntrySource source,
    String? sentence,
    required DateTime now,
  }) async {
    final days = canonicalWeekdays(weekdays);
    return guardStorage(
      'rules.edit',
      () => _db.transaction(() async {
        final rule = await _byId(id);
        if (rule == null) return false;
        _checkSavable(rule.kind, params);
        _checkValid(rule.kind, params, days);
        final undo = UndoRecorder(_db);
        if (rule.active) {
          await _turnOff(
            rulesReplacedBy(
              rule.kind,
              params,
              days,
              (await _ofKind(rule.kind)).where((other) => other.id != id),
            ),
            undo,
            now,
          );
        }
        await undo.before(_table, id);
        await _update(
          id,
          RulesCompanion(
            params: Value(params),
            weekdays: Value(days),
            source: Value(source),
            sentence: Value(sentence),
            updatedAt: Value(now),
          ),
        );
        await undo.write(table: _table, action: UndoAction.update, now: now);
        return true;
      }),
    );
  }

  /// 규칙을 지운다. 규칙이 없으면 false다.
  Future<Result<bool>> delete(int id, {required DateTime now}) async {
    return guardStorage(
      'rules.delete',
      () => _db.transaction(() async {
        final undo = UndoRecorder(_db);
        await undo.before(_table, id);
        final deleted = await (_db.delete(
          _db.rules,
        )..where((rule) => rule.id.equals(id))).go();
        if (deleted == 0) return false;
        await undo.write(table: _table, action: UndoAction.delete, now: now);
        return true;
      }),
    );
  }

  SimpleSelectStatement<$RulesTable, Rule> _all() =>
      _db.select(_db.rules)
        ..orderBy([(rule) => OrderingTerm(expression: rule.id)]);

  Future<List<Rule>> _ofKind(RuleKind kind) => (_db.select(
    _db.rules,
  )..where((rule) => rule.kind.equalsValue(kind))).get();

  Future<Rule?> _byId(int id) => (_db.select(
    _db.rules,
  )..where((rule) => rule.id.equals(id))).getSingleOrNull();

  Future<void> _update(int id, RulesCompanion values) => (_db.update(
    _db.rules,
  )..where((rule) => rule.id.equals(id))).write(values);

  /// [rules] 가운데 켜진 것을 끈다(되돌리기에 담음).
  Future<void> _turnOff(
    Iterable<Rule> rules,
    UndoRecorder undo,
    DateTime now,
  ) async {
    for (final rule in rules.where((rule) => rule.active)) {
      await undo.before(_table, rule.id);
      await _update(
        rule.id,
        RulesCompanion(active: const Value(false), updatedAt: Value(now)),
      );
    }
  }

  /// 알림 재설계 전에는 `notify`에서 [savableNotifyFields]만 저장한다.
  static void _checkSavable(RuleKind kind, RuleParams params) {
    if (kind != RuleKind.notify) return;
    final unsavable = [
      for (final field in RuleField.values)
        if (field.isSetIn(params) && !savableNotifyFields.contains(field))
          field.name,
    ];
    if (unsavable.isNotEmpty) {
      throw ArgumentError.value(
        unsavable,
        'params',
        'notify fields not saved before the notification redesign',
      );
    }
  }

  static void _checkValid(RuleKind kind, RuleParams params, List<int>? days) {
    final issues = validateRule(kind, params, weekdays: days);
    if (issues.isNotEmpty) {
      throw ArgumentError.value(issues, 'params', 'does not pass validateRule');
    }
  }
}
