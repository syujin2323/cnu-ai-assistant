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
    // 파일이 이 앱보다 새 스키마 버전이면(옛 빌드를 다시 설치했거나, 표를 바꾼 Shorebird 패치를 되돌린
    // 경우) 알아볼 수 있는 오류로 멈추고 파일은 그대로 둔다(지우거나 덮어쓰지 않음). 시작 실패 화면이 최신
    // 빌드를 안내한다. 첫 테스트 배포 전에는 schemaVersion이 1이라 올리는 단계가 없고, 올릴 때 여기에
    // 단계를 더한다(docs/architecture.md '폰 DB').
    onUpgrade: (migrator, from, to) async {
      if (from > to) throw NewerDatabaseException(from, to);
      throw StateError('no migration from $from to $to');
    },
    beforeOpen: (details) async {
      // SQLite는 외래 키 검사를 연결마다 켜야 한다.
      await customStatement('PRAGMA foreign_keys = ON');
      // 백그라운드 isolate(R1)와 같은 파일을 함께 쓰므로 WAL 모드로 둔다
      // (docs/architecture.md '앱 코드 규약'의 백그라운드 작업). 메모리 DB에서는 효과가 없다.
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}

/// 폰 DB 파일이 이 앱보다 새 스키마 버전으로 만들어졌다. 파일은 그대로 두고 앱을 시작하지 않는다
/// (20 시스템의 시작 실패 화면, docs/screens.md '20 시스템').
final class NewerDatabaseException implements Exception {
  const NewerDatabaseException(this.fileVersion, this.appVersion);

  /// 파일의 스키마 버전(`user_version`).
  final int fileVersion;

  /// 이 앱의 [AppDatabase.schemaVersion].
  final int appVersion;

  @override
  String toString() =>
      'NewerDatabaseException(file: $fileVersion, app: $appVersion)';
}
