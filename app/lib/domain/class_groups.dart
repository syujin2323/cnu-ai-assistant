// 시간표의 수업 묶음, 격자 배치, 겹침. docs/screens.md '13 시간표·고정 일정', '14 온보딩'의 2단계.
//
// 폰 DB는 수업 칸을 요일마다 한 행으로 둔다(`class_slots`). 13 시간표·고정 일정의 목록과 수업 시트는 최종
// 프로토타입처럼 과목·시각·장소·실시간 온라인·출처가 같은 칸을 한 수업으로 묶어 '월·수 09:00–10:15'처럼 보이고
// 함께 고친다([groupClassSlots]). 격자(13 시간표 탭, 14 온보딩 2단계)는 요일 열마다 칸을 그린다
// ([timetableGridLayout]). 수업 시트와 고정 일정 시트는 겹치는 수업을 알리기만 하고 막지 않는다
// ([overlappingClasses]). 같은 입력이면 늘 같은 결과다.

import 'package:cnu_ai_assistant/domain/models/class_slot.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot_entry.dart';
import 'package:cnu_ai_assistant/domain/models/course.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 한 수업: 과목·시각·장소·실시간 온라인·출처가 같은 수업 칸의 묶음.
final class ClassGroup {
  ClassGroup(List<ClassSlotEntry> entries)
    : assert(entries.isNotEmpty),
      entries = List.unmodifiable(entries);

  /// 묶음의 칸. 요일 순서이고 같으면 id 순서다.
  final List<ClassSlotEntry> entries;

  ClassSlot get _first => entries.first.slot;

  Course get course => entries.first.course;

  /// 수업이 있는 요일(1–7). 오름차순이고 겹치지 않는다.
  List<int> get weekdays => {for (final e in entries) e.slot.weekday}.toList();

  int get startMin => _first.startMin;

  int get endMin => _first.endMin;

  String? get place => _first.place;

  bool get online => _first.online;

  SlotSource get source => _first.source;

  /// 묶음의 `class_slots.id`.
  List<int> get slotIds => [for (final e in entries) e.slot.id];

  /// 목록의 때 '월·수 09:00–10:15'.
  String get whenText =>
      '${weekdaysText(weekdays)} ${timeRangeText(startMin, endMin)}';
}

/// [entries]를 과목·시각·장소·실시간 온라인·출처가 같은 수업으로 묶는다. 수업은 첫 요일, 시작 시각, 과목 이름,
/// 첫 칸 id 순서다.
List<ClassGroup> groupClassSlots(List<ClassSlotEntry> entries) {
  final groups =
      <(int, int, int, String?, bool, SlotSource), List<ClassSlotEntry>>{};
  final sorted = [...entries]..sort(_byDayThenTime);
  for (final entry in sorted) {
    final slot = entry.slot;
    final key = (
      slot.courseId,
      slot.startMin,
      slot.endMin,
      slot.place,
      slot.online,
      slot.source,
    );
    (groups[key] ??= []).add(entry);
  }
  return [for (final members in groups.values) ClassGroup(members)]
    ..sort((a, b) {
      final day = a.weekdays.first.compareTo(b.weekdays.first);
      if (day != 0) return day;
      final start = a.startMin.compareTo(b.startMin);
      if (start != 0) return start;
      final name = a.course.name.compareTo(b.course.name);
      return name != 0 ? name : a.slotIds.first.compareTo(b.slotIds.first);
    });
}

/// 요일 목록 '월·수·금'. 비었으면 '요일 없음'이다.
String weekdaysText(Iterable<int> weekdays) {
  final days = {...weekdays}.toList()..sort();
  return days.isEmpty ? '요일 없음' : days.map(weekdayText).join('·');
}

/// 시간표 격자의 배치.
final class TimetableGridLayout {
  const TimetableGridLayout({
    required this.days,
    required this.firstHour,
    required this.lastHour,
    required this.byDay,
  });

  /// 보일 요일 열. 월–금이고, 토·일에 수업이 있으면 월–일이다.
  final List<int> days;

  /// 격자 맨 위 시(포함). 기본 9시이고 더 이른 수업이 있으면 그 시까지 늘린다.
  final int firstHour;

  /// 격자 맨 아래 시(포함). 기본 18시이고 더 늦게 끝나는 수업이 있으면 그 시까지 늘린다(24시까지).
  final int lastHour;

  /// 요일 → 그 요일 칸(시작 시각 순서, 같으면 id 순서).
  final Map<int, List<ClassSlotEntry>> byDay;

  /// 격자의 분 길이.
  int get spanMin => (lastHour - firstHour) * 60;
}

/// 격자에 기본으로 보이는 시간대. 최종 프로토타입의 값이다(임시).
abstract final class TimetableGridDefaults {
  static const int firstHour = 9;
  static const int lastHour = 18;
}

/// [entries]의 격자 배치. 자정을 넘는 칸은 24시에서 자른다.
TimetableGridLayout timetableGridLayout(List<ClassSlotEntry> entries) {
  var first = TimetableGridDefaults.firstHour;
  var last = TimetableGridDefaults.lastHour;
  var weekend = false;
  final byDay = <int, List<ClassSlotEntry>>{};
  for (final entry in [...entries]..sort(_byDayThenTime)) {
    final slot = entry.slot;
    if (slot.weekday >= DateTime.saturday) weekend = true;
    final startHour = slot.startMin ~/ 60;
    final endHour = ((slot.endMin < 1440 ? slot.endMin : 1440) + 59) ~/ 60;
    if (startHour < first) first = startHour;
    if (endHour > last) last = endHour;
    (byDay[slot.weekday] ??= []).add(entry);
  }
  return TimetableGridLayout(
    days: [
      for (
        var day = DateTime.monday;
        day <= (weekend ? DateTime.sunday : DateTime.friday);
        day++
      )
        day,
    ],
    firstHour: first,
    lastHour: last,
    byDay: byDay,
  );
}

/// [weekdays]의 [startMin]–[endMin]과 겹치는 수업 칸. [exceptIds]의 칸(지금 고치는 수업)은 뺀다. 요일·시작 시각
/// 순서다. 같은 달력 요일 안에서만 견준다.
List<ClassSlotEntry> overlappingClasses(
  List<ClassSlotEntry> entries, {
  required Iterable<int> weekdays,
  required int startMin,
  required int endMin,
  Set<int> exceptIds = const {},
}) {
  final days = weekdays.toSet();
  return [
    for (final entry in [...entries]..sort(_byDayThenTime))
      if (!exceptIds.contains(entry.slot.id) &&
          days.contains(entry.slot.weekday) &&
          entry.slot.startMin < endMin &&
          startMin < entry.slot.endMin)
        entry,
  ];
}

int _byDayThenTime(ClassSlotEntry a, ClassSlotEntry b) {
  final day = a.slot.weekday.compareTo(b.slot.weekday);
  if (day != 0) return day;
  final start = a.slot.startMin.compareTo(b.slot.startMin);
  return start != 0 ? start : a.slot.id.compareTo(b.slot.id);
}
