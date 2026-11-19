// 09 일간(오늘 탭 `/today/day/:date`). docs/screens.md '09 일간', docs/architecture.md '화면 이동'.
//
// 들어오는 길은 02 홈 '일간 보기', 11 주간 날짜 줄·일정 줄, 08 월간 '이 날 일간 보기', 06 AI 비서 답
// '일간에서 보기'이고, 어디서 열든 `context.go(Routes.day(날짜, from: …))`로 열어 늘 오늘 탭에 둔다.
// 11·08에서 열면 [DayViewFrom]을 넘기고, 뒤로 가면 오늘 탭에서 이 화면이 빠진 뒤 그 화면으로 간다
// (docs/decisions.md 2026-11-13 '다른 탭에서 연 09 일간은 오늘 탭에 두고 뒤로 가면 온 화면으로
// 돌아간다'). 02 홈과 06 AI 비서에서 열면 넘기지 않고, 뒤로 가면 02 홈이다. 날짜를 넘길 때(날짜 줄, ‹ ›로 지난주·
// 다음 주 같은 요일, 화면을 옆으로 밀기, '오늘')는 `replace`로 이 화면만 바꿔 끼워 뒤로가 지난 날을 거치지 않게 한다.
//
// 위에서부터 위 막대(뒤로, 주 범위와 '오늘', ‹ ›), 날짜 줄 7칸, 머리(날짜와 요약 줄), 종일 일정, '모두 확정' 띠,
// 빈 날 카드, 마감 줄, 시간표다. 시간표는 02 홈과 같은 `DayTimeline`이고 제안 블록('제안')도 그리며, 지난 일정을
// 접지 않고 지난 날에는 빈 시간 카드를 그리지 않는다. 누르면: 블록 → 근거 시트, 체크 → 블록 완료, 수업·일정 →
// 일정 정보 시트, 빈 시간 → 빈 시간에 놓기 시트, 마감 줄 → 작은 할 일 시트. 보일 것은
// `domain/day_view.dart`가 정하고, 모양은 최종 프로토타입(09 일간)을 따른다. 'HH:MM에 놓기'와 학사일정·공휴일은
// 그 PR(S6 2부, H1)에서 더한다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/data/metrics_reporter.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/dashed_border.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline_layout.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/day_view.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/tasks/task_actions.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:cnu_ai_assistant/features/today/day_controller.dart';
import 'package:cnu_ai_assistant/features/today/event_info_actions.dart';
import 'package:cnu_ai_assistant/features/today/free_slot_actions.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 09 일간을 연 다른 탭의 화면. 뒤로 가면 이 화면으로 돌아간다.
enum DayViewFrom {
  /// 11 주간(캘린더 탭).
  week,

  /// 08 월간(캘린더 탭).
  month;

  /// 돌아갈 경로.
  String get location => switch (this) {
    DayViewFrom.week => Routes.calendar,
    DayViewFrom.month => Routes.calendarMonth,
  };
}

/// 옆으로 밀어 날짜를 넘기는 가장 느린 속도(논리 픽셀/초, 임시).
const double _swipeVelocity = 300;

/// 09 일간.
class DayScreen extends ConsumerWidget {
  const DayScreen({super.key, required this.date, this.from});

  /// 보여 줄 날짜(그날 0시의 로컬 시각).
  final DateTime date;

