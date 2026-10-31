// 선택일 패널을 끌어올렸을 때의 데일리 스케줄 본문. docs/architecture.md '화면 이동'.
//
// 위에서부터 실시간 시간표, To-Do, 오늘 해야 할 미배정 할 일 세 칸이 5:2:2 높이로 놓이고 칸마다
// 따로 스크롤한다. 시간표 칸 맨 위에는 지금 시각과 상황(진행 중·다음 일정·남은 빈 시간)을 한 줄로
// 둔다. 시간표는 0~24시(지금 선, 지난 일정은 흐리게)이고 처음에는 지금 1시간 전(오늘이 아니면 8시)이
// 위에 오게 스크롤한다. To-Do는 그날의 확정 블록과 그날 마감인 할 일이고, 체크하면 블록은 `done`,
// 할 일은 완료로 바꾸고 10초 동안 '되돌리기' 스낵바를 띄운다. 지금 시각은 1분마다 바뀐다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/repositories/plan_repository.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/unassigned_task_row.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/time_grid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 데일리 스케줄 본문(실시간 시간표 · To-Do · 오늘 미배정 할 일).
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

  /// To-Do 한 줄을 체크하거나 풀었을 때. 저장하면 되돌리기 스낵바를 띄운다.
  Future<void> _toggle(_TodoEntry entry, bool done) async {
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(planRepositoryProvider);
    final blockId = entry.blockId;
    final result = blockId != null
        ? await repository.setBlockDone(blockId, done: done)
        : await repository.setTaskDone(entry.taskId, done: done);
    messenger.hideCurrentSnackBar();
    if (result is Err) {
      messenger.showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          done ? '${entry.title} 완료로 표시했어요' : '${entry.title} 완료를 취소했어요',
        ),
        duration: PlanRepository.undoWindow,
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () => container.read(planRepositoryProvider).undoLast(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider).now();
    final boundary = ref.watch(dayBoundaryProvider);
    final isToday = day == ref.watch(calendarTodayProvider);
    final items = itemsOn(day, data);
    final unassigned = todayUnassigned(
      ref.watch(unassignedTasksProvider),
      now: now,
      dayBoundaryMin: boundary,
    );
    _scrollToNow(isToday ? now : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusLine(
                lines: isToday
                    ? [
                        ('지금', hm(now)),
                        ..._todayStatus(data, items, now, boundary),
                      ]
                    : [_otherDayStatus(day, now, items)],
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.screen,
                    AppSpace.s8,
                    AppSpace.screen,
                    AppSpace.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AllDayStrip(items: items),
                      TimeGrid(
                        key: _timelineKey,
                        days: [day],
                        data: data,
                        now: isToday ? now : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.edge),
        Expanded(
          flex: 2,
          child: _Region(
            title: 'To-Do',
            empty: '이날 할 일이 없어요.',
            children: [
              for (final entry in _todoOn(day, data))
                _TodoRow(
                  entry: entry,
                  onChanged: (done) => _toggle(entry, done),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.edge),
        Expanded(
          flex: 2,
          child: _Region(
            title: '오늘 해야 할 미배정 할 일 ${unassigned.length}개',
            empty: '오늘 시간을 정해야 할 할 일이 없어요.',
            children: [
              for (final item in unassigned)
                UnassignedTaskRow(
                  item: item,
                  now: now,
                  dayBoundaryMin: boundary,
                  onPlace: () =>
                      showAddSheet(context, day: day, taskId: item.task.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// [day]의 To-Do: 확정·완료 블록과 그날 마감인 할 일(할 일·완료). 시각 순이다.
  static List<_TodoEntry> _todoOn(DateTime day, CalendarData data) {
    final next = DateTime(day.year, day.month, day.day + 1);
    final taskById = {for (final task in data.tasks) task.id: task};
    final entries = <_TodoEntry>[
      for (final block in data.schedule.planBlocks)
        if ((block.status == PlanBlockStatus.confirmed ||
                block.status == PlanBlockStatus.done) &&
            block.startAt.isBefore(next) &&
            block.endAt.isAfter(day))
          _TodoEntry(
            title: taskById[block.taskId]?.title ?? '할 일',
            meta: '${hm(block.startAt)} - ${hm(block.endAt)}',
            at: block.startAt,
            done: block.status == PlanBlockStatus.done,
            taskId: block.taskId,
            blockId: block.id,
          ),
      for (final task in data.tasks)
        if ((task.status == TaskStatus.todo ||
                task.status == TaskStatus.done) &&
            task.dueAt != null &&
            !task.dueAt!.isBefore(day) &&
            task.dueAt!.isBefore(next))
          _TodoEntry(
            title: task.title,
            meta: '${hm(task.dueAt!)} 마감',
            at: task.dueAt!,
            done: task.status == TaskStatus.done,
            taskId: task.id,
          ),
    ];
    entries.sort((a, b) => a.at.compareTo(b.at));
    return entries;
  }

  /// 오늘의 상황: 진행 중, 다음, 남은 빈 시간.
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
      ('빈 시간', '남은 빈 시간 ${durationText(free)}'),
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

/// To-Do 한 줄의 값.
final class _TodoEntry {
  const _TodoEntry({
    required this.title,
    required this.meta,
    required this.at,
    required this.done,
    required this.taskId,
    this.blockId,
  });

  final String title;

  /// 블록이면 시각 범위, 마감이면 '23:59 마감'.
  final String meta;

  /// 정렬 기준(블록 시작, 마감 시각).
  final DateTime at;
  final bool done;
  final int taskId;

  /// 블록이면 그 블록 id, 마감이면 null.
  final int? blockId;
}

/// 상황 한 줄. 넘치면 옆으로 민다.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.lines});

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.tint,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.screen,
          vertical: AppSpace.s8,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              for (final (i, (label, text)) in lines.indexed) ...[
                if (i > 0) const TextSpan(text: '   '),
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: label == '지금' ? AppColors.alert : AppColors.accent,
                    fontWeight: AppText.semibold,
                  ),
                ),
                TextSpan(text: text),
              ],
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: AppText.small,
        ),
      ),
    );
  }
}

/// To-Do와 미배정 할 일 칸. 제목과 함께 칸 안에서 따로 스크롤한다.
class _Region extends StatelessWidget {
  const _Region({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;

  /// 줄이 없을 때의 문장.
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // 하루치 줄이라 짧으므로 한 번에 그린다(화면 읽기도 모든 줄을 읽는다).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s8,
        AppSpace.screen,
        AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.small.copyWith(
                color: AppColors.muted,
                fontWeight: AppText.semibold,
              ),
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Text(
                empty,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.entry, required this.onChanged});

  final _TodoEntry entry;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final done = entry.done;
    return InkWell(
      onTap: () => onChanged(!done),
      child: Row(
        children: [
          Checkbox(
            value: done,
            semanticLabel: entry.title,
            activeColor: AppColors.accent,
            onChanged: (value) => onChanged(value ?? false),
          ),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목은 체크 칸의 이름으로 읽으므로 따로 읽지 않는다.
                ExcludeSemantics(
                  child: Text(
                    entry.title,
                    style: AppText.body.copyWith(
                      color: done ? AppColors.muted : AppColors.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(
                  entry.meta,
                  style: AppText.caption.copyWith(
                    color: AppColors.muted,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
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
