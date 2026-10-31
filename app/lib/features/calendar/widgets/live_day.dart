// 선택일 패널을 끌어올렸을 때의 실시간 하루 시간표. docs/architecture.md '화면 이동'.
//
// 위에서부터 날짜·지금 시각, 상황(진행 중·다음 일정·남은 빈 시간), 0~24시 시간표(지금 선,
// 지난 일정은 흐리게), 오늘 해야 할 미배정 할 일이다. 지금 시각은 1분마다 바뀐다.
// 처음에는 지금 1시간 전(오늘이 아니면 8시)이 위에 오게 스크롤한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/design/widgets/unassigned_task_row.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/time_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 실시간 하루 시간표.
class LiveDay extends ConsumerStatefulWidget {
  const LiveDay({super.key, required this.day});

  /// 보여 줄 날(시각 없음).
  final DateTime day;

  @override
  ConsumerState<LiveDay> createState() => _LiveDayState();
}

class _LiveDayState extends ConsumerState<LiveDay> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _todoKey = GlobalKey();
  bool _scrolledToNow = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToNow(DateTime? now) {
    if (_scrolledToNow) return;
    _scrolledToNow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timeline = _timelineKey.currentContext?.findRenderObject();
      if (!mounted || timeline is! RenderBox || !_scroll.hasClients) return;
      final list = _scroll.position.context.storageContext.findRenderObject();
      if (list is! RenderBox) return;
      final top =
          timeline.localToGlobal(Offset.zero, ancestor: list).dy +
          _scroll.offset;
      _scroll.jumpTo(
        (top + TimeGrid.initialOffset(now)).clamp(
          0,
          _scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider).now();
    final boundary = ref.watch(dayBoundaryProvider);
    final isToday = day == ref.watch(calendarTodayProvider);
    final items = itemsOn(day, data);
    final todo = isToday
        ? todayUnassigned(
            ref.watch(unassignedTasksProvider),
            now: now,
            dayBoundaryMin: boundary,
          )
        : const <UnassignedTask>[];
    _scrollToNow(isToday ? now : null);

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        0,
        AppSpace.screen,
        CalendarBottomBar.height,
      ),
      children: [
        Semantics(
          header: true,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpace.s8,
            children: [
              Text('${day.day}', style: AppText.display),
              Text(
                '${weekdayText(day.weekday)}요일',
                style: AppText.bodyLarge.copyWith(fontWeight: AppText.semibold),
              ),
              if (isToday)
                Text(
                  '지금 ${hm(now)}',
                  style: AppText.body.copyWith(
                    color: AppColors.alert,
                    fontWeight: AppText.semibold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        _StatusCard(
          lines: isToday
              ? _todayStatus(data, items, now, boundary)
              : [_otherDayStatus(day, now, items)],
          todoCount: isToday ? todo.length : null,
          onJumpToTodo: () {
            final target = _todoKey.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                duration: const Duration(milliseconds: 250),
              );
            }
          },
        ),
        const SizedBox(height: AppSpace.s12),
        _AllDayStrip(items: items),
        TimeGrid(
          key: _timelineKey,
          days: [day],
          data: data,
          now: isToday ? now : null,
        ),
        if (isToday) ...[
          const SizedBox(height: AppSpace.s16),
          Semantics(
            key: _todoKey,
            header: true,
            child: Text(
              '오늘 해야 할 미배정 할 일 ${todo.length}개',
              style: AppText.small.copyWith(color: AppColors.muted),
            ),
          ),
          if (todo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
              child: Text(
                '오늘 시간을 정해야 할 할 일이 없어요.',
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ),
          for (final item in todo)
            UnassignedTaskRow(
              item: item,
              now: now,
              dayBoundaryMin: boundary,
              onPlace: () =>
                  showAddSheet(context, day: day, taskId: item.task.id),
            ),
        ],
      ],
    );
  }

  /// 오늘의 상황 줄: 진행 중, 다음, 남은 빈 시간.
  List<(String, String)> _todayStatus(
    CalendarData data,
    List<CalendarItem> items,
    DateTime now,
    int boundary,
  ) {
    final timed = items.where((i) => i.start != null && i.end != null);
    final current = timed.where(
      (i) => !i.start!.isAfter(now) && i.end!.isAfter(now),
    );
    final next = timed.where((i) => i.start!.isAfter(now)).firstOrNull;
    final free =
        freeSlots(
          widget.day,
          schedule: data.schedule,
          config: PlannerConfig.from(data.rules),
          dayBoundaryMin: boundary,
        ).fold(0, (sum, span) {
          final start = span.start.isAfter(now) ? span.start : now;
          return span.end.isAfter(start)
              ? sum + span.end.difference(start).inMinutes
              : sum;
        });
    return [
      for (final i in current)
        (
          '진행 중',
          '${i.title} · ${durationText(i.end!.difference(now).inMinutes)} 남음',
        ),
      (
        '다음',
        next == null
            ? '오늘 남은 일정 없음'
            : '${next.title} · ${durationText(next.start!.difference(now).inMinutes)} 뒤 (${hm(next.start!)})',
      ),
      ('빈 시간', '오늘 남은 빈 시간 ${durationText(free)}'),
    ];
  }

  (String, String) _otherDayStatus(
    DateTime day,
    DateTime now,
    List<CalendarItem> items,
  ) {
    final days = day.difference(DateTime(now.year, now.month, now.day)).inDays;
    return (days > 0 ? '$days일 뒤' : '${-days}일 전', '일정 ${items.length}개');
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.lines,
    required this.todoCount,
    required this.onJumpToTodo,
  });

  final List<(String, String)> lines;

  /// 오늘이면 미배정 할 일 수, 아니면 null(바로가기 없음).
  final int? todoCount;
  final VoidCallback onJumpToTodo;

  @override
  Widget build(BuildContext context) {
    final todoCount = this.todoCount;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, text) in lines)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: AppText.semibold,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: AppText.body,
            ),
          if (todoCount != null)
            TextButton(
              onPressed: onJumpToTodo,
              child: Text('오늘 미배정 $todoCount개 보기'),
            ),
        ],
      ),
    );
  }
}

/// 종일 일정과 마감. 시간표 위에 칩으로 둔다.
class _AllDayStrip extends StatelessWidget {
  const _AllDayStrip({required this.items});

  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final strip = [
      for (final i in items)
        if (i.allDay || i.kind == CalendarItemKind.deadline) i,
    ];
    if (strip.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Wrap(
        spacing: AppSpace.s4,
        runSpacing: AppSpace.s4,
        children: [
          for (final i in strip)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: itemTint(i.kind),
                borderRadius: BorderRadius.circular(AppRadius.tag),
              ),
              child: Text(
                i.kind == CalendarItemKind.deadline
                    ? '${hm(i.start!)} 마감 · ${i.title}'
                    : '종일 · ${i.title}',
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }
}
