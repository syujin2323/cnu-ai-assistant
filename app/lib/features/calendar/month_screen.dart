// 08 월간(캘린더 탭 `/calendar/month`). docs/screens.md '08 월간'.
//
// 이벤트만 보인다: 약속·행사 같은 일정, 종일 일정, 시험인 수업, 공휴일(`domain/holidays.dart`). 수업·고정 일정·
// 할 일·마감은 11 주간과 09 일간에서 본다. 일정이 있는 날은 날짜 아래 점, 공휴일은 붉은 날짜와 이름이다
// (`domain/month_view.dart`). 날짜를 누르면 아래 목록이 그날로 바뀌고, 카드는 일정 정보 시트를 연다. '이 날 일간
// 보기'는 09 일간을 `Routes.day(날짜, from: DayViewFrom.month)`로 열고, '주'는 같은 자리에서 11 주간으로 바꿔
// 끼운다(뒤로 화살표 없음). 보는 달과 고른 날은 화면을 떠나면 처음(이번 달, 오늘)으로 돌아간다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/holidays.dart';
import 'package:cnu_ai_assistant/domain/month_view.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/calendar_view_switch.dart';
import 'package:cnu_ai_assistant/features/today/day_screen.dart'
    show DayViewFrom;
import 'package:cnu_ai_assistant/features/today/event_info_actions.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// [month](그 달의 1일)의 달력 범위에 있는 일정과 수업 예외. 일정 표가 바뀌면 다시 낸다.
final monthScheduleProvider = StreamProvider.family<Schedule, DateTime>(
  (ref, month) => ref
      .watch(scheduleRepositoryProvider)
      .watch(start: monthGridStart(month), end: monthGridEnd(month)),
);

/// 08 월간.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  /// 이번 달에서 떨어진 달 수.
  int _offset = 0;

  /// 고른 날. null이면 오늘(다른 달을 보면 그 달의 1일)이다.
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = ref.watch(minuteClockProvider);
    final boundary =
        ref.watch(settingsProvider.select((s) => s.value?.dayBoundaryMin)) ??
        Defaults.dayBoundaryMin;
    final today = logicalDate(now, dayBoundaryMin: boundary);
    final month = DateTime(today.year, today.month + _offset);
    final selected = _picked ?? (_offset == 0 ? today : month);
    final schedule = ref.watch(monthScheduleProvider(month));
    final view = monthView(
      month: month,
      today: today,
      selected: selected,
      events: schedule.value?.events ?? const [],
      exceptions: schedule.value?.classExceptions ?? const [],
      dayBoundaryMin: boundary,
    );
    void shift(int months) => setState(() {
      _offset += months;
      _picked = null;
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s12,
            AppSpace.screen,
            120,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(
                            view.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (view.showToday)
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpace.s4),
                          child: TextButton(
                            onPressed: () => setState(() {
                              _offset = 0;
                              _picked = null;
                            }),
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
                        tooltip: '지난달',
                        onPressed: () => shift(-1),
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
                        tooltip: '다음 달',
                        onPressed: () => shift(1),
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
            ),
            const SizedBox(height: AppSpace.s8),
            const Align(
              alignment: Alignment.centerLeft,
              child: CalendarViewSwitch(current: CalendarView.month),
            ),
            const SizedBox(height: AppSpace.s12),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    Expanded(
                      child: Text(
                        weekdayText(day),
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          fontWeight: AppText.semibold,
                          color: day == DateTime.sunday
                              ? colors.alert
                              : colors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            for (final week in view.weeks)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cell in week)
                    Expanded(
                      child: _Cell(
                        cell: cell,
                        onTap: () => setState(() => _picked = cell.date),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpace.s16),
            _DayList(
              date: selected,
              today: today,
              onOpenDay: () =>
                  context.go(Routes.day(selected, from: DayViewFrom.month)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.onTap});

  final MonthCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final holiday = cell.holiday;
    final ink = cell.selected
        ? colors.onStrong
        : cell.red
        ? colors.alert
        : colors.ink;
    return Semantics(
      container: true,
      button: true,
      selected: cell.selected,
      label: [
        '${cell.date.month}월 ${cell.date.day}일',
        if (cell.today) '오늘',
        ?holiday,
        if (cell.dot) '일정 있음',
      ].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Opacity(
          opacity: cell.inMonth ? 1 : .38,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cell.selected ? colors.strong : null,
                    shape: BoxShape.circle,
                    border: cell.today && !cell.selected
                        ? Border.all(color: colors.strong)
                        : null,
                  ),
                  child: Text(
                    '${cell.date.day}',
                    style: AppText.small.copyWith(
                      fontWeight: cell.today || cell.selected
                          ? AppText.semibold
                          : AppText.medium,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 6,
                  child: cell.dot
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.personalInk,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                if (holiday != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      holiday,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(
                        fontSize: 10,
                        color: colors.alert,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 고른 날의 이벤트 목록.
class _DayList extends ConsumerWidget {
  const _DayList({
    required this.date,
    required this.today,
    required this.onOpenDay,
  });

  final DateTime date;
  final DateTime today;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final home = ref.watch(dayHomeProvider(date)).value;
    final holiday = holidayName(date);
    final rows = <({DayItem item, String time, String title, String kind})>[
      for (final event in home?.allDay ?? const [])
        (
          item: EventItem(TimeSpan(event.startAt, event.endAt), event: event),
          time: '종일',
          title: event.title,
          kind: '일정',
        ),
      for (final item in home?.items ?? const <DayItem>[])
        if (item case EventItem(:final event))
          (item: item, time: _range(item.span), title: event.title, kind: '일정')
        else if (item case ClassItem(exam: true, :final slot))
          (
            item: item,
            time: _range(item.span),
            title: home?.courseNames[slot.courseId] ?? '수업',
            kind: '시험',
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  monthDayText(date, today: today),
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
              ),
            ),
            TextButton(onPressed: onOpenDay, child: const Text('이 날 일간 보기 ›')),
          ],
        ),
        if (holiday != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: Text(
              '$holiday · 공휴일',
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.alert,
              ),
            ),
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Text(
              '이 날은 일정이 없어요',
              style: AppText.small.copyWith(color: colors.muted),
            ),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: _EventCard(
              time: row.time,
              title: row.title,
              kind: row.kind,
              look: switch (row.item) {
                ClassItem(:final slot) => CourseColors.of(
                  context,
                  slot.courseId,
                ),
                _ => (
                  tint: colors.personalTint,
                  line: colors.personalLine,
                  ink: colors.personalInk,
                ),
              },
              onTap: () => openEventInfoSheet(context, ref, row.item),
            ),
          ),
      ],
    );
  }

  static String _range(TimeSpan span) =>
      '${hhmmText(span.start.hour * 60 + span.start.minute)}–'
      '${hhmmText(span.end.hour * 60 + span.end.minute)}';
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.time,
    required this.title,
    required this.kind,
    required this.look,
    required this.onTap,
  });

  final String time;
  final String title;
  final String kind;
  final CourseLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      label: '$kind, $title, $time',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: look.tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: BorderSide(color: look.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body.copyWith(
                            fontWeight: AppText.semibold,
                            color: colors.ink,
                          ),
                        ),
                        Text(
                          '$kind · $time',
                          style: AppText.caption.copyWith(
                            color: look.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIcon(
                    AppIconName.chevronRight,
                    size: 16,
                    color: colors.icon,
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
