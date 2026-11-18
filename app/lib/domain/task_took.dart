// 03 할 일에서 할 일을 끝낸 뒤의 '얼마나 걸렸어요?'. docs/screens.md '03 할 일', docs/architecture.md '내 규칙'.
//
// 영상이 아닌 할 일을 끝내면 칩으로 걸린 시간을 고른다(건너뛸 수 있음). 과목 할 일이 예상과 30분(임시) 넘게
// 다르면 다음 예상을 바꿀지 묻고, [그렇게 할게요]면 그 과목·종류의 예상 시간 규칙으로 저장한다. 칩 값과 문구는
// 최종 프로토타입(03 할 일의 '걸린 시간 기록' 시트)을 따른다. 화면은 [tookSheetContent]와 [estimateAsk]의 결과를
// 그리기만 한다.

import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 다음 예상을 바꿀지 묻는, 예상과 걸린 시간의 차이(분, 임시). 이보다 크게 다르면 묻는다.
const int tookAskOverMin = 30;

/// 걸린 시간 칩에서 '3시간 이상'의 값(분).
const int tookLongMin = 240;

/// 끝냈을 때 쓰는 말(최종 프로토타입). 영상은 '다 봤어요', LMS 할 일은 '공부 완료', 그 밖은 '완료'다.
String taskDoneWord(Task task) {
  if (task.kind == TaskKind.video) return '다 봤어요';
  return task.lmsKey != null ? '공부 완료' : '완료';
}

/// 끝낸 뒤의 토스트 '{제목} · {끝낸 말}로 옮겼어요'.
String taskDoneToast(Task task) =>
    '${task.title} · ${withJosa(taskDoneWord(task), Josa.euroRo)} 옮겼어요';

/// 걸린 시간의 말('1시간 30분', '3시간 넘게').
String tookText(int minutes) =>
    minutes >= tookLongMin ? '3시간 넘게' : durationText(minutes);

/// 걸린 시간을 적은 뒤의 토스트 '{제목} · {끝낸 말} · {걸린 시간} 걸렸다고 기록했어요'.
String tookToast(Task task, int minutes) =>
    '${task.title} · ${taskDoneWord(task)} · ${tookText(minutes)} 걸렸다고 기록했어요';

/// 걸린 시간 칩 하나.
final class TookChoice {
  const TookChoice(this.minutes, this.label);

  final int minutes;
  final String label;
}

/// '얼마나 걸렸어요?' 시트의 첫 화면.
final class TookSheetContent {
  const TookSheetContent({
    required this.kicker,
    required this.sub,
    required this.choices,
  });

  /// 머리('공부 완료로 옮겼어요').
  final String kicker;

  /// 제목 아래 줄('{제목} · 예상 1시간이었어요. 다음 예상에 써요').
  final String sub;

  final List<TookChoice> choices;
}

/// 다음 예상을 바꿀지 묻는 둘째 화면과 [그렇게 할게요]면 저장할 규칙.
final class EstimateAsk {
  const EstimateAsk({
    required this.kicker,
    required this.title,
    required this.sub,
    required this.ruleSentence,
    required this.params,
    required this.savedToast,
  });

  /// 머리('2시간 걸렸다고 기록했어요').
  final String kicker;

  /// 제목('다음 운영체제 과제는 2시간으로 잡을까요?').
  final String title;

  /// 제목 아래 줄('이번에는 예상 1시간보다 오래 걸렸어요. …').
  final String sub;

  /// 저장할 규칙의 문장('운영체제 과제는 보통 2시간으로 잡아요').
  final String ruleSentence;

  /// 저장할 예상 시간 규칙의 값(과목·종류·분).
  final RuleParams params;

  /// 저장한 뒤의 토스트('다음 운영체제 과제는 2시간으로 잡을게요').
  final String savedToast;
}

/// 걸린 시간을 묻는 할 일인지. 영상은 출석 인정 시간을 쓰므로 묻지 않는다.
bool asksTook(Task task) => task.kind != TaskKind.video;

