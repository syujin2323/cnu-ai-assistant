// 01 계획(셸 밖 전체 화면 `/briefing`. 코드 이름은 briefing 그대로). docs/screens.md '01 계획',
// docs/architecture.md '계획 화면'. 예전 이름은 '아침 브리핑'이다(docs/decisions.md 2026-11-19 ''아침 브리핑'을
// '계획'으로 부르고 02 홈에서도 연다').
//
// 그날(논리적 하루) 아직 보지 않았으면 앱을 열 때 먼저 뜨고, 뜨는 순간 그날을 본 것으로 기록한다
// (어느 길로 떠나든 그날은 다시 자동으로 띄우지 않음). 들어오는 길은 앱 열기, 14 온보딩, 데모 진입, 02 홈 머리의
// [계획]이다. 02 홈에서 열었으면(push) 닫을 때 02 홈으로 돌아가고, 자동으로 떴으면 02 홈(`/today`)으로 간다.
// 01을 띄운 채 하루가 바뀌어 앱으로 돌아오면 새 날을 본 것으로 적고 그날로 다시 그린다. 돌아올 때 01은 미루는
// 화면이라 시작 위치 규칙이 새로 띄우지 않으므로, 그대로 두면 어제 화면이 남고 새 날은 적히지 않는다.
//
// 위에서부터 머리(날짜와 닫기) → 오늘 일정 → 어제 못 한 일 → 오늘 할 일(5개까지, 임시. 체크한 것만 확정) → LMS
// 상태 줄과 '할 일 전체 보기 · N개' → 말로 추가 칸 → 아래 고정 버튼('오늘 시작하기'/'N개 확정하기'/'확정한 할
// 일 빼기')이다. 무엇을 보일지와 체크·확정은 `briefing_controller.dart`가 한다. 확정해도 이 화면에 남고 버튼이
// '오늘 시작하기'로 바뀐다. 잠긴 줄을 눌러 여는 근거 시트는 W5 PR에서 붙인다. AI 문장과 챙길 것은 두지 않는다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/briefing.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/widgets/briefing_day.dart';
import 'package:cnu_ai_assistant/features/briefing/widgets/briefing_rows.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 01 아침 브리핑.
class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  late final AppLifecycleListener _lifecycle;

  /// 이 화면이 보이는 논리적 하루(본 것으로 적은 날). 처음 적기 전이나 적지 못했으면 null이다.
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _markSeen);
    // 화면에 뜨는 순간 그날 브리핑을 본 것으로 적는다.
    _markSeen();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 지금의 논리적 하루를 본 것으로 적는다. 띄운 채로 하루가 바뀌었으면 그날로 다시 그린다(내용은 열 때
  /// 계산하므로).
  void _markSeen() {
    unawaited(
      ref.read(markBriefingSeenProvider)().then((day) {
        if (!mounted || day == null || day == _day) return;
        setState(() => _day = day);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 적지 못했으면(폰 DB 오류) 오늘(논리적 하루)을 그대로 보인다.
    final day = _day ?? ref.watch(todayHomeProvider).value?.date;
    return Scaffold(
      body: day == null
          ? const SizedBox.shrink()
          // 하루가 바뀌면 그날 내용으로 새로 만든다(체크도 그날 것).
          : _BriefingBody(key: ValueKey(day), day: day),
    );
  }
}

/// 그날의 브리핑 내용과 아래 고정 버튼.
class _BriefingBody extends ConsumerStatefulWidget {
  const _BriefingBody({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<_BriefingBody> createState() => _BriefingBodyState();
}

class _BriefingBodyState extends ConsumerState<_BriefingBody> {
  final _sentence = TextEditingController();

  /// 확정을 저장하는 중(버튼을 막음).
  bool _saving = false;

  @override
  void dispose() {
    _sentence.dispose();
    super.dispose();
  }

  DateTime get day => widget.day;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final data = ref.watch(briefingDataProvider(day));
    final selection = ref.watch(briefingSelectionProvider(day));
    final value = data.value;
    final action = value == null
        ? BriefingActionKind.start
        : briefingAction(
            picks: selection.picks.values,
            previous: value.content.previous,
          );
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpace.screen,
              AppSpace.s16,
              AppSpace.screen,
              MediaQuery.paddingOf(context).bottom + 120,
            ),
            children: [
              _Header(day: day, onClose: _leave),
              if (value != null && selection.ready)
                ..._sections(context, value, selection)
              else if (data.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s24),
                  child: Text(
                    '계획을 불러오지 못했어요',
                    style: AppText.body.copyWith(color: colors.muted),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _CtaBar(
            action: action,
            count: selection.picks.length,
            busy: _saving,
            onPressed: () => _press(action),
          ),
        ),
      ],
    );
  }

  /// 이 화면을 떠난다. 02 홈에서 열었으면 돌아가고, 자동으로 떴으면(시작 위치) 02 홈으로 간다.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.today);
    }
  }

  Future<void> _press(BriefingActionKind action) async {
    if (action == BriefingActionKind.start) {
      _leave();
      return;
    }
    setState(() => _saving = true);
    await ref.read(briefingSelectionProvider(day).notifier).confirm();
    if (mounted) setState(() => _saving = false);
  }

  List<Widget> _sections(
    BuildContext context,
    BriefingData data,
    BriefingSelection selection,
  ) {
    final content = data.content;
    final tasks = ref.watch(taskEntriesProvider).value ?? const <TaskEntry>[];
    final titles = {for (final entry in tasks) entry.task.id: entry.task.title};
    return [
      Rise(
        delay: const Duration(milliseconds: 160),
        child: _TodaySchedule(data: data, selection: selection, titles: titles),
      ),
      if (content.missed.isNotEmpty)
        Rise(
          delay: const Duration(milliseconds: 260),
          child: _Yesterday(data: data, selection: selection),
        ),
      Rise(
        delay: const Duration(milliseconds: 320),
        child: _TodayTasks(data: data, selection: selection),
      ),
      Rise(
        delay: const Duration(milliseconds: 380),
        child: _Footer(remaining: content.remainingCount),
      ),
      Rise(
        delay: const Duration(milliseconds: 420),
        child: _SentenceField(controller: _sentence, onSend: _send),
      ),
    ];
  }

  /// 말로 추가: 06 AI 비서가 그 문장을 바로 보낸다.
  void _send() {
    final text = _sentence.text.trim();
    if (text.isEmpty) return;
    _sentence.clear();
    unawaited(
      context.push(
        Routes.assistant,
        extra: AssistantArgs(prefill: text, sendNow: true),
      ),
    );
  }
}

