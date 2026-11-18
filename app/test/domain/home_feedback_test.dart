// 02 홈 피드백 카드가 보일 것(homeFeedback) 테스트. docs/screens.md '02 홈'의 피드백 카드 표.

import 'package:cnu_ai_assistant/domain/home_feedback.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-16(월) [hour]:[minute].
DateTime at(int hour, [int minute = 0]) => DateTime(2026, 11, 16, hour, minute);

TaskEntry task(int id) => TaskEntry(
  task: Task(
    id: id,
    title: '할 일 $id',
    kind: TaskKind.assignment,
    dueTimeUnknown: false,
    status: TaskStatus.todo,
  ),
);

BlockItem item(
  int id,
  DateTime start,
  DateTime end, {
  PlanBlockStatus status = PlanBlockStatus.confirmed,
  DateTime? answeredAt,
  bool withTask = true,
}) => BlockItem(
  TimeSpan(start, end),
  block: PlanBlock(
    id: id,
    taskId: id,
    startAt: start,
    endAt: end,
    status: status,
    source: BlockSource.manual,
    answeredAt: answeredAt,
  ),
  entry: withTask ? task(id) : null,
);

HomeFeedback feedback(
  List<BlockItem> blocks, {
  required DateTime now,
  List<TimeSpan> free = const [],
  HomeAnswer? answer,
}) => homeFeedback(now: now, blocks: blocks, free: free, answer: answer);

int idOf(BlockItem item) => item.block.id;

