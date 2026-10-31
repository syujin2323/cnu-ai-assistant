// 주간(`/calendar/week`). 선택한 날이 든 주(일요일 시작)의 7일을 0~24시 시간표로 보여 준다.
// 좌우로 넘기면 앞뒤 주, 날짜를 누르면 그날 일간이다. docs/architecture.md '화면 이동'.

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

/// 주간.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  late final ScrollController _scroll;

  static const double _flingVelocity = 300;

  @override
  void initState() {
    super.initState();
    final today = ref.read(calendarTodayProvider);
    final inThisWeek = weekOf(ref.read(selectedDateProvider)).contains(today);
    _scroll = ScrollController(
      initialScrollOffset: TimeGrid.initialOffset(
        inThisWeek ? ref.read(clockProvider).now() : null,
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _shiftWeek(double? velocity) {
    if (velocity == null || velocity.abs() < _flingVelocity) return;
    final selected = ref.read(selectedDateProvider);
    ref
        .read(selectedDateProvider.notifier)
        .select(selected.add(Duration(days: velocity < 0 ? 7 : -7)));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(nowProvider).value;
    final days = weekOf(ref.watch(selectedDateProvider));
    final first = days.first, last = days.last;
    final title = first.month == last.month
        ? '${first.month}월'
        : '${first.month}–${last.month}월';
    return CalendarFrame(
      view: CalendarView.week,
      title: title,
      body: GestureDetector(
        onHorizontalDragEnd: (d) => _shiftWeek(d.primaryVelocity),
        child: Column(
          children: [
            WeekStrip(
              days: days,
              today: today,
              onTap: (day) {
                ref.read(selectedDateProvider.notifier).select(day);
                context.go(Routes.calendarDay(isoDate(day)));
              },
            ),
            AllDayRow(days: days, data: data),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 4,
                  bottom: CalendarBottomBar.height,
                ),
                child: TimeGrid(
                  days: days,
                  data: data,
                  now: now,
                  showTimes: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
