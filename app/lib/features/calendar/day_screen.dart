// 일간(`/calendar/day/:date`). 월간에서 선택한 날을 한 번 더 누르거나 드로어의 '일'로 연다.
// 위는 그 주의 요일 줄, 아래는 그날의 종일·마감 띠와 0~24시 시간표다. 좌우로 넘기면 앞뒤 날이다.
// docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_frame.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/time_grid.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/week_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 일간.
class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, required this.date});

  /// 보여 줄 날짜(`YYYY-MM-DD`). 읽을 때는 `domain/clock.dart`의 [tryParseIsoDate]를 쓴다.
  final String date;

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  late final ScrollController _scroll;

  static const double _flingVelocity = 300;

  DateTime get _day =>
      tryParseIsoDate(widget.date) ?? ref.read(calendarTodayProvider);

  @override
  void initState() {
    super.initState();
    final isToday = _day == ref.read(calendarTodayProvider);
    _scroll = ScrollController(
      initialScrollOffset: TimeGrid.initialOffset(
        isToday ? ref.read(clockProvider).now() : null,
      ),
    );
    // 경로의 날짜를 선택한 날로 둔다(추가 알약·다른 보기가 같은 날을 본다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(selectedDateProvider.notifier).select(_day);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(DateTime day) {
    ref.read(selectedDateProvider.notifier).select(day);
    context.go(Routes.calendarDay(isoDate(day)));
  }

  void _shiftDay(double? velocity) {
    if (velocity == null || velocity.abs() < _flingVelocity) return;
    _goTo(_day.add(Duration(days: velocity < 0 ? 1 : -1)));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(nowProvider).value;
    final day = _day;
    return CalendarFrame(
      view: CalendarView.day,
      title: '${day.month}월 ${day.day}일',
      onToday: () => _goTo(today),
      body: GestureDetector(
        onHorizontalDragEnd: (d) => _shiftDay(d.primaryVelocity),
        child: Column(
          children: [
            WeekStrip(
              days: weekOf(day),
              today: today,
              selected: day,
              onTap: _goTo,
            ),
            AllDayRow(days: [day], data: data),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 12,
                  bottom: CalendarBottomBar.height,
                ),
                child: TimeGrid(days: [day], data: data, now: now),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
