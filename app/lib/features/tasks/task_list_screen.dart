// 03 할 일(할 일 탭 `/tasks`). docs/screens.md '03 할 일'.
//
// 머리('할 일', [할 일 추가]), LMS 상태 줄, 탭 [주간 할 일 N | 전체 할 일 N], 'LMS만' 칩과 정렬 [마감순 | 과목별],
// 요약 줄, 묶음과 줄, 빈 화면이다. 보일 것은 [taskListProvider](`domain/task_list.dart`)가 주고, 이 화면은 그리기와
// 탭·칩·정렬·끝내기만 한다. 모양은 최종 프로토타입(03 할 일)을 따른다.
// - 'LMS만'은 개인 할 일 줄을 제자리에서 접고, 끄면 그 자리에서 다시 편다(줄은 목록에 남아 있음).
// - 끝내기: 동그라미를 누르면 체크하고 제목에 줄을 그은 뒤 줄을 접고, 1초 뒤 완료로 저장한다(프로토타입). 그다음
//   영상이 아니면 '얼마나 걸렸어요?' 시트를 거쳐 되돌리기 토스트를 띄운다([afterTaskCompleted]). 탭·정렬을 바꾸거나
//   화면이 사라지면 기다리던 저장을 바로 한다.
// - 줄을 누르면 무엇을 보일지는 아직 정하지 않았다(docs/screens.md '03 할 일').
// - LMS 상태 줄을 누르면 LMS 정보 시트, 다시 로그인이 필요하면 칩이 다시 로그인 화면을 연다.
// 처음 열 탭은 `/tasks?tab=all`처럼 받는다(`Routes.tasksTab`). 01 계획의 '할 일 전체 보기'가 [TaskListTab.all]로
// 연다. 화면에서 탭을 바꾸면 주소의 탭도 바꿔, 같은 탭으로 다시 열어도 그 탭이 열리게 한다. 문구는 디자인 전 임시
// 문구다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/repositories/task_repository.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/pop.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/pulse.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/dashed_border.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/models/task_entry.dart';
import 'package:cnu_ai_assistant/domain/task_list.dart';
import 'package:cnu_ai_assistant/domain/task_took.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/tasks/task_actions.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_controller.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 03 할 일의 탭. 따로 고르지 않으면 [weekly]가 열린다.
enum TaskListTab {
  /// 주간 할 일: 오늘부터 7일 뒤까지 마감인 일과 마감이 지났는데 안 끝낸 일.
  weekly,

  /// 전체 할 일: 남은 할 일 전부.
  all,
}

/// 03 할 일.
///
/// `/tasks`는 할 일 탭 가지의 첫 화면이다. 그래서 다른 탭에서 다른 [initialTab]으로 다시 열면 새 화면이 생기지
/// 않고, 남아 있던 이 화면이 새 값을 받는다(위젯만 바뀌고 상태는 그대로). 그때 `didUpdateWidget`이 그 탭으로
/// 옮긴다.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, this.initialTab = TaskListTab.weekly});

  /// 처음 열 탭.
  final TaskListTab initialTab;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

/// 체크해 저장을 기다리는 할 일. 화면이 사라져도 저장하도록 저장소와 시계를 잡아 둔다.
final class _Pending {
  _Pending({
    required this.entry,
    required this.repository,
    required this.clock,
  });

  final TaskEntry entry;
  final TaskRepository repository;
  final Clock clock;

  final List<Timer> timers = [];
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  /// 체크한 뒤 줄을 접기 시작할 때와 완료로 저장할 때(최종 프로토타입).
  static const Duration _foldAfter = Duration(milliseconds: 520);
  static const Duration _saveAfter = Duration(milliseconds: 1000);

  late TaskListTab _tab = widget.initialTab;
  bool _lmsOnly = false;
  TaskListSort _sort = TaskListSort.due;

  /// 체크해 저장을 기다리는 할 일.
  final Map<int, _Pending> _pending = {};

