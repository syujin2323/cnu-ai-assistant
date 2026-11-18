// 일정 정보 시트를 열고 고른 동작을 한다. docs/screens.md '일정 정보 시트'.
//
// 02 홈의 시간표가 쓰고, 09 일간·11 주간·08 월간도 같은 것을 쓴다. 시트에 보일 것은 `domain/event_info.dart`가
// 정한다. 수업 하루 바꾸기는 `ClassExceptionRepository.setDayChange`, 일정 지우기는 `EventRepository.delete`가 하고
// 되돌리기를 남긴다(10초 되돌리기 토스트). 바뀌면 재계산이 이동 시간과 제안을 다시 놓는다(`PlanController`가 표
// 변경을 봄). [말로 바꾸기]는 06 AI 비서에 '{M}월 {D}일 {제목} '을 채워 열고, [시간표·고정 일정에서 바꾸기]는 13의
// 고정 일정 탭을 연다. 토스트 문구는 최종 프로토타입의 문구다(임시).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/event_info_sheet.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/event_info.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// [item](수업·일정·고정 일정)의 일정 정보 시트를 열고 고른 동작을 한다. 이동·점심·할 일 블록은 열지 않는다.
/// 하루 시간표에 없는 종일 일정은 `EventItem(TimeSpan(event.startAt, event.endAt), event: event)`로 넘긴다.
Future<void> openEventInfoSheet(
  BuildContext context,
  WidgetRef ref,
  DayItem item,
) async {
  if (item is TravelItem || item is MealItem || item is BlockItem) return;
  final now = ref.read(clockProvider).now();
  final boundary =
      ref.read(settingsProvider).value?.dayBoundaryMin ??
      Defaults.dayBoundaryMin;
  final courseName = switch (item) {
    ClassItem(:final slot) =>
      ref
              .read(classSlotEntriesProvider)
              .value
              ?.where((entry) => entry.course.id == slot.courseId)
              .firstOrNull
              ?.course
              .name ??
          '수업',
    _ => '수업',
  };
  final content = eventInfoContent(
    item,
    courseName: courseName,
    now: now,
    dayBoundaryMin: boundary,
  );
  final action = await showEventInfoSheet(
    context,
    ref.read(motionLevelProvider),
    content,
  );
  if (action == null || !context.mounted) return;

  switch ((action, item)) {
    case (ChangeClassDay(:final change, :final place), ClassItem item):
      await _changeClassDay(ref, item, content, change: change, place: place);
    case (EditEventBySpeech(), EventItem(:final event)):
      final date = content.date;
      await context.push(
        Routes.assistant,
        extra: AssistantArgs(
          prefill: '${date.month}월 ${date.day}일 ${event.title} ',
        ),
      );
    case (DeleteEvent(), EventItem(:final event)):
      await _deleteEvent(ref, event);
    case (OpenFixedBlocks(), FixedItem()):
      await context.push(Routes.meTimetableTab(TimetableTab.fixed));
    case _:
      // 항목과 맞지 않는 동작은 시트가 보이지 않는다.
      return;
  }
}

/// 수업 [item]의 그날을 [change]로 바꾸고 알린다. null이면 원래대로 돌린다.
Future<void> _changeClassDay(
  WidgetRef ref,
  ClassItem item,
  EventInfoContent content, {
  required ClassDayChange? change,
  required String? place,
}) async {
  final result = await ref
      .read(classExceptionRepositoryProvider)
      .setDayChange(
        item.slot.id,
        item.date,
        kind: change?.kind,
        place: change == ClassDayChange.placeChange ? place : null,
        source: EntrySource.manual,
        now: ref.read(clockProvider).now(),
      );
  final lesson = '${content.dayWord} ${content.title} 수업';
  final toast = ref.read(toastControllerProvider.notifier);
  switch (result) {
    case Ok(value: true):
      toast.show(switch (change) {
        null => '$lesson을 원래대로 돌렸어요',
        ClassDayChange.placeChange =>
          '$lesson 장소를 ${withJosa(place ?? '', Josa.euroRo)} 바꿨어요',
        _ => '$lesson을 ${withJosa(change.label, Josa.euroRo)} 표시했어요',
      }, undoable: true);
    case Ok(value: false):
      // 시트를 연 사이 다른 곳에서 이미 그렇게 바꿨다.
      return;
    case Err():
      toast.show('바꾸지 못했어요. 다시 해 주세요');
  }
}

/// 일정 [event]를 지우고 알린다.
Future<void> _deleteEvent(WidgetRef ref, Event event) async {
  final result = await ref
      .read(eventRepositoryProvider)
      .delete(event.id, now: ref.read(clockProvider).now());
  final toast = ref.read(toastControllerProvider.notifier);
  switch (result) {
    case Ok(value: true):
      toast.show('${withJosa(event.title, Josa.eulReul)} 지웠어요', undoable: true);
    case Ok(value: false):
      // 시트를 연 사이 이미 지워졌다.
      return;
    case Err():
      toast.show('지우지 못했어요. 다시 해 주세요');
  }
}