/// 머리: '아침 브리핑'과 날짜, 닫기.
class _Header extends StatelessWidget {
  const _Header({required this.day, required this.onClose});

  final DateTime day;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Rise(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIcon(
                        AppIconName.today,
                        size: 16,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '계획',
                        style: AppText.small.copyWith(
                          fontWeight: AppText.semibold,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        text: '${day.month}월 ${day.day}일 ',
                        children: [
                          TextSpan(
                            text: '(${weekdayText(day.weekday)})',
                            style: TextStyle(
                              color: colors.muted,
                              fontWeight: AppText.medium,
                            ),
                          ),
                        ],
                      ),
                      style: AppText.display,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Press(
          child: IconButton(
            tooltip: '계획 닫기',
            onPressed: onClose,
            style: IconButton.styleFrom(
              backgroundColor: colors.tint,
              minimumSize: const Size.square(AppSize.minTouch),
            ),
            icon: AppIcon(AppIconName.close, size: 18, color: colors.accent),
          ),
        ),
      ],
    );
  }
}

/// 구역 머리(제목과 오른쪽 덧붙임).
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppText.body.copyWith(
                    fontWeight: AppText.semibold,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (trailing case final widget?) ...[
              const SizedBox(width: AppSpace.s8),
              widget,
            ],
          ],
        ),
      ),
    );
  }
}

