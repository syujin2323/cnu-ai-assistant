// 월간(`/calendar`, 첫 화면). docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 위는 둥근 타일의 월 그리드, 아래는 선택한 날의 일정 패널이다. 그리드는 위아래·좌우로 넘기거나
// 휠을 굴려 달을 바꾸고, 선택한 날을 한 번 더 누르면 그날 일간으로 간다. 패널 손잡이를 위로
// 끌면 실시간 시간표로 펼쳐지는 동작은 다음 PR에서 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_frame.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/live_day.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 월간.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  /// 보이는 달의 1일.
  late DateTime _month;

  /// 선택일 패널을 끌어올려 실시간 시간표로 펼쳤는지.
  bool _expanded = false;

  /// 손잡이를 끄는 동안의 패널 높이. 끌지 않을 때는 null이다.
  double? _dragHeight;

  /// 마지막 배치에서의 본문 전체 높이와 접힌 패널 높이.
  double _total = 0;
  double _collapsed = 0;

  /// 그리드를 끈 거리(달 넘기기).
  Offset _gridDrag = Offset.zero;

  /// 휠로 한 번에 여러 달이 넘어가지 않게 마지막으로 넘긴 때를 둔다.
  DateTime? _lastWheel;

  static const double _flingVelocity = 300;

  /// 이만큼 끌면 빠르기와 상관없이 달을 넘긴다.
  static const double _swipeDistance = 48;
  static const Duration _wheelGap = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    final selected = ref.read(selectedDateProvider);
    _month = DateTime(selected.year, selected.month);
  }

  void _shiftMonth(int by) {
    setState(() => _month = DateTime(_month.year, _month.month + by));
  }

  /// 그리드 끌기가 끝났을 때. 위(왼쪽)로 넘기면 다음 달, 아래(오른쪽)로 넘기면 이전 달.
  void _onGridDragEnd(DragEndDetails details) {
    final drag = _gridDrag;
    _gridDrag = Offset.zero;
    final velocity = details.velocity.pixelsPerSecond;
    final vertical = drag.dy.abs() >= drag.dx.abs();
    final distance = vertical ? drag.dy : drag.dx;
    final speed = vertical ? velocity.dy : velocity.dx;
    if (distance.abs() >= _swipeDistance) {
      _shiftMonth(distance < 0 ? 1 : -1);
    } else if (speed.abs() >= _flingVelocity) {
      _shiftMonth(speed < 0 ? 1 : -1);
    }
  }

  void _onPanelDrag(double dy) {
    final current = _dragHeight ?? (_expanded ? _total : _collapsed);
    setState(() => _dragHeight = (current - dy).clamp(_collapsed, _total));
  }

  /// 손잡이를 놓았을 때. 빠르게 튕겼으면 그 방향, 아니면 놓은 위치가 절반을 넘었는지로 정한다.
  void _onPanelDragEnd(double velocity) {
    final height = _dragHeight ?? (_expanded ? _total : _collapsed);
    final expand = velocity <= -_flingVelocity
        ? true
        : velocity >= _flingVelocity
        ? false
        : height > (_collapsed + _total) / 2;
    setState(() {
      _expanded = expand;
      _dragHeight = null;
    });
  }

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    final now = ref.read(clockProvider).now();
    final last = _lastWheel;
    if (last != null && now.difference(last) < _wheelGap) return;
    _lastWheel = now;
    _shiftMonth(event.scrollDelta.dy > 0 ? 1 : -1);
  }

  void _onDayTap(DateTime day) {
    final selected = ref.read(selectedDateProvider);
    if (day == selected) {
      context.go(Routes.calendarDay(isoDate(day)));
      return;
    }
    ref.read(selectedDateProvider.notifier).select(day);
    if (day.month != _month.month || day.year != _month.year) {
      setState(() => _month = DateTime(day.year, day.month));
    }
  }

  void _onToday() {
    ref.read(selectedDateProvider.notifier).today();
    final today = ref.read(selectedDateProvider);
    setState(() => _month = DateTime(today.year, today.month));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    // 다른 보기(연간·일간·검색)에서 고른 날이 보이는 달 밖이면 그 달로 옮긴다. 월간은 하위 경로 아래에
    // 살아 있으므로 다시 만들어지지 않는다.
    ref.listen(selectedDateProvider, (previous, next) {
      if (next.year != _month.year || next.month != _month.month) {
        setState(() => _month = DateTime(next.year, next.month));
      }
    });
    final selected = ref.watch(selectedDateProvider);
    final today = ref.watch(calendarTodayProvider);
    final title = _month.year == today.year
        ? '${_month.month}월'
        : '${_month.year}년 ${_month.month}월';

    return CalendarFrame(
      view: CalendarView.month,
      title: title,
      onToday: _onToday,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _total = constraints.maxHeight;
          _collapsed = _total * 9 / 20;
          final panel = (_dragHeight ?? (_expanded ? _total : _collapsed))
              .clamp(0.0, _total);
          final animate =
              _dragHeight == null &&
              ref.watch(motionLevelProvider) != MotionLevel.off;
          final duration = animate
              ? const Duration(milliseconds: 220)
              : Duration.zero;
          return Column(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                height: _total - panel,
                // 패널이 올라오는 동안 그리드는 접힌 때의 크기 그대로 두고 아래를 잘라 낸다.
                // 패널이 다 덮으면 그리지 않는다(화면 읽기에서도 빠진다).
                child: panel >= _total - 1
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: _total - _collapsed,
                          child: Column(
                            children: [
                              const _WeekdayRow(),
                              Expanded(
                                child: Listener(
                                  onPointerSignal: _onWheel,
                                  child: GestureDetector(
                                    onPanUpdate: (d) => _gridDrag += d.delta,
                                    onPanEnd: _onGridDragEnd,
                                    child: _MonthGrid(
                                      month: _month,
                                      selected: selected,
                                      today: today,
                                      data: data,
                                      onTap: _onDayTap,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                height: panel,
                child: _DayPanel(
                  day: selected,
                  items: itemsOn(selected, data),
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  onDrag: _onPanelDrag,
                  onDragEnd: _onPanelDragEnd,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 일요일부터 토요일까지 요일 머리줄.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const List<int> _order = [7, 1, 2, 3, 4, 5, 6];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s8,
          0,
          AppSpace.s8,
          AppSpace.s8,
        ),
        child: Row(
          children: [
            for (final weekday in _order)
              Expanded(
                child: Text(
                  weekdayText(weekday),
                  textAlign: TextAlign.center,
                  style: AppText.small.copyWith(color: _weekdayColor(weekday)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _weekdayColor(int weekday, {Color other = AppColors.muted}) =>
    switch (weekday) {
      DateTime.sunday => AppColors.sunday,
      DateTime.saturday => AppColors.saturday,
      _ => other,
    };

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.data,
    required this.onTap,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final CalendarData data;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // 일요일 시작. DateTime.weekday는 월 1 … 일 7이다.
    final first = DateTime(month.year, month.month);
    final start = DateTime(first.year, first.month, 1 - first.weekday % 7);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((first.weekday % 7) + daysInMonth + 6) ~/ 7;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      child: Column(
        children: [
          for (var w = 0; w < weeks; w++)
            Expanded(
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Builder(
                          builder: (context) {
                            final day = DateTime(
                              start.year,
                              start.month,
                              start.day + w * 7 + d,
                            );
                            return _DayCell(
                              day: day,
                              inMonth: day.month == month.month,
                              selected: day == selected,
                              today: day == today,
                              items: itemsOn(day, data),
                              onTap: () => onTap(day),
                            );
                          },
                        ),
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.items,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<CalendarItem> items;
  final VoidCallback onTap;

  static const int _maxChips = 2;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.dayCell);
    final label =
        '${day.month}월 ${day.day}일 ${weekdayText(day.weekday)}요일'
        '${today ? ', 오늘' : ''}, 일정 ${items.length}개';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: inMonth ? 1 : 0.45,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? AppColors.icon : AppColors.edge,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            // 글자가 커져도 넘침 예외 없이 칸 밖은 잘라 낸다.
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _DayNumber(day: day, today: today),
                  ),
                  for (final item in items.take(_maxChips)) _Chip(item: item),
                  if (items.length > _maxChips)
                    Text(
                      '+${items.length - _maxChips}',
                      textAlign: TextAlign.center,
                      style: AppText.tiny.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day, required this.today});

  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      '${day.day}',
      style: AppText.small.copyWith(
        fontWeight: AppText.semibold,
        color: today
            ? AppColors.bg
            : _weekdayColor(day.weekday, other: AppColors.ink),
      ),
    );
    if (!today) {
      return Padding(padding: const EdgeInsets.all(AppSpace.s4), child: text);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: text,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final deadline = item.kind == CalendarItemKind.deadline;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: deadline ? null : itemTint(item.kind),
        borderRadius: deadline ? null : BorderRadius.circular(AppRadius.tag),
        border: deadline
            ? const Border(left: BorderSide(color: AppColors.alert, width: 2))
            : null,
      ),
      child: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: AppText.tiny.copyWith(color: AppColors.ink),
      ),
    );
  }
}

/// 선택한 날의 일정 패널. 손잡이를 끌면 따라 움직이고, 놓은 위치(절반 넘게 올렸는지)나 튕긴 방향으로
/// 실시간 시간표로 펼치거나 접는다. 손잡이를 누르면 펼침·접힘이 바뀐다.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.onDrag,
    required this.onDragEnd,
  });

  final DateTime day;
  final List<CalendarItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  /// 손잡이를 끄는 동안 세로로 움직인 거리(위가 음수).
  final ValueChanged<double> onDrag;

  /// 손잡이를 놓았을 때의 세로 빠르기(위가 음수).
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.edge, blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: expanded ? '하루 시간표 접기' : '하루 시간표 펼치기',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
              onVerticalDragEnd: (details) =>
                  onDragEnd(details.primaryVelocity ?? 0),
              child: const SizedBox(
                width: double.infinity,
                height: AppSize.minTouch / 2,
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.edge,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: expanded
                ? LiveDay(key: ValueKey(day), day: day)
                : ListView(
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
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.s4,
                              ),
                              child: Text(
                                '${weekdayText(day.weekday)}요일',
                                style: AppText.bodyLarge.copyWith(
                                  fontWeight: AppText.semibold,
                                  color: _weekdayColor(
                                    day.weekday,
                                    other: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.s8),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s12,
                          ),
                          child: Text(
                            '일정이 없어요.',
                            style: AppText.body.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      for (final item in items) _ItemRow(item: item),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CalendarItem item;

  String get _meta {
    final start = item.start;
    final end = item.end;
    switch (item.kind) {
      case CalendarItemKind.deadline:
        return item.placed ? '마감 · 시간 정함' : '마감 · 아직 시간을 정하지 않음';
      case _:
        final time = start == null
            ? '종일'
            : end == null
            ? hm(start)
            : '${hm(start)} - ${hm(end)}';
        final place = item.place;
        return place == null ? time : '$time · $place';
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = item.start;
    final taskId = item.taskId;
    final deadline = item.kind == CalendarItemKind.deadline;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              start == null ? '종일' : hm(start),
              style: AppText.body.copyWith(fontWeight: AppText.medium),
            ),
          ),
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: deadline && !item.placed ? null : itemBar(item.kind),
              border: deadline && !item.placed
                  ? Border.all(color: itemBar(item.kind), width: 1.5)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.bodyLarge),
                Text(
                  _meta,
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (taskId == null) return row;
    // 시간을 정하지 않은 마감은 배치 시트를, 그 밖(정한 마감·블록)은 할 일 상세를 연다.
    return InkWell(
      onTap: deadline && !item.placed
          ? () => showAddSheet(context, day: item.start!, taskId: taskId)
          : () => context.push(Routes.task(taskId)),
      child: row,
    );
  }
}
