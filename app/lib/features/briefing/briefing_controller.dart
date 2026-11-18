// 01 아침 브리핑의 provider. docs/architecture.md '아침 브리핑', '화면 이동'.
//
// 그날(논리적 하루) 브리핑을 본 것으로 기록했는지 묻는 것과 기록하는 것을 둔다. 기록은 브리핑이 화면에 뜨는
// 순간 하고(docs/decisions.md 2026-11-13 '아침 브리핑은 뜨는 순간 본 것으로 기록한다'), 어느 길로 떠나든
// (앱을 그냥 꺼도) 그날은 다시 자동으로 띄우지 않는다. 01을 띄운 채 하루가 바뀌어 앱으로 돌아오면 01이 새 날을
// 다시 적는다(돌아올 때 01은 미루는 화면이라 시작 위치 규칙이 새로 띄우지 않으므로). 본 것·확정한 것을 읽고
// 쓰는 곳은 `BriefingRepository` 하나다(90일 지난 행은 `RetentionRepository`가, 데모를 끝낼 때는
// `DemoRepository.clearAll`이 지운다).
//
// 브리핑이 보일 것(어제 못 한 일·오늘 할 일)은 [briefingDataProvider]가 폰 DB와 배치 엔진의 마지막 결과로
// 계산하고(`domain/briefing.dart`), 체크와 확정은 [briefingSelectionProvider]가 한다. 체크는 화면을 떠나면
// 묻지 않고 버린다(확정하지 않은 체크는 저장하지 않음).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/briefing.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/suggest_slots.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오늘(논리적 하루)의 브리핑을 본 것으로 기록했는지 확인하는 함수.
typedef BriefingOpenedCheck = Future<bool> Function();

/// 오늘의 브리핑을 본 것으로 기록했는지 묻는다.
///
/// 시작 위치를 정하는 라우터의 redirect와 앱으로 돌아올 때의 확인이 부르고, 화면 테스트는 이 provider를
/// 덮어써 DB 없이 정한다. 부를 때마다 그때의 논리적 하루로 다시 묻는다. 설정(하루 경계)이나 기록을 읽지
/// 못하면 브리핑도 보여 줄 수 없으므로 본 것으로 보고 오늘로 보내게 한다.
final briefingOpenedTodayProvider = Provider<BriefingOpenedCheck>((ref) {
  return () async {
    final briefings = ref.read(briefingRepositoryProvider);
    final today = await _logicalToday(ref);
    if (today == null) return true;
    switch (await briefings.isSeen(today)) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        appLog(
          'briefing_check_failed',
          area: 'briefing',
          data: errorLogData(error),
        );
        return true;
    }
  };
});

/// 오늘의 브리핑을 본 것으로 적는 함수. 적은 논리적 하루를 돌려주고, 적지 않았거나 적지 못했으면 null이다.
typedef BriefingSeenMark = Future<DateTime?> Function();

/// 오늘(논리적 하루)의 브리핑을 본 것으로 적는다. 01 아침 브리핑이 화면에 뜨는 순간과, 01을 띄운 채 앱으로
/// 돌아왔을 때 부른다. 적지 못하면 기록만 남긴다(그러면 다음에 앱을 열 때 브리핑이 다시 뜬다).
///
/// 적을 DB(저장소)와 시각은 부르는 순간에 정한다. 설정을 읽는 동안 데모를 끝내기 시작했거나 모드가 바뀌었으면
/// 적지 않는다. 데모에서 본 브리핑이 실제 DB에 적히거나, 비운 데모 DB에 남아 다음 데모의 샘플을 막지 않게
/// 하기 위해서다.
final markBriefingSeenProvider = Provider<BriefingSeenMark>((ref) {
  return () async {
    final briefings = ref.read(briefingRepositoryProvider);
    final mode = ref.read(appModeProvider);
    final now = ref.read(clockProvider).now();
    final today = await _logicalToday(ref, now: now);
    if (today == null) return null;
    if (ref.read(appModeProvider) != mode ||
        ref.read(appModeProvider.notifier).exiting) {
      return null;
    }
    switch (await briefings.markSeen(today, at: now)) {
      case Ok():
        return today;
      case Err(:final error):
        appLog(
          'briefing_mark_seen_failed',
          area: 'briefing',
          data: errorLogData(error),
        );
        return null;
    }
  };
});

