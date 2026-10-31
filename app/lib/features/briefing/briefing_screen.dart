// 데일리 브리핑(전체 화면 `/briefing`). docs/architecture.md '데일리 브리핑과 중요 브리핑'.
//
// 논리적 하루에 앱을 처음 열 때 먼저 보여 주고, 드로어·중요 브리핑 시트에서 다시 연다. 범위는 직전
// 마지막 접속(`settings`의 `lastVisitAt`)부터 지금까지다. 위에서부터 글 브리핑(서버를 붙이기 전이라
// 템플릿 문장), 오늘 일정, 미배정 할 일, 마지막 접속 이후 생긴 일이다. 제목·닫기가 있는 위쪽 바는
// 스크롤해도 고정이다. 처음 열 때 `briefings`에 연 시각과 범위를 적고, 닫으면 그때까지의 중요
// 알림을 본 것으로 둔다. 날씨 한 줄은 서버를 붙인 뒤에 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/unassigned_task_row.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_template.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 데일리 브리핑.
class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  /// 이 브리핑의 범위 시작(직전 마지막 접속). 처음 연 날의 값을 쓴다.
  DateTime? _fromAt;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// 오늘 브리핑을 연 것으로 적는다. 이미 연 날이면 그때의 범위를 그대로 쓴다.
  Future<void> _open() async {
    final settings = await ref.read(settingsRepositoryProvider).read();
    final lastVisit = switch (settings) {
      Ok(:final value) => value.lastVisitAt,
      Err() => null,
    };
    final now = ref.read(clockProvider).now();
    final result = await ref
        .read(briefingRepositoryProvider)
        .openToday(
          date: isoDate(ref.read(calendarTodayProvider)),
          now: now,
          body: '',
          fromAt: lastVisit != null && lastVisit.isBefore(now)
              ? lastVisit
              : null,
        );
    if (!mounted) return;
    setState(() {
      _opened = true;
      if (result case Ok(:final value)) _fromAt = value.fromAt;
    });
  }

  Future<void> _close() async {
    await ref
        .read(briefingRepositoryProvider)
        .markSeen(until: ref.read(clockProvider).now());
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.calendar);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider).now();
    final boundary = ref.watch(dayBoundaryProvider);
    final unassigned = ref.watch(unassignedTasksProvider);
    final todayItems = itemsOn(today, data);
    final fromAt = _fromAt;
    final changes = [
      for (final alert in ref.watch(alertsProvider).value ?? const <Alert>[])
        if (fromAt == null || alert.createdAt.isAfter(fromAt)) alert,
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      // 위쪽 바(제목·닫기)는 스크롤해도 그대로 있다.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppStrings.dailyBriefing),
        actions: [
          IconButton(
            tooltip: '닫기',
            onPressed: _close,
            icon: const AppIcon(AppIconName.close, color: AppColors.ink),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s8,
            AppSpace.screen,
            AppSpace.s32,
          ),
          children: [
            Text('좋은 아침이에요', style: AppText.heading),
            Text(
              '${today.month}월 ${today.day}일 ${weekdayText(today.weekday)}요일'
              '${fromAt == null ? '' : ' · ${_visitText(fromAt, today)} 마지막 접속 이후'}',
              style: AppText.small.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.s16),
            _Card(
              title: '오늘의 브리핑',
              lead: true,
              children: [
                Text(
                  dailyBriefingText(
                    today: today,
                    todayItems: todayItems,
                    unassigned: unassigned,
                    now: now,
                    dayBoundaryMin: boundary,
                  ),
                  style: AppText.bodyLarge.copyWith(height: 1.6),
                ),
              ],
            ),
            _Card(
              title: '오늘 일정',
              children: [
                if (todayItems.isEmpty) const _Empty('오늘 일정이 없어요.'),
                for (final item in todayItems)
                  if (item.kind != CalendarItemKind.deadline)
                    _ScheduleLine(item: item),
              ],
            ),
            _Card(
              title: '${AppStrings.unassignedTasks} · 급한 순서',
              children: [
                if (unassigned.isEmpty) const _Empty('시간을 정할 할 일이 없어요.'),
                for (final item in unassigned)
                  UnassignedTaskRow(
                    item: item,
                    now: now,
                    dayBoundaryMin: boundary,
                    onPlace: () =>
                        showAddSheet(context, day: today, taskId: item.task.id),
                  ),
              ],
            ),
            _Card(
              title: fromAt == null ? '새로 생긴 일' : '마지막 접속 이후 생긴 일',
              children: [
                if (changes.isEmpty) const _Empty('새로 생긴 일이 없어요.'),
                for (final alert in changes) _AlertLine(alert: alert),
              ],
            ),
            const SizedBox(height: AppSpace.s8),
            FilledButton(
              onPressed: _opened ? _close : null,
              child: const Text('캘린더로 가기'),
            ),
          ],
        ),
      ),
    );
  }

  static String _visitText(DateTime at, DateTime today) {
    final day = DateTime(at.year, at.month, at.day);
    final label = day == today
        ? '오늘'
        : day == today.subtract(const Duration(days: 1))
        ? '어제'
        : '${at.month}월 ${at.day}일';
    return '$label ${clockText(at.hour * 60 + at.minute)}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children, this.lead = false});

  final String title;
  final List<Widget> children;

  /// 글 브리핑처럼 강조하는 카드.
  final bool lead;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.card),
      decoration: BoxDecoration(
        color: lead ? AppColors.classTint : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.small.copyWith(
                color: lead ? AppColors.accent : AppColors.muted,
                fontWeight: lead ? AppText.semibold : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          ...children,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.body.copyWith(color: AppColors.muted));
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.item});

  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final start = item.start, end = item.end;
    final time = start == null
        ? '종일'
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

/// 중요 알림 한 줄. 긴급은 빨간 글자로 '긴급'을 붙인다(색만으로 나누지 않음).
class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final urgent = alert.level == AlertLevel.urgent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: urgent ? '긴급  ' : '새 일정  ',
              style: TextStyle(
                color: urgent ? AppColors.alert : AppColors.accent,
                fontWeight: AppText.semibold,
              ),
            ),
            TextSpan(text: alert.body),
          ],
        ),
        style: AppText.body,
      ),
    );
  }
}
