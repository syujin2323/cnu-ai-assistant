// 폰 DB 테이블 정의. 표는 docs/architecture.md '폰 DB'에 있고, 테이블이나 열을
// 바꾸면 그 표도 같은 PR에서 고친 뒤 `dart run build_runner build -d`로 생성 파일을
// 다시 만든다.
//
// - 행 클래스는 `domain/models/`의 모델을 `@UseRowClass`로 쓴다. 쓰기는 생성된
//   companion으로 한다.
// - 기본 키는 `id`(autoIncrement. 행이 하나뿐인 `sync_lease`·`undo_log`는 기본값 1). 시각은
//   DateTimeColumn(ISO 8601 문자열로 저장, `app/build.yaml`), 날짜만 있는 값은 `YYYY-MM-DD` 문자열,
//   하루 안의 시각은 자정 기준 분.
// - 고유 키·CHECK·인덱스는 첫 테스트 배포 전에 둔다(배포 뒤에 바꾸려면 표를 다시 만들어야 한다).
//   CHECK에는 바뀌지 않을 불변식(요일 1–7, 시작 0–1439, 끝 > 시작이고 하루보다 짧음, 끝 시각 ≥
//   시작 시각, 0 이상인 수)만 넣고, 화면이 정한 범위(고정 일정 앞뒤 여유 0–60분 등)는
//   `domain/timetable_checks.dart`처럼 저장소가 먼저 부르는 Dart 검사에 둔다. CHECK에 걸리면
//   저장소는 `StorageError`를 돌려준다.
// - 열거형은 `EnumConverter`로 영문 snake_case, 구조가 있는 값은 JSON 문자열.
// - R1 표(`suggestions`, `public_calendar`)는 아직 두지 않는다. 알림 기록 표는 알림 재설계 때 정한다.

import 'package:cnu_ai_assistant/data/db/enum_converter.dart';
import 'package:cnu_ai_assistant/data/db/json_converters.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

@UseRowClass(Course)
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get semester => text().nullable()();
  TextColumn get name => text()();
  TextColumn get alias => text().nullable()();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  /// LMS 과목은 학기마다 하나다. 직접 만든 과목은 `remoteId`가 null이라 걸리지 않는다.
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {remoteId, semester},
  ];
}

@UseRowClass(ClassSlot)
class ClassSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId => integer().references(Courses, #id)();
  IntColumn get weekday => integer()();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get place => text().nullable()();
  TextColumn get campus => text().map(const EnumConverter(Campus.values))();
  BoolColumn get online => boolean()();
  TextColumn get repeatRule => text().nullable()();
  TextColumn get source => text().map(const EnumConverter(SlotSource.values))();

  @override
  List<String> get customConstraints => const [
    'CHECK ("weekday" BETWEEN 1 AND 7)',
    'CHECK ("start_min" BETWEEN 0 AND 1439)',
    'CHECK ("end_min" > "start_min" AND "end_min" < "start_min" + 1440)',
  ];
}

@TableIndex(name: 'class_exceptions_slot_date', columns: {#classSlotId, #date})
@UseRowClass(ClassException)
class ClassExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get classSlotId => integer().references(ClassSlots, #id)();
  TextColumn get kind =>
      text().map(const EnumConverter(ClassExceptionKind.values))();
  TextColumn get place => text().nullable()();
  TextColumn get source =>
      text().map(const EnumConverter(EntrySource.values))();
}

@UseRowClass(FixedBlock)
class FixedBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get weekdays => text().map(const IntListConverter())();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  IntColumn get bufferMin => integer()();
  TextColumn get kind =>
      text().map(const EnumConverter(FixedBlockKind.values))();
  TextColumn get prep => text().nullable()();
  TextColumn get source =>
      text().map(const EnumConverter(EntrySource.values))();

  /// 요일 목록의 값(1–7)과 앞뒤 여유의 위 끝(0–60분)은 `domain/timetable_checks.dart`가 본다.
  @override
  List<String> get customConstraints => const [
    'CHECK (json_valid("weekdays") AND json_type("weekdays") = \'array\')',
    'CHECK ("start_min" BETWEEN 0 AND 1439)',
    'CHECK ("end_min" > "start_min" AND "end_min" < "start_min" + 1440)',
    'CHECK ("buffer_min" >= 0)',
  ];
}

@UseRowClass(Event)
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get allDay => boolean()();
  TextColumn get place => text().nullable()();
  TextColumn get prep => text().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  TextColumn get source =>
      text().map(const EnumConverter(EventSource.values))();

  @override
  List<String> get customConstraints => const [
    'CHECK (julianday("end_at") >= julianday("start_at"))',
  ];
}

@UseRowClass(Task)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get kind => text().map(const EnumConverter(TaskKind.values))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueTimeUnknown => boolean()();
  IntColumn get estimateMin => integer().nullable()();
  IntColumn get spentMin => integer().nullable()();
  TextColumn get status => text().map(const EnumConverter(TaskStatus.values))();

  /// LMS 항목 하나에 할 일 하나다. 직접 만든 할 일은 null이고 여럿이어도 된다.
  TextColumn get lmsKey =>
      text().nullable().unique().references(LmsItems, #remoteKey)();
}