/// 오늘 일정: 작은 세로 시간표와 '고른 할 일' 표시.
class _TodaySchedule extends ConsumerWidget {
  const _TodaySchedule({
    required this.data,
    required this.selection,
    required this.titles,
  });

  final BriefingData data;
  final BriefingSelection selection;
  final Map<int, String> titles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final home = ref.watch(todayHomeProvider).value;
    final replaced = data.content.replacedIds;
    final kept = [
      for (final block in data.schedule.planBlocks)
        if ((block.status == PlanBlockStatus.confirmed ||
                block.status == PlanBlockStatus.done) &&
            !replaced.contains(block.id))
          block,
    ];
    final tasks = [
      for (final block in kept)
        BriefingDayTask(
          title: titles[block.taskId] ?? '할 일',
          span: TimeSpan(block.startAt, block.endAt),
          dim:
              block.status == PlanBlockStatus.done ||
              !block.endAt.isAfter(data.now),
        ),
      for (final pick in selection.picks.values)
        BriefingDayTask(
          title: titles[pick.taskId] ?? '할 일',
          span: TimeSpan(pick.startAt, pick.endAt),
        ),
    ];
    final sameDay = home != null && home.date == data.day;
    // 10 나에서 이동·점심 시간 표시를 끄면 그 카드를 그리지 않는다(docs/screens.md '이동·점심 시간 표시').
    final items = sameDay
        ? [
            for (final item in home.items)
              if (home.showTravelMeal ||
                  (item is! TravelItem && item is! MealItem))
                item,
          ]
        : const <DayItem>[];
    final classes = items
        .whereType<ClassItem>()
        .where((item) => !item.cancelled)
        .length;
    var freeMin = 0;
    if (sameDay) {
      for (final span in spansFrom(home.free, data.now)) {
        if (span.minutes >= 15) freeMin += span.minutes;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          title: '오늘 일정',
          trailing: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.taskInk, width: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '고른 할 일',
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        BriefingDay(
          day: data.day,
          now: data.now,
          items: items,
          tasks: tasks,
          windowEndMin: sameDay ? home.windowEndMin : 1380,
          courseNames: sameDay ? home.courseNames : const {},
          semanticsLabel:
              '오늘 일정. 수업 $classes개, 빈 시간 ${durationText(freeMin)}, '
              '고른 할 일 ${selection.picks.length}개',
        ),
      ],
    );
  }
}

/// 어제 못 한 일.
class _Yesterday extends ConsumerWidget {
  const _Yesterday({required this.data, required this.selection});

  final BriefingData data;
  final BriefingSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(briefingSelectionProvider(data.day).notifier);
    final yesterday = DateTime(data.day.year, data.day.month, data.day.day - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          title: '어제 못 한 일',
          trailing: Text(
            monthDayText(yesterday, today: data.day),
            style: AppText.caption.copyWith(color: colors.muted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            "했으면 '했어요'를, 오늘 하려면 체크해 주세요",
            style: AppText.caption.copyWith(color: colors.muted),
          ),
        ),
        const SizedBox(height: 10),
        BriefingList(
          children: [
            for (final missed in data.content.missed)
              _missedRow(missed, controller),
          ],
        ),
      ],
    );
  }

  Widget _missedRow(
    BriefingMissed missed,
    BriefingSelectionController controller,
  ) {
    final task = missed.entry.task;
    final pick = selection.picks[BriefingSelection.missedKey(missed.block.id)];
    final yesterdayRange = _range(missed.block.startAt, missed.block.endAt);
    final when = pick == null
        ? '어제 $yesterdayRange'
        : '오늘 ${_range(pick.startAt, pick.endAt)}';
    // 마감이 지났으면 오늘에 넣을 수 없다([했어요]만 됨).
    final due = task.dueAt;
    final canPlace = due == null || due.isAfter(data.now);
    return BriefingMissedRow(
      canPlace: canPlace,
      title: task.title,
      when: when,
      whenPlaced: pick != null,
      due: _due(task.dueAt, task.dueTimeUnknown, data),
      dueSoon: _dueSoon(task.dueAt, data),
      on: pick != null,
      onToggle: () => controller.toggleMissed(missed),
      onDone: () => unawaited(controller.didYesterday(missed)),
      toggleLabel:
          '${task.title}, 어제 ${_hhmm(missed.block.startAt)}부터 '
          '${_hhmm(missed.block.endAt)}, 못 한 일, '
          '${!canPlace
              ? '마감이 지나 오늘 일정에 넣을 수 없음'
              : pick == null
              ? '오늘 일정에 넣기'
              : '오늘 ${_range(pick.startAt, pick.endAt)}에 넣음, 빼기'}',
      doneLabel: '${task.title} 어제 했어요로 기록하기',
    );
  }
}