/// [now](없으면 지금)의 논리적 하루. 설정(하루 경계)을 읽지 못하면 기록만 남기고 null이다.
Future<DateTime?> _logicalToday(Ref ref, {DateTime? now}) async {
  final at = now ?? ref.read(clockProvider).now();
  switch (await ref.read(settingsRepositoryProvider).read()) {
    case Ok(:final value):
      return logicalDate(at, dayBoundaryMin: value.dayBoundaryMin);
    case Err(:final error):
      appLog(
        'briefing_settings_read_failed',
        area: 'briefing',
        data: errorLogData(error),
      );
      return null;
  }
}

/// 01 아침 브리핑이 [day](논리적 하루)에 보일 것과 체크를 확정할 때 쓸 값.
final class BriefingData {
  BriefingData({
    required this.day,
    required this.now,
    required this.dayBoundaryMin,
    required this.content,
    required this.schedule,
    required this.config,
    required Map<int, BlockReason> reasons,
  }) : reasons = Map.unmodifiable(reasons);

  /// 논리적 하루(그날 0시).
  final DateTime day;

  /// 지금(분 단위).
  final DateTime now;

  final int dayBoundaryMin;
  final BriefingContent content;

  /// 그날의 일정(체크한 할 일의 자리를 찾을 때 씀).
  final Schedule schedule;

  final PlannerConfig config;

  /// 배치 엔진이 할 일마다 낸 근거(그 할 일의 첫 제안). 제안 자리가 아닌 곳에 확정할 때 여유도와 급한 순번을
  /// 가져온다.
  final Map<int, BlockReason> reasons;

  /// 그날 하루 최대 공부량(분). 규칙이 없으면 null이다.
  int? get dailyCapMin => config.forWeekday(day.weekday).dailyCapMin;
}

/// 01 아침 브리핑이 [day](논리적 하루)에 보일 것. 그날과 전날의 일정, 할 일, 규칙, 배치 엔진의 마지막 결과(급한
/// 순서와 근거)로 계산한다. 아직 읽지 못한 것이 있으면 로딩이고, 그중 읽기에 실패한 것이 있으면 오류다.
final briefingDataProvider =
    Provider.family<AsyncValue<BriefingData>, DateTime>((ref, day) {
      final now = ref.watch(minuteClockProvider);
      final settings = ref.watch(settingsProvider);
      final boundary =
          settings.value?.dayBoundaryMin ??
          (settings.hasError ? Defaults.dayBoundaryMin : null);
      if (boundary == null) return const AsyncLoading();
      final date = DateTime(day.year, day.month, day.day);
      final today = ref.watch(dayScheduleProvider(date));
      final yesterday = ref.watch(
        dayScheduleProvider(DateTime(date.year, date.month, date.day - 1)),
      );
      final rules = ref.watch(rulesProvider);
      final tasks = ref.watch(taskEntriesProvider);
      final plan = ref.watch(planControllerProvider);
      final todayValue = today.value;
      final yesterdayValue = yesterday.value;
      final rulesValue = rules.value;
      final tasksValue = tasks.value;
      if (todayValue == null ||
          yesterdayValue == null ||
          rulesValue == null ||
          tasksValue == null) {
        for (final value in [today, yesterday, rules, tasks]) {
          if (value case AsyncError(:final error, :final stackTrace)) {
            return AsyncError(error, stackTrace);
          }
        }
        return const AsyncLoading();
      }
      final config = PlannerConfig.from(rulesValue);
      final reasons = <int, BlockReason>{};
      for (final draft in plan?.blocks ?? const <BlockDraft>[]) {
        if (draft.reason case final reason?) {
          reasons.putIfAbsent(draft.taskId, () => reason);
        }
      }
      for (final block in todayValue.planBlocks) {
        if (block.reason case final reason?) {
          reasons.putIfAbsent(block.taskId, () => reason);
        }
      }
      return AsyncData(
        BriefingData(
          day: date,
          now: now,
          dayBoundaryMin: boundary,
          content: briefingContent(
            now: now,
            today: todayValue.planBlocks,
            yesterday: yesterdayValue.planBlocks,
            tasks: tasksValue,
            ranked: plan?.ranked ?? const [],
            config: config,
          ),
          schedule: todayValue,
          config: config,
          reasons: reasons,
        ),
      );
    });

/// 01 아침 브리핑의 체크.
final class BriefingSelection {
  BriefingSelection({
    required Map<String, BlockDraft> picks,
    this.edits = 0,
    this.sort = BriefingSort.recommended,
    this.ready = true,
  }) : picks = Map.unmodifiable(picks);

