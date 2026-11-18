// 데모 모드의 샘플 학생 데이터. docs/architecture.md '데모 모드'.
//
// 데모 DB(`app_demo.sqlite`)를 열 때 모든 표가 비어 있으면(파일을 처음 만들었거나 데모를 끝내며 비운 뒤)
// `AppDatabase`가 한 트랜잭션 안에서 [seedDemo]를 부른다. 하루를 넘긴 데모는 다시 넣지 않는다
// (docs/decisions.md 2026-11-13 '하루를 넘긴 데모의 샘플은 다시 넣지 않는다'). 날짜는 넣는 때의 논리적
// 하루(아래 '오늘')를 기준으로 만든다. 그때 데모 DB의 설정은 늘 비어 있으므로 하루 경계는 기본값이다.
//
// 샘플 학생 한 명의 한 주다. 수업은 어제부터 닷새에 걸쳐 놓는다. 요일은 넣는 날에 따라 바뀌고, 그래서 어느
// 요일에 들어와도 오늘과 어제에 수업이 있다. 화면마다 보일 것이 있도록 아래를 넣는다.
// - 휴강과 시험이 하나씩 있다.
// - 할 일에 마감 지남·공개 전·마감 변경·마감 없음·끝낸 일(앱에서 끝냄, LMS 제출 확인)이 있다.
// - 블록은 어제 놓친 것과 끝낸 것, 오늘 직접 놓은 것과 제안, 내일 제안이다.
// 제안 블록은 배치 엔진이 다시 계산하면 새로 놓인다. 과목·장소·LMS 키는 모두 지어낸 값이고 실제 LMS의
// 값이 아니다.

import 'dart:convert';

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:drift/drift.dart';

/// 데모 DB에 샘플을 넣는다. [now]는 넣는 때다. 데모 동작에 맞는 설정도 함께 적는다.
Future<void> seedDemo(AppDatabase db, DateTime now) async {
  await _enableAi(db);
  final days = _Days(logicalDate(now, dayBoundaryMin: Defaults.dayBoundaryMin));
  final courses = await _insertCourses(db, now);
  final slots = await _insertTimetable(db, days, courses);
  await _insertClassExceptions(db, days, slots);
  await _insertFixedBlock(db, days);
  await _insertEvents(db, days);
  final tasks = await _insertTasks(db, days, courses, now);
  await _insertBlocks(db, days, tasks);
  await _insertRules(db, days);
  await _insertBriefing(db, days);
}

/// 데모에서는 AI를 부르지 않고 미리 적은 응답을 보이므로(서버 클라이언트가 요청을 막음) AI 사용을 켜 둔다.
/// 꺼 두면 06 AI 비서가 그 응답 대신 AI 사용 동의 화면을 연다.
Future<void> _enableAi(AppDatabase db) => db
    .into(db.settings)
    .insertOnConflictUpdate(
      SettingsCompanion.insert(
        key: SettingKeys.aiEnabled,
        value: jsonEncode(AppSettings.encodeValue(SettingKeys.aiEnabled, true)),
      ),
    );

/// 오늘(논리적 하루의 날짜)을 기준으로 한 날짜와 시각.
class _Days {
  _Days(this.today);

  /// 오늘. 시각은 0이다.
  final DateTime today;

  /// 오늘에서 [offset]일 떨어진 날의 [minute](자정 기준 분) 시각.
  DateTime at(int offset, int minute) =>
      DateTime(today.year, today.month, today.day + offset, 0, minute);

  /// 오늘에서 [offset]일 떨어진 날의 요일(1 월–7 일).
  int weekday(int offset) => at(offset, 0).weekday;

  /// 오늘에서 [offset]일 떨어진 날의 `YYYY-MM-DD`.
  String date(int offset) => isoDate(at(offset, 0));
}

/// 과목. 모두 LMS 과목이고 같은 학기다.
enum _Course {
  dataStructures('자료구조'),
  operatingSystems('운영체제'),
  networks('컴퓨터네트워크'),
  linearAlgebra('선형대수'),
  statistics('확률과 통계'),
  writing('글쓰기와 토론');

  const _Course(this.label);

  final String label;

  /// 지어낸 LMS 과목 ID.
  String get remoteId => 'demo-${index + 1}';
}

/// 지어낸 학기 값. 모든 과목이 같은 값이라 모두 '가장 최근 학기'다.
const _semester = 'demo';

