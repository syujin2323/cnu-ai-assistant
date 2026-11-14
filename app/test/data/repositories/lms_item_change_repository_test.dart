// LMS 항목 변경 기록 저장소 테스트. docs/screens.md '03 할 일'의 '마감 변경'.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/lms_item_change_repository.dart';
import 'package:cnu_ai_assistant/domain/models/lms_item_change.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());

  tearDown(() => db.close());

  final at = DateTime(2026, 11, 15, 9);

  Future<void> addChange(
    String key,
    String field,
    String? newValue,
    DateTime changedAt,
  ) => db
      .into(db.lmsItemChanges)
      .insert(
        LmsItemChangesCompanion.insert(
          remoteKey: key,
          field: field,
          oldValue: const Value('old'),
          newValue: Value(newValue),
          changedAt: changedAt,
        ),
      );

  test('항목마다 마지막 마감 변경만 주고 제출·출석 인정 변경은 뺀다', () async {
    await addChange('a', LmsItemChangeField.dueAt, 'first', at);
    await addChange(
      'a',
      LmsItemChangeField.dueAt,
      'second',
      at.add(const Duration(hours: 1)),
    );
    await addChange('b', LmsItemChangeField.submitted, '1', at);
    await addChange('c', LmsItemChangeField.dueAt, 'only', at);

    final latest = await LmsItemChangeRepository(db)
        .watchLatestDueChanges()
        .first;

    expect(latest.keys.toSet(), {'a', 'c'});
    expect(latest['a']!.newValue, 'second');
    expect(latest['c']!.newValue, 'only');
  });

  test('열 이름은 lms_items의 SQL 열 이름이다', () {
    final columns = db.lmsItems.columnsByName.keys.toSet();
    expect(
      columns,
      containsAll([
        LmsItemChangeField.dueAt,
        LmsItemChangeField.submitted,
        LmsItemChangeField.officiallyDone,
      ]),
    );
  });
}
