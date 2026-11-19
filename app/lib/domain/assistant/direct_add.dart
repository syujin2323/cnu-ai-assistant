// 직접 추가 폼의 값, 처음 값, 검사, 저장할 값. docs/screens.md '직접 추가 폼'·'06 AI 비서'.
//
// 폼은 [일정 | 반복 일정 | 할 일] 가운데 하나를 넣는다. 일정은 날짜(오늘부터 14일)·'시간 미정'(종일)·시작·끝
// (30분 단위)·알림(값만 저장. 알림은 재설계 예정), 반복 일정은 요일·시간(고정 일정), 할 일은 마감(없어도 됨,
// 기본 23:59)·예상 시간이고, 장소·준비물(선택)은 일정과 반복 일정에 둔다. 범위와 처음 값은 최종 프로토타입을
// 따른 임시값이다. 날짜는 달력 날짜다(06 AI 비서의 요청처럼 하루 경계를 적용하지 않음).
//
// 06 카드의 [고치기]로 열면 그 카드의 값으로 채우고, 할 일이면 카드의 과목·종류를 그대로 둔다. 저장은 06 AI 비서의
// 컨트롤러가 이 값을 카드와 같은 초안([EventDraft]·[TaskDraft])으로 바꿔 한다. 종류를 바꿔도 다른 종류의 값은
// 남겨 두어 다시 돌아오면 그대로다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 직접 추가 폼의 종류(screens.md '직접 추가 폼'의 [일정 | 반복 일정 | 할 일]).
enum DirectAddKind {
  /// 일정.
  event,

  /// 반복 일정(고정 일정으로 저장).
  repeating,

  /// 할 일.
  task,
}

/// 직접 추가 폼의 범위와 처음 값(임시).
abstract final class DirectAddLimits {
  /// 제목·장소·준비물의 글자 수.
  static const int titleLength = 40;
  static const int fieldLength = 40;

  /// 일정 날짜와 마감 날짜 칩의 날 수(오늘부터).
  static const int dateDays = 14;

  /// 시각 칸의 단추(−·+) 단위(분).
  static const int step = 30;

  /// 시각을 눌러 여는 휠의 단위(분).
  static const int pickStep = 5;

  /// 시작 시각의 범위(05:00–23:30). 끝은 다음 날 06:00까지 받아 자정을 넘는 일정도 넣는다.
  static const int startLow = 300;
  static const int startHigh = 1410;
  static const int endHigh = 1800;

  /// 처음 일정이 놓이는 시간대(09:00부터, 22:00 안에 끝남).
  static const int dayStart = 540;
  static const int dayEnd = 1320;

  /// 처음 일정의 길이와, 처음 시각을 지금에서 띄우는 분.
  static const int length = 60;
  static const int lead = 10;

  /// 마감 시각 칸(06:00–23:30을 30분마다, 끝은 23:59).
  static const int dueLow = 360;
  static const int dueHigh = 1410;
  static const int dueDefault = 1439;

  /// 알림 칩(분 전). 0은 '없음'이다.
  static const List<int> reminderChoices = [0, 10, 30, 60];
}

/// 폼을 저장하지 못하게 하는 까닭.
enum DirectAddIssue {
  /// 제목이 없다.
  title,

  /// 반복 일정인데 요일을 고르지 않았다.
  weekdays,

  /// 마감 시각이 이미 지났다.
  pastDue,
}

/// 까닭의 문구(임시, 최종 프로토타입).
String directAddIssueText(DirectAddIssue issue) => switch (issue) {
  DirectAddIssue.title => '제목을 넣어 주세요',
  DirectAddIssue.weekdays => '반복할 요일을 하나 이상 골라 주세요',
  DirectAddIssue.pastDue => '마감 시각이 이미 지났어요. 시각이나 날짜를 바꿔 주세요',
};

/// 직접 추가 폼의 값. 시각은 자정 기준 분이고 날짜는 그날 0시다.
final class DirectAddDraft {
  const DirectAddDraft({
    required this.kind,
    this.title = '',
    required this.date,
    this.timeUnknown = false,
    required this.startMin,
    required this.endMin,
    this.weekdays = const {},
    this.dueDate,
    this.dueTimeMin = DirectAddLimits.dueDefault,
    this.saidEstimateMin,
    this.pickedEstimateMin,
    this.courseName,
    this.taskKind,
    this.reminderMinutes,
    this.place = '',
    this.prep = '',
    this.fixedKind,
  });