Future<Map<_Course, int>> _insertCourses(AppDatabase db, DateTime now) async =>
    {
      for (final course in _Course.values)
        course: await db
            .into(db.courses)
            .insert(
              CoursesCompanion.insert(
                name: course.label,
                remoteId: Value(course.remoteId),
                semester: const Value(_semester),
                lastSeenAt: Value(now),
              ),
            ),
    };

/// 수업 칸 하나. [offset]은 오늘에서 떨어진 날이고 그날의 요일에 매주 열린다.
typedef _Slot = ({
  _Course course,
  int offset,
  int startMin,
  int endMin,
  String? place,
});

const List<_Slot> _timetable = [
  (
    course: _Course.dataStructures,
    offset: -1,
    startMin: 540,
    endMin: 615,
    place: '공학관 201',
  ),
  (
    course: _Course.operatingSystems,
    offset: -1,
    startMin: 780,
    endMin: 855,
    place: '공학관 305',
  ),
  (
    course: _Course.linearAlgebra,
    offset: 0,
    startMin: 630,
    endMin: 705,
    place: '자연과학관 105',
  ),
  (
    course: _Course.networks,
    offset: 0,
    startMin: 870,
    endMin: 945,
    place: '공학관 412',
  ),
  (
    course: _Course.dataStructures,
    offset: 1,
    startMin: 540,
    endMin: 615,
    place: '공학관 201',
  ),
  (
    course: _Course.operatingSystems,
    offset: 1,
    startMin: 780,
    endMin: 855,
    place: '공학관 305',
  ),
  (
    course: _Course.linearAlgebra,
    offset: 2,
    startMin: 630,
    endMin: 705,
    place: '자연과학관 105',
  ),
  (
    course: _Course.networks,
    offset: 2,
    startMin: 870,
    endMin: 945,
    place: '공학관 412',
  ),
  // 실시간 비대면 수업(장소·이동 여유 없음).
  (
    course: _Course.writing,
    offset: 2,
    startMin: 960,
    endMin: 1070,
    place: null,
  ),
  (
    course: _Course.statistics,
    offset: 3,
    startMin: 600,
    endMin: 765,
    place: '자연과학관 210',
  ),
];

/// 시간표를 통합정보시스템에서 불러온 것처럼(`auto`, 불러온 원래 값 함께) 넣는다. 돌려주는 목록은
/// [_timetable]과 같은 순서의 수업 칸 id다.
Future<List<int>> _insertTimetable(
  AppDatabase db,
  _Days days,
  Map<_Course, int> courses,
) async => [
  for (final slot in _timetable)
    await db
        .into(db.classSlots)
        .insert(
          ClassSlotsCompanion.insert(
            courseId: courses[slot.course]!,
            weekday: days.weekday(slot.offset),
            startMin: slot.startMin,
            endMin: slot.endMin,
            place: Value(slot.place),
            online: slot.place == null,
            source: SlotSource.auto,
            importedWeekday: Value(days.weekday(slot.offset)),
            importedStartMin: Value(slot.startMin),
            importedEndMin: Value(slot.endMin),
            importedPlace: Value(slot.place),
          ),
        ),
];

/// 모레 컴퓨터네트워크 휴강, 다음 주 오늘 선형대수 시험.
Future<void> _insertClassExceptions(
  AppDatabase db,
  _Days days,
  List<int> slots,
) async {
  int slotOf(_Course course, int offset) =>
      slots[_timetable.indexWhere(
        (slot) => slot.course == course && slot.offset == offset,
      )];
  await db
      .into(db.classExceptions)
      .insert(
        ClassExceptionsCompanion.insert(
          date: days.date(2),
          classSlotId: slotOf(_Course.networks, 2),
          kind: ClassExceptionKind.cancelled,
          source: EntrySource.manual,
        ),
      );
  await db
      .into(db.classExceptions)
      .insert(
        ClassExceptionsCompanion.insert(
          date: days.date(7),
          classSlotId: slotOf(_Course.linearAlgebra, 0),
          kind: ClassExceptionKind.exam,
          place: const Value('자연과학관 대강의실'),
          source: EntrySource.manual,
        ),
      );
}

/// 오늘과 사흘 뒤 저녁의 알바.
Future<void> _insertFixedBlock(AppDatabase db, _Days days) => db
    .into(db.fixedBlocks)
    .insert(
      FixedBlocksCompanion.insert(
        name: '카페 알바',
        weekdays: [days.weekday(0), days.weekday(3)]..sort(),
        startMin: 1080,
        endMin: 1260,
        bufferMin: 10,
        kind: FixedBlockKind.work,
        source: EntrySource.manual,
        place: const Value('정문 앞 카페'),
      ),
    );

