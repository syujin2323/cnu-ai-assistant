// 폰 DB 테이블 정의. 표는 docs/architecture.md '폰 DB'에 있고, 테이블이나 열을
// 바꾸면 그 표도 같은 PR에서 고친 뒤 `dart run build_runner build -d`로 생성 파일을
// 다시 만든다.
//
// - 행 클래스는 `domain/models/`의 모델을 `@UseRowClass`로 쓴다. 쓰기는 생성된
//   companion으로 한다.
// - 기본 키는 `id`(autoIncrement). 시각은 DateTimeColumn(ISO 8601 문자열로 저장,
//   `app/build.yaml`), 날짜만 있는 값은 `YYYY-MM-DD` 문자열, 하루 안의 시각은 자정 기준 분.
// - 열거형은 `EnumConverter`로 영문 snake_case, 구조가 있는 값은 JSON 문자열.
// - R1 표(`notification_events`, `suggestions`, `public_calendar`)는 아직 두지 않는다.

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
}

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
  TextColumn get lmsKey => text().nullable().references(LmsItems, #remoteKey)();
}

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
  // drift `Table`의 `text()`와 이름이 겹쳐 getter는 body이고, SQL 열 이름은 표대로 text다.
  TextColumn get body => text().named('text')();
  TextColumn get cardsJson => text()();
  BoolColumn get usedTemplate => boolean()();
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

/// 행이 하나뿐인 표라 id는 늘 1이다(CHECK로 막으므로 id를 넣지 않은 insert는 실패할
/// 수 있다. 늘 `id: Value(1)`로 쓴다). 표 이름은 문서대로 `sync_lease`.
@UseRowClass(SyncLease)
class SyncLeases extends Table {
  @override
  String get tableName => 'sync_lease';

  @override
  List<String> get customConstraints => const ['CHECK ("id" = 1)'];

  IntColumn get id => integer().autoIncrement()();
  TextColumn get holder =>
      text().map(const EnumConverter(LeaseHolder.values))();
  IntColumn get runId => integer().nullable()();
  DateTimeColumn get expiresAt => dateTime()();
}

/// 값은 JSON 문자열이다. 읽고 쓰는 곳은 `data/repositories/settings_repository.dart` 하나다.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 행이 하나뿐인 표라 id는 늘 1이다(CHECK로 막는다. 늘 `id: Value(1)`로 덮어쓴다).
@UseRowClass(UndoLogEntry)
class UndoLog extends Table {
  @override
  List<String> get customConstraints => const ['CHECK ("id" = 1)'];

  IntColumn get id => integer().autoIncrement()();
  // drift `Table`의 `tableName`과 이름이 겹쳐 getter는 targetTable이고,
  // SQL 열 이름은 표대로 table_name이다.
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get action => text().map(const EnumConverter(UndoAction.values))();
  IntColumn get rowId => integer().nullable()();
  TextColumn get beforeJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
