// 데모 시드 테스트. docs/architecture.md '데모 모드'.
//
// 데모 DB를 처음 열 때 넣는 샘플 학생의 한 주를 본다. 표마다 넣는 수, 넣는 때의 논리적 하루를 기준으로 한
// 날짜, 화면이 보여 줄 상태(마감 지남·공개 전·마감 변경 등), 블록이 실제 빈 시간 계산과 맞는지를 확인한다.

import 'package:cnu_ai_assistant/data/db/database.dart';
import 'package:cnu_ai_assistant/data/demo/demo_seed.dart';
import 'package:cnu_ai_assistant/data/repositories/class_slot_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/lms_item_change_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/rules_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/schedule_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/settings_repository.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart' show TestClock;

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final error) => fail('$error'),
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// [now]에 데모 DB를 처음 열어 샘플을 넣는다.
  Future<AppDatabase> open(DateTime now) async {
    final db = AppDatabase(
      NativeDatabase.memory(),
      demoSeeder: seedDemo,
      clock: TestClock(now),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    return db;
  }

  // 2026-11-13(금) 09:00.
  final friday = DateTime(2026, 11, 13, 9);

  test('데모 DB는 AI 사용을 켠 채로 열고, 다른 설정은 기본값이다', () async {
    final db = await open(friday);
    final settings = _ok(await SettingsRepository(db).read());
    expect(settings, AppSettings.defaults.copyWith(aiEnabled: true));
  });

  test('표마다 정한 수만큼 넣는다', () async {
    final db = await open(friday);
    Future<int> count(String table) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM "$table"')
                .getSingle())
            .read<int>('n');
    expect(
      {
        for (final table in db.allTables)
          table.actualTableName: await count(table.actualTableName),
      },
      {
        'courses': 6,
        'class_slots': 10,
        'class_exceptions': 2,
        'fixed_blocks': 1,
        'events': 2,
        'tasks': 13,
        'plan_blocks': 6,
        'rules': 3,
        'lms_items': 10,
        'lms_item_changes': 1,
        'briefings': 1,
        'sync_runs': 0,
        'sync_lease': 0,
        'settings': 1,
        'undo_log': 0,
      },
    );
  });

  test('어느 요일에 넣어도 오늘과 어제에 수업이 둘씩 있고 수업은 닷새에 걸친다', () async {
    for (var day = 0; day < 7; day++) {
      final now = DateTime(2026, 11, 16 + day, 9);
      final db = await open(now);
      final entries = _ok(await ClassSlotRepository(db).read());
      final byWeekday = <int, int>{};
      for (final entry in entries) {
        byWeekday[entry.slot.weekday] =
            (byWeekday[entry.slot.weekday] ?? 0) + 1;
      }
      final today = now.weekday;
      final yesterday = today == 1 ? 7 : today - 1;
      expect(byWeekday[today], 2, reason: '$now');
      expect(byWeekday[yesterday], 2, reason: '$now');
      expect(byWeekday.length, 5, reason: '$now');
      expect(entries.every((e) => e.slot.source == SlotSource.auto), isTrue);
      expect(entries.map((e) => e.course.name).toSet(), hasLength(6));
    }
  });

  test('날짜는 넣는 때의 논리적 하루를 기준으로 한다(하루 경계 전 새벽은 전날)', () async {
    // 토요일 02:00은 금요일(11-13)의 논리적 하루다.
    final db = await open(DateTime(2026, 11, 14, 2));
    final quiz =
        await (db.select(db.planBlocks)
              ..where((t) => t.status.equalsValue(PlanBlockStatus.confirmed)))
            .getSingle();
    expect(quiz.startAt, DateTime(2026, 11, 13, 13));
    expect((await db.select(db.briefings).getSingle()).date, '2026-11-12');
    expect([
      for (final e in await db.select(db.classExceptions).get()) e.date,
    ], unorderedEquals(['2026-11-15', '2026-11-20']));
    final slots = _ok(await ClassSlotRepository(db).read());
    expect(slots.where((e) => e.slot.weekday == DateTime.friday), hasLength(2));
  });

  test('할 일은 끝낸 일·마감 지남·공개 전·마감 변경·마감 없음을 모두 담는다', () async {
    final db = await open(friday);
    final entries = _ok(await TaskRepository(db).read());
    TaskEntry byTitle(String title) =>
        entries.singleWhere((e) => e.task.title == title);

    expect(entries, hasLength(13));
    expect([
      for (final e in entries.where((e) => e.isDone)) e.task.title,
    ], unorderedEquals(['소켓 프로그래밍 실습', '도서관 책 반납']));
    expect(entries.where((e) => e.isRemaining), hasLength(11));

    final shell = byTitle('셸 만들기');
    expect(shell.isRemaining, isTrue);
    expect(shell.task.dueAt!.isBefore(friday), isTrue);

    final video = byTitle('조건부 확률');
    expect(video.lmsItem!.openAt!.isAfter(friday), isTrue);
    expect(byTitle('토익 단어 외우기').task.dueAt, isNull);
    expect(byTitle('도서관 책 반납').task.actualMin, 20);
    expect(byTitle('연결 리스트 구현').task.spentMin, 60);
    // 개인 할 일과 LMS 할 일이 섞여 있고, LMS 할 일은 원본의 과목을 읽는다.
    expect(entries.where((e) => e.lmsItem == null), hasLength(3));
    expect(byTitle('중간고사').course!.name, '선형대수');

    final changes = await LmsItemChangeRepository(db)
        .watchLatestDueChanges()
        .first;
    final eigen = byTitle('고윳값 연습문제');
    final change = changes[eigen.lmsItem!.remoteKey]!;
    expect(decodeDateTime(change.newValue!), eigen.task.dueAt);
    expect(decodeDateTime(change.oldValue!), DateTime(2026, 11, 16, 23, 59));
  });

  test('규칙 셋은 값 검사를 통과하고 배치 설정에 들어간다', () async {
    final db = await open(friday);
    final rules = _ok(await RulesRepository(db).read());
    expect(
      rules.map((r) => r.kind),
      unorderedEquals([RuleKind.travel, RuleKind.dailyCap, RuleKind.notify]),
    );
    for (final rule in rules) {
      expect(
        validateRule(rule.kind, rule.params, weekdays: rule.weekdays),
        isEmpty,
        reason: rule.kind.name,
      );
    }
    final day = PlannerConfig.from(rules).forWeekday(DateTime.friday);
    expect(day.travel!.minutes, 30);
    expect(day.dailyCapMin, 240);
    expect(NotifyConfig.from(rules).briefingMin, 510);
  });

  test('블록은 어제 놓침·완료, 오늘 직접 놓은 확정과 제안, 내일 제안이고 모두 그날의 빈 시간 안이다', () async {
    for (final now in [friday, DateTime(2026, 11, 16, 23)]) {
      final db = await open(now);
      final today = logicalDate(now, dayBoundaryMin: Defaults.dayBoundaryMin);
      DateTime dayAt(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final schedule = _ok(
        await ScheduleRepository(db).read(
          start: logicalDayStart(
            dayAt(-1),
            dayBoundaryMin: Defaults.dayBoundaryMin,
          ),
          end: logicalDayEnd(dayAt(1), dayBoundaryMin: Defaults.dayBoundaryMin),
        ),
      );
      // 오늘 화면에 고정 일정(알바)도 보인다.
      expect(schedule.fixedBlocks.single.weekdays, contains(today.weekday));
      final blocks = schedule.planBlocks;
      expect(
        [
          for (final b in blocks)
            '${logicalDate(b.startAt, dayBoundaryMin: Defaults.dayBoundaryMin).difference(today).inDays} ${b.status.name}',
        ],
        unorderedEquals([
          '-1 missed',
          '-1 done',
          '0 confirmed',
          '0 suggested',
          '0 suggested',
          '1 suggested',
        ]),
      );
      // 직접 놓은 블록만 근거가 없다.
      for (final b in blocks) {
        expect(b.reason == null, b.source == BlockSource.manual);
      }

      // 블록을 뺀 일정으로 빈 시간을 계산해, 블록마다 그날의 빈 시간 안에 드는지 본다(수업·이동·고정 일정·
      // 일정·점심과 겹치지 않음).
      final config = PlannerConfig.from(_ok(await RulesRepository(db).read()));
      final withoutBlocks = Schedule(
        classSlots: schedule.classSlots,
        classExceptions: schedule.classExceptions,
        fixedBlocks: schedule.fixedBlocks,
        events: schedule.events,
      );
      for (final offset in [-1, 0, 1]) {
        final free = dayAvailability(
          dayAt(offset),
          schedule: withoutBlocks,
          config: config,
          dayBoundaryMin: Defaults.dayBoundaryMin,
        ).free;
        final dayBlocks = blocks.where(
          (b) =>
              logicalDate(b.startAt, dayBoundaryMin: Defaults.dayBoundaryMin) ==
              dayAt(offset),
        );
        for (final b in dayBlocks) {
          expect(
            free.any(
              (s) => !b.startAt.isBefore(s.start) && !b.endAt.isAfter(s.end),
            ),
            isTrue,
            reason: '$now ${b.startAt}–${b.endAt}',
          );
        }
        // 하루 최대 공부량(4시간) 안이다.
        final minutes = dayBlocks.fold<int>(
          0,
          (sum, b) => sum + b.endAt.difference(b.startAt).inMinutes,
        );
        expect(minutes, lessThanOrEqualTo(240));
      }
    }
  });
}