  /// 아직 브리핑을 읽지 못해 체크를 정하지 않았다.
  BriefingSelection.loading()
    : picks = const {},
      edits = 0,
      sort = BriefingSort.recommended,
      ready = false;

  /// 체크한 것: 줄의 열쇠([taskKey]·[missedKey], 화면에 줄이 없는 전 브리핑 확정은 'block:{id}')에서 놓을 블록
  /// 초안으로.
  final Map<String, BlockDraft> picks;

  /// 확정하기 전에 체크를 켜고 끈 횟수(사용 지표).
  final int edits;

  final BriefingSort sort;
  final bool ready;

  /// 오늘 할 일 줄의 열쇠.
  static String taskKey(int taskId) => 'task:$taskId';

  /// 어제 못 한 일 줄의 열쇠.
  static String missedKey(int blockId) => 'missed:$blockId';

  BriefingSelection copyWith({
    Map<String, BlockDraft>? picks,
    int? edits,
    BriefingSort? sort,
  }) => BriefingSelection(
    picks: picks ?? this.picks,
    edits: edits ?? this.edits,
    sort: sort ?? this.sort,
    ready: ready,
  );
}

/// 01 아침 브리핑의 체크와 확정. [day]는 브리핑이 보이는 논리적 하루이고, 화면을 떠나면 체크를 버린다.
final briefingSelectionProvider = NotifierProvider.autoDispose
    .family<BriefingSelectionController, BriefingSelection, DateTime>(
      BriefingSelectionController.new,
    );

/// [briefingSelectionProvider]의 노티파이어.
class BriefingSelectionController extends Notifier<BriefingSelection> {
  BriefingSelectionController(this.day);

  final DateTime day;

  @override
  BriefingSelection build() {
    // 처음 읽은 브리핑으로 체크를 정하고, 그 뒤 브리핑이 다시 계산돼도(재계산·분 바뀜) 체크는 그대로 둔다.
    final data = ref.read(briefingDataProvider(day)).value;
    if (data != null) return _initial(data);
    ref.listen(briefingDataProvider(day), (_, next) {
      if (state.ready) return;
      if (next.value case final data?) state = _initial(data);
    });
    return BriefingSelection.loading();
  }

  /// 전에 브리핑에서 확정한 것을 체크된 채로 둔다.
  BriefingSelection _initial(BriefingData data) {
    final content = data.content;
    final keys = <int, String>{
      for (final task in content.tasks)
        if (task.kind == BriefingTaskKind.confirmed && task.block != null)
          task.block!.id: BriefingSelection.taskKey(task.taskId),
      for (final missed in content.missed)
        if (missed.placed != null)
          missed.placed!.id: BriefingSelection.missedKey(missed.block.id),
    };
    return BriefingSelection(
      picks: {
        for (final block in content.previous)
          keys[block.id] ?? 'block:${block.id}': BlockDraft(
            taskId: block.taskId,
            startAt: block.startAt,
            endAt: block.endAt,
            source: block.source,
            reason: block.reason,
          ),
      },
    );
  }

  /// 오늘 할 일 [task]의 체크를 켜거나 끈다. 잠긴 줄은 바꾸지 않는다. 켤 때 놓을 자리가 없으면 체크하지 않고
  /// '오늘은 빈 시간이 없어요'를 띄운다.
  void toggleTask(BriefingTask task) {
    final minutes = task.minutes;
    if (task.kind == BriefingTaskKind.locked || minutes == null) return;
    _toggle(
      BriefingSelection.taskKey(task.taskId),
      entryTask: task,
      minutes: minutes,
      suggestion: task.block,
    );
  }

  /// 어제 못 한 일 [missed]의 체크를 켜거나 끈다. 켜면 그 블록 길이만큼 오늘 빈 자리에 넣는다.
  void toggleMissed(BriefingMissed missed) => _toggle(
    BriefingSelection.missedKey(missed.block.id),
    entryMissed: missed,
    minutes: missed.minutes,
    suggestion: missed.placed,
  );