  /// 다른 탭에서 열었으면 뒤로 가면 돌아갈 화면. null이면 02 홈으로 돌아간다.
  final DayViewFrom? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 뒤로 간 뒤에는 이 화면의 context를 쓸 수 없으므로 라우터를 미리 잡아 둔다.
    final router = GoRouter.of(context);
    final from = this.from;
    final colors = AppColors.of(context);
    final data = ref.watch(dayViewProvider(date));
    final value = data.value;
    return PopScope(
      // 뒤로 가기는 막지 않는다(iOS 왼쪽 끝 스와이프 뒤로를 살림). 오늘 탭에서 이 화면이 빠진 뒤 연
      // 화면으로 가며, 스와이프하는 동안 아래에 02 홈이 비치는 것은 받아들였다. 그 탭의 화면 상태는 남는다.
      // 이 콜백은 오늘 탭을 다시 누르거나 다른 곳으로 가서 이 화면이 빠질 때도 불리고, 어느 쪽이든 라우터는
      // 이미 새 위치에 있다. 뒤로 가기로 닫혔을 때만 연 화면으로 간다([Routes.isDayClosedByBack]).
      onPopInvokedWithResult: (didPop, result) {
        if (didPop &&
            from != null &&
            Routes.isDayClosedByBack(router.state.uri, from)) {
          router.go(from.location);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: value == null
              ? (data.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.screen),
                          child: Text(
                            '이 날 일정을 불러오지 못했어요',
                            textAlign: TextAlign.center,
                            style: AppText.body.copyWith(color: colors.muted),
                          ),
                        ),
                      )
                    : const SizedBox.shrink())
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity.abs() < _swipeVelocity) return;
                    _showDay(context, velocity < 0 ? 1 : -1);
                  },
                  child: _content(context, ref, value),
                ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, DayViewData data) {
    final colors = AppColors.of(context);
    final view = data.view;
    final home = data.home;
    final today = logicalDate(home.now, dayBoundaryMin: home.dayBoundaryMin);
    final isToday = home.date == today;
    final past = home.date.isBefore(today);
    final layout = layoutDayTimeline(
      day: home.date,
      items: home.items,
      // 제안 자리를 뺀 빈 시간이다(지난 날은 비어 있음).
      free: view.free,
      now: home.now,
      today: isToday,
      windowEndMin: home.windowEndMin,
      showPast: true,
      showTravelMeal: home.showTravelMeal,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        MediaQuery.paddingOf(context).bottom + AppSpace.s24,
      ),
      children: [
        Rise(
          child: _TopBar(view: view, onShow: (d) => _showDate(context, d)),
        ),
        Rise(
          delay: const Duration(milliseconds: 50),
          child: _Strip(days: view.strip, onPick: (d) => _showDate(context, d)),
        ),
        Rise(
          delay: const Duration(milliseconds: 110),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(view.title, style: AppText.heading),
                ),
                const SizedBox(height: 2),
                Text(
                  view.sub,
                  style: AppText.small.copyWith(
                    color: colors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final allDay in view.allDay)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8),
            child: _AllDayCard(
              allDay: allDay,
              onTap: () => openEventInfoSheet(
                context,
                ref,
                EventItem(
                  TimeSpan(allDay.event.startAt, allDay.event.endAt),
                  event: allDay.event,
                ),
              ),
            ),
          ),
        if (view.confirmable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s12),
            child: _ConfirmBand(
              title: view.confirmTitle,
              onConfirm: () => _confirmAll(ref, view),
            ),
          ),
        if (view.empty case final empty?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s12),
            child: _EmptyCard(empty: empty),
          ),
        if (view.dues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                for (final row in view.dues)
                  _DueRow(
                    row: row,
                    onTap: () => openTaskSheet(context, ref, row.entry.task.id),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: '${view.title} 시간표',
          explicitChildNodes: true,
          child: DayTimeline(
            layout: layout,
            day: home.date,
            now: home.now,
            dayBoundaryMin: home.dayBoundaryMin,
            courseNames: home.courseNames,
            onItemTap: (item) => openEventInfoSheet(context, ref, item),
            onBlockTap: (item) => openBlockSheet(context, ref, item.block),
            onBlockCheck: ref.read(homeAnswerProvider.notifier).toggleBlock,
            onFreeTap: past
                ? null
                : (gap) => openFreeSlotSheet(context, ref, gap),
          ),
        ),
      ],
    );
  }

  /// '모두 확정': 그날 확정 전 제안을 엔진 자리 그대로 확정한다(되돌리기 토스트).
  Future<void> _confirmAll(WidgetRef ref, DayView view) async {
    final toast = ref.read(toastControllerProvider.notifier);
    final metrics = ref.read(metricsReporterProvider);
    final result = await ref.read(planBlockRepositoryProvider).confirm([
      for (final block in view.confirmable) block.id,
    ], now: ref.read(clockProvider).now());
    switch (result) {
      case Ok(value: true):
        toast.show(view.confirmedToast, undoable: true);
        unawaited(metrics.noteConfirmed());
      case Ok():
        // 그사이 재계산이 제안을 바꿔 끼웠다.
        toast.show('제안이 바뀌었어요. 다시 확인해 주세요');
      case Err():
        toast.show('확정하지 못했어요. 다시 해 주세요');
    }
  }

  /// [days]만큼 옮긴 날로 바꿔 끼운다(쌓지 않음).
  void _showDay(BuildContext context, int days) =>
      _showDate(context, DateTime(date.year, date.month, date.day + days));

  /// [day]로 바꿔 끼운다(쌓지 않음). 지금 날이면 그대로 둔다.
  void _showDate(BuildContext context, DateTime day) {
    if (day == date) return;
    context.replace(Routes.day(day, from: from));
  }
}