/// [entry]의 예상 시간(분): 할 일의 값 → 그 과목·종류의 예상 시간 규칙 → 종류별 기본값. 없으면(토론·시험의
/// 기본값 없음, 영상) null이다. 배치 엔진의 남은 작업 시간과 같은 순서다(`remainingWorkMin`).
int? tookEstimate(TaskEntry entry, PlannerConfig config) {
  final task = entry.task;
  if (task.kind == TaskKind.video) return null;
  return task.estimateMin ??
      config.estimateMin(
        courseId: task.courseIdWith(entry.lmsItem),
        kind: task.kind,
      ) ??
      Defaults.estimateMinByKind[task.kind];
}

/// '얼마나 걸렸어요?' 시트의 첫 화면. 과목 할 일은 30분·1시간·2시간·3시간 이상, 개인 할 일은 10분·30분·1시간·
/// 2시간이다(최종 프로토타입).
TookSheetContent tookSheetContent(TaskEntry entry, PlannerConfig config) {
  final task = entry.task;
  final course = _courseName(entry) != null;
  final estimate = tookEstimate(entry, config);
  // 걸린 시간은 과목 할 일만 다음 예상(예상 시간 규칙)에 쓴다.
  final note = course ? '다음 예상에 써요' : '기록만 해 둘게요';
  final minutes = course
      ? const [30, 60, 120, tookLongMin]
      : const [10, 30, 60, 120];
  return TookSheetContent(
    kicker: '${withJosa(taskDoneWord(task), Josa.euroRo)} 옮겼어요',
    sub: estimate == null
        ? '${task.title} · $note'
        : '${task.title} · 예상 ${durationText(estimate)}이었어요. $note',
    choices: [
      for (final value in minutes)
        TookChoice(
          value,
          value >= tookLongMin ? '3시간 이상' : durationText(value),
        ),
    ],
  );
}

/// [minutes]를 골랐을 때 다음 예상을 바꿀지 물을 것. 과목 할 일이고 예상이 있으며 [tookAskOverMin]보다 크게
/// 다를 때만 묻고, 그 밖에는 null이다. 저장할 규칙이 값 검사([validateRule])를 통과하지 못하면 묻지 않는다.
EstimateAsk? estimateAsk(TaskEntry entry, int minutes, PlannerConfig config) {
  final task = entry.task;
  final courseName = _courseName(entry);
  final courseId = task.courseIdWith(entry.lmsItem);
  final estimate = tookEstimate(entry, config);
  if (courseName == null || courseId == null || estimate == null) return null;
  if ((minutes - estimate).abs() <= tookAskOverMin) return null;
  final params = RuleParams(
    courseId: courseId,
    taskKind: task.kind,
    minutes: minutes,
  );
  if (validateRule(RuleKind.estimate, params).isNotEmpty) return null;
  final sentence = rulePreviewSentence(
    RuleKind.estimate,
    params,
    courseName: courseName,
  );
  if (sentence == null) return null;
  final subject = '$courseName ${taskKindText(task.kind)}';
  final next =
      '다음 ${withJosa(subject, Josa.eunNeun)} '
      '${withJosa(durationText(minutes), Josa.euroRo)}';
  return EstimateAsk(
    kicker: '${tookText(minutes)} 걸렸다고 기록했어요',
    title: '$next 잡을까요?',
    sub:
        '이번에는 예상 ${durationText(estimate)}보다 '
        '${minutes > estimate ? '오래 걸렸어요' : '빨리 끝났어요'}. '
        '바꾼 값은 내 규칙에서 언제든 고칠 수 있어요',
    ruleSentence: sentence,
    params: params,
    savedToast: '$next 잡을게요',
  );
}

/// 과목 이름. LMS 할 일은 원본의 과목, 06 AI 비서로 과목을 정해 만든 할 일은 그 과목이다.
String? _courseName(TaskEntry entry) =>
    entry.course?.name ?? entry.lmsItem?.courseName;
