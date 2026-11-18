// 옮기기 시트·빈 시간에 놓기 시트 내용 테스트. docs/screens.md '옮기기 시트'·'빈 시간에 놓기 시트'.
//
// 지금은 2026-11-16(월) 10:00이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/move_sheet.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 16, 10);
const boundary = 240;
final config = PlannerConfig.from(const []);

DateTime at(int date, int hour, [int minute = 0]) =>
    DateTime(2026, 11, date, hour, minute);

TaskEntry task(
  int id, {
  String title = '자료구조 과제',
  TaskKind kind = TaskKind.assignment,
  DateTime? due,
  bool noDue = false,
  int? estimateMin,
  int? spentMin,
  TaskStatus status = TaskStatus.todo,
  DateTime? openAt,
}) {
  final key = 'k$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: title,
      kind: kind,
      dueAt: noDue ? null : (due ?? at(17, 23, 59)),
      dueTimeUnknown: false,
      estimateMin: estimateMin,
      spentMin: spentMin,
      status: status,
      lmsKey: openAt == null ? null : key,
    ),
    lmsItem: openAt == null
        ? null
        : LmsItem(
            id: id,
            remoteKey: key,
            courseId: 7,
            courseName: '자료구조',
            title: title,
            kind: LmsItemKind.values.byName(kind.name),
            dueAt: noDue ? null : (due ?? at(17, 23, 59)),
            dueTimeUnknown: false,
            openAt: openAt,
            firstSeenAt: now,
            lastSeenAt: now,
            missCount: 0,
            contentHash: key,
          ),
  );
}

PlanBlock block({DateTime? start, DateTime? end}) => PlanBlock(
  id: 9,
  taskId: 1,
  startAt: start ?? at(16, 14),
  endAt: end ?? at(16, 15, 30),
  status: PlanBlockStatus.confirmed,
  source: BlockSource.manual,
);

SlotOption option(
  DateTime start,
  int minutes, {
  int gapMin = 120,
  BlockFactor factor = BlockFactor.unsplit,
}) => SlotOption(
  span: TimeSpan(start, start.add(Duration(minutes: minutes))),
  gapMin: gapMin,
  factor: factor,
);

MoveSheetContent move(
  List<SlotOption> options, {
  TaskEntry? entry,
  String? courseName = '자료구조',
}) => moveSheetContent(
  block: block(),
  entry: entry ?? task(1),
  options: options,
  courseName: courseName,
  now: now,
  dayBoundaryMin: boundary,
);

FreeSlotContent? content(
  TimeSpan gap,
  List<TaskEntry> entries, {
  List<int> ranked = const [],
  DateTime? at,
}) => freeSlotContent(
  gap: gap,
  entries: entries,
  ranked: ranked,
  config: config,
  now: at ?? now,
  dayBoundaryMin: boundary,
);

FreeSlotContent free(
  TimeSpan gap,
  List<TaskEntry> entries, {
  List<int> ranked = const [],
  DateTime? at,
}) => content(gap, entries, ranked: ranked, at: at)!;

