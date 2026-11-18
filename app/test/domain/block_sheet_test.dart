// 근거 시트 내용 테스트. docs/screens.md '근거 시트'.
//
// 지금은 2026-11-16(월) 10:00이고 하루 경계는 04:00이다. 할 일 '자료구조 과제'의 마감은 11/17 23:59다.

import 'package:cnu_ai_assistant/domain/block_sheet.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 11, 16, 10);

DateTime at(int date, int hour, [int minute = 0]) =>
    DateTime(2026, 11, date, hour, minute);

TaskEntry entry({int? partialGoalMin}) => TaskEntry(
  task: Task(
    id: 1,
    title: '자료구조 과제',
    kind: TaskKind.assignment,
    dueAt: at(17, 23, 59),
    dueTimeUnknown: false,
    status: TaskStatus.todo,
    partialGoalMin: partialGoalMin,
  ),
);

PlanBlock block({
  PlanBlockStatus status = PlanBlockStatus.suggested,
  BlockSource source = BlockSource.auto,
  BlockFactor factor = BlockFactor.fit,
  bool reason = true,
  DateTime? start,
  DateTime? end,
}) => PlanBlock(
  id: 7,
  taskId: 1,
  startAt: start ?? at(16, 14),
  endAt: end ?? at(16, 15, 30),
  status: status,
  source: source,
  reason: reason
      ? BlockReason(
          slackMin: 300,
          dueAt: at(17, 23, 59),
          gapMin: 120,
          rank: 2,
          factor: factor,
        )
      : null,
);

BlockSheetContent content(
  PlanBlock block, {
  TaskEntry? task,
  String? courseName = '자료구조',
  DateTime? next,
}) => blockSheetContent(
  block: block,
  entry: task ?? entry(),
  courseName: courseName,
  now: now,
  dayBoundaryMin: 240,
  nextSuggestionAt: next,
);

void main() {
  test('제안은 머리·이름·시각 줄과 엔진의 근거 네 줄, 확정·완료·옮기기·지우기를 보인다', () {
    final result = content(block());

    expect(result.kicker, '제안 · 아직 확정 전');
    expect(result.title, '자료구조 과제');
    expect(result.time, '오늘 14:00–15:30 · 1시간 30분 · 내일 23:59 마감');
    expect(result.manual, isFalse);
    expect(result.reasons, [
      '마감까지 1일 13시간 남았어요',
      '이 자리는 120분 비어 있어요',
      '지금 할 일 가운데 2번째로 급해요',
      '2시간 비어 있어 한 조각을 끝낼 수 있어요',
    ]);
    expect(result.missedText, isNull);
    expect(result.actions, [
      BlockSheetAction.confirm,
      BlockSheetAction.complete,
      BlockSheetAction.move,
      BlockSheetAction.dismiss,
    ]);
  });

  test('고른 이유는 근거의 까닭마다 다르다', () {
    String line(BlockFactor factor, {String? course = '자료구조'}) =>
        content(block(factor: factor), courseName: course).reasons.last;

    expect(line(BlockFactor.nearClass), '자료구조 수업과 가까워 내용이 이어져요');
    expect(line(BlockFactor.nearClass, course: null), '관련 수업과 가까워 내용이 이어져요');
    expect(line(BlockFactor.preferred), '평소 집중하는 시간이에요');
    expect(line(BlockFactor.unsplit), '나누지 않고 한 번에 할 수 있어요');
  });

  test('확정은 완료·옮기기·지우기이고, 부분 목표의 블록이면 머리에 부분을 붙인다', () {
    final confirmed = block(status: PlanBlockStatus.confirmed);
    expect(content(confirmed).kicker, '확정');
    expect(
      content(confirmed, task: entry(partialGoalMin: 60)).kicker,
      '확정 · 부분',
    );
    expect(content(confirmed).actions, [
      BlockSheetAction.complete,
      BlockSheetAction.move,
      BlockSheetAction.dismiss,
    ]);
  });

  test('직접 정한 블록은 근거 대신 직접 정한 시간이라고 쓴다', () {
    final result = content(
      block(
        status: PlanBlockStatus.confirmed,
        source: BlockSource.manual,
        reason: false,
      ),
    );
    expect(result.manual, isTrue);
    expect(result.reasons, isEmpty);

    // 근거가 남아 있어도 직접 정한 블록이면 근거를 보이지 않는다.
    final kept = content(
      block(status: PlanBlockStatus.confirmed, source: BlockSource.manual),
    );
    expect(kept.manual, isTrue);
    expect(kept.reasons, isEmpty);
  });

  test('완료는 완료 취소만 있고, 놓침은 버튼 없이 탓하지 않는 문장과 다음 제안 자리를 보인다', () {
    expect(content(block(status: PlanBlockStatus.done)).kicker, '완료');
    expect(content(block(status: PlanBlockStatus.done)).actions, [
      BlockSheetAction.uncomplete,
    ]);

    final missed = block(
      status: PlanBlockStatus.missed,
      start: at(16, 8),
      end: at(16, 9),
    );
    expect(content(missed).kicker, '놓침');
    expect(content(missed).actions, isEmpty);
    expect(
      content(missed, next: at(17, 13, 30)).missedText,
      '못 했어도 괜찮아요. 내일 13:30에 다시 놓아 뒀어요',
    );
    expect(content(missed).missedText, '못 했어도 괜찮아요. 다음 빈 시간에 다시 놓을게요');
  });

  test('마감이 지났으면 남은 시간 대신 지났다고 쓰고, 자정에 끝나는 블록은 24:00이다', () {
    final late = blockSheetContent(
      block: block(start: at(16, 23), end: at(17, 0)),
      entry: entry(),
      courseName: null,
      now: at(18, 9),
      dayBoundaryMin: 240,
      nextSuggestionAt: null,
    );
    expect(late.reasons.first, '마감이 지났어요');
    expect(late.time, '2일 전 23:00–24:00 · 1시간 · 어제 23:59 마감');
  });
}
