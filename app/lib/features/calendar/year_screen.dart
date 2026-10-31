// 연간(`/calendar/year`). 열두 달의 작은 달력이고, 일정이 있는 날 아래에 점을 찍는다. 좌우로 넘기면
// 앞뒤 해, 달을 누르면 그 달 월간이다. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_frame.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/week_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 연간.
class YearScreen extends ConsumerStatefulWidget {
  const YearScreen({super.key});

  @override
  ConsumerState<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends ConsumerState<YearScreen> {
  late int _year = ref.read(selectedDateProvider).year;

  static const double _flingVelocity = 300;

  void _openMonth(int month) {
    final today = ref.read(calendarTodayProvider);
    final day = today.year == _year && today.month == month
        ? today
        : DateTime(_year, month);
    ref.read(selectedDateProvider.notifier).select(day);
    context.go(Routes.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    return CalendarFrame(
      view: CalendarView.year,
      title: '$_year년',
      onToday: () => setState(() => _year = today.year),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity;
          if (v == null || v.abs() < _flingVelocity) return;
          setState(() => _year += v < 0 ? 1 : -1);
        },
        child: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 0.78,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s8,
            0,
            AppSpace.s8,
            CalendarBottomBar.height,
          ),
          children: [
            for (var month = 1; month <= 12; month++)
              _MiniMonth(
                year: _year,
                month: month,
                today: today,
                data: data,
                onTap: () => _openMonth(month),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.year,
    required this.month,
    required this.today,
    required this.data,
    required this.onTap,
  });

  final int year;
  final int month;
  final DateTime today;
  final CalendarData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month);
    final lead = first.weekday % 7;
    final days = DateTime(year, month + 1, 0).day;
    final current = today.year == year && today.month == month;
    return Semantics(
      button: true,
      label: '$year년 $month월',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          // 글자가 커져도 넘침 예외 없이 칸 밖은 잘라 낸다.
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$month월',
                  style: AppText.body.copyWith(
                    fontWeight: AppText.semibold,
                    color: current ? AppColors.accent : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                    for (var d = 1; d <= days; d++)
                      _MiniDay(
                        day: DateTime(year, month, d),
                        today: today,
                        hasItems: itemsOn(
                          DateTime(year, month, d),
                          data,
                        ).isNotEmpty,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDay extends StatelessWidget {
  const _MiniDay({
    required this.day,
    required this.today,
    required this.hasItems,
  });

  final DateTime day;
  final DateTime today;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    // 칸이 작아 세로로 쌓지 않고 겹쳐 놓는다(점은 글자 아래쪽 가장자리).
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Text(
          '${day.day}',
          textScaler: TextScaler.noScaling,
          style: AppText.tiny.copyWith(
            fontWeight: isToday ? AppText.semibold : null,
            color: isToday
                ? AppColors.accent
                : weekdayColor(day.weekday, other: AppColors.ink),
          ),
        ),
        if (hasItems)
          const Positioned(
            bottom: 0,
            child: SizedBox.square(
              dimension: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
