import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:drift/drift.dart';

/// `rules` 표(내 규칙)를 읽고 쓰는 저장소. docs/architecture.md '내 규칙'.
///
/// 지금은 하나만 두는 종류(`class_buffer`, `max_block`, `notify`)를 합쳐 저장하는 일만 한다.
/// 저장 전에 합친 값을 [validateRule]로 검사하고, 걸리면 저장하지 않고 걸린 값을 돌려준다.
/// 폰 DB를 읽거나 쓰지 못하면 예외 대신 [StorageError]를 담은 [Err]다.
class RulesRepository {
  RulesRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// 한 행에 새 값을 합치는 종류.
  static const Set<RuleKind> singleKinds = {
    RuleKind.classBuffer,
    RuleKind.maxBlock,
    RuleKind.notify,
  };

  /// 모든 규칙(꺼진 것 포함)을 내고, 바뀔 때마다 새 목록을 낸다.
  Stream<List<Rule>> watchAll() => _db.select(_db.rules).watch();

  /// 모든 규칙(꺼진 것 포함).
  Future<Result<List<Rule>>> all() async {
    try {
      return Ok(await _db.select(_db.rules).get());
    } on Exception catch (error) {
      return Err(StorageError('rules.all', causeType: _typeOf(error)));
    }
  }

  /// 하나만 두는 종류 [kind]에 [patch]를 합쳐 저장한다.
  ///
  /// [patch]에서 null인 값은 기존 값을 그대로 둔다. 켜진 같은 종류 행이 있으면 가장 나중에 저장한
  /// 행(`updatedAt`, 같으면 `id`가 큰 것)에 합치고, 남은 켜진 행은 그 값을 먼저 합친 뒤 끈다.
  /// 없으면 새 행을 만든다. 합친 값이 검사에 걸리면 저장하지 않고 걸린 값을 담아 돌려준다
  /// (빈 목록이면 저장한 것이다).
  Future<Result<List<RuleIssue>>> saveSingle(
    RuleKind kind,
    RuleParams patch, {
    EntrySource source = EntrySource.manual,
    String? sentence,
  }) async {
    if (!singleKinds.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'is not a single-row rule kind');
    }
    try {
      return Ok(
        await _db.transaction(() async {
          final existing =
              await (_db.select(_db.rules)..where(
                      (rule) => rule.kind.equalsValue(kind) & rule.active,
                    ))
                    .get()
                ..sort((a, b) {
                  final byTime = b.updatedAt.compareTo(a.updatedAt);
                  return byTime != 0 ? byTime : b.id.compareTo(a.id);
                });
          final merged = existing.fold(
            patch,
            (params, rule) => _merge(params, rule.params),
          );
          final issues = validateRule(kind, merged);
          if (issues.isNotEmpty) return issues;

          final now = _clock.now();
          if (existing.isEmpty) {
            await _db
                .into(_db.rules)
                .insert(
                  RulesCompanion.insert(
                    kind: kind,
                    params: merged,
                    active: true,
                    source: source,
                    sentence: Value(sentence),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
            return const <RuleIssue>[];
          }
          final target = existing.first;
          await (_db.update(
            _db.rules,
          )..where((rule) => rule.id.equals(target.id))).write(
            RulesCompanion(
              params: Value(merged),
              source: Value(source),
              // 문장은 새로 말한 것이 있을 때만 바꾼다.
              sentence: sentence == null
                  ? const Value.absent()
                  : Value(sentence),
              updatedAt: Value(now),
            ),
          );
          final others = [for (final rule in existing.skip(1)) rule.id];
          if (others.isNotEmpty) {
            await (_db.update(
              _db.rules,
            )..where((rule) => rule.id.isIn(others))).write(
              RulesCompanion(active: const Value(false), updatedAt: Value(now)),
            );
          }
          return const <RuleIssue>[];
        }),
      );
    } on Exception catch (error) {
      return Err(StorageError('rules.saveSingle', causeType: _typeOf(error)));
    }
  }

  /// [newer]의 값을 먼저 쓰고, 없는 값은 [older]에서 채운다.
  static RuleParams _merge(RuleParams newer, RuleParams older) => RuleParams(
    minutes: newer.minutes ?? older.minutes,
    position: newer.position ?? older.position,
    startMin: newer.startMin ?? older.startMin,
    endMin: newer.endMin ?? older.endMin,
    courseId: newer.courseId ?? older.courseId,
    taskKind: newer.taskKind ?? older.taskKind,
    briefingMin: newer.briefingMin ?? older.briefingMin,
    notifyCap: newer.notifyCap ?? older.notifyCap,
    // 조용한 시간은 시작과 끝을 함께 둔다.
    quietStartMin: newer.quietStartMin ?? older.quietStartMin,
    quietEndMin: newer.quietStartMin == null
        ? older.quietEndMin
        : newer.quietEndMin,
  );

  /// 원인 예외의 타입 이름. 메시지에는 SQL이나 값이 들어갈 수 있어 담지 않는다.
  static String _typeOf(Object error) => error.runtimeType.toString();
}