@TableIndex(name: 'plan_blocks_task_id', columns: {#taskId})
@UseRowClass(PlanBlock)
class PlanBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id)();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  TextColumn get status =>
      text().map(const EnumConverter(PlanBlockStatus.values))();
  TextColumn get source =>
      text().map(const EnumConverter(BlockSource.values))();
  TextColumn get reason =>
      text().nullable().map(const BlockReasonConverter())();

  @override
  List<String> get customConstraints => const [
    'CHECK (julianday("end_at") >= julianday("start_at"))',
  ];
}

@UseRowClass(Rule)
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text().map(const EnumConverter(RuleKind.values))();
  TextColumn get params => text().map(const RuleParamsConverter())();
  TextColumn get weekdays => text().nullable().map(const IntListConverter())();
  BoolColumn get active => boolean()();
  TextColumn get source =>
      text().map(const EnumConverter(EntrySource.values))();
  TextColumn get sentence => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@UseRowClass(LmsItem)
class LmsItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteKey => text().unique()();
  IntColumn get courseId => integer().references(Courses, #id)();
  TextColumn get courseName => text()();
  TextColumn get title => text()();
  TextColumn get kind => text().map(const EnumConverter(LmsItemKind.values))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  BoolColumn get dueTimeUnknown => boolean()();
  DateTimeColumn get openAt => dateTime().nullable()();
  IntColumn get videoMin => integer().nullable()();
  IntColumn get requiredMin => integer().nullable()();
  IntColumn get watchedMin => integer().nullable()();
  BoolColumn get officiallyDone => boolean().nullable()();
  BoolColumn get submitted => boolean().nullable()();
  TextColumn get link => text().nullable()();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  IntColumn get missCount => integer()();
  DateTimeColumn get goneAt => dateTime().nullable()();
  TextColumn get contentHash => text()();

  @override
  List<String> get customConstraints => const ['CHECK ("miss_count" >= 0)'];
}

@UseRowClass(LmsItemChange)
class LmsItemChanges extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteKey => text()();
  TextColumn get field => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get changedAt => dateTime()();
}

@UseRowClass(Briefing)
class Briefings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get openedAt => dateTime().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
}

@UseRowClass(SyncRun)
class SyncRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  TextColumn get trigger =>
      text().map(const EnumConverter(SyncTrigger.values))();
  TextColumn get scope => text().map(const EnumConverter(SyncScope.values))();
  TextColumn get result =>
      text().map(const EnumConverter(SyncResultKind.values))();
  IntColumn get changedCount => integer()();
  TextColumn get failedCourseIds =>
      text().nullable().map(const IntListConverter())();
  IntColumn get elapsedMs => integer()();
  TextColumn get detail => text().nullable()();
}

/// 동기화 잠금. 행이 하나뿐인 표라 id는 기본값 1인 기본 키이고 CHECK로 1만 받는다. 잡기·
/// 늘리기·풀기는 `data/repositories/sync_lease_repository.dart`가 한다. 표 이름은 문서대로
/// `sync_lease`.
///
/// INTEGER 기본 키 하나는 rowid의 별칭이라 id를 넣지 않으면 기본값 대신 자동 번호(지운 뒤에는 2)가
/// 붙어 CHECK에 걸린다. 그래서 rowid 없는 표로 두어 기본값 1이 쓰이게 한다(undo_log도 같다).
@UseRowClass(SyncLease)
class SyncLeases extends Table {
  @override
  String get tableName => 'sync_lease';

  @override
  bool get withoutRowId => true;

  @override
  List<String> get customConstraints => const ['CHECK ("id" = 1)'];

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get holder =>
      text().map(const EnumConverter(LeaseHolder.values))();
  TextColumn get token => text()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 값은 JSON 문자열이다. 읽고 쓰는 곳은 `data/repositories/settings_repository.dart` 하나다.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 행이 하나뿐인 표라 id는 기본값 1인 기본 키이고 CHECK로 1만 받는다(rowid 없는 표인 까닭은
/// [SyncLeases]와 같다). 저장소는 동작마다 이 행을 덮어쓴다(insertOnConflictUpdate).
@UseRowClass(UndoLogEntry)
class UndoLog extends Table {
  @override
  bool get withoutRowId => true;

  @override
  List<String> get customConstraints => const ['CHECK ("id" = 1)'];

  IntColumn get id => integer().withDefault(const Constant(1))();
  // drift `Table`의 `tableName`과 이름이 겹쳐 getter는 targetTable이고,
  // SQL 열 이름은 표대로 table_name이다.
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get action => text().map(const EnumConverter(UndoAction.values))();
  IntColumn get rowId => integer().nullable()();
  TextColumn get beforeJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
