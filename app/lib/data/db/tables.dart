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
// - `suggestions`(07 알림 감지, 스토어 공개 뒤)는 아직 두지 않는다. 공휴일은 표가 아니라 `domain/holidays.dart`의
//   Dart 표이고 학사일정은 두지 않는다. 알림 기록 표는 알림 재설계 때 정한다.

import 'package:cnu_ai_assistant/data/db/enum_converter.dart';
import 'package:cnu_ai_assistant/data/db/json_converters.dart';
import 'package:cnu_ai_assistant/data/db/kst_date_time_converter.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

@UseRowClass(Course)
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteId => text().nullable()();
  TextColumn get semester => text().nullable()();
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get lastSeenAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();

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
  BoolColumn get online => boolean()();
  TextColumn get repeatRule => text().nullable()();
  TextColumn get source => text().map(
    const EnumConverter(SlotSource.values, fallback: SlotSource.manual),
  )();
  IntColumn get importedWeekday => integer().nullable()();
  IntColumn get importedStartMin => integer().nullable()();
  IntColumn get importedEndMin => integer().nullable()();
  TextColumn get importedPlace => text().nullable()();
  BoolColumn get placeEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get onlineEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// 불러온 원래 요일·시각도 같은 규칙이고, 셋은 함께 있거나(불러온 수업) 함께 없다(직접 넣은 수업).
  @override
  List<String> get customConstraints => const [
    'CHECK ("weekday" BETWEEN 1 AND 7)',
    'CHECK ("start_min" BETWEEN 0 AND 1439)',
    'CHECK ("end_min" > "start_min" AND "end_min" < "start_min" + 1440)',
    'CHECK ("imported_weekday" BETWEEN 1 AND 7)',
    'CHECK ("imported_start_min" BETWEEN 0 AND 1439)',
    'CHECK ("imported_end_min" > "imported_start_min" AND '
        '"imported_end_min" < "imported_start_min" + 1440)',
    'CHECK (("imported_weekday" IS NULL) = ("imported_start_min" IS NULL) '
        'AND ("imported_start_min" IS NULL) = ("imported_end_min" IS NULL))',
  ];
}

// 인덱스는 `IF NOT EXISTS`로 만든다. 처음 만들다 버전(user_version)을 적기 전에 멈춘 파일은 다음에 열 때 표와
// 인덱스를 다시 만드는데, 이미 있는 인덱스에서 실패하면 그 파일은 영영 열리지 않는다(drift는 표만 `IF NOT EXISTS`).
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS class_exceptions_slot_date '
  'ON class_exceptions (class_slot_id, date)',
)
@UseRowClass(ClassException)
class ClassExceptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  IntColumn get classSlotId => integer().references(ClassSlots, #id)();
  TextColumn get kind =>
      text().map(const EnumConverter(ClassExceptionKind.values))();
  TextColumn get place => text().nullable()();
  TextColumn get source => text().map(
    const EnumConverter(EntrySource.values, fallback: EntrySource.manual),
  )();
  IntColumn get startMin => integer().nullable()();
  IntColumn get endMin => integer().nullable()();

  /// 보강 시각은 수업 칸의 시각과 같은 규칙이고, 둘은 함께 있거나 함께 없다(없으면 평소 시각).
  @override
  List<String> get customConstraints => const [
    'CHECK ("start_min" BETWEEN 0 AND 1439)',
    'CHECK ("end_min" > "start_min" AND "end_min" < "start_min" + 1440)',
    'CHECK (("start_min" IS NULL) = ("end_min" IS NULL))',
  ];
}

@UseRowClass(FixedBlock)
class FixedBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get weekdays => text().map(const IntListConverter())();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  IntColumn get bufferMin => integer()();
  TextColumn get kind => text().map(
    const EnumConverter(FixedBlockKind.values, fallback: FixedBlockKind.other),
  )();
  TextColumn get prep => text().nullable()();
  TextColumn get source => text().map(
    const EnumConverter(EntrySource.values, fallback: EntrySource.manual),
  )();

  /// 반복 일정의 장소(13·직접 추가 폼에서 넣음). 없으면 null.
  TextColumn get place => text().nullable()();

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
  DateTimeColumn get startAt => dateTime().map(const KstDateTimeConverter())();
  DateTimeColumn get endAt => dateTime().map(const KstDateTimeConverter())();
  BoolColumn get allDay => boolean()();
  TextColumn get place => text().nullable()();
  TextColumn get prep => text().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  TextColumn get source => text().map(
    const EnumConverter(EventSource.values, fallback: EventSource.manual),
  )();

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
  DateTimeColumn get dueAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();
  BoolColumn get dueTimeUnknown => boolean()();
  IntColumn get estimateMin => integer().nullable()();
  IntColumn get spentMin => integer().nullable()();
  TextColumn get status => text().map(const EnumConverter(TaskStatus.values))();

  /// LMS 항목 하나에 할 일 하나다. 직접 만든 할 일은 null이고 여럿이어도 된다.
  TextColumn get lmsKey =>
      text().nullable().unique().references(LmsItems, #remoteKey)();

  /// 과목을 정해 만든 할 일의 과목. LMS 할 일은 null이고 과목은 `lms_items.courseId`에서 읽는다
  /// (동기화는 이 열을 쓰지 않는다).
  IntColumn get courseId => integer().nullable().references(Courses, #id)();

  /// 할 일을 넣은 곳: 직접 추가 폼(`manual`), 06 AI 비서(`ai`). LMS 할 일은 null이다.
  TextColumn get source => text().nullable().map(
    const EnumConverter(EntrySource.values, fallback: EntrySource.manual),
  )();

  /// 끝낸 시각(03 할 일의 동그라미). 끝내기를 되돌리면 null로 돌아간다.
  DateTimeColumn get completedAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();

  /// '얼마나 걸렸어요?'에 답한 걸린 시간(분). 블록으로 한 만큼인 `spentMin`과 다르다.
  IntColumn get actualMin => integer().nullable()();

  /// 시간 부족에서 '부분 목표'를 고른 목표 시간(분). 블록의 '부분' 표시는 이 값으로 판단한다.
  IntColumn get partialGoalMin => integer().nullable()();

  /// 시간 부족에서 '밤 시간 쓰기'를 고른 날(`YYYY-MM-DD`). 그날부터 이 할 일의 마감일까지 하루 창
  /// 끝을 늘린다.
  TextColumn get nightWindowFrom => text().nullable()();

  /// 시간 부족에서 '다른 일 미루기'로 이번 계획에서 뺀 할 일이 다시 배치되는 날(`YYYY-MM-DD`).
  TextColumn get deferredUntil => text().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK ("actual_min" IS NULL OR "actual_min" >= 0)',
    'CHECK ("partial_goal_min" IS NULL OR "partial_goal_min" > 0)',
  ];
}

