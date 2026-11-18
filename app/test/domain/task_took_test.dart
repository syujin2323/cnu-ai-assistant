// '얼마나 걸렸어요?' 문구와 다음 예상 묻기의 테스트. docs/screens.md '03 할 일'.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/task_took.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 11, 16, 10);

TaskEntry lms(
  String title, {
  TaskKind kind = TaskKind.assignment,
  int? estimateMin,
  String courseName = '자료구조',
  int courseId = 7,
}) {
  const key = 'k';
  return TaskEntry(
    task: Task(
      id: 1,
      title: title,
      kind: kind,
      dueTimeUnknown: false,
      estimateMin: estimateMin,
      status: TaskStatus.done,
      lmsKey: key,
    ),
    lmsItem: LmsItem(
      id: 1,
      remoteKey: key,
      courseId: courseId,
      courseName: courseName,
      title: title,
      kind: LmsItemKind.values.byName(kind.name),
      dueTimeUnknown: false,
      firstSeenAt: _at,
      lastSeenAt: _at,
      missCount: 0,
      contentHash: key,
    ),
  );
}

TaskEntry personal(String title, {Course? course, TaskKind? kind}) => TaskEntry(
  task: Task(
    id: 2,
    title: title,
    kind: kind ?? TaskKind.personal,
    dueTimeUnknown: false,
    status: TaskStatus.done,
    courseId: course?.id,
    source: EntrySource.ai,
  ),
  course: course,
);

final _config = PlannerConfig.from(const []);

Rule _estimateRule(int courseId, TaskKind kind, int minutes) => Rule(
  id: 1,
  kind: RuleKind.estimate,
  params: RuleParams(courseId: courseId, taskKind: kind, minutes: minutes),
  active: true,
  source: EntrySource.manual,
  createdAt: _at,
  updatedAt: _at,
);

void main() {
  test('끝낸 말과 토스트는 영상·LMS·개인에 따라 다르다', () {
    final video = lms('3주차 영상', kind: TaskKind.video);
    expect(taskDoneWord(video.task), '다 봤어요');
    expect(taskDoneToast(video.task), '3주차 영상 · 다 봤어요로 옮겼어요');
    expect(taskDoneToast(lms('셸 만들기').task), '셸 만들기 · 공부 완료로 옮겼어요');
    expect(taskDoneToast(personal('서류 내기').task), '서류 내기 · 완료로 옮겼어요');
    expect(asksTook(video.task), isFalse);
    expect(asksTook(lms('셸 만들기').task), isTrue);
  });

  test('걸린 시간의 말은 3시간 이상이면 3시간 넘게다', () {
    expect(tookText(90), '1시간 30분');
    expect(tookText(tookLongMin), '3시간 넘게');
    expect(tookToast(lms('셸 만들기').task, 60), '셸 만들기 · 공부 완료 · 1시간 걸렸다고 기록했어요');
  });

  test('예상 시간은 할 일의 값, 규칙, 기본값 순서이고 토론·시험·영상은 없다', () {
    expect(tookEstimate(lms('a', estimateMin: 45), _config), 45);
    final config = PlannerConfig.from([
      _estimateRule(7, TaskKind.assignment, 150),
    ]);
    expect(tookEstimate(lms('a'), config), 150);
    expect(tookEstimate(lms('a', courseId: 8), config), 60);
    expect(tookEstimate(lms('a', kind: TaskKind.exam), _config), isNull);
    expect(tookEstimate(lms('a', kind: TaskKind.video), _config), isNull);
  });

  test('과목 할 일은 30분·1시간·2시간·3시간 이상을 고르고 다음 예상에 쓴다', () {
    final content = tookSheetContent(lms('셸 만들기'), _config);
    expect(content.kicker, '공부 완료로 옮겼어요');
    expect(content.sub, '셸 만들기 · 예상 1시간이었어요. 다음 예상에 써요');
    expect([for (final c in content.choices) c.minutes], [30, 60, 120, 240]);
    expect(
      [for (final c in content.choices) c.label],
      ['30분', '1시간', '2시간', '3시간 이상'],
    );
    expect(
      tookSheetContent(lms('중간고사', kind: TaskKind.exam), _config).sub,
      '중간고사 · 다음 예상에 써요',
    );
  });

  test('개인 할 일은 10분·30분·1시간·2시간을 고르고 기록만 한다', () {
    final content = tookSheetContent(personal('서류 내기'), _config);
    expect(content.kicker, '완료로 옮겼어요');
    expect(content.sub, '서류 내기 · 예상 1시간이었어요. 기록만 해 둘게요');
    expect([for (final c in content.choices) c.minutes], [10, 30, 60, 120]);
  });

  group('다음 예상 묻기', () {
    test('과목 할 일이 예상과 30분 넘게 다르면 묻고 저장할 규칙을 준다', () {
      final ask = estimateAsk(lms('셸 만들기'), 120, _config)!;
      expect(ask.kicker, '2시간 걸렸다고 기록했어요');
      expect(ask.title, '다음 자료구조 과제는 2시간으로 잡을까요?');
      expect(ask.sub, '이번에는 예상 1시간보다 오래 걸렸어요. 바꾼 값은 내 규칙에서 언제든 고칠 수 있어요');
      expect(ask.ruleSentence, '자료구조 과제는 보통 2시간으로 잡아요');
      expect(ask.params.courseId, 7);
      expect(ask.params.taskKind, TaskKind.assignment);
      expect(ask.params.minutes, 120);
      expect(ask.savedToast, '다음 자료구조 과제는 2시간으로 잡을게요');
    });

    test('빨리 끝났으면 그렇게 말하고, 3시간 이상은 4시간으로 묻는다', () {
      final team = lms('중간 보고서', kind: TaskKind.team, courseName: '데이터베이스');
      expect(
        estimateAsk(team, 30, _config)!.sub,
        startsWith('이번에는 예상 2시간보다 빨리 끝났어요.'),
      );
      final long = estimateAsk(lms('셸 만들기'), tookLongMin, _config)!;
      expect(long.kicker, '3시간 넘게 걸렸다고 기록했어요');
      expect(long.title, '다음 자료구조 과제는 4시간으로 잡을까요?');
    });

    test('30분까지 다르면 묻지 않는다', () {
      expect(estimateAsk(lms('셸 만들기'), 30, _config), isNull);
      expect(estimateAsk(lms('셸 만들기'), 90, _config), isNull);
      expect(estimateAsk(lms('퀴즈', kind: TaskKind.quiz), 60, _config), isNull);
      expect(
        estimateAsk(lms('퀴즈', kind: TaskKind.quiz), 120, _config),
        isNotNull,
      );
    });

    test('개인 할 일과 예상이 없는 할 일은 묻지 않는다', () {
      expect(estimateAsk(personal('서류 내기'), 120, _config), isNull);
      expect(
        estimateAsk(lms('중간고사', kind: TaskKind.exam), 240, _config),
        isNull,
      );
    });

    test('06 AI 비서로 과목을 정해 만든 할 일은 그 과목으로 묻는다', () {
      const course = Course(id: 3, name: '운영체제');
      final entry = personal('세마포어 정리', course: course, kind: TaskKind.quiz);
      final ask = estimateAsk(entry, 120, _config)!;
      expect(ask.title, '다음 운영체제 퀴즈는 2시간으로 잡을까요?');
      expect(ask.params.courseId, 3);
    });
  });
}