  /// 새 폼의 처음 값. [at]이 있으면 그 날짜·시각(빈 시간에서 연 06 AI 비서)부터 한 시간이다. 없으면 오늘 지금
  /// 10분 뒤의 다음 30분 칸(9시 전이면 9시)부터 한 시간이고, 22시 안에 끝나지 않으면 내일 9시다(임시. 최종
  /// 프로토타입은 겹치지 않는 시각을 찾지만 여기서는 겹침을 바로 알리기만 함). [now]에는 `Clock.now`의 값을 넘긴다.
  factory DirectAddDraft.initial(
    DirectAddKind kind, {
    required DateTime now,
    DateTime? at,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    if (at != null) {
      final minute = (at.hour * 60 + at.minute).clamp(
        DirectAddLimits.startLow,
        DirectAddLimits.startHigh,
      );
      return DirectAddDraft(
        kind: kind,
        date: DateTime(at.year, at.month, at.day),
        startMin: minute,
        endMin: minute + DirectAddLimits.length,
      );
    }
    const step = DirectAddLimits.step;
    final soon =
        ((now.hour * 60 + now.minute + DirectAddLimits.lead + step - 1) ~/
            step) *
        step;
    final start = soon < DirectAddLimits.dayStart
        ? DirectAddLimits.dayStart
        : soon;
    final fitsToday = start + DirectAddLimits.length <= DirectAddLimits.dayEnd;
    final begin = fitsToday ? start : DirectAddLimits.dayStart;
    return DirectAddDraft(
      kind: kind,
      date: fitsToday
          ? today
          : DateTime(today.year, today.month, today.day + 1),
      startMin: begin,
      endMin: begin + DirectAddLimits.length,
    );
  }

  /// 일정 카드 [draft]를 고치는 폼(06 카드의 [고치기]). 시간 미정이면 시간 칸은 새 폼의 처음 값이다.
  factory DirectAddDraft.fromEvent(EventDraft draft, {required DateTime now}) {
    final weekdays = draft.weekdays;
    final base = DirectAddDraft.initial(
      weekdays == null ? DirectAddKind.event : DirectAddKind.repeating,
      now: now,
    );
    final start = draft.startMin ?? base.startMin;
    return base.copyWith(
      title: draft.title,
      date: draft.date ?? base.date,
      weekdays: {...?weekdays},
      timeUnknown: weekdays == null && draft.timeUnknown,
      startMin: start,
      endMin: draft.endMin ?? start + DirectAddLimits.length,
      place: draft.place ?? '',
      prep: draft.prep ?? '',
      fixedKind: () => draft.fixedKind,
      reminderMinutes: () => draft.reminderMinutes,
    );
  }

  /// 할 일 카드 [draft]를 고치는 폼(06 카드의 [고치기]). 카드의 과목·종류와 말한·고른 예상 시간을 그대로 둔다.
  factory DirectAddDraft.fromTask(TaskDraft draft, {required DateTime now}) =>
      DirectAddDraft.initial(DirectAddKind.task, now: now).copyWith(
        title: draft.title,
        courseName: () => draft.courseName,
        taskKind: () => draft.kind,
        dueDate: () => draft.dueDate,
        dueTimeMin: draft.dueTimeMin ?? DirectAddLimits.dueDefault,
        saidEstimateMin: () => draft.saidEstimateMin,
        pickedEstimateMin: () => draft.pickedEstimateMin,
      );

  final DirectAddKind kind;

  /// 제목(앞뒤 공백은 저장할 때 지운다).
  final String title;

  /// 일정의 날짜(그날 0시).
  final DateTime date;

  /// 일정의 '시간 미정'(종일 일정으로 저장).
  final bool timeUnknown;

  /// 일정·반복 일정의 시작과 끝. 끝이 자정을 넘으면 1440을 더한 값이다.
  final int startMin;
  final int endMin;

  /// 반복 일정의 요일(1–7).
  final Set<int> weekdays;

  /// 할 일의 마감 날짜(그날 0시). 마감이 없으면 null이다.
  final DateTime? dueDate;

  /// 할 일의 마감 시각(기본 23:59).
  final int dueTimeMin;

  /// 06 카드의 문장에서 말한 예상 시간(분).
  final int? saidEstimateMin;

  /// 예상 시간 칩으로 고른 값(분). 고르거나 말한 값만 할 일에 저장한다(06 카드와 같음).
  final int? pickedEstimateMin;

  /// 06 카드의 과목과 종류. 폼에서 새로 넣은 할 일은 개인 할 일이라 null이다.
  final String? courseName;
  final TaskKind? taskKind;

  /// 일정의 알림(분 전, 값만 저장). 고르지 않았거나 '없음'이면 null이다.
  final int? reminderMinutes;

  final String place;
  final String prep;

  /// 반복 일정의 종류. 06 카드에서 온 값이고, 없으면 저장할 때 제목으로 짐작한다([guessFixedKind]).
  final FixedBlockKind? fixedKind;

  /// 할 일의 마감 시각. 마감이 없으면 null이다.
  DateTime? get dueAt {
    final day = dueDate;
    if (day == null) return null;
    return DateTime(day.year, day.month, day.day, 0, dueTimeMin);
  }

  /// 일정의 시작·끝 시각(시간 미정이면 null).
  DateTime? get startAt => timeUnknown
      ? null
      : DateTime(date.year, date.month, date.day, 0, startMin);
  DateTime? get endAt =>
      timeUnknown ? null : DateTime(date.year, date.month, date.day, 0, endMin);

  DirectAddDraft copyWith({
    DirectAddKind? kind,
    String? title,
    DateTime? date,
    bool? timeUnknown,
    int? startMin,
    int? endMin,
    Set<int>? weekdays,
    DateTime? Function()? dueDate,
    int? dueTimeMin,
    int? Function()? saidEstimateMin,
    int? Function()? pickedEstimateMin,
    String? Function()? courseName,
    TaskKind? Function()? taskKind,
    int? Function()? reminderMinutes,
    String? place,
    String? prep,
    FixedBlockKind? Function()? fixedKind,
  }) => DirectAddDraft(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    date: date ?? this.date,
    timeUnknown: timeUnknown ?? this.timeUnknown,
    startMin: startMin ?? this.startMin,
    endMin: endMin ?? this.endMin,
    weekdays: weekdays ?? this.weekdays,
    dueDate: dueDate == null ? this.dueDate : dueDate(),
    dueTimeMin: dueTimeMin ?? this.dueTimeMin,
    saidEstimateMin: saidEstimateMin == null
        ? this.saidEstimateMin
        : saidEstimateMin(),
    pickedEstimateMin: pickedEstimateMin == null
        ? this.pickedEstimateMin
        : pickedEstimateMin(),
    courseName: courseName == null ? this.courseName : courseName(),
    taskKind: taskKind == null ? this.taskKind : taskKind(),
    reminderMinutes: reminderMinutes == null
        ? this.reminderMinutes
        : reminderMinutes(),
    place: place ?? this.place,
    prep: prep ?? this.prep,
    fixedKind: fixedKind == null ? this.fixedKind : fixedKind(),
  );

  /// 저장할 일정 초안(일정·반복 일정). 장소·준비물은 비면 null이고, 시간 미정이거나 반복 일정이면 알림을 두지
  /// 않는다(고정 일정에는 알림 칸이 없음).
  EventDraft toEventDraft() {
    final repeating = kind == DirectAddKind.repeating;
    final unknown = !repeating && timeUnknown;
    return EventDraft(
      title: title.trim(),
      date: repeating ? null : date,
      weekdays: repeating ? (weekdays.toList()..sort()) : null,
      startMin: unknown ? null : startMin,
      endMin: unknown ? null : endMin,
      place: _optional(place),
      prep: _optional(prep),
      fixedKind: repeating ? fixedKind ?? guessFixedKind(title) : null,
      reminderMinutes: repeating || unknown ? null : reminderMinutes,
    );
  }

  /// 저장할 할 일 초안. 과목이 없으면 개인 할 일이고, 마감 시각은 늘 정한 값이다(기본 23:59).
  TaskDraft toTaskDraft() => TaskDraft(
    title: title.trim(),
    courseName: courseName,
    kind:
        taskKind ??
        (courseName == null ? TaskKind.personal : TaskKind.assignment),
    dueDate: dueDate,
    dueTimeMin: dueDate == null ? null : dueTimeMin,
    saidEstimateMin: saidEstimateMin,
    pickedEstimateMin: pickedEstimateMin,
  );

  /// 제목·장소·준비물은 적지 않는다(사용자가 쓴 말).
  @override
  String toString() =>
      'DirectAddDraft(${kind.name}, $date, $startMin–$endMin, due: $dueAt)';
}

/// 저장하지 못하게 하는 첫 까닭. 없으면 null이다. [now]에는 `Clock.now`의 값을 넘긴다.
DirectAddIssue? directAddIssue(DirectAddDraft draft, {required DateTime now}) {
  if (draft.title.trim().isEmpty) return DirectAddIssue.title;
  switch (draft.kind) {
    case DirectAddKind.repeating when draft.weekdays.isEmpty:
      return DirectAddIssue.weekdays;
    case DirectAddKind.task:
      final due = draft.dueAt;
      if (due != null && !due.isAfter(now)) return DirectAddIssue.pastDue;
    case _:
      break;
  }
  return null;
}

/// 오늘 일정이 이미 끝났으면 그 안내(막지 않음, 임시). 그 밖에는 null이다.
String? directAddPastNote(DirectAddDraft draft, {required DateTime now}) {
  if (draft.kind != DirectAddKind.event) return null;
  final end = draft.endAt;
  if (end == null || end.isAfter(now)) return null;
  if (DateTime(now.year, now.month, now.day) != draft.date) return null;
  return '오늘 ${timeRangeText(draft.startMin, draft.endMin)}은 이미 지났어요 · '
      '그대로 넣으면 지난 일정으로 보여요';
}

/// 반복 일정의 종류를 제목으로 짐작한다(알바·근무는 알바, 운동 종목은 운동, 그 밖은 기타. 최종 프로토타입).
FixedBlockKind guessFixedKind(String title) {
  if (_work.hasMatch(title)) return FixedBlockKind.work;
  if (_exercise.hasMatch(title)) return FixedBlockKind.exercise;
  return FixedBlockKind.other;
}

final _work = RegExp('알바|아르바이트|과외|근무');
final _exercise = RegExp('헬스|운동|수영|필라테스|요가|클라이밍|러닝');

/// 날짜 칩: 오늘부터 [DirectAddLimits.dateDays]일. [include]가 그 밖의 날이면(카드에서 온 날짜) 날짜 순서로 더한다.
List<DateTime> directAddDays(DateTime today, {DateTime? include}) {
  final days = [
    for (var i = 0; i < DirectAddLimits.dateDays; i++)
      DateTime(today.year, today.month, today.day + i),
  ];
  if (include != null) {
    final day = DateTime(include.year, include.month, include.day);
    if (!days.contains(day)) days.add(day);
  }
  return days..sort();
}

/// 마감 시각 칸의 값(06:00–23:30을 30분마다, 끝은 23:59).
final List<int> dueTimeChoices = List.unmodifiable([
  for (
    var minute = DirectAddLimits.dueLow;
    minute <= DirectAddLimits.dueHigh;
    minute += DirectAddLimits.step
  )
    minute,
  DirectAddLimits.dueDefault,
]);

/// 마감 시각을 한 칸 옮긴 값. [later]면 뒤, 아니면 앞이고 더 갈 곳이 없으면 null이다. 칸에 없는 값(카드에서 온
/// 시각)이면 그 앞뒤의 칸으로 간다.
int? stepDueTime(int current, {required bool later}) {
  if (later) {
    for (final minute in dueTimeChoices) {
      if (minute > current) return minute;
    }
    return null;
  }
  for (final minute in dueTimeChoices.reversed) {
    if (minute < current) return minute;
  }
  return null;
}

/// 넣기 전에 보이는 할 일이 놓일 자리(임시 문구). [plan]은 그 할 일을 [taskId]로 넣었다고 보고 돌린 배치 결과이고
/// 모르면 null이다. [estimate]는 그 할 일의 예상 시간(없으면 자동으로 놓지 않음), [hasTimetable]은 수업 칸이
/// 하나라도 있는지다. [alert]면 붉게 쓴다. [now]에는 `Clock.now`의 값을 넘긴다.
({String text, bool alert})? taskPreview({
  required TaskDraft draft,
  required int taskId,
  required int? estimate,
  required PlanResult? plan,
  required bool hasTimetable,
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final due = draft.dueAt;
  if (due == null) return (text: '마감이 없어 자동으로 놓지 않아요', alert: false);
  if (!due.isAfter(now)) return (text: '마감 시각이 지나 계획에 놓지 않아요', alert: true);
  if (estimate == null) {
    return (text: '예상 시간을 몰라 자동으로 놓지 않아요', alert: false);
  }
  if (!hasTimetable) {
    return (text: '시간표가 없어 아직 자동으로 놓지 않아요', alert: false);
  }
  if (plan == null) return null;
  final blocks = plan.blocks.where((block) => block.taskId == taskId).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  if (blocks.isNotEmpty) {
    final first = blocks.first;
    final start = first.startAt.hour * 60 + first.startAt.minute;
    final end = start + first.endAt.difference(first.startAt).inMinutes;
    final day = dayWord(
      first.startAt,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    );
    final split = blocks.length > 1 ? ' · ${blocks.length}번에 나눠요' : '';
    return (
      text: '넣으면 $day ${timeRangeText(start, end)}에 제안으로 놓아요$split',
      alert: false,
    );
  }
  for (final shortage in plan.shortages) {
    if (shortage.taskId != taskId) continue;
    return (
      text:
          '마감 전 빈 시간이 ${durationText(shortage.missingMin)} 모자라요 · '
          '넣은 뒤 홈에서 방법을 골라 주세요',
      alert: true,
    );
  }
  if (due.isAfter(now.add(const Duration(days: Defaults.planHorizonDays)))) {
    return (
      text: '마감 ${Defaults.planHorizonDays}일 전부터 빈 시간에 놓아요',
      alert: false,
    );
  }
  return (text: '마감 전에 놓을 빈 시간을 아직 찾지 못했어요', alert: false);
}

String? _optional(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