@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS plan_blocks_task_id ON plan_blocks (task_id)',
)
@UseRowClass(PlanBlock)
class PlanBlocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id)();
  DateTimeColumn get startAt => dateTime().map(const KstDateTimeConverter())();
  DateTimeColumn get endAt => dateTime().map(const KstDateTimeConverter())();
  TextColumn get status => text().map(
    const EnumConverter(
      PlanBlockStatus.values,
      fallback: PlanBlockStatus.dismissed,
    ),
  )();
  TextColumn get source => text().map(
    const EnumConverter(BlockSource.values, fallback: BlockSource.manual),
  )();
  TextColumn get reason =>
      text().nullable().map(const BlockReasonConverter())();

  /// 02 홈 피드백 카드에서 '했어요'·'못 했어요'로 답한 시각. 답한 블록은 다시 묻지 않는다.
  DateTimeColumn get answeredAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();

  /// 01 계획에서 확정한 블록. 브리핑에서 다시 확정하면 이 블록을 새 선택으로 바꾼다.
  BoolColumn get fromBriefing => boolean().withDefault(const Constant(false))();

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
  TextColumn get source => text().map(
    const EnumConverter(EntrySource.values, fallback: EntrySource.manual),
  )();
  TextColumn get sentence => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().map(const KstDateTimeConverter())();
  DateTimeColumn get updatedAt =>
      dateTime().map(const KstDateTimeConverter())();
}

@UseRowClass(LmsItem)
class LmsItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get remoteKey => text().unique()();
  IntColumn get courseId => integer().references(Courses, #id)();
  TextColumn get courseName => text()();
  TextColumn get title => text()();
  TextColumn get kind => text().map(
    const EnumConverter(LmsItemKind.values, fallback: LmsItemKind.material),
  )();
  DateTimeColumn get dueAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();
  BoolColumn get dueTimeUnknown => boolean()();
  DateTimeColumn get openAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();
  IntColumn get videoMin => integer().nullable()();
  IntColumn get requiredMin => integer().nullable()();
  IntColumn get watchedMin => integer().nullable()();
  BoolColumn get officiallyDone => boolean().nullable()();
  BoolColumn get submitted => boolean().nullable()();
  TextColumn get link => text().nullable()();
  DateTimeColumn get firstSeenAt =>
      dateTime().map(const KstDateTimeConverter())();
  DateTimeColumn get lastSeenAt =>
      dateTime().map(const KstDateTimeConverter())();
  IntColumn get missCount => integer()();
  DateTimeColumn get goneAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();
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
  DateTimeColumn get changedAt =>
      dateTime().map(const KstDateTimeConverter())();
}

@UseRowClass(Briefing)
class Briefings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  DateTimeColumn get createdAt =>
      dateTime().map(const KstDateTimeConverter())();
  DateTimeColumn get openedAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();
  DateTimeColumn get confirmedAt =>
      dateTime().nullable().map(const KstDateTimeConverter())();

  /// 확정하기 전에 고른 것을 바꾼 횟수(사용 지표).
  IntColumn get editCount => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => const ['CHECK ("edit_count" >= 0)'];
}

@UseRowClass(SyncRun)
class SyncRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt =>
      dateTime().map(const KstDateTimeConverter())();
  TextColumn get trigger =>
      text().map(const EnumConverter(SyncTrigger.values))();
  TextColumn get scope => text().map(const EnumConverter(SyncScope.values))();
  TextColumn get result => text().map(
    const EnumConverter(
      SyncResultKind.values,
      fallback: SyncResultKind.parseFailure,
    ),
  )();
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
  DateTimeColumn get expiresAt =>
      dateTime().map(const KstDateTimeConverter())();

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
  DateTimeColumn get createdAt =>
      dateTime().map(const KstDateTimeConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