  void _toggle(
    String key, {
    BriefingTask? entryTask,
    BriefingMissed? entryMissed,
    required int minutes,
    PlanBlock? suggestion,
  }) {
    final current = state;
    if (!current.ready) return;
    if (current.picks.containsKey(key)) {
      state = current.copyWith(
        picks: {...current.picks}..remove(key),
        edits: current.edits + 1,
      );
      return;
    }
    final data = ref.read(briefingDataProvider(day)).value;
    final entry = entryTask?.entry ?? entryMissed?.entry;
    if (data == null || entry == null) return;
    final slot = briefingSlot(
      now: ref.read(clockProvider).now(),
      entry: entry,
      minutes: minutes,
      preferred: suggestion == null
          ? null
          : TimeSpan(suggestion.startAt, suggestion.endAt),
      schedule: data.schedule,
      replaced: data.content.replacedIds,
      taken: [
        for (final pick in current.picks.values)
          TimeSpan(pick.startAt, pick.endAt),
      ],
      config: data.config,
      dayBoundaryMin: data.dayBoundaryMin,
    );
    if (slot == null) {
      ref.read(toastControllerProvider.notifier).show(noFreeTimeText);
      return;
    }
    state = current.copyWith(
      picks: {
        ...current.picks,
        key: briefingDraft(
          entry: entry,
          slot: slot,
          suggestion: suggestion,
          base: data.reasons[entry.task.id],
        ),
      },
      edits: current.edits + 1,
    );
  }

  /// 오늘 할 일의 정렬을 바꾼다.
  void setSort(BriefingSort sort) => state = state.copyWith(sort: sort);

  /// 아래 고정 버튼. '오늘 시작하기'면 아무것도 쓰지 않고, 'N개 확정하기'·'확정한 할 일 빼기'면 오늘 시작 전인
  /// 자동 확정 블록과 브리핑 확정 블록을 지우고 체크한 것을 넣은 뒤(10초 되돌리기) 확정한 것으로 기록한다.
  /// 저장하지 못하면 '저장하지 못했어요'를 띄우고 false다.
  Future<bool> confirm() async {
    final data = ref.read(briefingDataProvider(day)).value;
    final current = state;
    if (data == null || !current.ready) return false;
    final action = briefingAction(
      picks: current.picks.values,
      previous: data.content.previous,
    );
    if (action == BriefingActionKind.start) return true;
    final now = _now();
    final drafts = [...current.picks.values]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    switch (await ref
        .read(planBlockRepositoryProvider)
        .confirmFromBriefing(
          dayStart: logicalDayStart(day, dayBoundaryMin: data.dayBoundaryMin),
          dayEnd: logicalDayEnd(day, dayBoundaryMin: data.dayBoundaryMin),
          drafts: drafts,
          now: now,
        )) {
      case Ok():
        break;
      case Err(:final error):
        _failed('briefing_confirm_failed', error);
        return false;
    }
    final edits = current.edits;
    if (ref.mounted) state = state.copyWith(edits: 0);
    if (await ref
            .read(briefingRepositoryProvider)
            .markConfirmed(day, at: now, edits: edits)
        case Err(:final error)) {
      appLog(
        'briefing_mark_confirmed_failed',
        area: 'briefing',
        data: errorLogData(error),
      );
    }
    ref
        .read(toastControllerProvider.notifier)
        .show(
          action == BriefingActionKind.clear
              ? '확정한 할 일을 뺐어요'
              : '할 일 ${drafts.length}개를 확정했어요',
          undoable: true,
        );
    return true;
  }

  /// 어제 못 한 일 [missed]의 [했어요]. 어제 한 것으로 기록하고(10초 되돌리기) 그 줄의 체크를 거둔다.
  Future<void> didYesterday(BriefingMissed missed) async {
    final now = _now();
    switch (await ref
        .read(planBlockRepositoryProvider)
        .answer(missed.block.id, did: true, now: now)) {
      case Ok(value: true):
        final key = BriefingSelection.missedKey(missed.block.id);
        if (ref.mounted && state.picks.containsKey(key)) {
          state = state.copyWith(picks: {...state.picks}..remove(key));
        }
        ref
            .read(toastControllerProvider.notifier)
            .show(
              '${withJosa(missed.entry.task.title, Josa.eulReul)} 어제 한 것으로 '
              '기록했어요',
              undoable: true,
            );
      case Ok():
        break;
      case Err(:final error):
        _failed('briefing_did_yesterday_failed', error);
    }
  }

  /// 체크할 자리가 없을 때의 안내(임시 문구).
  static const String noFreeTimeText = '오늘은 빈 시간이 없어요';

  void _failed(String event, AppError error) {
    appLog(event, area: 'briefing', data: errorLogData(error));
    ref.read(toastControllerProvider.notifier).show(AppStrings.saveFailed);
  }

  /// 저장에 쓰는 지금(밀리초 단위로 자름. 되돌리기 기록 시각과 견줄 때 같게).
  DateTime _now() {
    final now = ref.read(clockProvider).now();
    return DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch);
  }
}
