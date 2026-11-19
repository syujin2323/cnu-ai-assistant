// 직접 추가 폼의 값·처음 값·검사·저장할 값 테스트. docs/screens.md '직접 추가 폼'·'06 AI 비서'.
//
// 지금은 2026-11-19(목) 10:30이고 하루 경계는 04:00이다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/direct_add.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19, 10, 30);
final _today = DateTime(2026, 11, 19);

DirectAddDraft _event({String title = '회의'}) => DirectAddDraft.initial(
  DirectAddKind.event,
  now: _now,
).copyWith(title: title);

void main() {
  group('처음 값', () {
    test('지금 10분 뒤의 다음 30분 칸부터 한 시간이다', () {
      final draft = DirectAddDraft.initial(DirectAddKind.event, now: _now);
      expect(draft.kind, DirectAddKind.event);
      expect(draft.title, '');
      expect(draft.date, _today);
      expect(draft.startMin, 11 * 60);
      expect(draft.endMin, 12 * 60);
      expect(draft.timeUnknown, isFalse);
      expect(draft.weekdays, isEmpty);
      expect(draft.dueDate, isNull);
      expect(draft.dueTimeMin, 23 * 60 + 59);
      expect(draft.reminderMinutes, isNull);
      expect(draft.place, '');
      expect(draft.prep, '');
      // 정확히 30분 칸 20분 전이면 그 칸이다(10분을 띄움).
      expect(
        DirectAddDraft.initial(
          DirectAddKind.event,
          now: DateTime(2026, 11, 19, 10, 20),
        ).startMin,
        10 * 60 + 30,
      );
      expect(
        DirectAddDraft.initial(
          DirectAddKind.event,
          now: DateTime(2026, 11, 19, 10, 21),
        ).startMin,
        11 * 60,
      );
    });

    test('9시 전이면 9시, 22시 안에 끝나지 않으면 내일 9시다', () {
      final early = DirectAddDraft.initial(
        DirectAddKind.task,
        now: DateTime(2026, 11, 19, 7),
      );
      expect(early.date, _today);
      expect(early.startMin, 9 * 60);
      expect(early.kind, DirectAddKind.task);
      // 20:50 → 21:00부터 22:00까지는 오늘 안이다.
      final fits = DirectAddDraft.initial(
        DirectAddKind.event,
        now: DateTime(2026, 11, 19, 20, 50),
      );
      expect(fits.date, _today);
      expect(fits.startMin, 21 * 60);
      expect(fits.endMin, 22 * 60);
      final late = DirectAddDraft.initial(
        DirectAddKind.event,
        now: DateTime(2026, 11, 19, 20, 51),
      );
      expect(late.date, DateTime(2026, 11, 20));
      expect(late.startMin, 9 * 60);
      expect(late.endMin, 10 * 60);
    });

    test('받은 날짜·시각이 있으면 그 시각부터 한 시간이고 시작 범위로 줄인다', () {
      final at = DirectAddDraft.initial(
        DirectAddKind.event,
        now: _now,
        at: DateTime(2026, 11, 22, 14, 10),
      );
      expect(at.date, DateTime(2026, 11, 22));
      expect(at.startMin, 14 * 60 + 10);
      expect(at.endMin, 15 * 60 + 10);
      final night = DirectAddDraft.initial(
        DirectAddKind.event,
        now: _now,
        at: DateTime(2026, 11, 22, 3),
      );
      expect(night.startMin, DirectAddLimits.startLow);
      final midnight = DirectAddDraft.initial(
        DirectAddKind.event,
        now: _now,
        at: DateTime(2026, 11, 22, 23, 50),
      );
      expect(midnight.startMin, DirectAddLimits.startHigh);
    });
  });

  group('카드에서', () {
    test('한 번뿐인 일정 카드의 값을 채운다', () {
      final draft = DirectAddDraft.fromEvent(
        EventDraft(
          title: '회의',
          date: DateTime(2026, 11, 20),
          startMin: 15 * 60,
          endMin: 16 * 60,
          place: '공대 2호관',
          prep: '노트북',
          reminderMinutes: 30,
        ),
        now: _now,
      );
      expect(draft.kind, DirectAddKind.event);
      expect(draft.title, '회의');
      expect(draft.date, DateTime(2026, 11, 20));
      expect(draft.startMin, 15 * 60);
      expect(draft.endMin, 16 * 60);
      expect(draft.timeUnknown, isFalse);
      expect(draft.place, '공대 2호관');
      expect(draft.prep, '노트북');
      expect(draft.reminderMinutes, 30);
    });

    test('시간 미정 카드는 시간 미정이고 시간 칸은 새 폼의 처음 값이다', () {
      final draft = DirectAddDraft.fromEvent(
        EventDraft(title: '병원', date: DateTime(2026, 11, 20)),
        now: _now,
      );
      expect(draft.timeUnknown, isTrue);
      expect(draft.startMin, 11 * 60);
      expect(draft.endMin, 12 * 60);
      expect(draft.place, '');
    });

    test('반복 일정 카드는 요일·시간·종류를 채운다', () {
      final draft = DirectAddDraft.fromEvent(
        const EventDraft(
          title: '헬스',
          weekdays: [1, 3],
          startMin: 19 * 60,
          endMin: 20 * 60 + 30,
          fixedKind: FixedBlockKind.exercise,
        ),
        now: _now,
      );
      expect(draft.kind, DirectAddKind.repeating);
      expect(draft.weekdays, {1, 3});
      expect(draft.startMin, 19 * 60);
      expect(draft.endMin, 20 * 60 + 30);
      expect(draft.timeUnknown, isFalse);
      expect(draft.fixedKind, FixedBlockKind.exercise);
      expect(draft.date, _today);
    });

    test('할 일 카드의 과목·종류·마감·예상 시간을 그대로 둔다', () {
      final draft = DirectAddDraft.fromTask(
        TaskDraft(
          title: '보고서',
          courseName: '공학설계',
          kind: TaskKind.quiz,
          dueDate: DateTime(2026, 11, 21),
          dueTimeMin: 18 * 60,
          saidEstimateMin: 90,
          pickedEstimateMin: 120,
        ),
        now: _now,
      );
      expect(draft.kind, DirectAddKind.task);
      expect(draft.courseName, '공학설계');
      expect(draft.taskKind, TaskKind.quiz);
      expect(draft.dueDate, DateTime(2026, 11, 21));
      expect(draft.dueTimeMin, 18 * 60);
      expect(draft.saidEstimateMin, 90);
      expect(draft.pickedEstimateMin, 120);
      // 시각을 말하지 않은 마감은 23:59다.
      expect(
        DirectAddDraft.fromTask(
          TaskDraft(
            title: '보고서',
            kind: TaskKind.personal,
            dueDate: DateTime(2026, 11, 21),
          ),
          now: _now,
        ).dueTimeMin,
        23 * 60 + 59,
      );
    });
  });

  group('저장할 값', () {
    test('일정은 제목을 다듬고 빈 장소·준비물을 비우며 알림을 둔다', () {
      final event = _event(title: '  회의 ')
          .copyWith(
            place: '  ',
            prep: ' 노트북 ',
            reminderMinutes: () => 10,
            weekdays: {2},
            fixedKind: () => FixedBlockKind.work,
          )
          .toEventDraft();
      expect(event.title, '회의');
      expect(event.date, _today);
      expect(event.weekdays, isNull);
      expect(event.startMin, 11 * 60);
      expect(event.endMin, 12 * 60);
      expect(event.place, isNull);
      expect(event.prep, '노트북');
      expect(event.reminderMinutes, 10);
      expect(event.fixedKind, isNull);
    });

    test('시간 미정 일정은 시각과 알림을 두지 않는다', () {
      final event = _event()
          .copyWith(timeUnknown: true, reminderMinutes: () => 10)
          .toEventDraft();
      expect(event.startMin, isNull);
      expect(event.endMin, isNull);
      expect(event.timeUnknown, isTrue);
      expect(event.reminderMinutes, isNull);
    });

    test('반복 일정은 요일을 정렬하고 종류를 짐작하며 알림을 두지 않는다', () {
      final repeating = _event(title: '편의점 알바')
          .copyWith(
            kind: DirectAddKind.repeating,
            weekdays: {7, 6},
            timeUnknown: true,
            reminderMinutes: () => 10,
          )
          .toEventDraft();
      expect(repeating.date, isNull);
      expect(repeating.weekdays, [6, 7]);
      // 반복 일정에는 시간 미정이 없다.
      expect(repeating.startMin, 11 * 60);
      expect(repeating.fixedKind, FixedBlockKind.work);
      expect(repeating.reminderMinutes, isNull);
      // 카드에서 온 종류는 그대로다.
      expect(
        _event(title: '편의점 알바')
            .copyWith(
              kind: DirectAddKind.repeating,
              weekdays: {1},
              fixedKind: () => FixedBlockKind.other,
            )
            .toEventDraft()
            .fixedKind,
        FixedBlockKind.other,
      );
    });

    test('할 일은 과목이 없으면 개인 할 일이고 마감 시각을 정해 둔다', () {
      final personal = _event(title: ' 책 반납 ')
          .copyWith(
            kind: DirectAddKind.task,
            dueDate: () => DateTime(2026, 11, 21),
            dueTimeMin: 18 * 60,
          )
          .toTaskDraft();
      expect(personal.title, '책 반납');
      expect(personal.kind, TaskKind.personal);
      expect(personal.courseName, isNull);
      expect(personal.dueAt, DateTime(2026, 11, 21, 18));
      expect(personal.dueTimeUnknown, isFalse);
      expect(personal.estimateToStore, isNull);
      final course = _event()
          .copyWith(
            kind: DirectAddKind.task,
            courseName: () => '공학설계',
            pickedEstimateMin: () => 30,
          )
          .toTaskDraft();
      expect(course.kind, TaskKind.assignment);
      expect(course.dueAt, isNull);
      expect(course.dueTimeMin, isNull);
      expect(course.estimateToStore, 30);
      expect(
        _event()
            .copyWith(
              kind: DirectAddKind.task,
              courseName: () => '공학설계',
              taskKind: () => TaskKind.team,
            )
            .toTaskDraft()
            .kind,
        TaskKind.team,
      );
    });

    test('copyWith는 함수로 넘긴 값을 비울 수 있다', () {
      final filled = _event().copyWith(
        dueDate: () => _today,
        reminderMinutes: () => 10,
        courseName: () => '공학설계',
        taskKind: () => TaskKind.quiz,
        saidEstimateMin: () => 60,
        pickedEstimateMin: () => 30,
        fixedKind: () => FixedBlockKind.work,
      );
      final cleared = filled.copyWith(
        dueDate: () => null,
        reminderMinutes: () => null,
        courseName: () => null,
        taskKind: () => null,
        saidEstimateMin: () => null,
        pickedEstimateMin: () => null,
        fixedKind: () => null,
      );
      expect(cleared.dueDate, isNull);
      expect(cleared.reminderMinutes, isNull);
      expect(cleared.courseName, isNull);
      expect(cleared.taskKind, isNull);
      expect(cleared.saidEstimateMin, isNull);
      expect(cleared.pickedEstimateMin, isNull);
      expect(cleared.fixedKind, isNull);
      // 넘기지 않은 값은 그대로다.
      final same = filled.copyWith();
      expect(same.dueDate, _today);
      expect(same.reminderMinutes, 10);
      expect(same.courseName, '공학설계');
      expect(same.taskKind, TaskKind.quiz);
      expect(same.saidEstimateMin, 60);
      expect(same.pickedEstimateMin, 30);
      expect(same.fixedKind, FixedBlockKind.work);
      expect(same.toString(), isNot(contains('회의')));
    });
  });

  group('검사', () {
    test('제목이 비면 저장하지 않는다', () {
      expect(
        directAddIssue(_event(title: '  '), now: _now),
        DirectAddIssue.title,
      );
      expect(directAddIssue(_event(), now: _now), isNull);
      expect(directAddIssueText(DirectAddIssue.title), '제목을 넣어 주세요');
    });

    test('반복 일정은 요일이 하나 이상 있어야 한다', () {
      final repeating = _event().copyWith(kind: DirectAddKind.repeating);
      expect(directAddIssue(repeating, now: _now), DirectAddIssue.weekdays);
      expect(
        directAddIssue(repeating.copyWith(weekdays: {3}), now: _now),
        isNull,
      );
      // 반복 일정이 아니면 요일을 보지 않는다.
      expect(directAddIssue(_event(), now: _now), isNull);
      expect(
        directAddIssueText(DirectAddIssue.weekdays),
        '반복할 요일을 하나 이상 골라 주세요',
      );
    });

    test('마감이 지금이거나 지났으면 저장하지 않는다', () {
      final task = _event().copyWith(
        kind: DirectAddKind.task,
        dueDate: () => _today,
      );
      expect(
        directAddIssue(task.copyWith(dueTimeMin: 10 * 60 + 30), now: _now),
        DirectAddIssue.pastDue,
      );
      expect(
        directAddIssue(task.copyWith(dueTimeMin: 10 * 60 + 31), now: _now),
        isNull,
      );
      // 마감이 없거나 할 일이 아니면 보지 않는다.
      expect(
        directAddIssue(task.copyWith(dueDate: () => null), now: _now),
        isNull,
      );
      expect(
        directAddIssue(
          _event().copyWith(dueDate: () => _today, dueTimeMin: 0),
          now: _now,
        ),
        isNull,
      );
      expect(
        directAddIssueText(DirectAddIssue.pastDue),
        '마감 시각이 이미 지났어요. 시각이나 날짜를 바꿔 주세요',
      );
    });

    test('오늘 이미 끝난 일정은 알리기만 한다', () {
      final ended = _event().copyWith(startMin: 9 * 60, endMin: 10 * 60 + 30);
      expect(
        directAddPastNote(ended, now: _now),
        '오늘 09:00–10:30은 이미 지났어요 · 그대로 넣으면 지난 일정으로 보여요',
      );
      expect(directAddIssue(ended, now: _now), isNull);
      expect(
        directAddPastNote(ended.copyWith(endMin: 10 * 60 + 31), now: _now),
        isNull,
      );
      expect(
        directAddPastNote(ended.copyWith(timeUnknown: true), now: _now),
        isNull,
      );
      expect(
        directAddPastNote(
          ended.copyWith(date: DateTime(2026, 11, 18)),
          now: _now,
        ),
        isNull,
      );
      expect(
        directAddPastNote(
          ended.copyWith(kind: DirectAddKind.repeating, weekdays: {4}),
          now: _now,
        ),
        isNull,
      );
    });
  });

  test('반복 일정의 종류를 제목으로 짐작한다', () {
    expect(guessFixedKind('편의점 알바'), FixedBlockKind.work);
    expect(guessFixedKind('카페 아르바이트'), FixedBlockKind.work);
    expect(guessFixedKind('수학 과외'), FixedBlockKind.work);
    expect(guessFixedKind('주말 근무'), FixedBlockKind.work);
    expect(guessFixedKind('헬스'), FixedBlockKind.exercise);
    expect(guessFixedKind('아침 운동'), FixedBlockKind.exercise);
    expect(guessFixedKind('수영'), FixedBlockKind.exercise);
    expect(guessFixedKind('필라테스'), FixedBlockKind.exercise);
    expect(guessFixedKind('요가'), FixedBlockKind.exercise);
    expect(guessFixedKind('클라이밍'), FixedBlockKind.exercise);
    expect(guessFixedKind('러닝 크루'), FixedBlockKind.exercise);
    expect(guessFixedKind('동아리'), FixedBlockKind.other);
  });

  test('날짜 칩은 오늘부터 14일이고, 그 밖의 날은 날짜 순서로 더한다', () {
    final days = directAddDays(_today);
    expect(days, hasLength(14));
    expect(days.first, _today);
    expect(days.last, DateTime(2026, 12, 2));
    expect(directAddDays(_today, include: DateTime(2026, 11, 25)), days);
    final far = directAddDays(_today, include: DateTime(2026, 12, 10, 15));
    expect(far, hasLength(15));
    expect(far.last, DateTime(2026, 12, 10));
    final past = directAddDays(_today, include: DateTime(2026, 11, 18));
    expect(past.first, DateTime(2026, 11, 18));
  });

  test('마감 시각 칸은 06:00–23:30을 30분마다, 끝은 23:59이다', () {
    expect(dueTimeChoices.first, 6 * 60);
    expect(dueTimeChoices[1], 6 * 60 + 30);
    expect(dueTimeChoices[dueTimeChoices.length - 2], 23 * 60 + 30);
    expect(dueTimeChoices.last, 23 * 60 + 59);
    expect(dueTimeChoices, hasLength(37));
    expect(stepDueTime(23 * 60 + 59, later: false), 23 * 60 + 30);
    expect(stepDueTime(23 * 60 + 30, later: true), 23 * 60 + 59);
    expect(stepDueTime(23 * 60 + 59, later: true), isNull);
    expect(stepDueTime(6 * 60, later: false), isNull);
    expect(stepDueTime(6 * 60, later: true), 6 * 60 + 30);
    // 칸에 없는 값은 앞뒤 칸으로 간다.
    expect(stepDueTime(18 * 60 + 15, later: true), 18 * 60 + 30);
    expect(stepDueTime(18 * 60 + 15, later: false), 18 * 60);
    expect(stepDueTime(5 * 60, later: true), 6 * 60);
  });

  group('할 일이 놓일 자리', () {
    final due = TaskDraft(
      title: '보고서',
      kind: TaskKind.personal,
      dueDate: DateTime(2026, 11, 21),
      dueTimeMin: 18 * 60,
    );

    ({String text, bool alert})? preview(
      TaskDraft draft, {
      int? estimate = 60,
      PlanResult? plan,
      bool hasTimetable = true,
    }) => taskPreview(
      draft: draft,
      taskId: -1,
      estimate: estimate,
      plan: plan,
      hasTimetable: hasTimetable,
      now: _now,
      dayBoundaryMin: 240,
    );

    BlockDraft block(DateTime start, int minutes, {int taskId = -1}) =>
        BlockDraft(
          taskId: taskId,
          startAt: start,
          endAt: start.add(Duration(minutes: minutes)),
        );

    test('배치 엔진 없이 정해지는 것', () {
      expect(preview(const TaskDraft(title: '보고서', kind: TaskKind.personal)), (
        text: '마감이 없어 자동으로 놓지 않아요',
        alert: false,
      ));
      expect(
        preview(
          TaskDraft(
            title: '보고서',
            kind: TaskKind.personal,
            dueDate: _today,
            dueTimeMin: 10 * 60 + 30,
          ),
        ),
        (text: '마감 시각이 지나 계획에 놓지 않아요', alert: true),
      );
      expect(preview(due, estimate: null), (
        text: '예상 시간을 몰라 자동으로 놓지 않아요',
        alert: false,
      ));
      expect(preview(due, hasTimetable: false), (
        text: '시간표가 없어 아직 자동으로 놓지 않아요',
        alert: false,
      ));
      // 그 밖에는 배치 결과가 있어야 답한다.
      expect(preview(due), isNull);
    });

    test('놓인 첫 블록을 알리고, 여럿이면 나눈다고 적는다', () {
      final one = PlanResult(
        blocks: [
          block(DateTime(2026, 11, 20, 15), 60),
          block(DateTime(2026, 11, 19, 14), 60, taskId: 3),
        ],
        shortages: const [],
        ranked: const [],
      );
      expect(preview(due, plan: one), (
        text: '넣으면 내일 15:00–16:00에 제안으로 놓아요',
        alert: false,
      ));
      final two = PlanResult(
        blocks: [
          block(DateTime(2026, 11, 20, 15), 60),
          block(DateTime(2026, 11, 19, 14), 30),
        ],
        shortages: const [],
        ranked: const [],
      );
      expect(preview(due, plan: two), (
        text: '넣으면 오늘 14:00–14:30에 제안으로 놓아요 · 2번에 나눠요',
        alert: false,
      ));
    });

    test('모자라면 모자란 시간을, 멀면 배치 지평을, 그 밖에는 못 찾았다고 적는다', () {
      final short = PlanResult(
        blocks: const [],
        shortages: [
          Shortage(taskId: 3, missingMin: 10, dueAt: DateTime(2026, 11, 21)),
          Shortage(taskId: -1, missingMin: 90, dueAt: DateTime(2026, 11, 21)),
        ],
        ranked: const [],
      );
      expect(preview(due, plan: short), (
        text: '마감 전 빈 시간이 1시간 30분 모자라요 · 넣은 뒤 홈에서 방법을 골라 주세요',
        alert: true,
      ));
      final far = TaskDraft(
        title: '보고서',
        kind: TaskKind.personal,
        dueDate: DateTime(2026, 12, 10),
      );
      expect(preview(far, plan: PlanResult.empty), (
        text: '마감 14일 전부터 빈 시간에 놓아요',
        alert: false,
      ));
      expect(preview(due, plan: PlanResult.empty), (
        text: '마감 전에 놓을 빈 시간을 아직 찾지 못했어요',
        alert: false,
      ));
    });
  });
}
