// 데모 DB 저장소 테스트. docs/architecture.md '데모 모드'.
//
// 데모를 끝낼 때 모든 표를 비우는지(외래 키로 이어진 행까지), 하나라도 지우지 못하면 아무것도 지우지 않고
// Err인지 본다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/repositories/demo_repository.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  /// 과목(부모)과 그 과목의 시간표 칸(자식), 설정 한 행을 넣는다.
  Future<void> addRows() async {
    final courseId = await db
        .into(db.courses)
        .insert(CoursesCompanion.insert(name: '과목A'));
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courseId,
            weekday: 1,
            startMin: 540,
            endMin: 615,
            campus: Campus.daedeok,
            online: false,
            source: SlotSource.manual,
          ),
        );
    await db.customStatement(
      "INSERT INTO settings (key, value) VALUES ('aiEnabled', 'true')",
    );
  }

  Future<int> rowCount() async {
    var count = 0;
    for (final table in db.allTables) {
      count += (await db.select(table).get()).length;
    }
    return count;
  }

  test('모든 표를 비운다(부모가 먼저 지워져도 외래 키에 걸리지 않는다)', () async {
    await addRows();

    expect(await DemoRepository(db).clearAll(), isA<Ok<void>>());

    expect(await rowCount(), 0);
  });

  test('하나라도 지우지 못하면 아무것도 지우지 않고 Err다', () async {
    await addRows();
    // settings는 과목·시간표 칸보다 뒤에 지운다. 앞에서 지운 행도 되돌려져야 한다.
    await db.customStatement(
      'CREATE TRIGGER keep_settings BEFORE DELETE ON settings '
      "BEGIN SELECT RAISE(ABORT, 'test'); END",
    );

    // RAISE(ABORT)는 확장 결과 코드 1811(트리거 제약)이다.
    expect(
      await DemoRepository(db).clearAll(),
      const Err<void>(
        StorageError('demo.clearAll', causeType: 'SqliteException', code: 1811),
      ),
    );
    expect(await rowCount(), 3);
  });
}