/// 개인 일정 둘(내일 저녁 동아리 회의, 나흘 뒤 치과).
Future<void> _insertEvents(AppDatabase db, _Days days) async {
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '동아리 정기 회의',
          startAt: days.at(1, 1140),
          endAt: days.at(1, 1230),
          allDay: false,
          place: const Value('학생회관 3층'),
          source: EventSource.manual,
        ),
      );
  await db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          title: '치과 예약',
          startAt: days.at(4, 660),
          endAt: days.at(4, 720),
          allDay: false,
          place: const Value('학교 앞 치과'),
          reminderMinutes: const Value(60),
          source: EventSource.ai,
        ),
      );
}

/// 블록이 가리키는 할 일.
enum _Task {
  linkedList,
  schedulingQuiz,
  tcpVideo,
  eigenvalues,
  probabilityVideo,
  teamReport,
  discussion,
  shell,
  socket,
  midterm,
  vocabulary,
  scholarship,
  libraryBook,
}

/// LMS 항목 하나와 그 할 일. [dueOffset]·[dueMin]은 마감(오늘에서 떨어진 날과 분), [openOffset]은 공개 날이다.
typedef _LmsTask = ({
  _Task task,
  _Course course,
  LmsItemKind kind,
  String title,
  int dueOffset,
  int dueMin,
  int? openOffset,
  int? videoMin,
  int? requiredMin,
  bool? submitted,
});