/// 위 막대: 뒤로, 주 범위와 '오늘', 지난주·다음 주 같은 요일.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.view, required this.onShow});

  final DayView view;
  final ValueChanged<DateTime> onShow;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selected = view.strip.firstWhere((day) => day.selected).date;
    DateTime shifted(int days) =>
        DateTime(selected.year, selected.month, selected.day + days);
    return Row(
      children: [
        const BackButton(),
        Expanded(
          // 주 범위가 길면 줄임표로 줄이고 '오늘' 알약은 같은 줄 끝에 둔다(최종 프로토타입).
          child: Row(
            children: [
              Flexible(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    view.weekLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      fontWeight: AppText.semibold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (view.showToday) _TodayPill(onTap: () => onShow(view.today)),
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
                tooltip: '지난주 같은 요일 보기',
                onPressed: () => onShow(shifted(-7)),
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
                tooltip: '다음 주 같은 요일 보기',
                onPressed: () => onShow(shifted(7)),
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

/// '오늘' 알약. 다른 날을 보고 있을 때만 둔다.
class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      label: '오늘로 가기',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                height: 28,
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                // 알약은 글자 너비만큼이다(Container의 alignment는 가로를 다 차지하므로 쓰지 않음).
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '오늘',
                    style: AppText.caption.copyWith(
                      fontWeight: AppText.semibold,
                      color: colors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜 줄 7칸. 고른 날은 진한 바탕, 오늘은 테두리, 일요일은 붉은 날짜다.
class _Strip extends StatelessWidget {
  const _Strip({required this.days, required this.onPick});

  final List<DayStripDay> days;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: day.selected,
                label:
                    '${day.date.month}월 ${day.date.day}일 '
                    '(${weekdayText(day.date.weekday)})'
                    '${day.today ? ', 오늘' : ''}',
                excludeSemantics: true,
                onTap: () => onPick(day.date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 5,
                  ),
                  child: Press(
                    child: Material(
                      color: day.selected ? colors.strong : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.notice),
                        side: day.today && !day.selected
                            ? BorderSide(color: colors.stripe, width: 1.5)
                            : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onPick(day.date),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 60),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                day.label,
                                maxLines: 1,
                                style: AppText.caption.copyWith(
                                  fontWeight: day.today
                                      ? AppText.semibold
                                      : AppText.medium,
                                  color: day.selected
                                      ? colors.onStrong
                                      : day.today
                                      ? colors.accent
                                      : colors.muted,
                                ),
                              ),
                              Text(
                                '${day.date.day}',
                                maxLines: 1,
                                style: AppText.bodyLarge.copyWith(
                                  fontWeight: AppText.semibold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: day.selected
                                      ? colors.onStrong
                                      : day.sunday
                                      ? colors.alert
                                      : colors.ink,
                                ),
                              ),
                            ],
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
    );
  }
}

/// 종일 일정 카드('종일' 표시, 제목, 장소). 누르면 일정 정보 시트.
class _AllDayCard extends StatelessWidget {
  const _AllDayCard({required this.allDay, required this.onTap});

  final DayAllDay allDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      label: '${allDay.event.title}, 종일 일정, 정보 보기',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.personalTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.timetableBlock),
          side: BorderSide(color: colors.personalLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '종일',
                    style: AppText.caption.copyWith(
                      fontWeight: AppText.semibold,
                      color: colors.personalInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDay.event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          fontWeight: AppText.semibold,
                        ),
                      ),
                      Text(
                        allDay.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: colors.personalInk,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon(
                  AppIconName.person,
                  size: 16,
                  color: colors.personalInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// '모두 확정' 띠: 확정 전 제안 수와 [모두 확정].
class _ConfirmBand extends StatelessWidget {
  const _ConfirmBand({required this.title, required this.onConfirm});

  final String title;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.s16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        children: [
          DashedBorder(
            color: colors.taskInk,
            radius: 6,
            child: const SizedBox.square(dimension: 16),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
                Text(
                  '확정하면 02 홈에도 보여요',
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Press(
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size(AppSize.minTouch, AppSize.minTouch),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              ),
              child: const Text('모두 확정'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 빈 날 카드.
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.empty});

  final DayEmptyCard empty;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, AppSpace.s16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppIcon(
              AppIconName.freeTime,
              size: 20,
              color: colors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty.title,
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
                const SizedBox(height: 2),
                Text(
                  empty.body,
                  style: AppText.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 마감 줄 하나('23:59 ⚑ 마감 · 제목   상태 ›'). 누르면 작은 할 일 시트.
class _DueRow extends StatelessWidget {
  const _DueRow({required this.row, required this.onTap});

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
      label:
          '${row.time} 마감, ${row.title}'
          '${state == null ? '' : ', $state'}, 자세히 보기',
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
                    fontWeight: row.urgent ? AppText.semibold : AppText.medium,
                    color: ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              AppIcon(AppIconName.flag, size: 14, color: ink),
              const SizedBox(width: 6),
              Text(
                '마감',
                style: AppText.small.copyWith(
                  fontWeight: AppText.semibold,
                  color: ink,
                ),
              ),
              Text(' · ', style: AppText.small.copyWith(color: colors.icon)),
              Expanded(
                child: Text(
                  row.title,
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
              AppIcon(AppIconName.chevronRight, size: 16, color: colors.icon),
            ],
          ),
        ),
      ),
    );
  }
}
