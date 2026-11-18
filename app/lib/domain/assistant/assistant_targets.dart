// 06 AI 비서의 수업 변경·일정 바꾸기·지우기가 보는 폰 DB의 값과 찾기. docs/screens.md '06 AI 비서'의 카드 3·5.
//
// 수업 변경은 과목 이름으로 오늘부터 2주 안의 수업을 찾는다(휴강한 수업과 보강은 빼고). 일정 바꾸기·지우기는
// 고정 일정과 오늘 뒤 일정에서 대상을 가리키는 말(`target`)과 제목이 가장 많이 맞는 것을 고른다. 대상의 날짜
// (`targetDate`)를 말했으면 그날의 일정과 그 요일의 고정 일정만 보고, 그래도 없으면 날짜 없이 다시 찾는다.
// 날짜는 요청의 today와 같은 한국 달력 날짜로 센다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot_entry.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:cnu_ai_assistant/domain/models/event.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';

/// 카드를 만들 때 한 번 읽어 둔 폰 DB의 값.
final class AssistantSnapshot {
  const AssistantSnapshot({
    this.courses = const [],
    this.slots = const [],
    this.exceptions = const [],
    this.fixedBlocks = const [],
    this.events = const [],
    this.rules = const [],
  });

  /// 고를 수 있는 과목(요청에 보낸 과목).
  final List<Course> courses;

  /// 숨기지 않은 수업 칸과 과목.
  final List<ClassSlotEntry> slots;

  /// 오늘부터 2주의 수업 예외.
  final List<ClassException> exceptions;

  final List<FixedBlock> fixedBlocks;

  /// 오늘 뒤(오늘 0시 이후 시작) 일정. 지난 일정은 바꾸지 않는다.
  final List<Event> events;

  /// 내 규칙 전부(꺼진 것도). 규칙 카드가 지금 값·바뀌는 규칙·지울 대상을 찾는다.
  final List<Rule> rules;
}

/// 수업 한 번(그 날짜에 평소대로 열리는 수업 칸).
final class ClassSession {
  const ClassSession({
    required this.slot,
    required this.courseName,
    required this.date,
    this.place,
  });

  final ClassSlot slot;
  final String courseName;

  /// 그 날짜(0시).
  final DateTime date;

  /// 그날의 강의실(장소 변경이 있으면 그 값, 없으면 수업 칸의 값).
  final String? place;

  int get startMin => slot.startMin;
  int get endMin => slot.endMin;
}

/// 수업 변경을 찾을 날 수(오늘부터 2주).
const sessionSearchDays = 14;

/// [courseName] 과목이 [today]부터 [days]일 안에 평소대로 열리는 수업(날짜·시작 순서). 그날 휴강한 수업은
/// 뺀다. 보강은 따로 넣는 것이라 넣지 않는다.
List<ClassSession> sessionsOf(
  String courseName,
  AssistantSnapshot snapshot, {
  required DateTime today,
  int days = sessionSearchDays,
}) {
  final slots = [
    for (final entry in snapshot.slots)
      if (entry.course.name == courseName) entry.slot,
  ];
  final sessions = <ClassSession>[];
  for (var offset = 0; offset < days; offset++) {
    final date = DateTime(today.year, today.month, today.day + offset);
    final iso = isoDate(date);
    for (final slot in slots) {
      if (slot.weekday != date.weekday) continue;
      final dayExceptions = snapshot.exceptions.where(
        (exception) =>
            exception.classSlotId == slot.id && exception.date == iso,
      );
      if (dayExceptions.any((e) => e.kind == ClassExceptionKind.cancelled)) {
        continue;
      }
      final changed = dayExceptions
          .where((e) => e.kind == ClassExceptionKind.placeChange)
          .firstOrNull;
      sessions.add(
        ClassSession(
          slot: slot,
          courseName: courseName,
          date: date,
          place: changed?.place ?? slot.place,
        ),
      );
    }
  }
  sessions.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.startMin.compareTo(b.startMin);
  });
  return sessions;
}

/// [courseName] 과목의 수업 칸 하나(보강을 넣을 칸). 시작이 가장 이른 칸이고 없으면 null이다.
ClassSlot? anySlotOf(String courseName, AssistantSnapshot snapshot) {
  final slots =
      [
        for (final entry in snapshot.slots)
          if (entry.course.name == courseName) entry.slot,
      ]..sort(
        (a, b) => (a.weekday * 1440 + a.startMin).compareTo(
          b.weekday * 1440 + b.startMin,
        ),
      );
  return slots.firstOrNull;
}

/// 바꾸거나 지울 대상.
sealed class ChangeTarget {
  const ChangeTarget();

  String get title;
}

/// 한 번뿐인 일정.
final class EventTarget extends ChangeTarget {
  const EventTarget(this.event);

  final Event event;

  @override
  String get title => event.title;
}

/// 고정 일정(매주 반복).
final class FixedTarget extends ChangeTarget {
  const FixedTarget(this.block);

  final FixedBlock block;

  @override
  String get title => block.name;
}