  /// 끝내서 접은 할 일. 저장한 뒤 목록에서 빠지면 지운다.
  final Set<int> _gone = {};

  @override
  void didUpdateWidget(covariant TaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab &&
        widget.initialTab != _tab) {
      _flushPending();
      _tab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    // 기다리던 저장은 바로 한다(토스트 없이). 화면이 사라진 뒤라 ref 대신 체크할 때 잡아 둔 저장소를 쓴다.
    for (final MapEntry(key: id, value: pending) in _pending.entries) {
      for (final timer in pending.timers) {
        timer.cancel();
      }
      unawaited(pending.repository.complete(id, now: pending.clock.now()));
    }
    _pending.clear();
    super.dispose();
  }

  void _setTab(TaskListTab tab) {
    if (tab == _tab) return;
    _flushPending();
    setState(() => _tab = tab);
    // 주소의 탭도 맞춘다. 01 계획의 '할 일 전체 보기'처럼 같은 탭으로 다시 열 때 그 탭으로 옮기려고.
    context.go(Routes.tasksTab(tab));
  }

  void _setSort(TaskListSort sort) {
    if (sort == _sort) return;
    _flushPending();
    setState(() => _sort = sort);
  }

  void _setLmsOnly(bool on) => setState(() => _lmsOnly = on);

  /// 동그라미를 눌렀을 때. 체크하고 잠시 뒤 줄을 접은 다음 완료로 저장한다.
  void _check(TaskRow row) {
    final id = row.taskId;
    if (_pending.containsKey(id) || _gone.contains(id)) return;
    final motion = ref.read(motionLevelProvider);
    final pending = _Pending(
      entry: row.entry,
      repository: ref.read(taskRepositoryProvider),
      clock: ref.read(clockProvider),
    );
    pending.timers.addAll([
      Timer(motion.duration(_foldAfter), () {
        if (mounted) setState(() => _gone.add(id));
      }),
      Timer(motion.duration(_saveAfter), () => unawaited(_save(id))),
    ]);
    setState(() => _pending[id] = pending);
  }

