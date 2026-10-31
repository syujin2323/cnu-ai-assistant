// 월간(`/calendar`, 첫 화면). docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 세 가지 모양을 위아래로 넘겨 바꾼다(삼성 캘린더와 같다).
// - 기본: 위는 둥근 타일의 월 그리드, 아래는 선택한 날의 일정 패널, 맨 아래 하단 바.
// - 데일리 스케줄: 기본에서 그리드나 패널 손잡이를 위로 넘기면 패널이 상단바 아래를 모두 덮는다.
//   맨 위 고정 머리줄('29일 목요일 데일리 스케줄', 닫기 X) 아래에 실시간 시간표 · To-Do · 오늘 미배정
//   할 일을 5:2:2로 둔다(`widgets/live_day.dart`). 하단 바는 숨긴다. 손잡이를 아래로 끌거나 누르거나
//   X를 누르면 기본으로 돌아간다.
// - 전체 달: 기본에서 그리드를 아래로 넘기면 패널이 사라지고 그리드가 본문을 모두 쓴다. 날짜 칸마다
//   일정 제목을 두 줄까지 색선과 함께 보여 준다. 일요일 칸은 숫자 아래에 음력('9.22')을 적는다
//   (라우터가 [MonthScreen.daySubtitle]로 넘긴다). 위로 넘기면 기본으로 돌아간다.
// 기본 모양 패널 머리는 '16 월요일' 옆에 작게 '음력 10월 8일'을 적는다(삼성 캘린더와 같다).
// 좌우로 넘기거나 휠을 굴리면 달이 바뀌고, 모션이 켜져 있으면 그리드가 옆으로 밀린다. 선택한 날을
// 한 번 더 누르면 그날 일간으로 간다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/text/lunar.dart';
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
  const MonthScreen({super.key, this.daySubtitle});

  /// 전체 달 모양에서 날짜 칸의 숫자 아래에 적을 작은 글(예: 음력 날짜). null을 돌려주면 아무것도
  /// 적지 않는다. 어느 칸에 적을지(예: 일요일 열만)는 이 함수가 정한다. 기본 모양 칸에는 적지 않는다.
  final String? Function(DateTime day)? daySubtitle;

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

/// 월간의 세 모양.
enum _MonthMode {
  /// 월 그리드 + 선택일 패널 + 하단 바.
  normal,

  /// 그리드만(칸마다 일정 제목) + 하단 바.
  fullMonth,

  /// 선택일 패널이 본문을 모두 덮은 데일리 스케줄. 하단 바는 숨긴다.
  daily,
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  /// 보이는 달의 1일.
  late DateTime _month;

  /// 마지막으로 달이 바뀐 방향(1 다음 달, -1 이전 달). 그리드가 밀리는 방향이다.
  int _slide = 1;

  _MonthMode _mode = _MonthMode.normal;

  /// 선택일 패널을 끌어올려 데일리 스케줄로 펼쳤는지.
  bool get _expanded => _mode == _MonthMode.daily;

  /// 손잡이를 끄는 동안의 패널 높이. 끌지 않을 때는 null이다.
  double? _dragHeight;

  /// 마지막 배치에서의 본문 전체 높이와 접힌 패널 높이.
  double _total = 0;
  double _collapsed = 0;

  /// 그리드를 끈 거리(좌우는 달 넘기기, 위아래는 모양 바꾸기).
  Offset _gridDrag = Offset.zero;

  /// 휠로 한 번에 여러 달이 넘어가지 않게 마지막으로 넘긴 때를 둔다.
  DateTime? _lastWheel;

  static const double _flingVelocity = 300;

