// `rules` 저장소 테스트. docs/architecture.md '내 규칙'의 '하나만 두는 종류'.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 31, 9);

/// 저장 결과에서 검사에 걸린 값을 꺼낸다. 폰 DB 오류면 실패한다.
List<RuleIssue> _issues(Result<List<RuleIssue>> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('unexpected $error'),
};

void main() {
  late AppDatabase db;
  late RulesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = RulesRepository(db, FixedClock(_now));
  });
  tearDown(() => db.close());

  Future<int> insertNotify(
    RuleParams params, {
    required DateTime updatedAt,
    bool active = true,
  }) => db
      .into(db.rules)
      .insert(
        RulesCompanion.insert(
          kind: RuleKind.notify,
          params: params,
          active: active,
          source: EntrySource.ai,
          sentence: const Value('알림은 하루 네 개까지만'),
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      );

  test('규칙이 없으면 새 notify 행을 만든다', () async {
    final result = await repository.saveSingle(
      RuleKind.notify,
      const RuleParams(briefingMin: 450),
    );

    expect(_issues(result), isEmpty);
    final rule = await db.select(db.rules).getSingle();
    expect(rule.kind, RuleKind.notify);
    expect(rule.params.toJson(), {'briefingMin': 450});
    expect(rule.active, isTrue);
    expect(rule.source, EntrySource.manual);
    expect(rule.createdAt, _now);
    expect(rule.updatedAt, _now);
  });

  test('켜진 notify 행에 합치고 다른 켜진 행은 그 값을 넘겨받은 뒤 끈다', () async {
    final older = await insertNotify(
      const RuleParams(quietStartMin: 1380, quietEndMin: 1860),
      updatedAt: DateTime(2026, 10, 1),
    );
    final latest = await insertNotify(
      const RuleParams(briefingMin: 480, notifyCap: 4),
      updatedAt: DateTime(2026, 10, 20),
    );
    final off = await insertNotify(
      const RuleParams(notifyCap: 9),
      updatedAt: DateTime(2026, 10, 30),
      active: false,
    );

    final result = await repository.saveSingle(
      RuleKind.notify,
      const RuleParams(briefingMin: 420),
    );

    expect(_issues(result), isEmpty);
    final rows = {
      for (final rule in await db.select(db.rules).get()) rule.id: rule,
    };
    expect(rows, hasLength(3));
    expect(rows[latest]!.params.toJson(), {
      'briefingMin': 420,
      'notifyCap': 4,
      'quietStartMin': 1380,
      'quietEndMin': 1860,
    });
    expect(rows[latest]!.active, isTrue);
    expect(rows[latest]!.source, EntrySource.manual);
    expect(rows[latest]!.sentence, '알림은 하루 네 개까지만');
    expect(rows[latest]!.updatedAt, _now);
    expect(rows[older]!.active, isFalse);
    // 꺼진 행은 합치지 않는다.
    expect(rows[off]!.params.toJson(), {'notifyCap': 9});
    expect(NotifyConfig.from(rows.values).briefingMin, 420);
    expect(NotifyConfig.from(rows.values).notifyCap, 4);
  });

  test('합친 값이 검사에 걸리면 저장하지 않는다', () async {
    final result = await repository.saveSingle(
      RuleKind.notify,
      const RuleParams(briefingMin: 1440),
    );

    expect(_issues(result), const [
      RuleIssue('briefingMin', RuleIssueKind.outOfRange),
    ]);
    expect(await db.select(db.rules).get(), isEmpty);
  });

  test('하나만 두는 종류가 아니면 프로그래밍 오류다', () async {
    await expectLater(
      repository.saveSingle(
        RuleKind.blackout,
        const RuleParams(startMin: 0, endMin: 60),
      ),
      throwsArgumentError,
    );
  });
}
