// 일정 정보 시트가 보일 것. docs/screens.md '일정 정보 시트'.
//
// 02 홈·09 일간·11 주간에서 수업·일정·고정 일정을 누르면 여는 시트의 머리(종류, 제목, 날짜·시각·장소)와, 수업이면
// 그날만 바꿀 수 있는지와 지금 바뀐 것을 정한다. 지난 수업과 보강은 바꾸지 않고 안내만 둔다(공휴일에도 수업은
// 그대로라 막지 않는다. 쉬면 사용자가 휴강을 고른다). 문구는 최종 프로토타입의 문구다(임시). 그리기는
// `design/widgets/event_info_sheet.dart`, 동작은 `features/today/event_info_actions.dart`가 한다.

import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 수업 하루만 바꾸는 것(`class_exceptions.kind`의 휴강·시험·장소 변경).
enum ClassDayChange {
  cancelled('휴강', ClassExceptionKind.cancelled),
  exam('시험', ClassExceptionKind.exam),
  placeChange('장소 변경', ClassExceptionKind.placeChange);

  const ClassDayChange(this.label, this.kind);

  /// 칩 이름.
  final String label;

  /// 저장할 수업 예외 종류.
  final ClassExceptionKind kind;
}

/// 시트가 연 항목의 종류.
enum EventInfoKind { classItem, event, fixed }

/// 일정 정보 시트의 내용.
final class EventInfoContent {
  const EventInfoContent({
    required this.kind,
    required this.kicker,
    required this.title,
    required this.time,
    required this.dayWord,
    required this.date,
    this.change,
    this.changeLabel,
    this.lockText,
    this.canEditBySpeech = false,
  });

  final EventInfoKind kind;

  /// 머리 띠(수업·휴강·시험·장소 변경·보강·개인 일정·고정 일정).
  final String kicker;

  final String title;

  /// '11월 16일 (월) · 09:00–10:15 · 공대 5호관 101'.
  final String time;

  /// 그날의 날짜 말(오늘·내일·{요일}요일 …). 토스트 문구에 쓴다.
  final String dayWord;

  /// 머리에 쓴 날짜(시각이 있으면 논리적 하루, 종일 일정이면 첫날)의 0시. [말로 바꾸기]가 채우는 문장에 쓴다.
  final DateTime date;

  /// 수업의 지금 하루 바꿈. 없으면 null이다.
  final ClassDayChange? change;

  /// '{날짜 말} 수업만 바꾸기'. 바꿀 수 없는 수업과 수업이 아닌 항목은 null이다.
  final String? changeLabel;

  /// 바꿀 수 없는 수업의 안내. 바꿀 수 있거나 수업이 아니면 null이다.
  final String? lockText;

  /// 수업 하루를 바꿀 수 있는지.
  bool get canChange => changeLabel != null;

  /// 일정을 [말로 바꾸기]로 06 AI 비서에서 바꿀 수 있는지. 06은 오늘부터의 일정만 바꾸기 대상으로 찾으므로 지난
  /// 날의 일정(논리적 하루로 셈, 종일 일정은 끝날로 셈)은 false다. 수업·고정 일정도 false다.
  final bool canEditBySpeech;
}

/// [item]의 시트 내용. 수업·일정·고정 일정만 받는다(그 밖은 [ArgumentError]). 하루 시간표에 없는 종일 일정은
/// `EventItem(TimeSpan(event.startAt, event.endAt), event: event)`로 넘긴다. [courseName]은 수업의 과목 이름이다.
/// [now]는 지금이고, 지난 날의 수업(논리적 하루로 셈)은 바꾸지 못한다. 날짜는 시간표의 머리처럼 논리적 하루이고
/// 시각은 실제 시각이다(그 논리적 하루로 자른 시각. 시간표 카드와 같음).
EventInfoContent eventInfoContent(
  DayItem item, {
  String courseName = '수업',
  required DateTime now,
  required int dayBoundaryMin,
}) {
  final start = item.span.start;
  final day = logicalDate(start, dayBoundaryMin: dayBoundaryMin);
  final today = logicalDate(now, dayBoundaryMin: dayBoundaryMin);
  final startMin = start.hour * 60 + start.minute;
  // 논리적 하루를 꽉 채운 일정(24시간)도 시간 범위로 쓸 수 있게 하루 안으로 줄인다(근거 시트와 같음).
  final length = item.span.minutes.clamp(1, 1439).toInt();
  final word = dayWord(start, now: now, dayBoundaryMin: dayBoundaryMin);
  String timeLine(String? place) => [
    monthDayText(day, today: today),
    timeRangeText(startMin, startMin + length),
    if (place != null && place.isNotEmpty) place,
  ].join(' · ');

  switch (item) {
    case ClassItem():
      final change = item.cancelled
          ? ClassDayChange.cancelled
          : item.exam
          ? ClassDayChange.exam
          : item.placeChanged
          ? ClassDayChange.placeChange
          : null;
      final past = day.isBefore(today);
      final lock = item.makeup
          ? '보강 수업이에요. 시간표에는 넣지 않았어요'
          : past
          ? '지난 수업은 바꿀 수 없어요'
          : null;
      return EventInfoContent(
        kind: EventInfoKind.classItem,
        kicker: item.makeup ? '보강' : change?.label ?? '수업',
        title: courseName,
        time: timeLine(item.slot.online ? '실시간 온라인' : item.place),
        dayWord: word,
        date: day,
        change: change,
        changeLabel: lock == null ? '$word 수업만 바꾸기' : null,
        lockText: lock,
      );
    case EventItem(:final event) when event.allDay:
      // 종일 일정('시간 미정' 일정 포함)은 날짜로만 쓴다. 저장된 시각은 그날 0시부터 다음 날 0시까지라 논리적
      // 하루가 아니라 달력 날짜로 센다.
      final first = DateTime(
        event.startAt.year,
        event.startAt.month,
        event.startAt.day,
      );
      final endDay = DateTime(
        event.endAt.year,
        event.endAt.month,
        event.endAt.day,
      );
      final last = event.endAt.isAfter(endDay)
          ? endDay
          : DateTime(endDay.year, endDay.month, endDay.day - 1);
      final dates = last.isAfter(first)
          ? '${monthDayText(first, today: today)} – '
                '${monthDayText(last, today: today)}'
          : monthDayText(first, today: today);
      return EventInfoContent(
        kind: EventInfoKind.event,
        kicker: '개인 일정',
        title: event.title,
        time: [
          dates,
          '종일',
          if (event.place case final place? when place.isNotEmpty) place,
        ].join(' · '),
        // 그날 낮을 넘겨 논리적 하루가 달력 날짜와 같게 센다.
        dayWord: dayWord(
          DateTime(first.year, first.month, first.day, 12),
          now: now,
          dayBoundaryMin: dayBoundaryMin,
        ),
        date: first,
        canEditBySpeech: !last.isBefore(today),
      );
    case EventItem(:final event):
      return EventInfoContent(
        kind: EventInfoKind.event,
        kicker: '개인 일정',
        title: event.title,
        time: timeLine(event.place),
        dayWord: word,
        date: day,
        canEditBySpeech: !day.isBefore(today),
      );
    case FixedItem(:final block):
      return EventInfoContent(
        kind: EventInfoKind.fixed,
        kicker: '고정 일정',
        title: block.name,
        time: timeLine(block.place),
        dayWord: word,
        date: day,
      );
    case TravelItem() || MealItem() || BlockItem():
      throw ArgumentError.value(item, 'item', '수업·일정·고정 일정만 받는다');
  }
}