/// [target]('내일 스터디')과 제목이 가장 많이 맞는 대상. 두 글자 이상인 말마다 제목(공백을 뺌)에 들어 있으면
/// 1점이고(세 글자 이상인 말은 제목이 그 말에 들어 있어도), 가장 높은 점수의 대상을 모두 돌려준다(고정 일정
/// 먼저, 그다음 시작 순서). [targetDate]가 있으면 그날의 일정과 그 요일의 고정 일정에서 먼저 찾는다.
List<ChangeTarget> findTargets(
  String? target,
  DateTime? targetDate,
  AssistantSnapshot snapshot,
) {
  final words = (target ?? '')
      .split(RegExp(r'\s+'))
      .where((word) => word.runes.length >= 2)
      .toList();
  if (words.isEmpty) return const [];
  int score(String title) {
    final compact = title.replaceAll(RegExp(r'\s'), '');
    return words
        .where(
          (word) =>
              compact.contains(word) ||
              (word.runes.length >= 3 &&
                  compact.isNotEmpty &&
                  word.contains(compact)),
        )
        .length;
  }

  List<ChangeTarget> best(bool Function(ChangeTarget) on) {
    final scored = [
      for (final block in snapshot.fixedBlocks)
        (FixedTarget(block) as ChangeTarget, score(block.name)),
      for (final event in [
        ...snapshot.events,
      ]..sort((a, b) => a.startAt.compareTo(b.startAt)))
        (EventTarget(event) as ChangeTarget, score(event.title)),
    ].where((pair) => pair.$2 > 0 && on(pair.$1)).toList();
    if (scored.isEmpty) return const [];
    final top = scored.map((pair) => pair.$2).reduce((a, b) => a > b ? a : b);
    return [
      for (final (candidate, points) in scored)
        if (points == top) candidate,
    ];
  }

  if (targetDate != null) {
    final onDate = best(
      (candidate) => switch (candidate) {
        EventTarget(:final event) => _sameDate(event.startAt, targetDate),
        FixedTarget(:final block) => block.weekdays.contains(
          targetDate.weekday,
        ),
      },
    );
    if (onDate.isNotEmpty) return onDate;
  }
  return best((_) => true);
}

/// 바꾼 뒤의 값. 일정은 시작·끝(종일이면 그날 0시–다음 날 0시), 고정 일정은 요일과 시각이다.
sealed class ChangeAfter {
  const ChangeAfter();
}

final class EventAfter extends ChangeAfter {
  const EventAfter({
    required this.startAt,
    required this.endAt,
    required this.allDay,
  });

  final DateTime startAt;
  final DateTime endAt;
  final bool allDay;
}

final class FixedAfter extends ChangeAfter {
  const FixedAfter({
    required this.weekdays,
    required this.startMin,
    required this.endMin,
  });

  final List<int> weekdays;
  final int startMin;
  final int endMin;
}

/// [item]이 말한 새 값을 [target]에 적용한 값. 바꿀 값(날짜·시각·옮긴 분·요일)이 하나도 없으면 null이다.
///
/// - 옮긴 분([ParseItem.shiftMinutes])은 시작과 끝을 함께 옮긴다.
/// - 새 시작만 말하면 길이를 그대로 두고, 끝도 말하면 그 끝이다(끝이 시작보다 이르면 자정을 넘는 것으로 봄).
/// - 일정은 새 날짜([ParseItem.date])로 옮기고, 종일 일정에 시각을 말하면 그 시각의 일정이 된다(끝이 없으면
///   한 시간, 임시).
/// - 고정 일정은 날짜 대신 요일로 옮긴다(매주 반복 요일이나 문장 속 요일. 요일이 하나인 고정 일정만 한 요일로
///   옮김).
ChangeAfter? changedAfter(ChangeTarget target, ParseItem item) {
  final shift = item.shiftMinutes;
  final start = item.startMin;
  final end = item.endMin;
  switch (target) {
    case EventTarget(:final event):
      final newDate = item.date;
      if (shift == null && start == null && newDate == null) return null;
      final day = newDate ?? _dateOf(event.startAt);
      if (event.allDay && start == null) {
        // 종일 일정은 날짜만 옮긴다(옮긴 분은 시각이 없어 쓰지 않음).
        if (newDate == null) return null;
        return EventAfter(
          startAt: day,
          endAt: DateTime(day.year, day.month, day.day + 1),
          allDay: true,
        );
      }
      final length = event.allDay
          ? 60
          : event.endAt.difference(event.startAt).inMinutes;
      var startMin = start ?? (event.startAt.hour * 60 + event.startAt.minute);
      var endMin = start == null
          ? startMin + length
          : _endFor(start, end, length);
      if (start == null && shift != null) {
        startMin += shift;
        endMin += shift;
      }
      return EventAfter(
        startAt: DateTime(day.year, day.month, day.day, 0, startMin),
        endAt: DateTime(day.year, day.month, day.day, 0, endMin),
        allDay: false,
      );
    case FixedTarget(:final block):
      final repeatDays = item.repeat?.weekdays;
      final saidDay = item.weekday;
      final weekdays = repeatDays != null && repeatDays.isNotEmpty
          ? ({...repeatDays}.toList()..sort())
          : saidDay != null && block.weekdays.length == 1
          ? [saidDay]
          : block.weekdays;
      final daysChanged = !_sameList(weekdays, block.weekdays);
      if (shift == null && start == null && !daysChanged) return null;
      final length = block.endMin - block.startMin;
      var startMin = start ?? block.startMin;
      var endMin = start == null
          ? startMin + length
          : _endFor(start, end, length);
      if (start == null && shift != null) {
        startMin += shift;
        endMin += shift;
      }
      // 옮겨서 하루 밖으로 나가면(전날·다음 날) 하루 안으로 되돌린다.
      if (startMin < 0 || startMin >= 1440) {
        final wrapped = startMin % 1440;
        endMin += wrapped - startMin;
        startMin = wrapped;
      }
      return FixedAfter(weekdays: weekdays, startMin: startMin, endMin: endMin);
  }
}

/// 새 시작 [start]의 끝. 끝을 말했으면 그 끝(이르면 자정을 넘음), 아니면 [length]만큼 뒤다.
int _endFor(int start, int? end, int length) {
  if (end == null) return start + length;
  final value = end > start ? end : end + 1440;
  return value - start >= 1440 ? start + length : value;
}

DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