void main() {
  test('확정 블록이 없으면 지금 뒤 오늘 남은 빈 시간과 가장 가까운 빈 시간이다', () {
    final free = [
      TimeSpan(at(9), at(9, 20)),
      TimeSpan(at(12, 58), at(13, 24)),
      TimeSpan(at(13, 30), at(13, 55)),
      TimeSpan(at(14), at(16)),
    ];
    final none = feedback(const [], now: at(12, 50), free: free);
    expect(none, isA<FeedbackNone>());
    none as FeedbackNone;
    // 12:58–13:24는 5분 올리면 24분이라 빼고, 13:30–13:55(25분)는 넣는다.
    expect(none.freeMin, 25 + 120);
    expect(none.nearest, TimeSpan(at(13, 30), at(13, 55)));

    // 지금에 걸친 빈 시간은 지금부터 세고, 시작은 5분 단위로 올린다.
    final clipped =
        feedback(const [], now: at(14, 2), free: free) as FeedbackNone;
    expect(clipped.freeMin, 118);
    expect(clipped.nearest, TimeSpan(at(14, 5), at(16)));

    final empty = feedback(const [], now: at(17), free: free) as FeedbackNone;
    expect(empty.freeMin, 0);
    expect(empty.nearest, isNull);
  });

  test('다음 확정 블록과 오늘 남은 확정 블록 수다', () {
    final next = feedback([
      item(2, at(16), at(17)),
      item(1, at(14), at(15)),
    ], now: at(12));
    expect(next, isA<FeedbackNext>());
    next as FeedbackNext;
    expect(idOf(next.block), 1);
    expect(next.left, 2);
  });

  test('지금 하는 블록(시작 포함, 끝 제외)이 다음 블록보다 먼저다', () {
    final blocks = [item(1, at(12), at(13)), item(2, at(14), at(15))];
    final live = feedback(blocks, now: at(12));
    expect(live, isA<FeedbackLive>());
    expect(idOf((live as FeedbackLive).block), 1);
    // 끝난 순간부터는 답을 묻는다.
    expect(feedback(blocks, now: at(13)), isA<FeedbackAsk>());
  });

  test('끝났는데 답하지 않은 블록(놓침 포함)은 가장 늦게 끝난 것을 지금 블록보다 먼저 묻는다', () {
    final blocks = [
      item(1, at(9), at(10)),
      item(2, at(10), at(11), status: PlanBlockStatus.missed),
      item(3, at(11, 30), at(12, 30)),
    ];
    final ask = feedback(blocks, now: at(12));
    expect(ask, isA<FeedbackAsk>());
    expect(idOf((ask as FeedbackAsk).block), 2);

    // 답한 블록은 다시 묻지 않는다.
    final answered = [
      item(1, at(9), at(10), status: PlanBlockStatus.done, answeredAt: at(10)),
      item(
        2,
        at(10),
        at(11),
        status: PlanBlockStatus.missed,
        answeredAt: at(11),
      ),
      item(3, at(11, 30), at(12, 30)),
    ];
    expect(feedback(answered, now: at(12)), isA<FeedbackLive>());
  });

  test('같은 시각에 끝난 블록이 여럿이면 id가 큰 것을 묻는다', () {
    final ask = feedback([
      item(1, at(9), at(10)),
      item(2, at(9, 30), at(10)),
    ], now: at(11));
    expect(idOf((ask as FeedbackAsk).block), 2);
  });

  test('모두 끝냈거나 놓쳤으면 끝낸 수·분과 놓친 수다', () {
    final all = feedback([
      item(1, at(9), at(10), status: PlanBlockStatus.done),
      item(2, at(13), at(13, 30), status: PlanBlockStatus.done),
      item(
        3,
        at(15),
        at(16),
        status: PlanBlockStatus.missed,
        answeredAt: at(16),
      ),
    ], now: at(18));
    expect(all, isA<FeedbackAllDone>());
    all as FeedbackAllDone;
    expect((all.done, all.missed, all.doneMin), (2, 1, 90));
  });

  test('방금 했어요면 기록했어요와 오늘 남은 확정 블록이고, 블록이 완료가 아니면 보지 않는다', () {
    final blocks = [
      item(1, at(10), at(11), status: PlanBlockStatus.done, answeredAt: at(11)),
      item(3, at(16), at(17)),
      item(2, at(14), at(15)),
      // 끝난 확정 블록은 남은 블록이 아니다.
      item(4, at(8), at(9)),
    ];
    final recorded = feedback(
      blocks,
      now: at(11, 5),
      answer: const HomeAnswer(blockId: 1, did: true),
    );
    expect(recorded, isA<FeedbackRecorded>());
    recorded as FeedbackRecorded;
    expect(idOf(recorded.block), 1);
    expect(recorded.left.map(idOf), [2, 3]);

    // 되돌려 확정으로 돌아갔으면 답을 보지 않고 다시 묻는다.
    final undone = [item(1, at(10), at(11)), item(2, at(14), at(15))];
    expect(
      feedback(
        undone,
        now: at(11, 5),
        answer: const HomeAnswer(blockId: 1, did: true),
      ),
      isA<FeedbackAsk>(),
    );
    // 답한 블록이 오늘 목록에 없어도 보지 않는다.
    expect(
      feedback(
        undone,
        now: at(11, 5),
        answer: const HomeAnswer(blockId: 9, did: true),
      ),
      isA<FeedbackAsk>(),
    );
  });

  test('방금 못 했어요면 다시 놓을 자리(없으면 null)이고, 블록이 놓침이 아니면 보지 않는다', () {
    final slot = TimeSpan(at(13), at(14));
    final missed = [
      item(
        1,
        at(10),
        at(11),
        status: PlanBlockStatus.missed,
        answeredAt: at(11),
      ),
    ];
    final retry = feedback(
      missed,
      now: at(11, 5),
      answer: HomeAnswer(blockId: 1, did: false, slot: slot),
    );
    expect(retry, isA<FeedbackRetry>());
    expect((retry as FeedbackRetry).slot, slot);
    expect(idOf(retry.block), 1);
    expect(
      (feedback(
        missed,
        now: at(11, 5),
        answer: const HomeAnswer(blockId: 1, did: false),
      ) as FeedbackRetry).slot,
      isNull,
    );
    // 했어요로 답한 줄 알았는데 놓침이면(다른 곳에서 바뀜) 답을 보지 않는다.
    expect(
      feedback(
        missed,
        now: at(11, 5),
        answer: const HomeAnswer(blockId: 1, did: true),
      ),
      isA<FeedbackAllDone>(),
    );
    expect(
      feedback(
        [item(1, at(10), at(11), status: PlanBlockStatus.done)],
        now: at(11, 5),
        answer: HomeAnswer(blockId: 1, did: false, slot: slot),
      ),
      isA<FeedbackAllDone>(),
    );
  });

  test('제안 블록과 할 일을 찾지 못한 블록은 보지 않는다', () {
    final result = feedback([
      item(1, at(14), at(15), status: PlanBlockStatus.suggested),
      item(2, at(16), at(17), withTask: false),
    ], now: at(12));
    expect(result, isA<FeedbackNone>());
  });
}