  /// 이만큼 끌면 빠르기와 상관없이 넘긴다.
  static const double _swipeDistance = 48;
  static const Duration _wheelGap = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    final selected = ref.read(selectedDateProvider);
    _month = DateTime(selected.year, selected.month);
  }

  void _shiftMonth(int by) {
    setState(() {
      _slide = by;
      _month = DateTime(_month.year, _month.month + by);
    });
  }

  /// [day]가 든 달로 옮긴다. 이미 그 달이면 그대로다.
  void _showMonthOf(DateTime day) {
    final month = DateTime(day.year, day.month);
    if (month == _month) return;
    setState(() {
      _slide = month.isAfter(_month) ? 1 : -1;
      _month = month;
    });
  }

  /// 그리드 끌기가 끝났을 때. 끈 거리(없으면 빠르기)가 큰 쪽의 방향으로 정한다. 왼쪽으로 넘기면
  /// 다음 달, 오른쪽은 이전 달이다. 위로 넘기면 전체 달은 기본으로, 기본은 데일리 스케줄로
  /// 펼치고, 아래로 넘기면 기본이 전체 달이 된다.
  void _onGridDragEnd(DragEndDetails details) {
    final drag = _gridDrag;
    _gridDrag = Offset.zero;
    final velocity = details.velocity.pixelsPerSecond;
    final Offset motion;
    if (drag.distance >= _swipeDistance) {
      motion = drag;
    } else if (velocity.distance >= _flingVelocity) {
      motion = velocity;
    } else {
      return;
    }
    if (motion.dx.abs() > motion.dy.abs()) {
      _shiftMonth(motion.dx < 0 ? 1 : -1);
      return;
    }
    final up = motion.dy < 0;
    final next = switch (_mode) {
      _MonthMode.normal => up ? _MonthMode.daily : _MonthMode.fullMonth,
      _MonthMode.fullMonth => up ? _MonthMode.normal : _MonthMode.fullMonth,
      _MonthMode.daily => _MonthMode.daily,
    };
    if (next != _mode) setState(() => _mode = next);
  }

  /// 지금 모양에서 패널이 차지할 높이.
  double get _panelTarget => switch (_mode) {
    _MonthMode.normal => _collapsed,
    _MonthMode.fullMonth => 0,
    _MonthMode.daily => _total,
  };

  void _onPanelDrag(double dy) {
    final current = _dragHeight ?? _panelTarget;
    setState(() => _dragHeight = (current - dy).clamp(_collapsed, _total));
  }

  /// 손잡이를 놓았을 때. 빠르게 튕겼으면 그 방향, 아니면 놓은 위치가 절반을 넘었는지로 정한다.
  void _onPanelDragEnd(double velocity) {
    final height = _dragHeight ?? _panelTarget;
    final expand = velocity <= -_flingVelocity
        ? true
        : velocity >= _flingVelocity
        ? false
        : height > (_collapsed + _total) / 2;
    setState(() {
      _mode = expand ? _MonthMode.daily : _MonthMode.normal;
      _dragHeight = null;
    });
  }

  void _setExpanded(bool expanded) =>
      setState(() => _mode = expanded ? _MonthMode.daily : _MonthMode.normal);

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
    _showMonthOf(day);
  }

  void _onToday() {
    ref.read(selectedDateProvider.notifier).today();
    _showMonthOf(ref.read(selectedDateProvider));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    // 다른 보기(연간·일간·검색)에서 고른 날이 보이는 달 밖이면 그 달로 옮긴다. 월간은 하위 경로 아래에
    // 살아 있으므로 다시 만들어지지 않는다.
    ref.listen(selectedDateProvider, (previous, next) => _showMonthOf(next));
    final selected = ref.watch(selectedDateProvider);
    final today = ref.watch(calendarTodayProvider);
    final motionOn = ref.watch(motionLevelProvider) != MotionLevel.off;
    final title = _month.year == today.year
        ? '${_month.month}월'
        : '${_month.year}년 ${_month.month}월';
    final fullMonth = _mode == _MonthMode.fullMonth;

    return CalendarFrame(
      view: CalendarView.month,
      title: title,
      onToday: _onToday,
      showBottomBar: !_expanded,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _total = constraints.maxHeight;
          _collapsed = _total * 9 / 20;
          final panel = (_dragHeight ?? _panelTarget).clamp(0.0, _total);
          final duration = _dragHeight == null && motionOn
              ? AppMotion.standard
              : Duration.zero;
          Widget grid = _MonthGrid(
            key: ValueKey(_month),
            month: _month,
            selected: selected,
            today: today,
            data: data,
            full: fullMonth,
            subtitle: widget.daySubtitle,
            onTap: _onDayTap,
          );
          if (motionOn) {
            // 달이 바뀌면 새 달은 넘긴 쪽에서 들어오고 이전 달은 반대쪽으로 나간다.
            grid = AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppEase.standard,
              switchOutCurve: AppEase.standard,
              layoutBuilder: (current, previous) =>
                  Stack(children: [...previous, ?current]),
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(_month);
                final from = (incoming ? _slide : -_slide).toDouble();
                return SlideTransition(
                  position: Tween(
                    begin: Offset(from, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: grid,
            );
          }
          return Column(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: AppEase.standard,
                height: _total - panel,
                // 패널이 올라오는 동안 그리드는 접힌 때의 크기 그대로 두고 아래를 잘라 낸다.
                // 패널이 다 덮으면 그리지 않는다(화면 읽기에서도 빠진다).
                child: panel >= _total - 1
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: 0,
                          maxHeight: fullMonth ? _total : _total - _collapsed,
                          child: Column(
                            children: [
                              const _WeekdayRow(),
                              Expanded(
                                child: Listener(
                                  onPointerSignal: _onWheel,
                                  child: GestureDetector(
                                    onPanUpdate: (d) => _gridDrag += d.delta,
                                    onPanEnd: _onGridDragEnd,
                                    child: Padding(
                                      // 전체 달에서는 마지막 주가 하단 바에 가리지 않게 비운다.
                                      padding: EdgeInsets.only(
                                        bottom: fullMonth
                                            ? CalendarBottomBar.height
                                            : 0,
                                      ),
                                      child: ClipRect(child: grid),
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
                curve: AppEase.standard,
                height: panel,
                // 너무 낮아 손잡이도 들어가지 않는 동안(전체 달로 접히거나 펼 때)은 그리지 않는다.
                child: LayoutBuilder(
                  builder: (context, box) =>
                      box.maxHeight < AppSize.minTouch * 2
                      ? const SizedBox.shrink()
                      : _DayPanel(
                          day: selected,
                          items: itemsOn(selected, data),
                          expanded: _expanded,
                          onToggle: () => _setExpanded(!_expanded),
                          onClose: () => _setExpanded(false),
                          onDrag: _onPanelDrag,
                          onDragEnd: _onPanelDragEnd,
                        ),
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
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.data,
    required this.full,
    required this.subtitle,
    required this.onTap,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final CalendarData data;

  /// 전체 달 모양인지(칸마다 일정 제목을 두 줄까지).
  final bool full;

  /// 숫자 아래 작은 글. [MonthScreen.daySubtitle]. [full]일 때만 쓴다.
  final String? Function(DateTime day)? subtitle;
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
                              full: full,
                              // 기본 모양 칸은 좁아서 전체 달에서만 적는다.
                              subtitle: full ? subtitle?.call(day) : null,
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
    required this.full,
    required this.subtitle,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<CalendarItem> items;

  /// 전체 달 모양이면 제목을 두 줄까지 색선과 함께, 세 개까지 보여 준다.
  final bool full;

  /// 숫자 아래 작은 글(없으면 null).
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxChips = full ? 3 : 2;
    final subtitle = this.subtitle;
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
                  if (subtitle != null)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppText.tiny.copyWith(color: AppColors.muted),
                    ),
                  for (final item in items.take(maxChips))
                    full ? _TallChip(item: item) : _Chip(item: item),
                  if (items.length > maxChips)
                    Text(
                      '+${items.length - maxChips}',
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

/// 전체 달 칸의 일정: 왼쪽 색선과 제목 두 줄.
class _TallChip extends StatelessWidget {
  const _TallChip({required this.item});

  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final deadline = item.kind == CalendarItemKind.deadline;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(left: 3, right: 2),
      decoration: BoxDecoration(
        color: deadline ? null : itemTint(item.kind),
        border: Border(
          left: BorderSide(
            color: deadline ? AppColors.alert : itemBar(item.kind),
            width: 2,
          ),
        ),
      ),
      child: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.tiny.copyWith(color: AppColors.ink),
      ),
    );
  }
}

/// 선택한 날의 일정 패널. 손잡이를 끌면 따라 움직이고, 놓은 위치(절반 넘게 올렸는지)나 튕긴 방향으로
/// 데일리 스케줄로 펼치거나 접는다. 손잡이를 누르면 펼침·접힘이 바뀐다. 펼치면 손잡이 아래에
/// 고정 머리줄('29일 목요일 데일리 스케줄'과 닫기 X)을 두고 그 아래를 [LiveDay]가 채운다.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.day,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.onClose,
    required this.onDrag,
    required this.onDragEnd,
  });

  final DateTime day;
  final List<CalendarItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  /// 머리줄의 X. 접는다.
  final VoidCallback onClose;

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
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.screen,
                0,
                AppSpace.s4,
                AppSpace.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${day.day}일 ${weekdayText(day.weekday)}요일 데일리 스케줄',
                        style: AppText.title,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: onClose,
                    icon: const AppIcon(
                      AppIconName.close,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          if (expanded) const Divider(height: 1, color: AppColors.edge),
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
                            // 삼성 캘린더처럼 요일 옆에 작게 음력을 적는다. 표 범위 밖이면 뺀다.
                            if (lunarText(day) case final lunar?)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.s4,
                                ),
                                child: Text(
                                  lunar,
                                  style: AppText.small.copyWith(
                                    color: AppColors.muted,
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