/// 오늘 할 일: [추천순 | 시간순], 고른 수와 합계, 줄, 하루 최대 공부량 안내.
class _TodayTasks extends ConsumerWidget {
  const _TodayTasks({required this.data, required this.selection});

  final BriefingData data;
  final BriefingSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(briefingSelectionProvider(data.day).notifier);
    final content = data.content;
    final picks = selection.picks;
    final rows = sortBriefingTasks(
      content.tasks,
      selection.sort,
      startOf: (task) =>
          picks[BriefingSelection.taskKey(task.taskId)]?.startAt ??
          task.span?.start,
    );
    var pickedMin = 0;
    for (final pick in picks.values) {
      pickedMin += pick.endAt.difference(pick.startAt).inMinutes;
    }
    final cap = data.dailyCapMin;
    final over =
        cap != null &&
        briefingLoadMin(
              picks: picks.values,
              today: data.schedule.planBlocks,
              replaced: content.replacedIds,
            ) >
            cap;
    final same =
        content.previous.isNotEmpty &&
        briefingAction(picks: picks.values, previous: content.previous) ==
            BriefingActionKind.start;
    final recommended = content.tasks
        .where(
          (task) =>
              task.kind == BriefingTaskKind.suggested ||
              task.kind == BriefingTaskKind.confirmed,
        )
        .length;
    final note = picks.isEmpty
        ? (recommended > 0
              ? '추천 $recommended개 · 체크하면 오늘 일정에 들어가요'
              : '체크하면 오늘 일정에 들어가요')
        : '${same ? '오늘 확정한 할 일' : '고른 할 일'} ${picks.length}개';
    final noteStyle = AppText.caption.copyWith(color: colors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          title: '오늘 할 일',
          trailing: SizedBox(
            width: 136,
            height: 40,
            child: SegmentedButton<BriefingSort>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: AppText.small.copyWith(fontSize: 13),
                padding: EdgeInsets.zero,
              ),
              segments: const [
                ButtonSegment(
                  value: BriefingSort.recommended,
                  label: Text('추천순', maxLines: 1, softWrap: false),
                ),
                ButtonSegment(
                  value: BriefingSort.time,
                  label: Text('시간순', maxLines: 1, softWrap: false),
                ),
              ],
              selected: {selection.sort},
              onSelectionChanged: (chosen) => controller.setSort(chosen.single),
            ),
          ),
        ),
        if (content.tasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s4),
            child: Text.rich(
              TextSpan(
                text: note,
                children: [
                  if (picks.isNotEmpty) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: durationText(pickedMin),
                      style: over
                          ? TextStyle(
                              color: colors.alert,
                              fontWeight: AppText.semibold,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
              style: noteStyle,
            ),
          ),
          const SizedBox(height: 10),
          BriefingList(
            children: [
              for (final task in rows)
                _taskRow(context, ref, task, controller, same),
            ],
          ),
        ] else
          const _NothingToPick(),
        if (over)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                AppIcon(AppIconName.warning, size: 14, color: colors.alert),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '하루 공부 ${durationText(cap)}(내 규칙)을 넘어요',
                    style: AppText.caption.copyWith(
                      fontWeight: AppText.medium,
                      color: colors.alert,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _taskRow(
    BuildContext context,
    WidgetRef ref,
    BriefingTask task,
    BriefingSelectionController controller,
    bool same,
  ) {
    final colors = AppColors.of(context);
    final entry = task.entry.task;
    final pick = selection.picks[BriefingSelection.taskKey(task.taskId)];
    final locked = task.kind == BriefingTaskKind.locked;
    final block = task.block;
    final span = locked
        ? task.span
        : (pick == null ? task.span : TimeSpan(pick.startAt, pick.endAt));
    final minutes = span?.minutes ?? task.minutes ?? 0;
    final time = span == null ? null : _range(span.start, span.end);
    final timeMuted = !locked && pick == null;
    String? tag;
    Color? tagColor;
    if (locked && block != null) {
      tag = _lockedTag(block, data.now);
      tagColor = colors.muted;
    } else if (pick != null &&
        same &&
        task.kind == BriefingTaskKind.confirmed &&
        block != null &&
        pick.startAt == block.startAt &&
        pick.endAt == block.endAt) {
      tag = '확정';
      tagColor = colors.ink2;
    } else if (pick == null &&
        (task.kind == BriefingTaskKind.suggested ||
            task.kind == BriefingTaskKind.confirmed)) {
      tag = '추천';
      tagColor = colors.accent;
    }
    final on = locked || pick != null;
    final action = locked
        ? (block == null ? '' : ', 근거 보기')
        : (pick != null ? ', 오늘 일정에서 빼기' : ', 오늘 일정에 넣기');
    return BriefingTaskRow(
      title: entry.title,
      meta: '${taskKindText(entry.kind)} · ',
      due: _due(entry.dueAt, entry.dueTimeUnknown, data),
      dueSoon: _dueSoon(entry.dueAt, data),
      tail: ' · ${durationText(minutes)}',
      on: on,
      locked: locked,
      time: time,
      timeMuted: timeMuted,
      tag: tag,
      tagColor: tagColor,
      // 잠긴 줄(오늘 이미 확정·완료한 블록)은 근거 시트를 연다(docs/screens.md '근거 시트').
      onTap: locked
          ? (block == null ? null : () => openBlockSheet(context, ref, block))
          : () => controller.toggleTask(task),
      semanticsLabel:
          '${entry.title}'
          '${time == null ? '' : ', ${on ? '오늘' : '추천 시간'} $time'}'
          '${tag == null ? '' : ', $tag'}$action',
    );
  }

  /// 잠긴 줄의 상태.
  String _lockedTag(PlanBlock block, DateTime now) {
    if (block.status == PlanBlockStatus.done) return '완료';
    if (!block.startAt.isAfter(now) && block.endAt.isAfter(now)) {
      return '진행 중';
    }
    if (!block.endAt.isAfter(now)) return '지남';
    return block.source == BlockSource.manual ? '직접 놓음' : '진행 전';
  }
}

/// 고를 할 일이 없을 때.
class _NothingToPick extends StatelessWidget {
  const _NothingToPick();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s8),
      padding: const EdgeInsets.all(AppSpace.card),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              AppIconName.checkSquare,
              size: 18,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 고를 할 일이 없어요',
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
                const SizedBox(height: 2),
                Text(
                  '빈 시간은 그대로 둘게요. 새 할 일이 생기면 여기에 보여 드려요',
                  style: AppText.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// LMS 상태 줄(또는 '다시 로그인' 칩)과 '할 일 전체 보기 · N개'.
class _Footer extends ConsumerWidget {
  const _Footer({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final status = ref.watch(lmsStatusProvider);
    final busy = ref.watch(lmsSyncingProvider).value ?? false;
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    final refreshable =
        !demo &&
        status != null &&
        status.kind != LmsStatusKind.paused &&
        status.kind != LmsStatusKind.beforeLogin &&
        status.kind != LmsStatusKind.demo;
    Widget? lms;
    if (status != null) {
      lms = status.kind == LmsStatusKind.reloginNeeded
          ? LmsReloginChip(
              status: status,
              onTap: () => openRelogin(context, ref),
            )
          : LmsStatusLine(
              status: status,
              busy: busy,
              onTap: refreshable
                  ? () => unawaited(
                      ref
                          .read(syncCoordinatorProvider)
                          .run(
                            trigger: SyncTrigger.manual,
                            scope: SyncScope.list,
                          ),
                    )
                  : null,
              tapHint: refreshable ? '눌러서 새로 고침' : null,
            );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          lms ?? const SizedBox.shrink(),
          Press(
            child: Semantics(
              button: true,
              label: '할 일 전체 보기, $remaining개',
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.go(Routes.tasksTab(TaskListTab.all)),
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSize.minTouch,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '할 일 전체 보기 · $remaining개',
                          style: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                            color: colors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      AppIcon(
                        AppIconName.chevronRight,
                        size: 14,
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 말로 추가 칸.
class _SentenceField extends StatefulWidget {
  const _SentenceField({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  State<_SentenceField> createState() => _SentenceFieldState();
}

class _SentenceFieldState extends State<_SentenceField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ready = widget.controller.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        children: [
          AppIcon(AppIconName.assistant, size: 18, color: colors.icon),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              style: AppText.body,
              decoration: InputDecoration.collapsed(
                hintText: '말로 추가 · 예: 목요일 8시 팀플 회의',
                hintStyle: AppText.body.copyWith(color: colors.muted),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Press(
            child: IconButton(
              tooltip: ready ? '06 AI 비서로 보내기' : '말로 추가할 문장을 먼저 써 주세요',
              onPressed: ready ? widget.onSend : null,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                backgroundColor: ready ? colors.strong : colors.tint,
                disabledBackgroundColor: colors.tint,
              ),
              icon: AppIcon(
                AppIconName.send,
                size: 18,
                color: ready ? colors.onStrong : colors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래 고정 버튼(바탕이 아래로 갈수록 화면 색으로 덮임).
class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.action,
    required this.count,
    required this.busy,
    required this.onPressed,
  });

  final BriefingActionKind action;
  final int count;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = switch (action) {
      BriefingActionKind.start => '오늘 시작하기',
      BriefingActionKind.confirm => '$count개 확정하기',
      BriefingActionKind.clear => '확정한 할 일 빼기',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.bg.withValues(alpha: 0), colors.bg],
          stops: const [0, 0.34],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.screen,
          AppSpace.s16,
          AppSpace.screen,
          MediaQuery.paddingOf(context).bottom + AppSpace.s16,
        ),
        child: ToastAnchor(
          child: Press(
            enabled: !busy,
            child: FilledButton(
              onPressed: busy ? null : onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: AppText.body.copyWith(
                  fontSize: 16,
                  fontWeight: AppText.semibold,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (action == BriefingActionKind.start) ...[
                    const SizedBox(width: 6),
                    AppIcon(
                      AppIconName.chevronRight,
                      size: 18,
                      color: colors.onStrong,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);

String _range(DateTime start, DateTime end) => '${_hhmm(start)}–${_hhmm(end)}';

String _due(DateTime? dueAt, bool dueTimeUnknown, BriefingData data) => dueText(
  dueAt,
  dueTimeUnknown: dueTimeUnknown,
  now: data.now,
  dayBoundaryMin: data.dayBoundaryMin,
);

bool _dueSoon(DateTime? dueAt, BriefingData data) =>
    dueAt != null &&
    isDueSoon(
      dueDayOffset(dueAt, now: data.now, dayBoundaryMin: data.dayBoundaryMin),
    );
