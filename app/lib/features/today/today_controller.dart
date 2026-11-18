// 02 홈의 provider. docs/screens.md '02 홈', docs/architecture.md '화면과 기능 폴더'.
//
// [todayHomeProvider]는 오늘(논리적 하루)의 일정·규칙·할 일·수업 과목과 지금 시각을 묶어 시간표 항목과 머리
// 숫자를 낸다. [homeAnswerProvider]는 피드백 카드에서 방금 한 답을 들고 카드의 동작(답하기, 카드 안 되돌리기,
// 다시 놓기)을 한다. 답은 되돌리기 기록과 함께 남고, 화면을 떠나면 둘 다 버린다(docs/screens.md '되돌리기').
// 시간표의 블록 체크도 여기서 한다(토스트와 10초 되돌리기).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/toast_controller.dart';
import 'package:cnu_ai_assistant/data/repositories/undo_repository.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/home_feedback.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 02 홈이 그리는 오늘.
final class TodayHome {
  const TodayHome({
    required this.date,
    required this.now,
    required this.dayBoundaryMin,
    required this.items,
    required this.free,
    required this.windowEndMin,
    required this.courseNames,
    this.showTravelMeal = true,
  });

  /// 오늘(논리적 하루)의 날짜.
  final DateTime date;

  /// 지금(분 단위로 바뀜, [minuteClockProvider]).
  final DateTime now;

  final int dayBoundaryMin;

  /// 시간표 항목(`dayItems`, 제안 블록 제외).
  final List<DayItem> items;

  /// 오늘의 빈 구간(`DayAvailability.free`).
  final List<TimeSpan> free;

  /// 하루 창 끝(그날 0시 기준 분, 자정을 넘으면 1440 이상).
  final int windowEndMin;

  /// 과목 id → 과목 이름(수업 카드의 제목).
  final Map<int, String> courseNames;

  /// 10 나의 '이동·점심 시간 표시'(`settings`의 `showTravelMeal`). false면 시간표가 이동·점심 카드를 그리지 않는다
  /// ([items]에는 그대로 있다. 빈 시간은 그 시간을 이미 뺀 값이다).
  final bool showTravelMeal;

  /// 오늘의 블록(확정·완료·놓침).
  List<BlockItem> get blocks => [
    for (final item in items)
      if (item is BlockItem) item,
  ];

  /// 머리의 '남은 일정 N개': 지금 하거나 지금 뒤에 있는 수업(휴강 제외)·일정·고정 일정.
  int get eventsLeft => items
      .where(
        (item) =>
            switch (item) {
              ClassItem(:final cancelled) => !cancelled,
              EventItem() || FixedItem() => true,
              _ => false,
            } &&
            item.span.end.isAfter(now),
      )
      .length;

  /// 머리의 '할 일 N개': 지금 뒤에 끝나는 확정 블록.
  int get tasksLeft => blocks
      .where(
        (item) =>
            item.block.status == PlanBlockStatus.confirmed &&
            item.block.endAt.isAfter(now),
      )
      .length;
}

