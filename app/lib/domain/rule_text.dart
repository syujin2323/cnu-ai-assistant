// 내 규칙의 이름·짧은 값·문장. docs/architecture.md '내 규칙', docs/screens.md '12 내 규칙'·'06 AI 비서'.
//
// 12 내 규칙의 카드(이름·짧은 값)와 폼 미리 보기, 06 AI 비서의 내 규칙 미리보기·제안 확인·되묻기가 쓰는 순수
// 함수다. 시각은 `domain/text/time_text.dart`(문장 속 시각 [clockText], 짧은 값의 [timeRangeText]·[hhmmText]),
// 길이는 [durationText], 조사는 [withJosa]로 쓴다. 자정을 넘는 구간은 끝에 '다음 날'을 붙이고, 정확히 자정에
// 끝나면 '밤 12시'다(docs/decisions.md 2026-11-14 '자정 마감은 전날 24:00, 새벽 마감은 달력 날짜로 쓴다').
// 값은 [validateRule]을 통과한 것을 넘기고, 필요한 값이 없거나 읽지 못한 값이면 null을 돌려준다. 말투는 차분한
// 존댓말이고 숫자·시각을 먼저 말한다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 알림 재설계 전에 저장하지 않는 값([unsavableFields])이나 정해진 종류에 없는 조건을 받았을 때의 답.
const String unsavableRuleText = '아직 그런 조건은 정할 수 없어요';

/// 규칙 종류의 이름(docs/screens.md '12 내 규칙' 표).
String ruleKindName(RuleKind kind) => switch (kind) {
  RuleKind.travel => '이동 시간',
  RuleKind.classBuffer => '수업 앞뒤 여유',
  RuleKind.workWindow => '공부 가능한 시간대',
  RuleKind.blackout => '피할 시간',
  RuleKind.preferred => '선호 시간대',
  RuleKind.maxBlock => '한 번에 할 최대 시간',
  RuleKind.dailyCap => '하루 최대 공부량',
  RuleKind.meal => '식사',
  RuleKind.estimate => '예상 시간',
  RuleKind.notify => '알림',
};

/// 12 내 규칙 카드의 짧은 값('30분 · 매 수업 앞뒤', '09:00–23:00', '17:30–19:30 · 40분', '과제 · 1시간 30분',
/// '08:00'). 요일을 고른 규칙은 앞에 '월·수 · '를 붙인다. 예상 시간의 과목 이름은 [courseName]이다(없으면
/// '과목'). 자정을 넘는 구간은 [timeRangeText]대로 끝의 실제 시각을 쓴다('22:00–02:00').
String? ruleShortValue(
  RuleKind kind,
  RuleParams params, {
  List<int>? weekdays,
  String? courseName,
}) {
  if (params is UnreadableRuleParams) return null;
  final minutes = params.minutes;
  final position = params.position;
  final range = _rangeOf(params);
  final briefingMin = params.briefingMin;
  final subject = _estimateSubject(params, courseName);
  final value = switch (kind) {
    RuleKind.travel when minutes != null && position != null =>
      '${durationText(minutes)} · ${_positionShort(position)}',
    RuleKind.classBuffer ||
    RuleKind.maxBlock ||
    RuleKind.dailyCap when minutes != null => durationText(minutes),
    RuleKind.workWindow || RuleKind.blackout || RuleKind.preferred
        when range != null =>
      timeRangeText(range.startMin, range.endMin),
    RuleKind.meal when range != null && minutes != null =>
      '${timeRangeText(range.startMin, range.endMin)} · ${durationText(minutes)}',
    RuleKind.estimate when subject != null && minutes != null =>
      '$subject · ${durationText(minutes)}',
    RuleKind.notify when briefingMin != null => hhmmText(briefingMin),
    _ => null,
  };
  if (value == null) return null;
  return weekdays == null ? value : '${_weekdaysShort(weekdays)} · $value';
}