  /// 기다리던 [id]를 완료로 저장한다.
  Future<void> _save(int id) async {
    final pending = _pending.remove(id);
    if (pending == null) return;
    for (final timer in pending.timers) {
      timer.cancel();
    }
    if (mounted) setState(() => _gone.add(id));
    final completedAt = pending.clock.now();
    final result = await pending.repository.complete(id, now: completedAt);
    if (!mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    switch (result) {
      case Ok(value: true):
        // 영상은 토스트만, 그 밖에는 '얼마나 걸렸어요?'를 거쳐 토스트를 띄운다.
        await afterTaskCompleted(
          context,
          ref,
          pending.entry,
          completedAt: completedAt,
        );
      case Ok():
        // 이미 끝냈거나 없는 할 일이다. 목록에 남아 있으면 다시 편다.
        setState(() => _gone.remove(id));
      case Err(:final error):
        appLog(
          'task_complete_failed',
          area: 'tasks',
          data: errorLogData(error),
        );
        setState(() => _gone.remove(id));
        toast.show(AppStrings.saveFailed);
    }
  }

  void _flushPending() {
    for (final id in [..._pending.keys]) {
      unawaited(_save(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = ref.watch(lmsStatusProvider);
    // 'LMS만'은 로그인 전에는 두지 않는다.
    final lmsChip = status != null && status.kind != LmsStatusKind.beforeLogin;
    final lmsOnly = _lmsOnly && lmsChip;
    final content = ref.watch(
      taskListProvider((
        weekly: _tab == TaskListTab.weekly,
        lmsOnly: lmsOnly,
        sort: _sort,
      )),
    );
    final value = content.value;
    if (value != null) _forgetSaved(value);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            top: AppSpace.s16,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpace.s24,
          ),
          children: [
            _padded(const Rise(child: _Header())),
            if (status != null)
              _padded(
                Rise(
                  delay: const Duration(milliseconds: 50),
                  child: _LmsLine(status: status),
                ),
              ),
            if (value == null)
              if (content.hasError)
                _padded(
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s32),
                    child: Text(
                      '할 일을 불러오지 못했어요',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: colors.muted),
                    ),
                  ),
                )
              else
                const SizedBox.shrink()
            else ...[
              _padded(
                Rise(
                  delay: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s8),
                    child: _Tabs(
                      tab: _tab,
                      weeklyCount: value.weeklyCount,
                      allCount: value.allCount,
                      onSelect: _setTab,
                    ),
                  ),
                ),
              ),
              _padded(
                Rise(
                  delay: const Duration(milliseconds: 140),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpace.s8,
                      children: [
                        if (lmsChip)
                          _LmsOnlyChip(on: lmsOnly, onChanged: _setLmsOnly)
                        else
                          const SizedBox.shrink(),
                        _SortSwitch(sort: _sort, onSelect: _setSort),
                      ],
                    ),
                  ),
                ),
              ),
              _padded(
                Rise(
                  delay: const Duration(milliseconds: 170),
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        value.summary,
                        style: AppText.small.copyWith(color: colors.muted),
                      ),
                    ),
                  ),
                ),
              ),
              ..._rows(value),
              if (value.empty case final empty?)
                _padded(
                  _EmptyState(
                    empty: empty,
                    otherCount: value.otherCount,
                    status: status,
                    onAdd: () => _openAdd(context),
                    onAll: () => _setTab(TaskListTab.all),
                    onPersonal: () => _setLmsOnly(false),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 저장한 뒤 목록에서 빠진 할 일을 접힌 목록에서 지운다(되돌리면 접히지 않은 채 다시 보이게).
  void _forgetSaved(TaskListContent content) {
    final present = {
      for (final group in content.groups)
        for (final row in group.rows) row.taskId,
    };
    _gone.removeWhere(
      (id) => !_pending.containsKey(id) && !present.contains(id),
    );
  }

  List<Widget> _rows(TaskListContent content) => [
    for (final group in content.groups) ...[
      if (group.kind != TaskGroupKind.due)
        _Fold(
          key: ValueKey('group-${group.kind.name}-${group.title}'),
          folded: !group.rows.any(_shows),
          child: _GroupHead(
            group: group,
            count: group.rows.where(_shows).length,
          ),
        ),
      for (final row in group.rows)
        _Fold(
          key: ValueKey('task-${row.taskId}'),
          folded: !_shows(row),
          slide: _gone.contains(row.taskId),
          child: _TaskRowTile(
            row: row,
            checked:
                _pending.containsKey(row.taskId) || _gone.contains(row.taskId),
            onCheck: () => _check(row),
          ),
        ),
    ],
  ];

  /// 접히지 않고 보이는 줄인지('LMS만'으로 접었거나 끝내서 접지 않음).
  bool _shows(TaskRow row) => !row.folded && !_gone.contains(row.taskId);
}

Widget _padded(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
  child: child,
);

/// 06 AI 비서의 직접 추가 폼을 할 일로 연다.
void _openAdd(BuildContext context) => unawaited(
  context.push<void>(
    Routes.assistant,
    extra: const AssistantArgs(form: DirectAddKind.task),
  ),
);

/// '할 일'과 [할 일 추가].
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: const Text(AppStrings.tabTasks, style: AppText.heading),
          ),
        ),
        Press(
          child: TextButton.icon(
            onPressed: () => _openAdd(context),
            style: TextButton.styleFrom(
              backgroundColor: colors.surface,
              foregroundColor: colors.accent,
              minimumSize: const Size(0, AppSize.minTouch),
              padding: const EdgeInsets.fromLTRB(12, 0, AppSpace.s16, 0),
              shape: StadiumBorder(side: BorderSide(color: colors.edge)),
            ),
            icon: AppIcon(AppIconName.plus, size: 17, color: colors.accent),
            label: Text(
              '할 일 추가',
              style: AppText.small.copyWith(fontWeight: AppText.semibold),
            ),
          ),
        ),
      ],
    );
  }
}