const List<_LmsTask> _lmsTasks = [
  (
    task: _Task.linkedList,
    course: _Course.dataStructures,
    kind: LmsItemKind.assignment,
    title: '연결 리스트 구현',
    dueOffset: 2,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  (
    task: _Task.schedulingQuiz,
    course: _Course.operatingSystems,
    kind: LmsItemKind.quiz,
    title: '프로세스 스케줄링 퀴즈',
    dueOffset: 1,
    dueMin: 1080,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  (
    task: _Task.tcpVideo,
    course: _Course.networks,
    kind: LmsItemKind.video,
    title: 'TCP 흐름 제어',
    dueOffset: 4,
    dueMin: 1439,
    openOffset: null,
    videoMin: 48,
    requiredMin: 40,
    submitted: null,
  ),
  // 마감이 이틀 늦춰졌다(아래 변경 기록).
  (
    task: _Task.eigenvalues,
    course: _Course.linearAlgebra,
    kind: LmsItemKind.assignment,
    title: '고윳값 연습문제',
    dueOffset: 5,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  // 모레 열린다(공개 전).
  (
    task: _Task.probabilityVideo,
    course: _Course.statistics,
    kind: LmsItemKind.video,
    title: '조건부 확률',
    dueOffset: 9,
    dueMin: 1439,
    openOffset: 2,
    videoMin: 52,
    requiredMin: 45,
    submitted: null,
  ),
  (
    task: _Task.teamReport,
    course: _Course.dataStructures,
    kind: LmsItemKind.team,
    title: '팀 프로젝트 중간 보고서',
    dueOffset: 6,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  // 토론은 자동으로 놓지 않는다.
  (
    task: _Task.discussion,
    course: _Course.writing,
    kind: LmsItemKind.discussion,
    title: '토론 게시판 의견 쓰기',
    dueOffset: 3,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  // 어제 마감인데 내지 않았다(마감 지남).
  (
    task: _Task.shell,
    course: _Course.operatingSystems,
    kind: LmsItemKind.assignment,
    title: '셸 만들기',
    dueOffset: -1,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: false,
  ),
  // LMS가 제출을 알려 줘서 끝낸 일로 본다.
  (
    task: _Task.socket,
    course: _Course.networks,
    kind: LmsItemKind.assignment,
    title: '소켓 프로그래밍 실습',
    dueOffset: -2,
    dueMin: 1439,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: true,
  ),
  // 위 시험 수업과 같은 때다. 시험은 자동으로 놓지 않는다.
  (
    task: _Task.midterm,
    course: _Course.linearAlgebra,
    kind: LmsItemKind.exam,
    title: '중간고사',
    dueOffset: 7,
    dueMin: 630,
    openOffset: null,
    videoMin: null,
    requiredMin: null,
    submitted: null,
  ),
];

/// 지어낸 LMS 원본 키(학기·과목·종류·항목 번호를 `:`로 이음).
String _remoteKey(_LmsTask item) =>
    '$_semester:${item.course.remoteId}:${item.kind.name}:${item.task.index + 1}';

/// LMS 항목과 그 할 일, 마감 변경 기록, 개인 할 일 셋을 넣는다. 할 일은 동기화가 만드는 것처럼 제목·종류·마감을
/// 원본에서 복사한다(docs/architecture.md '폰 DB'의 LMS 항목을 할 일로 만드는 규칙).
Future<Map<_Task, int>> _insertTasks(
  AppDatabase db,
  _Days days,
  Map<_Course, int> courses,
  DateTime now,
) async {
  final ids = <_Task, int>{};
  for (final item in _lmsTasks) {
    final key = _remoteKey(item);
    final dueAt = days.at(item.dueOffset, item.dueMin);
    await db
        .into(db.lmsItems)
        .insert(
          LmsItemsCompanion.insert(
            remoteKey: key,
            courseId: courses[item.course]!,
            courseName: item.course.label,
            title: item.title,
            kind: item.kind,
            dueAt: Value(dueAt),
            dueTimeUnknown: false,
            openAt: Value(
              item.openOffset == null ? null : days.at(item.openOffset!, 540),
            ),
            videoMin: Value(item.videoMin),
            requiredMin: Value(item.requiredMin),
            officiallyDone: Value(
              item.kind == LmsItemKind.video ? false : null,
            ),
            submitted: Value(item.submitted),
            firstSeenAt: days.at(-6, 600),
            lastSeenAt: now,
            missCount: 0,
            contentHash: key,
          ),
        );
    ids[item.task] = await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            title: item.title,
            kind: TaskKind.values.byName(item.kind.name),
            dueAt: Value(dueAt),
            dueTimeUnknown: false,
            // 사용자가 넣은 예상 시간과 어제 끝낸 블록만큼의 한 시간.
            estimateMin: Value(item.task == _Task.linkedList ? 180 : null),
            spentMin: Value(item.task == _Task.linkedList ? 60 : null),
            status: TaskStatus.todo,
            lmsKey: Value(key),
          ),
        );
  }
  final eigenvalues = _lmsTasks.firstWhere(
    (item) => item.task == _Task.eigenvalues,
  );
  await db
      .into(db.lmsItemChanges)
      .insert(
        LmsItemChangesCompanion.insert(
          remoteKey: _remoteKey(eigenvalues),
          field: LmsItemChangeField.dueAt,
          oldValue: Value(encodeDateTime(days.at(3, 1439))),
          newValue: Value(encodeDateTime(days.at(5, 1439))),
          changedAt: days.at(-1, 1270),
        ),
      );

  Future<int> personal(
    String title, {
    DateTime? dueAt,
    required int estimateMin,
    TaskStatus status = TaskStatus.todo,
    DateTime? completedAt,
    int? actualMin,
  }) => db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: title,
          kind: TaskKind.personal,
          dueAt: Value(dueAt),
          dueTimeUnknown: false,
          estimateMin: Value(estimateMin),
          status: status,
          source: const Value(EntrySource.manual),
          completedAt: Value(completedAt),
          actualMin: Value(actualMin),
        ),
      );
  // 마감 없는 일.
  ids[_Task.vocabulary] = await personal('토익 단어 외우기', estimateMin: 30);
  ids[_Task.scholarship] = await personal(
    '장학금 서류 내기',
    dueAt: days.at(1, 1020),
    estimateMin: 60,
  );
  // 어제 끝낸 일('얼마나 걸렸어요?'에 20분으로 답함).
  ids[_Task.libraryBook] = await personal(
    '도서관 책 반납',
    dueAt: days.at(-1, 1080),
    estimateMin: 30,
    status: TaskStatus.done,
    completedAt: days.at(-1, 930),
    actualMin: 20,
  );
  return ids;
}

/// 블록. 어제는 아침 브리핑에서 확정한 둘(놓침·완료), 오늘은 직접 놓은 확정 하나와 제안 둘, 내일은 제안 하나다.
Future<void> _insertBlocks(
  AppDatabase db,
  _Days days,
  Map<_Task, int> tasks,
) async {
  Future<void> block(
    _Task task,
    int offset,
    int startMin,
    int endMin,
    PlanBlockStatus status, {
    BlockReason? reason,
    DateTime? answeredAt,
    bool fromBriefing = false,
  }) => db
      .into(db.planBlocks)
      .insert(
        PlanBlocksCompanion.insert(
          taskId: tasks[task]!,
          startAt: days.at(offset, startMin),
          endAt: days.at(offset, endMin),
          status: status,
          source: reason == null ? BlockSource.manual : BlockSource.auto,
          reason: Value(reason),
          answeredAt: Value(answeredAt),
          fromBriefing: Value(fromBriefing),
        ),
      );
  BlockReason reason(
    _Task task, {
    required int slackMin,
    required int gapMin,
    required int rank,
    required BlockFactor factor,
  }) {
    final item = _lmsTasks.firstWhere((item) => item.task == task);
    return BlockReason(
      slackMin: slackMin,
      dueAt: days.at(item.dueOffset, item.dueMin),
      gapMin: gapMin,
      rank: rank,
      factor: factor,
    );
  }

  // 어제 놓친 블록(01 계획의 '어제 못 한 일').
  await block(
    _Task.shell,
    -1,
    900,
    990,
    PlanBlockStatus.missed,
    reason: reason(
      _Task.shell,
      slackMin: 120,
      gapMin: 135,
      rank: 1,
      factor: BlockFactor.fit,
    ),
    fromBriefing: true,
  );
  await block(
    _Task.linkedList,
    -1,
    1140,
    1200,
    PlanBlockStatus.done,
    reason: reason(
      _Task.linkedList,
      slackMin: 600,
      gapMin: 240,
      rank: 2,
      factor: BlockFactor.unsplit,
    ),
    answeredAt: days.at(-1, 1205),
    fromBriefing: true,
  );
  // 오늘 직접 놓은 확정 블록(근거 없음).
  await block(_Task.schedulingQuiz, 0, 780, 810, PlanBlockStatus.confirmed);
  await block(
    _Task.linkedList,
    0,
    990,
    1060,
    PlanBlockStatus.suggested,
    reason: reason(
      _Task.linkedList,
      slackMin: 420,
      gapMin: 95,
      rank: 1,
      factor: BlockFactor.nearClass,
    ),
  );
  await block(
    _Task.tcpVideo,
    0,
    1275,
    1315,
    PlanBlockStatus.suggested,
    reason: reason(
      _Task.tcpVideo,
      slackMin: 900,
      gapMin: 110,
      rank: 2,
      factor: BlockFactor.fit,
    ),
  );
  await block(
    _Task.teamReport,
    1,
    630,
    720,
    PlanBlockStatus.suggested,
    reason: reason(
      _Task.teamReport,
      slackMin: 1500,
      gapMin: 105,
      rank: 3,
      factor: BlockFactor.unsplit,
    ),
  );
}

/// 내 규칙 셋: 통학 30분(온보딩 3단계), 12 내 규칙 폼으로 정한 선호 시간대 매일 19:00–22:00, 말로 정한 하루 최대
/// 공부량 4시간.
Future<void> _insertRules(AppDatabase db, _Days days) async {
  Future<void> rule(
    RuleKind kind,
    RuleParams params, {
    required EntrySource source,
    String? sentence,
    required DateTime at,
  }) => db
      .into(db.rules)
      .insert(
        RulesCompanion.insert(
          kind: kind,
          params: params,
          active: true,
          source: source,
          sentence: Value(sentence),
          createdAt: at,
          updatedAt: at,
        ),
      );
  await rule(
    RuleKind.travel,
    const RuleParams(minutes: 30, position: TravelPosition.dayEdges),
    source: EntrySource.manual,
    at: days.at(-7, 1260),
  );
  await rule(
    RuleKind.preferred,
    const RuleParams(startMin: 1140, endMin: 1320),
    source: EntrySource.manual,
    at: days.at(-7, 1261),
  );
  await rule(
    RuleKind.dailyCap,
    const RuleParams(minutes: 240),
    source: EntrySource.ai,
    sentence: '하루에 네 시간 넘게는 공부 못 하겠어',
    at: days.at(-3, 1320),
  );
}

/// 어제 아침 브리핑에서 할 일 둘을 확정한 기록. 오늘 브리핑은 비워 두어 데모에 들어오면 01 계획이 뜬다.
Future<void> _insertBriefing(AppDatabase db, _Days days) => db
    .into(db.briefings)
    .insert(
      BriefingsCompanion.insert(
        date: days.date(-1),
        createdAt: days.at(-1, 511),
        openedAt: Value(days.at(-1, 511)),
        confirmedAt: Value(days.at(-1, 515)),
        editCount: const Value(1),
      ),
    );