/// 규칙 문장(12 폼 미리 보기, 06 AI 비서의 내 규칙 미리보기). 예: '대면 수업마다 앞뒤로 40분씩 비워요',
/// '월·수요일에는 오후 9시부터 오후 11시까지는 할 일을 놓지 않아요', '데이터구조 과제는 보통 3시간으로 잡아요'.
/// 자정을 넘는 끝은 '다음 날'을 붙인다('오후 10시부터 다음 날 오전 2시까지').
String? rulePreviewSentence(
  RuleKind kind,
  RuleParams params, {
  List<int>? weekdays,
  String? courseName,
}) {
  if (params is UnreadableRuleParams) return null;
  final on = _weekdaysOn(weekdays);
  final minutes = params.minutes;
  final position = params.position;
  final range = _rangeOf(params);
  final briefingMin = params.briefingMin;
  final subject = _estimateSubject(params, courseName);
  return switch (kind) {
    RuleKind.travel when minutes != null && position != null =>
      switch (position) {
        TravelPosition.everyClass =>
          '$on대면 수업마다 앞뒤로 ${durationText(minutes)}씩 비워요',
        TravelPosition.dayEdges =>
          '$on하루 첫 대면 수업 전과 마지막 대면 수업 뒤에 ${durationText(minutes)}씩 비워요',
      },
    RuleKind.classBuffer when minutes != null =>
      '수업마다 앞뒤로 ${durationText(minutes)}씩 비워요. 실시간 온라인 수업은 비우지 않아요',
    RuleKind.workWindow when range != null => '$on${_fromTo(range)}만 할 일을 놓아요',
    RuleKind.blackout when range != null => '$on${_fromTo(range)}는 할 일을 놓지 않아요',
    RuleKind.preferred when range != null =>
      '$on${_fromUntil(range)} 사이에 되도록 할 일을 놓아요',
    RuleKind.maxBlock when minutes != null =>
      '할 일은 한 번에 ${durationText(minutes)}까지만 놓아요',
    RuleKind.dailyCap when minutes != null =>
      '$on하루에 ${durationText(minutes)}까지만 할 일을 놓아요',
    RuleKind.meal when range != null && minutes != null => _mealSentence(
      range,
      minutes,
    ),
    RuleKind.estimate when subject != null && minutes != null =>
      '${withJosa(subject, Josa.eunNeun)} 보통 '
          '${withJosa(durationText(minutes), Josa.euroRo)} 잡아요',
    RuleKind.notify when briefingMin != null =>
      '아침 브리핑을 ${clockText(briefingMin)}에 보여 줘요',
    _ => null,
  };
}

/// 규칙을 고칠 때의 문장('수업 앞뒤 여유를 10분에서 15분으로 바꿔요'). 고치기 전과 뒤의 짧은 값([ruleShortValue])
/// 으로 견주고, 짧은 값이 같거나 어느 한쪽을 쓸 수 없으면 null이다.
String? ruleChangeSentence(
  RuleKind kind, {
  required RuleParams before,
  required RuleParams after,
  List<int>? beforeWeekdays,
  List<int>? afterWeekdays,
  String? courseName,
}) {
  final from = ruleShortValue(
    kind,
    before,
    weekdays: beforeWeekdays,
    courseName: courseName,
  );
  final to = ruleShortValue(
    kind,
    after,
    weekdays: afterWeekdays,
    courseName: courseName,
  );
  if (from == null || to == null || from == to) return null;
  return '${withJosa(ruleKindName(kind), Josa.eulReul)} $from에서 '
      '${withJosa(to, Josa.euroRo)} 바꿔요';
}

/// 저장하면 함께 끄는 이전 규칙을 알리는 문장('같은 자리의 이전 규칙 1개는 꺼요'). [count]가 0 이하면 null이다.
String? ruleTurnOffSentence(int count) =>
    count <= 0 ? null : '같은 자리의 이전 규칙 $count개는 꺼요';

/// 채우기([completeRule])가 제안한 값이 맞는지 묻는 문장(docs/decisions.md 2026-11-14 '말로 정한 규칙의 빈
/// 값은 가장 그럴듯한 값을 제안해 확인받는다'). 제안한 값이 없으면 null이다.
/// 예: '오전 8시부터 오후 11시까지만 할 일을 놓을까요?', '오후 12시부터 오후 1시까지 모두 식사 시간으로 비울까요?'
String? ruleProposalQuestion(
  RuleKind kind,
  RuleCompletion completion, {
  List<int>? weekdays,
}) {
  if (completion.proposed.isEmpty) return null;
  final range = _rangeOf(completion.params);
  return switch (kind) {
    RuleKind.workWindow when range != null =>
      '${_weekdaysOn(weekdays)}${_fromTo(range)}만 할 일을 놓을까요?',
    RuleKind.meal when range != null => '${_fromTo(range)} 모두 식사 시간으로 비울까요?',
    _ => null,
  };
}

/// 값 검사([validateRule])에 걸린 값을 되묻는 문장(06 AI 비서 되묻기, 12 폼 안내). 지금 저장하지 않는
/// 종류([ruleKindSavable], 알림)는 되묻지 않고 [unsavableRuleText]다(읽을 수 없는 규칙은 빼고).
String ruleIssueQuestion(RuleKind kind, RuleIssue issue) {
  final field = issue.field;
  return switch (issue.kind) {
    RuleIssueKind.unreadable => '저장된 값을 읽을 수 없는 규칙이에요. 지우고 다시 정해 주세요',
    _ when !ruleKindSavable(kind) => unsavableRuleText,
    RuleIssueKind.missing when field == 'position' =>
      '매 수업 앞뒤인가요, 하루 첫 수업 전과 마지막 수업 뒤인가요?',
    RuleIssueKind.missing when field == 'minutes' => _minutesQuestion(kind),
    RuleIssueKind.missing => _rangeQuestion(kind),
    RuleIssueKind.missingOneOf => '어느 과목이나 종류의 할 일인가요?',
    RuleIssueKind.notAllowed when field == 'weekdays' =>
      '${withJosa(ruleKindName(kind), Josa.eunNeun)} 요일을 나눠 정할 수 없어요',
    RuleIssueKind.notAllowed when field == 'taskKind' =>
      '영상과 자료에는 예상 시간을 정할 수 없어요',
    RuleIssueKind.notAllowed when field == 'courseId' =>
      '개인 할 일에는 과목을 정할 수 없어요',
    RuleIssueKind.notAllowed => unsavableRuleText,
    RuleIssueKind.outOfRange when field == 'minutes' => _minutesRangeQuestion(
      kind,
    ),
    RuleIssueKind.outOfRange when field == 'weekdays' => '요일을 다시 골라 주세요',
    RuleIssueKind.outOfRange =>
      '${withJosa(ruleKindName(kind), Josa.eulReul)} 다시 정해 주세요',
    RuleIssueKind.badOrder =>
      '끝 시각이 시작 시각과 같거나 하루를 넘어요. ${_rangeQuestion(kind)}',
  };
}

