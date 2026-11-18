// 작은 할 일 시트 내용의 테스트. docs/screens.md '할 일 시트'.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-16(월) 10:00.
final now = DateTime(2026, 11, 16, 10);

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

final config = PlannerConfig.from(const []);

TaskEntry lms(
  int id, {
  TaskKind kind = TaskKind.assignment,
  DateTime? due,
  int? estimateMin,
  int? requiredMin,
  TaskStatus status = TaskStatus.todo,
}) {
  final key = 'k$id';
  return TaskEntry(
    task: Task(
      id: id,
      title: '할 일 $id',
      kind: kind,
      dueAt: due,
      dueTimeUnknown: false,
      estimateMin: estimateMin,
      status: status,
      lmsKey: key,
    ),
    lmsItem: LmsItem(
      id: id,
      remoteKey: key,
      courseId: 7,
      courseName: '자료구조',
      title: '할 일 $id',
      kind: LmsItemKind.values.byName(kind.name),
      dueAt: due,
      dueTimeUnknown: false,
      requiredMin: requiredMin,
      firstSeenAt: now,
      lastSeenAt: now,
      missCount: 0,
      contentHash: key,
    ),
  );
}

TaskEntry personal(int id, {int? estimateMin}) => TaskEntry(
  task: Task(
    id: id,
    title: '개인 $id',
    kind: TaskKind.personal,
    dueTimeUnknown: false,
    estimateMin: estimateMin,
    status: TaskStatus.todo,
    source: EntrySource.manual,
  ),
);

PlanBlock block(
  int id,
  int taskId,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
}) => PlanBlock(
  id: id,
  taskId: taskId,
  startAt: start,
  endAt: end,
  status: status,
  source: BlockSource.auto,
);

TaskSheetContent sheet(
  TaskEntry entry, {
  List<PlanBlock> blocks = const [],
  PlannerConfig? rules,
}) => taskSheetContent(
  entry,
  blocks: blocks,
  config: rules ?? config,
  now: now,
  dayBoundaryMin: Defaults.dayBoundaryMin,
);

void main() {
  test('머리·제목·마감과 LMS 할 일 표시', () {
    final content = sheet(lms(1, due: at(17, 23, 59)));
    expect(content.kicker, '자료구조 · 과제');
    expect(content.title, '할 일 1');
    expect(content.due, '내일 23:59 마감');
    expect(content.dueUrgent, isTrue);
    expect(content.lms, isTrue);
    expect(content.remaining, isTrue);
    final mine = sheet(personal(2));
    expect(mine.kicker, '개인');
    expect(mine.due, '마감 없음');
    expect(mine.lms, isFalse);
  });

  test('지난 마감은 붉게 쓰지 않고, 끝낸 일은 남은 일이 아니다', () {
    expect(sheet(lms(1, due: at(16, 9))).dueUrgent, isFalse);
    expect(
      sheet(lms(1, due: at(17, 9), status: TaskStatus.done)).remaining,
      isFalse,
    );
  });

  group('예상 시간', () {
    test('고른 값은 안내가 없고 칩에 그 값이 든다', () {
      final content = sheet(lms(1, estimateMin: 45));
      expect(content.estimate, 45);
      expect(content.estimateNote, isNull);
      expect(content.estimateChoices, [30, 45, 60, 120, 180]);
    });

    test('규칙·기본값이면 그렇다고 알리고, 없으면 고르라고 한다', () {
      final rule = Rule(
        id: 1,
        kind: RuleKind.estimate,
        params: const RuleParams(
          courseId: 7,
          taskKind: TaskKind.assignment,
          minutes: 150,
        ),
        active: true,
        source: EntrySource.manual,
        createdAt: now,
        updatedAt: now,
      );
      final byRule = sheet(lms(1), rules: PlannerConfig.from([rule]));
      expect(byRule.estimate, 150);
      expect(byRule.estimateNote, '내 규칙의 예상 시간이에요');
      // 할 일에 고른 값이 있으면 규칙보다 앞선다.
      final picked = sheet(
        lms(1, estimateMin: 45),
        rules: PlannerConfig.from([rule]),
      );
      expect(picked.estimate, 45);
      expect(picked.estimateNote, isNull);
      final byKind = sheet(lms(1));
      expect(byKind.estimate, 60);
      expect(byKind.estimateNote, '과제 기본 예상 시간이에요. 맞게 골라 주세요');
      expect(byKind.estimateChoices, [30, 60, 120, 180]);
      final none = sheet(lms(1, kind: TaskKind.exam));
      expect(none.estimate, isNull);
      expect(none.estimateNote, '예상 시간을 고르면 빈 시간에 놓아요');
    });

    test('영상은 칩 없이 영상 길이를 보인다', () {
      final content = sheet(lms(1, kind: TaskKind.video, requiredMin: 50));
      expect(content.estimateChoices, isEmpty);
      expect(content.estimate, isNull);
      expect(content.estimateNote, isNull);
      expect(content.video, '출석 인정 50분');
    });
  });

  test('이 할 일의 앞으로의 확정·제안 블록을 시작 순서로 보인다', () {
    final content = sheet(
      lms(1),
      blocks: [
        block(1, 1, at(17, 14), at(17, 15), status: PlanBlockStatus.suggested),
        block(2, 1, at(16, 9, 30), at(16, 11)),
        block(3, 1, at(16, 8), at(16, 9)),
        block(4, 1, at(18, 9), at(18, 10), status: PlanBlockStatus.dismissed),
        block(5, 2, at(17, 9), at(17, 10)),
        block(6, 1, at(16, 22), DateTime(2026, 11, 17)),
      ],
    );
    expect([for (final b in content.blocks) b.block.id], [2, 6, 1]);
    expect(
      [for (final b in content.blocks) b.kind],
      [
        TaskSheetBlockKind.now,
        TaskSheetBlockKind.confirmed,
        TaskSheetBlockKind.suggested,
      ],
    );
    expect(
      [for (final b in content.blocks) b.text],
      ['지금 하는 중 · 11:00까지', '오늘 22:00–24:00 · 확정', '내일 14:00–15:00 · 제안'],
    );
  });
}
