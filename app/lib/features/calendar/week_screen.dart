// 11 주간(캘린더 탭의 첫 화면 `/calendar`). docs/screens.md '11 주간'.
//
// 날짜별 목록이고 머리는 주 범위, '오늘', ‹ ›, '주 | 월', '제안 일정' 스위치다. 요약 세 칸 아래에 날짜마다 날짜 줄
// (하루 막대와 '빈 시간 N · 수업 N개 · 할 일 N개'), 마감 줄, 일정 줄(4개까지와 'N개 더 보기')을 둔다
// (`domain/week_view.dart`). 날짜 줄·일정 줄을 누르면 09 일간을 `Routes.day(날짜, from: DayViewFrom.week)`로 열고
// (오늘 탭에 속하고 뒤로 가면 여기로 돌아옴), 할 일 블록 줄은 근거 시트, 마감 줄은 할 일 시트를 연다. '월'은 같은
// 자리에서 08 월간으로 바꿔 끼운다. 보는 주와 '제안 일정'은 화면을 떠나면 처음(이번 주, 꺼짐)으로 돌아간다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/day_view.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/week_view.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/calendar_view_switch.dart';
import 'package:cnu_ai_assistant/features/tasks/task_actions.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:cnu_ai_assistant/features/today/day_controller.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart'
    show DayViewFrom;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 11 주간.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  /// 이번 주에서 떨어진 주 수.
  int _offset = 0;

  /// '제안 일정'.
  bool _suggested = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = ref.watch(minuteClockProvider);
    final boundary =
        ref.watch(settingsProvider.select((s) => s.value?.dayBoundaryMin)) ??
        Defaults.dayBoundaryMin;
    final today = logicalDate(now, dayBoundaryMin: boundary);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) + _offset * 7,
    );
    final dates = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    final days = [for (final date in dates) ref.watch(dayViewProvider(date))];
    final config = ref.watch(plannerConfigProvider);
    final failed = days.any((day) => day.hasError && day.value == null);
    final ready = days.every((day) => day.value != null);

    final WeekView? view = ready
        ? weekView(
            monday: monday,
            days: [
              for (final day in days)
                (
                  date: day.value!.home.date,
                  items: day.value!.home.items,
                  allDay: day.value!.home.allDay,
                  dues: day.value!.view.dues,
                  free: day.value!.home.free,
                ),
            ],
            today: today,
            now: now,
            showSuggested: _suggested,
            courseNames: days.first.value!.home.courseNames,
            estimateOf: (entry) =>
                config == null ? null : remainingWorkMin(entry, config),
          )
        : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.s12,
                AppSpace.s12,
                0,
              ),
              child: _Header(
                label:
                    view?.label ??
                    '${monday.month}월 ${monday.day}일 – ${dates.last.day}일',
                showToday: _offset != 0,
                onToday: () => setState(() => _offset = 0),
                onShift: (weeks) => setState(() => _offset += weeks),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                AppSpace.s8,
                AppSpace.screen,
                AppSpace.s8,
              ),
              child: Row(
                children: [
                  const CalendarViewSwitch(current: CalendarView.week),
                  const Spacer(),
                  Text(
                    '제안 일정',
                    style: AppText.small.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Semantics(
                    label: '제안 일정 보기',
                    child: Switch(
                      value: _suggested,
                      onChanged: (value) => setState(() => _suggested = value),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: view == null
                  ? Center(
                      child: failed
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpace.screen),
                              child: Text(
                                '이 주 일정을 불러오지 못했어요',
                                textAlign: TextAlign.center,
                                style: AppText.body.copyWith(
                                  color: colors.muted,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.screen,
                        AppSpace.s4,
                        AppSpace.screen,
                        120,
                      ),
                      children: [
                        _Summary(cells: view.cells),
                        for (final day in view.days) ...[
                          const SizedBox(height: AppSpace.s12),
                          _DaySection(
                            day: day,
                            onOpenDay: () => context.go(
                              Routes.day(day.date, from: DayViewFrom.week),
                            ),
                            onBlock: (item) =>
                                openBlockSheet(context, ref, item.block),
                            onDue: (row) =>
                                openTaskSheet(context, ref, row.entry.task.id),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.label,
    required this.showToday,
    required this.onToday,
    required this.onShift,
  });

  final String label;
  final bool showToday;
  final VoidCallback onToday;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (showToday)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: TextButton(
                    onPressed: onToday,
                    child: const Text('오늘'),
                  ),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: colors.edge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '지난주',
                onPressed: () => onShift(-1),
                icon: RotatedBox(
                  quarterTurns: 2,
                  child: AppIcon(
                    AppIconName.chevronRight,
                    size: 18,
                    color: colors.ink2,
                  ),
                ),
              ),
              SizedBox(
                width: 1,
                height: 18,
                child: ColoredBox(color: colors.edge2),
              ),
              IconButton(
                tooltip: '다음 주',
                onPressed: () => onShift(1),
                icon: AppIcon(
                  AppIconName.chevronRight,
                  size: 18,
                  color: colors.ink2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cells});

  final List<WeekCell> cells;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: Semantics(
                container: true,
                label: '${cell.label} ${cell.value}',
                excludeSemantics: true,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cell.value,
                        maxLines: 1,
                        style: AppText.bodyLarge.copyWith(
                          fontWeight: AppText.semibold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cell.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.onOpenDay,
    required this.onBlock,
    required this.onDue,
  });

  final WeekDay day;
  final VoidCallback onOpenDay;
  final ValueChanged<BlockItem> onBlock;
  final ValueChanged<DayDueRow> onDue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final holiday = day.holiday;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s4,
        AppSpace.s8,
        AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: day.today ? colors.surface : null,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: day.today ? colors.edge2 : colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            label:
                '${day.title}${holiday == null ? '' : ', $holiday'}, ${day.sub}, '
                '일간 보기',
            excludeSemantics: true,
            onTap: onOpenDay,
            child: InkWell(
              onTap: onOpenDay,
              borderRadius: BorderRadius.circular(AppRadius.input),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.minTouch),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpace.s8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            holiday == null
                                ? day.title
                                : '${day.title} · $holiday',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                              fontWeight: AppText.semibold,
                              color: day.red
                                  ? colors.alert
                                  : day.today
                                  ? colors.accent
                                  : colors.ink,
                            ),
                          ),
                        ),
                        AppIcon(
                          AppIconName.chevronRight,
                          size: 16,
                          color: colors.icon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _DayBar(bars: day.bars),
                    const SizedBox(height: 6),
                    Text(
                      day.sub,
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: AppSpace.s4),
                  ],
                ),
              ),
            ),
          ),
          for (final due in day.dues)
            _DueLine(row: due, onTap: () => onDue(due)),
          for (final row in day.items)
            _ItemLine(
              row: row,
              onTap: switch (row.item) {
                final BlockItem block => () => onBlock(block),
                _ => onOpenDay,
              },
            ),
          if (day.more > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenDay,
                child: Text('${day.more}개 더 보기'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 하루 막대(08–23시).
class _DayBar extends StatelessWidget {
  const _DayBar({required this.bars});

  final List<WeekBar> bars;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: colors.tint)),
                for (final bar in bars)
                  Positioned(
                    left: bar.from * width,
                    width: (bar.to - bar.from) * width,
                    top: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: switch (bar.kind) {
                        WeekBarKind.classItem => colors.classInk,
                        WeekBarKind.event => colors.personalInk,
                        WeekBarKind.block => colors.taskInk,
                        WeekBarKind.suggested => colors.taskLine,
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DueLine extends StatelessWidget {
  const _DueLine({required this.row, required this.onTap});

  final DayDueRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = row.urgent
        ? colors.alert
        : row.finished
        ? colors.muted
        : colors.ink2;
    final state = row.state;
    return Semantics(
      container: true,
      button: true,
      label: '${row.time} 마감, ${row.title}${state == null ? '' : ', $state'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  row.time,
                  style: AppText.small.copyWith(
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppIcon(AppIconName.flag, size: 14, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '마감 · ${row.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    fontWeight: row.urgent ? AppText.semibold : AppText.medium,
                    color: row.urgent
                        ? colors.alert
                        : row.finished
                        ? colors.muted
                        : colors.ink,
                    decoration: row.finished
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: colors.faint,
                  ),
                ),
              ),
              if (state != null) ...[
                const SizedBox(width: 6),
                Text(
                  state,
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ],
              const SizedBox(width: AppSpace.s8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.row, required this.onTap});

  final WeekItemRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tag = row.tag;
    final dot = switch (row.item) {
      ClassItem(:final slot) => CourseColors.of(context, slot.courseId).ink,
      BlockItem() => colors.taskInk,
      _ => colors.personalInk,
    };
    return Semantics(
      container: true,
      button: true,
      label: '${row.time}, ${row.title}${tag == null ? '' : ', $tag'}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  row.time,
                  style: AppText.small.copyWith(
                    color: colors.ink2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.copyWith(
                    fontWeight: AppText.medium,
                    color: row.dim ? colors.muted : colors.ink,
                    decoration: row.tag == '휴강'
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: colors.faint,
                  ),
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.tint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tag,
                    style: AppText.caption.copyWith(
                      fontWeight: AppText.semibold,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpace.s8),
            ],
          ),
        ),
      ),
    );
  }
}