/// 시작과 끝. 둘 중 하나라도 없으면 null.
MinuteRange? _rangeOf(RuleParams params) {
  final start = params.startMin;
  final end = params.endMin;
  return start == null || end == null ? null : MinuteRange(start, end);
}

/// 예상 시간 규칙의 대상('데이터구조 과제', '데이터구조', '과제'). 과목도 종류도 없으면 null.
String? _estimateSubject(RuleParams params, String? courseName) {
  final course = params.courseId == null ? null : (courseName ?? '과목');
  final taskKind = params.taskKind;
  final kind = taskKind == null ? null : taskKindText(taskKind);
  if (course == null && kind == null) return null;
  return [?course, ?kind].join(' ');
}

String _positionShort(TravelPosition position) => switch (position) {
  TravelPosition.everyClass => '매 수업 앞뒤',
  TravelPosition.dayEdges => '첫 수업 전·마지막 수업 뒤',
};

/// '월·수'(요일 순서).
String _weekdaysShort(List<int> weekdays) =>
    ([...weekdays]..sort()).map(weekdayText).join('·');

/// 요일을 고른 규칙의 문장 머리 '월·수요일에는 '. 매일이면 빈 글자.
String _weekdaysOn(List<int>? weekdays) =>
    weekdays == null ? '' : '${_weekdaysShort(weekdays)}요일에는 ';

/// '오후 9시부터 오후 11시까지'. 자정을 넘는 끝은 '다음 날'을 붙인다.
String _fromTo(MinuteRange range) => '${_fromUntil(range)}까지';

/// '오후 9시부터 오후 11시'(뒤에 '까지'나 '사이'를 붙인다).
String _fromUntil(MinuteRange range) {
  final end = range.endMin > _minutesPerDay
      ? '다음 날 ${clockText(range.endMin)}'
      : clockText(range.endMin);
  return '${clockText(range.startMin)}부터 $end';
}

String _mealSentence(MinuteRange range, int minutes) {
  if (minutes == 0) {
    return '${_fromUntil(range)} 사이에는 식사 시간을 비우지 않아요';
  }
  if (minutes == range.minutes) return '${_fromTo(range)} 식사 시간으로 비워요';
  return '${_fromUntil(range)} 사이에 식사 시간 '
      '${withJosa(durationText(minutes), Josa.eulReul)} 비워요';
}

String _rangeQuestion(RuleKind kind) => switch (kind) {
  RuleKind.workWindow => '몇 시부터 몇 시까지 공부할 수 있나요?',
  RuleKind.blackout => '몇 시부터 몇 시까지 비울까요?',
  RuleKind.preferred => '몇 시부터 몇 시 사이가 좋나요?',
  RuleKind.meal => '몇 시부터 몇 시 사이에 먹나요?',
  _ => '몇 시부터 몇 시까지인가요?',
};

String _minutesQuestion(RuleKind kind) => switch (kind) {
  RuleKind.travel => '이동 시간은 몇 분인가요?',
  RuleKind.classBuffer => '수업 앞뒤로 몇 분씩 비울까요?',
  RuleKind.maxBlock => '한 번에 얼마나 할까요?',
  RuleKind.dailyCap => '하루에 얼마나 공부할까요?',
  RuleKind.meal => '식사 시간은 몇 분인가요?',
  RuleKind.estimate => '보통 얼마나 걸리나요?',
  _ => '${withJosa(ruleKindName(kind), Josa.eulReul)} 다시 정해 주세요',
};

String _minutesRangeQuestion(RuleKind kind) {
  final (:low, :high) = RuleLimits.minutesOf(kind);
  final range = '${durationText(low)}부터 ${durationText(high)} 사이';
  return kind == RuleKind.meal
      ? '식사 시간은 $range로, 시간대보다 길지 않게 정해 주세요'
      : '$range로 정해 주세요';
}

const int _minutesPerDay = 1440;
