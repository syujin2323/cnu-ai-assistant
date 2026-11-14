// 폰 DB 스키마와 마이그레이션 테스트. docs/architecture.md '폰 DB'.
//
// `drift_schemas/app/`의 스냅샷(`drift_schema_v<N>.json`)과 그것으로 만든 도우미(`generated/`)로, 지금 코드가 만드는 표·인덱스가
// 지금 버전의 스냅샷과 같은지, 옛 버전 스냅샷의 파일을 지금 앱으로 열면(마이그레이션) 지금 버전의 스냅샷과 같아지는지 본다.
// 첫 테스트 배포 전에는 버전이 1 하나뿐이라 지금 코드와 v1 스냅샷을 견주는 테스트다.
//
// 표나 인덱스를 바꾸면 레포 루트의 `make schema`로 스냅샷과 도우미를 다시 만들어 같은 PR에 넣는다(첫 배포 전에는 v1을 다시
// 만들고, 배포 뒤에는 `schemaVersion`을 올려 새 버전을 더한다). 이 파일과 `generated/`는 `lib/`의 원본이 없어 '원본과 같은
// 경로' 규칙의 예외다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('스냅샷의 마지막 버전이 지금 schemaVersion이다', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    expect(GeneratedHelper.versions.last, db.schemaVersion);
  });

  test('새로 만든 파일의 표·인덱스는 지금 버전의 스냅샷과 같다', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, db.schemaVersion);
  });

  for (final from in GeneratedHelper.versions) {
    test('v$from 스냅샷의 파일을 지금 앱으로 열면 지금 버전의 스냅샷과 같다', () async {
      final db = AppDatabase(await verifier.startAt(from));
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, db.schemaVersion);
    });
  }
}