/// LMS 상태 줄. 다시 로그인이 필요하면 칩이 다시 로그인 화면을 열고, 그 밖에는 누르면 LMS 정보 시트를 연다.
class _LmsLine extends ConsumerWidget {
  const _LmsLine({required this.status});

  final LmsStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status.kind == LmsStatusKind.reloginNeeded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LmsReloginChip(
          status: status,
          onTap: () => openRelogin(context, ref),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: LmsStatusLine(
        status: status,
        busy: ref.watch(lmsSyncingProvider).value ?? false,
        onTap: () => unawaited(
          openLmsInfoSheet(
            context,
            ref,
            onRefresh: () => ref
                .read(syncCoordinatorProvider)
                .run(trigger: SyncTrigger.manual, scope: SyncScope.list),
          ),
        ),
        tapHint: '자세히 보기',
      ),
    );
  }
}

/// 탭 [주간 할 일 N | 전체 할 일 N]. 고른 쪽 뒤의 표시가 옮겨 간다.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.weeklyCount,
    required this.allCount,
    required this.onSelect,
  });

  final TaskListTab tab;
  final int weeklyCount;
  final int allCount;
  final ValueChanged<TaskListTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final duration = MotionScope.of(context).duration(AppMotion.standard);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tint,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: tab == TaskListTab.weekly
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: duration,
                curve: AppEase.morph,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.tint2,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (value, label, count) in [
                  (TaskListTab.weekly, '주간 할 일', weeklyCount),
                  (TaskListTab.all, '전체 할 일', allCount),
                ])
                  Expanded(
                    child: _TabButton(
                      label: label,
                      count: count,
                      selected: tab == value,
                      onTap: () => onSelect(value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = AppText.body.copyWith(
      fontSize: 14,
      fontWeight: AppText.semibold,
      color: selected ? colors.ink : colors.muted,
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '$label $count개',
      excludeSemantics: true,
      child: Press(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch - 6),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s8,
                  vertical: AppSpace.s4,
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: label),
                      const TextSpan(text: ' '),
                      TextSpan(text: '$count'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 'LMS만' 칩. 켜면 개인 할 일 줄을 접는다.
class _LmsOnlyChip extends StatelessWidget {
  const _LmsOnlyChip({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final duration = MotionScope.of(context).duration(AppMotion.fade);
    final foreground = on ? colors.onStrong : colors.accent;
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: 'LMS 할 일만 보기',
      excludeSemantics: true,
      child: Press(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!on),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: duration,
                curve: AppEase.fade,
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.fromLTRB(10, 4, 13, 4),
                decoration: ShapeDecoration(
                  color: on ? colors.strong : colors.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: on ? colors.strong : colors.edge),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      AppIconName.school,
                      size: 15,
                      color: on ? colors.onStrong : colors.icon,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LMS만',
                      style: AppText.small.copyWith(
                        fontWeight: AppText.semibold,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 정렬 [마감순 | 과목별]. 두 버튼은 같은 너비이고 고른 쪽 뒤의 표시가 옮겨 간다.
class _SortSwitch extends StatelessWidget {
  const _SortSwitch({required this.sort, required this.onSelect});

  final TaskListSort sort;
  final ValueChanged<TaskListSort> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final duration = MotionScope.of(context).duration(AppMotion.standard);
    return Semantics(
      container: true,
      label: '정렬 방식',
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                alignment: sort == TaskListSort.due
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: duration,
                curve: AppEase.spring,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.tint,
                        shape: StadiumBorder(
                          side: BorderSide(color: colors.edge),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (value, label) in [
                  (TaskListSort.due, '마감순'),
                  (TaskListSort.course, '과목별'),
                ])
                  Expanded(
                    child: Semantics(
                      container: true,
                      button: true,
                      selected: sort == value,
                      label: label,
                      excludeSemantics: true,
                      child: Press(
                        child: InkWell(
                          onTap: () => onSelect(value),
                          customBorder: const StadiumBorder(),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 62,
                              minHeight: AppSize.minTouch,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  label,
                                  style: AppText.small.copyWith(
                                    fontWeight: AppText.semibold,
                                    color: sort == value
                                        ? colors.ink
                                        : colors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 줄이나 묶음 머리를 제자리에서 접고 편다. 접힌 것은 누를 수 없고 읽기 도구도 읽지 않는다. [slide]면 접히며
/// 왼쪽으로 조금 밀려난다(끝낸 할 일).
class _Fold extends StatelessWidget {
  const _Fold({
    super.key,
    required this.folded,
    this.slide = false,
    required this.child,
  });

  final bool folded;
  final bool slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: folded,
      child: ExcludeSemantics(
        excluding: folded,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: folded ? 0 : 1),
          duration: MotionScope.of(context).duration(AppMotion.standard),
          curve: AppEase.standard,
          builder: (context, shown, child) => ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: shown,
              child: Opacity(
                opacity: shown,
                child: Transform.translate(
                  offset: Offset(slide ? -16 * (1 - shown) : 0, 0),
                  child: child,
                ),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 묶음 머리: 과목·개인은 이름과 수, '마감 없음'은 옅은 이름만.
class _GroupHead extends StatelessWidget {
  const _GroupHead({required this.group, required this.count});

  final TaskGroup group;

  /// 보이는 줄의 수.
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final soft = group.kind == TaskGroupKind.noDue;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.screen,
          soft ? AppSpace.s24 : AppSpace.s20,
          AppSpace.screen,
          2,
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                group.title ?? '',
                style: soft
                    ? AppText.caption.copyWith(color: colors.muted)
                    : AppText.small.copyWith(
                        fontWeight: AppText.semibold,
                        color: colors.ink2,
                      ),
              ),
            ),
            if (!soft) ...[
              const SizedBox(width: 6),
              Text(
                '$count개',
                style: AppText.caption.copyWith(color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 할 일 한 줄: 동그라미, 머리, 제목, 마감과 덧줄(마감 변경·영상 길이·계획·안내).
class _TaskRowTile extends StatelessWidget {
  const _TaskRowTile({
    required this.row,
    required this.checked,
    required this.onCheck,
  });

  final TaskRow row;

  /// 체크했는지(저장을 기다리거나 접히는 중).
  final bool checked;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final task = row.entry.task;
    final lines = <Widget>[
      if (row.dueChange case final change?)
        _Line(
          icon: AppIcon(AppIconName.clock, size: 13, color: colors.accent),
          text: change,
          color: colors.accent,
          bold: true,
        ),
      if (row.video case final video?)
        _Line(
          icon: AppIcon(AppIconName.clock, size: 13, color: colors.icon),
          text: video,
          color: colors.ink2,
        ),
      if (row.plan case final plan?)
        _Line(
          icon: _PlanGlyph(kind: plan.kind),
          text: plan.text,
          color: plan.alert ? colors.alert : colors.ink2,
        ),
      if (row.note case final note?)
        _Line(
          icon: AppIcon(
            note.kind == TaskNoteKind.opens
                ? AppIconName.clock
                : AppIconName.info,
            size: 13,
            color: colors.icon,
          ),
          text: note.text,
          color: colors.ink2,
        ),
    ];
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 15, AppSpace.screen, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _DoneCheck(
                  checked: checked,
                  label:
                      '${row.title} ${withJosa(taskDoneWord(task), Josa.euroRo)} 표시',
                  onTap: onCheck,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppIcon(
                          _kindIcon(task.kind),
                          size: 14,
                          color: colors.icon,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            row.kicker,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: MotionScope.of(context)
                          .duration(const Duration(milliseconds: 300)),
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: AppText.semibold,
                        color: checked ? colors.muted : colors.ink,
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: colors.faint,
                        decorationThickness: 1.5,
                      ),
                      child: Text(row.title),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.due,
                      style: AppText.small.copyWith(
                        color: row.dueUrgent && !checked
                            ? colors.alert
                            : colors.muted,
                        fontWeight: row.dueUrgent && !checked
                            ? AppText.semibold
                            : AppText.regular,
                      ),
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: AppSpace.s8),
                      line,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // 줄 사이 선은 동그라미 오른쪽 아래부터 긋는다(최종 프로토타입).
        Positioned(
          left: 40,
          right: 0,
          bottom: 0,
          child: SizedBox(height: 1, child: ColoredBox(color: colors.edge)),
        ),
      ],
    );
  }
}

/// 할 일 종류의 아이콘(최종 프로토타입).
AppIconName _kindIcon(TaskKind kind) => switch (kind) {
  TaskKind.assignment || TaskKind.material => AppIconName.doc,
  TaskKind.video => AppIconName.video,
  TaskKind.quiz => AppIconName.quiz,
  TaskKind.team => AppIconName.team,
  TaskKind.discussion => AppIconName.discussion,
  TaskKind.exam => AppIconName.flag,
  TaskKind.personal => AppIconName.person,
};

/// 덧줄 하나(12pt).
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  final Widget icon;
  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption.copyWith(
      color: color,
      fontWeight: bold ? AppText.semibold : AppText.regular,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: (style.fontSize ?? 12) * (style.height ?? 1.45),
          width: 13,
          child: Center(child: icon),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// 계획 줄 앞의 표시: 확정은 네모, 제안은 점선 네모, 지금 하는 중은 퍼지는 점, 블록이 없으면 모래시계.
class _PlanGlyph extends StatelessWidget {
  const _PlanGlyph({required this.kind});

  final TaskPlanKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    switch (kind) {
      case TaskPlanKind.confirmed:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: colors.taskInk, width: 1.5),
          ),
        );
      case TaskPlanKind.suggested:
        return SizedBox(
          width: 10,
          height: 10,
          child: DashedBorder(
            color: colors.taskInk,
            radius: 3,
            child: const SizedBox.expand(),
          ),
        );
      case TaskPlanKind.now:
        Widget dot(Color color) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
        return Stack(
          alignment: Alignment.center,
          children: [
            Pulse(child: dot(colors.stripe)),
            dot(colors.strong),
          ],
        );
      case TaskPlanKind.none:
        return AppIcon(AppIconName.hourglass, size: 13, color: colors.icon);
    }
  }
}

/// 끝내기 동그라미(누르는 자리 48pt).
class _DoneCheck extends StatelessWidget {
  const _DoneCheck({
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final circle = AnimatedContainer(
      duration: MotionScope.of(context)
          .duration(const Duration(milliseconds: 300)),
      curve: AppEase.emphasized,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? colors.strong : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: checked ? colors.strong : colors.icon,
          width: 1.6,
        ),
      ),
      child: checked
          ? Pop(
              key: const ValueKey('checked'),
              child: Center(
                child: AppIcon(
                  AppIconName.check,
                  size: 12,
                  color: colors.onStrong,
                ),
              ),
            )
          : null,
    );
    return Semantics(
      container: true,
      checked: checked,
      label: label,
      excludeSemantics: true,
      onTap: checked ? null : onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: checked ? null : onTap,
        child: SizedBox.square(
          dimension: AppSize.minTouch,
          child: Center(child: circle),
        ),
      ),
    );
  }
}

/// 빈 화면(docs/screens.md '03 할 일'의 빈 화면 셋).
class _EmptyState extends ConsumerWidget {
  const _EmptyState({
    required this.empty,
    required this.otherCount,
    required this.status,
    required this.onAdd,
    required this.onAll,
    required this.onPersonal,
  });

  final TaskListEmpty empty;
  final int otherCount;
  final LmsStatus? status;
  final VoidCallback onAdd;
  final VoidCallback onAll;
  final VoidCallback onPersonal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final now = ref.watch(minuteClockProvider);
    final boundary =
        ref.watch(settingsProvider).value?.dayBoundaryMin ??
        Defaults.dayBoundaryMin;
    final today = logicalDate(now, dayBoundaryMin: boundary);
    final weekEnd = DateTime(today.year, today.month, today.day + 7);
    final (title, lines, button) = switch (empty) {
      TaskListEmpty.notThisWeek => (
        '7일 안에 마감인 할 일이 없어요',
        [
          '${monthDayText(weekEnd, today: today)}까지는 비어 있어요',
          '나머지 할 일 $otherCount개는 전체 할 일에 있어요',
        ],
        _EmptyButton(label: '전체 할 일 보기', onTap: onAll),
      ),
      TaskListEmpty.noLmsTasks => (
        '남은 LMS 할 일이 없어요',
        [?_lmsLine(status, now), '개인 할 일 $otherCount개는 LMS만을 끄면 보여요'],
        _EmptyButton(label: '개인 할 일도 보기', onTap: onPersonal),
      ),
      TaskListEmpty.nothing => (
        '남은 할 일이 없어요',
        [?_lmsLine(status, now), ?_nextLine(status)],
        _EmptyButton(label: '할 일 추가', icon: AppIconName.plus, onTap: onAdd),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s32),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.bodyLarge.copyWith(fontWeight: AppText.semibold),
          ),
          const SizedBox(height: AppSpace.s4),
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(color: colors.muted),
            ),
          const SizedBox(height: 18),
          button,
        ],
      ),
    );
  }

  /// 첫 줄: 할 일 목록이 어디서 온 것인지.
  static String? _lmsLine(LmsStatus? status, DateTime now) {
    if (status == null) return null;
    return switch (status.kind) {
      LmsStatusKind.demo => '샘플 데이터예요',
      LmsStatusKind.beforeLogin => 'LMS에 로그인하지 않았어요',
      LmsStatusKind.synced => switch (status.lastSuccessAt) {
        final at? =>
          '${lastCheckedText(lastSuccessAt: at, now: now, byUserRefresh: status.byUserRefresh)} LMS에서 확인했어요',
        null => 'LMS 정보를 아직 받지 않았어요',
      },
      _ => 'LMS에서 받아 둔 목록이에요',
    };
  }

  /// 둘째 줄: 새 할 일을 언제 가져오는지.
  static String? _nextLine(LmsStatus? status) => switch (status?.kind) {
    null || LmsStatusKind.demo => null,
    LmsStatusKind.synced => '새 할 일이 올라오면 정해진 시간에 가져와요',
    LmsStatusKind.reloginNeeded => '다시 로그인하면 새 할 일을 가져와요',
    LmsStatusKind.connectionFailed => '연결되면 다시 확인할게요',
    LmsStatusKind.maintenance => '점검이 끝나면 새 할 일을 가져와요',
    LmsStatusKind.paused => '연동을 다시 켜면 새 할 일을 가져와요',
    LmsStatusKind.beforeLogin => '할 일은 직접 넣거나 AI 비서로 추가해요',
  };
}

class _EmptyButton extends StatelessWidget {
  const _EmptyButton({required this.label, this.icon, required this.onTap});

  final String label;
  final AppIconName? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Text(
      label,
      style: AppText.body.copyWith(fontSize: 14, fontWeight: AppText.semibold),
    );
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, AppSize.minTouch),
      padding: const EdgeInsets.symmetric(horizontal: 18),
    );
    return Press(
      child: switch (icon) {
        final icon? => OutlinedButton.icon(
          onPressed: onTap,
          style: style,
          icon: AppIcon(icon, size: 17, color: colors.accent),
          label: text,
        ),
        null => OutlinedButton(onPressed: onTap, style: style, child: text),
      },
    );
  }
}
