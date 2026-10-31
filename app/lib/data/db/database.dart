import 'package:cnu_ai_assistant/data/db/enum_converter.dart';
import 'package:cnu_ai_assistant/data/db/json_converters.dart';
import 'package:cnu_ai_assistant/data/db/tables.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// 폰 DB. docs/architecture.md '폰 DB (drift)'.
///
/// 화면 쪽 인스턴스는 `databaseProvider` 하나로만 만든다. 앱 모드에 따라 파일이 다르다
/// ([open]). 첫 테스트 배포 전까지 [schemaVersion]은 1이고, 테이블이 바뀌면 개발
/// 기기의 앱을 지우고 다시 설치한다. 첫 배포 뒤부터는 테이블을 바꿀 때 버전을 1 올리고
/// [migration]의 `onUpgrade`에 그 단계를 더한다.
@DriftDatabase(
  tables: [
    Courses,
    ClassSlots,
    ClassExceptions,
    FixedBlocks,
    Events,
    Tasks,
    PlanBlocks,
    Rules,
    LmsItems,
    LmsItemChanges,
    Briefings,
    Alerts,
    SyncRuns,
    SyncLeases,
    Settings,
    UndoLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 앱 모드의 DB 파일을 연다. real은 `app.sqlite`, demo는 `app_demo.sqlite`이고
  /// 둘 다 앱 문서 폴더에 있다. iOS는 `AppDelegate.swift`가 이 폴더를 백업에서
  /// 빼므로, 폴더를 바꾸면(`DriftNativeOptions`) 그 코드도 함께 바꾼다.
  static AppDatabase open(AppMode mode) => AppDatabase(
    driftDatabase(
      name: switch (mode) {
        AppMode.real => 'app',
        AppMode.demo => 'app_demo',
      },
    ),
  );

  /// 메모리에만 있는 DB(테스트용).
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // SQLite는 외래 키 검사를 연결마다 켜야 한다.
      await customStatement('PRAGMA foreign_keys = ON');
      // 백그라운드 isolate(R1)와 같은 파일을 함께 쓰므로 WAL 모드로 둔다
      // (docs/architecture.md '앱 코드 규약'의 백그라운드 작업). 메모리 DB에서는 효과가 없다.
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
