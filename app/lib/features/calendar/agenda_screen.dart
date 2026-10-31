// 일정 목록(`/calendar/agenda`). 일주일 전부터 두 달 뒤까지 일정이 있는 날만 날짜별로 모아 보여 주고,
// 처음에는 오늘(없으면 그다음 날)이 위에 오게 스크롤한다. 날짜를 누르면 그날 일간이다.
// docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_frame.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/week_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 일정 목록.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  final GlobalKey _anchor = GlobalKey();
  bool _scrolled = false;

  static const int _daysBefore = 7;
  static const int _daysAfter = 60;

  void _scrollToAnchor() {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _anchor.currentContext;
      if (target != null && mounted) Scrollable.ensureVisible(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    final days = [
      for (var i = -_daysBefore; i <= _daysAfter; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    final groups = [
      for (final day in days)
        if (itemsOn(day, data) case final items when items.isNotEmpty)
          (day, items),
    ];
    final anchorIndex = groups.indexWhere((g) => !g.$1.isBefore(today));
    _scrollToAnchor();
    return CalendarFrame(
      view: CalendarView.agenda,
      title: '일정',
      body: ListView(
        // 맨 위에서 ensureVisible로 오늘에 맞추므로 지난 날도 위에 둔다.
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          0,
          AppSpace.screen,
          CalendarBottomBar.height,
        ),
        children: [
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
              child: Text(
                '다가오는 일정이 없어요.',
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ),
          for (final (index, (day, items)) in groups.indexed)
            Column(
              key: index == anchorIndex ? _anchor : null,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).select(day);
                    context.go(Routes.calendarDay(isoDate(day)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpace.s16,
                      bottom: AppSpace.s4,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${day.month}월 ${day.day}일 ${weekdayText(day.weekday)}요일'
                        '${day == today ? ' · 오늘' : ''}',
                        style: AppText.body.copyWith(
                          fontWeight: AppText.semibold,
                          color: day == today
                              ? AppColors.accent
                              : weekdayColor(day.weekday, other: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final item in items) _AgendaRow(item: item),
              ],
            ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.item});

  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final start = item.start, end = item.end;
    final deadline = item.kind == CalendarItemKind.deadline;
    final time = start == null
        ? '종일'
        : deadline
        ? '${hm(start)} 마감'
        : end == null
        ? hm(start)
        : '${hm(start)} - ${hm(end)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: itemBar(item.kind),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.body),
                Text(
                  item.place == null ? time : '$time · ${item.place}',
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