void main() {
  group('옮기기 시트', () {
    test('제목 아래 줄은 이름·블록 길이·마감이고 후보마다 때·이유·버튼을 만든다', () {
      final result = move([
        option(at(16, 16), 90),
        option(at(17, 9, 15), 90, factor: BlockFactor.preferred),
      ]);

      expect(result.sub, '자료구조 과제 · 1시간 30분 · 내일 23:59 마감');
      expect(
        [for (final c in result.choices) c.when],
        ['오늘 16:00–17:30', '내일 09:15–10:45'],
      );
      expect(result.choices.first.why, '2시간 비어 있어 한 번에 끝낼 수 있어요');
      expect(result.choices.last.why, '평소 집중하는 시간이에요');
      expect(result.choices.first.option, option(at(16, 16), 90));
    });

    test('버튼의 조사는 시각의 끝소리를 따른다', () {
      final result = move([option(at(16, 16), 60), option(at(16, 18, 15), 60)]);

      expect(result.choices.first.cta, '16:00으로 옮기기');
      expect(result.choices.last.cta, '18:15로 옮기기');
    });

    test('이유는 고른 까닭마다 다르고 과목을 모르면 관련 수업이라 한다', () {
      String why(BlockFactor factor, {String? course = ' 자료구조 '}) => move([
        option(at(16, 16), 45, gapMin: 45, factor: factor),
      ], courseName: course).choices.single.why;

      expect(why(BlockFactor.nearClass), '자료구조 수업과 가까워 내용이 이어져요');
      expect(why(BlockFactor.nearClass, course: null), '관련 수업과 가까워 내용이 이어져요');
      expect(why(BlockFactor.fit), '45분 비어 있어 한 조각을 끝낼 수 있어요');
      expect(why(BlockFactor.unsplit), '45분 비어 있어 한 번에 끝낼 수 있어요');
    });

    test('자정에 끝나면 24:00, 사흘 뒤는 요일로 쓴다', () {
      final result = move([option(at(16, 23), 60), option(at(19, 20), 60)]);

      expect(result.choices.first.when, '오늘 23:00–24:00');
      expect(result.choices.last.when, '목요일 20:00–21:00');
    });

    test('후보가 없을 때 안내는 마감이 있는지에 따라 다르다', () {
      expect(move(const []).choices, isEmpty);
      expect(move(const []).noneText, '마감 전에 옮길 수 있는 빈 시간이 없어요');
      expect(
        move(const [], entry: task(1, noDue: true)).noneText,
        '옮길 수 있는 빈 시간이 없어요',
      );
    });

    test('옮긴 뒤 토스트는 날짜 말과 시각을 쓴다', () {
      expect(
        movedToast('자료구조 과제', at(17, 14), now: now, dayBoundaryMin: boundary),
        '자료구조 과제를 내일 14:00으로 옮겼어요',
      );
      expect(
        movedToast('셸 만들기', at(16, 18, 15), now: now, dayBoundaryMin: boundary),
        '셸 만들기를 오늘 18:15로 옮겼어요',
      );
    });
  });

  group('빈 시간에 놓기 시트', () {
    final gap = TimeSpan(at(16, 15), at(16, 16, 30));

    test('제목은 빈 시간과 길이이고 오늘이 아니면 날짜 말을 앞에 쓴다', () {
      expect(free(gap, const []).title, '15:00–16:30 · 1시간 30분 비어 있어요');
      expect(
        free(TimeSpan(at(17, 9), at(17, 10)), const []).title,
        '내일 09:00–10:00 · 1시간 비어 있어요',
      );
      expect(free(gap, const []).span, gap);
    });

    test('지금 전에 시작한 빈 시간은 지금 뒤 5분 단위부터 센다', () {
      final result = free(TimeSpan(at(16, 9), at(16, 11)), [
        task(1),
      ], at: at(16, 10, 7));

      expect(result.span, TimeSpan(at(16, 10, 10), at(16, 11)));
      expect(result.title, '10:10–11:00 · 50분 비어 있어요');
      expect(result.choices.single.minutes, 50);
      // 오늘 시간표의 빈 시간 카드는 지금부터 그린다.
      expect(
        free(
          TimeSpan(at(16, 10, 2), at(16, 11)),
          const [],
          at: at(16, 10, 2),
        ).span,
        TimeSpan(at(16, 10, 5), at(16, 11)),
      );
      expect(
        free(
          TimeSpan(at(16, 10, 5), at(16, 11)),
          const [],
          at: at(16, 10, 5),
        ).span,
        TimeSpan(at(16, 10, 5), at(16, 11)),
      );
    });

    test('빈 시간이 지났으면 시트에 보일 것이 없다', () {
      final gap = TimeSpan(at(16, 9), at(16, 10, 10));

      expect(content(gap, [task(1)], at: at(16, 10, 6)), isNull);
      expect(content(gap, [task(1)], at: at(16, 10, 5))?.span.minutes, 5);
    });

    test('남은 할 일 가운데 그 시각 뒤 마감이거나 마감이 없고 공개된 것만 고른다', () {
      final result = free(gap, [
        task(1),
        task(2, status: TaskStatus.done),
        task(3, status: TaskStatus.hidden),
        task(4, due: at(16, 15)),
        task(5, due: at(16, 15, 1)),
        task(6, noDue: true),
        task(7, kind: TaskKind.video, openAt: at(16, 15, 1)),
        task(8, kind: TaskKind.video, openAt: at(16, 15)),
      ]);

      expect([for (final c in result.choices) c.taskId], [5, 1, 8, 6]);
    });

    test('남은 작업이 없는 할 일은 빼고 예상 시간이 없는 시험은 넣는다', () {
      final result = free(gap, [
        task(1, estimateMin: 60, spentMin: 60),
        task(2, kind: TaskKind.exam),
      ]);

      expect([for (final c in result.choices) c.taskId], [2]);
      expect(result.choices.single.minutes, 90);
    });

    test('급한 순서가 먼저이고 순서에 없으면 마감, 같으면 id 순서로 4개까지다', () {
      final result = free(
        gap,
        [
          task(1, due: at(18, 12)),
          task(2, due: at(17, 12)),
          task(3, noDue: true),
          task(4, due: at(17, 12)),
          task(5, due: at(20, 12)),
          task(6, due: at(21, 12)),
        ],
        ranked: [6, 5],
      );

      expect([for (final c in result.choices) c.taskId], [6, 5, 2, 4]);
    });

    test('마감 순서에서 마감 없는 일은 뒤로 간다', () {
      final result = free(gap, [
        task(1, noDue: true),
        task(2, due: at(19, 12)),
      ]);

      expect([for (final c in result.choices) c.taskId], [2, 1]);
    });

    test('길이는 빈 시간·남은 작업·2시간·마감까지 가운데 가장 짧은 것이다', () {
      final wide = TimeSpan(at(16, 13), at(16, 17));
      int minutes(TaskEntry entry, [TimeSpan? span]) =>
          free(span ?? wide, [entry]).choices.single.minutes;

      expect(minutes(task(1, estimateMin: 45)), 45);
      expect(minutes(task(1, estimateMin: 200)), 120);
      expect(minutes(task(1, estimateMin: 200), gap), 90);
      expect(minutes(task(1, estimateMin: 200, due: at(16, 13, 50))), 50);
      expect(minutes(task(1, kind: TaskKind.exam, noDue: true)), 120);
    });

    test('후보 줄은 종류와 마감이다', () {
      final result = free(gap, [
        task(1),
        task(2, title: '서류 내기', kind: TaskKind.personal, noDue: true),
      ]);

      expect(result.choices.first.sub, '과제 · 내일 23:59 마감');
      expect(result.choices.first.title, '자료구조 과제');
      expect(result.choices.last.sub, '개인 · 마감 없음');
    });

    test('놓은 뒤 토스트는 오늘이 아닐 때만 날짜 말을 쓴다', () {
      expect(
        placedToast(
          '자료구조 과제',
          TimeSpan(at(16, 15), at(16, 16)),
          now: now,
          dayBoundaryMin: boundary,
        ),
        '자료구조 과제를 15:00–16:00에 놓았어요',
      );
      expect(
        placedToast(
          '셸 만들기',
          TimeSpan(at(19, 9), at(19, 10, 30)),
          now: now,
          dayBoundaryMin: boundary,
        ),
        '셸 만들기를 목요일 09:00–10:30에 놓았어요',
      );
    });
  });
}