/// 오늘의 02 홈. 일정·규칙·할 일·수업을 아직 읽지 못했으면 불러오는 중이고, 읽지 못했으면 오류다(전에 읽은
/// 값이 있으면 그 값으로 계산함). 설정을 읽지 못하면 기본 하루 경계로 본다.
final todayHomeProvider = Provider<AsyncValue<TodayHome>>((ref) {
  final now = ref.watch(minuteClockProvider);
  final settings = ref.watch(settingsProvider);
  final boundary =
      settings.value?.dayBoundaryMin ??
      (settings.hasError ? Defaults.dayBoundaryMin : null);
  if (boundary == null) return const AsyncLoading();
  final date = logicalDate(now, dayBoundaryMin: boundary);
  final schedule = ref.watch(dayScheduleProvider(date));
  final rules = ref.watch(rulesProvider);
  final tasks = ref.watch(taskEntriesProvider);
  final slots = ref.watch(classSlotEntriesProvider);
  final scheduleValue = schedule.value;
  final rulesValue = rules.value;
  final tasksValue = tasks.value;
  final slotsValue = slots.value;
  if (scheduleValue == null ||
      rulesValue == null ||
      tasksValue == null ||
      slotsValue == null) {
    for (final value in [schedule, rules, tasks, slots]) {
      if (value case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
    }
    return const AsyncLoading();
  }
  final config = PlannerConfig.from(rulesValue);
  final availability = dayAvailability(
    date,
    schedule: scheduleValue,
    config: config,
    dayBoundaryMin: boundary,
  );
  final windows = availability.windows;
  return AsyncData(
    TodayHome(
      date: date,
      now: now,
      dayBoundaryMin: boundary,
      items: dayItems(
        date,
        schedule: scheduleValue,
        availability: availability,
        tasks: tasksValue,
        dayBoundaryMin: boundary,
      ),
      free: availability.free,
      windowEndMin: windows.isEmpty
          ? Defaults.dayWindowEndMin
          : windows.last.end.difference(date).inMinutes,
      courseNames: {
        for (final entry in slotsValue) entry.course.id: entry.course.name,
      },
      showTravelMeal:
          settings.value?.showTravelMeal ?? AppSettings.defaults.showTravelMeal,
    ),
  );
});

/// 피드백 카드에서 방금 한 답과 그 되돌리기 기록.
final class HomeAnswerState {
  const HomeAnswerState(this.answer, this.mark);

  final HomeAnswer answer;

  /// 이 답의 되돌리기 기록(카드 안 [되돌리기]와 화면을 떠날 때 버리기).
  final UndoMark mark;
}

/// 피드백 카드에서 방금 한 답. 없으면 null이다.
final homeAnswerProvider =
    NotifierProvider<HomeAnswerController, HomeAnswerState?>(
      HomeAnswerController.new,
    );

/// [homeAnswerProvider]의 노티파이어. 피드백 카드와 시간표 블록 체크의 동작을 한다.
class HomeAnswerController extends Notifier<HomeAnswerState?> {
  @override
  HomeAnswerState? build() {
    // 데모에 들어가거나 나오면 다른 DB이므로 답을 버린다(기록은 그 DB에 남아도 시간으로 버려짐).
    ref.watch(databaseProvider);
    return null;
  }

  /// [item]에 '했어요'·'끝냈어요'([did])나 '못 했어요'로 답한다. '못 했어요'면 [다시 놓기]가 놓을 자리를
  /// 먼저 찾는다(`retrySlot`, 오늘과 내일). 저장하지 못하면 토스트로 알리고 답을 두지 않는다.
  Future<void> answer(BlockItem item, {required bool did}) async {
    final now = _now();
    final slot = did ? null : await _retrySlot(item, now);
    switch (await ref
        .read(planBlockRepositoryProvider)
        .answer(item.block.id, did: did, now: now)) {
      case Ok(value: true):
        state = HomeAnswerState(
          HomeAnswer(blockId: item.block.id, did: did, slot: slot),
          UndoMark('plan_blocks', now),
        );
      case Ok():
        state = null;
      case Err(:final error):
        _failed('home_answer_failed', error);
    }
  }

  /// 카드 안 [되돌리기]. 방금 한 답을 되돌린다(시간 제한 없음). 그 뒤 다른 동작이 있었거나 되돌리지 못하면
  /// '되돌리지 못했어요'를 띄운다.
  Future<void> undo() async {
    final current = state;
    if (current == null) return;
    state = null;
    final result = await ref
        .read(undoRepositoryProvider)
        .undoLast(now: _now(), only: current.mark);
    if (result case Ok(value: true)) return;
    if (result case Err(:final error)) {
      appLog('home_undo_failed', area: 'today', data: errorLogData(error));
    }
    ref
        .read(toastControllerProvider.notifier)
        .show(ToastController.undoFailedText);
  }

  /// [다시 놓기]. 방금 '못 했어요'로 답한 블록의 할 일을 찾아 둔 자리에 직접 정한 확정 블록으로 놓고 10초
  /// 되돌리기 토스트를 띄운다.
  Future<void> retry() async {
    final current = state;
    final slot = current?.answer.slot;
    if (current == null || slot == null) return;
    final item = ref
        .read(todayHomeProvider)
        .value
        ?.blocks
        .where((block) => block.block.id == current.answer.blockId)
        .firstOrNull;
    if (item == null) {
      state = null;
      return;
    }
    final now = _now();
    state = null;
    switch (await ref
        .read(planBlockRepositoryProvider)
        .place(
          taskId: item.block.taskId,
          start: slot.start,
          end: slot.end,
          now: now,
        )) {
      case Ok(value: final id?):
        appLog('home_retry_placed', area: 'today', data: {'id': id});
        final title = _title(item);
        final when = _tomorrow(slot.start)
            ? '내일 ${_hhmm(slot.start)}'
            : _hhmm(slot.start);
        ref
            .read(toastControllerProvider.notifier)
            .show(
              '${withJosa(title, Josa.eulReul)} $when에 다시 놓았어요',
              undoable: true,
            );
      case Ok():
        break;
      case Err(:final error):
        _failed('home_retry_failed', error);
    }
  }

  /// [오늘은 괜찮아요]. 놓침으로 둔 채 다시 놓지 않는다.
  void skipRetry() {
    state = null;
    ref.read(toastControllerProvider.notifier).show('오늘은 다시 놓지 않을게요');
  }

  /// 다시 놓을 자리가 없을 때의 [확인].
  void dismiss() => state = null;

  /// 02 홈을 떠날 때 부른다. 방금 한 답과 그 되돌리기 기록을 버린다(그 뒤 다른 동작의 기록은 남김).
  Future<void> leave() async {
    final current = state;
    if (current == null) return;
    state = null;
    final result = await ref
        .read(undoRepositoryProvider)
        .discard(only: current.mark);
    if (result case Err(:final error)) {
      appLog(
        'home_undo_discard_failed',
        area: 'today',
        data: errorLogData(error),
      );
    }
  }

  /// 시간표 블록의 체크. 완료면 완료를 끄고, 아니면 완료로 바꾼 뒤 10초 되돌리기 토스트를 띄운다. 카드의 방금
  /// 한 답은 버린다(되돌리기 기록이 바뀌므로).
  Future<void> toggleBlock(BlockItem item) async {
    final now = _now();
    final repository = ref.read(planBlockRepositoryProvider);
    final done = item.block.status == PlanBlockStatus.done;
    state = null;
    final result = done
        ? await repository.uncomplete(item.block.id, now: now)
        : await repository.complete(item.block.id, now: now);
    switch (result) {
      case Ok(value: true):
        final title = _title(item);
        ref
            .read(toastControllerProvider.notifier)
            .show(
              done
                  ? '${withJosa(title, Josa.eulReul)} 다시 할 일로 돌렸어요'
                  : '$title · ${durationText(item.span.minutes)} 끝냈어요',
              undoable: true,
            );
      case Ok():
        break;
      case Err(:final error):
        _failed('home_block_check_failed', error);
    }
  }

  /// 오늘과 내일의 일정으로 [다시 놓기]가 놓을 자리를 찾는다. 읽지 못하면 null이다(자리가 없다고 보임).
  Future<TimeSpan?> _retrySlot(BlockItem item, DateTime now) async {
    final home = ref.read(todayHomeProvider).value;
    final entry = item.entry;
    final rules = ref.read(rulesProvider).value;
    if (home == null || entry == null || rules == null) return null;
    final tomorrow = DateTime(
      home.date.year,
      home.date.month,
      home.date.day + 1,
    );
    final schedule = await ref
        .read(scheduleRepositoryProvider)
        .read(
          start: logicalDayStart(
            home.date,
            dayBoundaryMin: home.dayBoundaryMin,
          ),
          end: logicalDayEnd(tomorrow, dayBoundaryMin: home.dayBoundaryMin),
        );
    switch (schedule) {
      case Ok(:final value):
        return retrySlot(
          now: now,
          block: item.block,
          entry: entry,
          schedule: value,
          config: PlannerConfig.from(rules),
          dayBoundaryMin: home.dayBoundaryMin,
        );
      case Err(:final error):
        appLog(
          'home_retry_read_failed',
          area: 'today',
          data: errorLogData(error),
        );
        return null;
    }
  }

  bool _tomorrow(DateTime at) {
    final home = ref.read(todayHomeProvider).value;
    if (home == null) return false;
    return logicalDate(at, dayBoundaryMin: home.dayBoundaryMin) != home.date;
  }

  void _failed(String event, AppError error) {
    appLog(event, area: 'today', data: errorLogData(error));
    ref.read(toastControllerProvider.notifier).show(AppStrings.saveFailed);
  }

  /// 지금(밀리초까지). 되돌리기 기록의 시각과 견주므로 저장하는 값과 같게 맞춘다.
  DateTime _now() {
    final now = ref.read(clockProvider).now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );
  }
}

/// 블록의 할 일 이름.
String _title(BlockItem item) => item.entry?.task.title ?? '할 일';

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);
