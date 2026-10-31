// 중요 브리핑 시트. docs/architecture.md '데일리 브리핑과 중요 브리핑'.
//
// 캘린더 하단 원형 버튼으로 연다. 일정 배치가 아니라 '브리핑 이후 지금까지 무슨 일이 있었나'를 글로
// 알려 준다. 위에서부터 제목과 '데일리 브리핑 보기', 중요 알림 카드(긴급은 빨강, 안 본 것은 NEW),
// '지금까지 요약'(서버를 붙이기 전이라 템플릿 문장)이다. 열면 지금까지의 알림을 본 것으로 둔다.
// 알림함 버튼은 알림 감지(R1)와 함께 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/unassigned_tasks.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_template.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 중요 브리핑 시트를 띄운다.
Future<void> showImportantSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => const ImportantSheet(),
  );
}

/// 중요 브리핑 시트 본문.
class ImportantSheet extends ConsumerStatefulWidget {
  const ImportantSheet({super.key});

  @override
  ConsumerState<ImportantSheet> createState() => _ImportantSheetState();
}

class _ImportantSheetState extends ConsumerState<ImportantSheet> {
  /// 시트를 열 때 안 봤던 알림. 열자마자 본 것으로 적어도 이번에는 NEW로 보여 준다.
  late final Set<int> _unseenAtOpen;

  @override
  void initState() {
    super.initState();
    final alerts = ref.read(alertsProvider).value ?? const <Alert>[];
    _unseenAtOpen = {
      for (final a in alerts)
        if (a.seenAt == null) a.id,
    };
    ref
        .read(briefingRepositoryProvider)
        .markSeen(until: ref.read(clockProvider).now());
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider).value ?? const <Alert>[];
    final ordered = [...alerts]
      ..sort((a, b) {
        if (a.level != b.level) return a.level == AlertLevel.urgent ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider).now();
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final todo = todayUnassigned(
      ref.watch(unassignedTasksProvider),
      now: now,
      dayBoundaryMin: ref.watch(dayBoundaryProvider),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        0,
        AppSpace.screen,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: const Text('중요 브리핑', style: AppText.title),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.briefing);
                },
                child: const Text('${AppStrings.dailyBriefing} 보기'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          if (ordered.isEmpty)
            Text(
              '새로 생긴 중요한 일이 없어요.',
              style: AppText.body.copyWith(color: AppColors.muted),
            ),
          for (final alert in ordered)
            _AlertCard(alert: alert, isNew: _unseenAtOpen.contains(alert.id)),
          const SizedBox(height: AppSpace.s8),
          Container(
            padding: const EdgeInsets.all(AppSpace.card),
            decoration: BoxDecoration(
              color: AppColors.classTint,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금까지 요약',
                  style: AppText.small.copyWith(
                    color: AppColors.accent,
                    fontWeight: AppText.semibold,
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                Text(
                  nowSummaryText(
                    now: now,
                    todayItems: itemsOn(today, data),
                    newAlertCount: _unseenAtOpen.length,
                    todayTodo: todo,
                  ),
                  style: AppText.body.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.isNew});

  final Alert alert;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final urgent = alert.level == AlertLevel.urgent;
    final at = alert.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s8),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: urgent ? AppColors.alertSoft : AppColors.tint,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                urgent ? '긴급' : '새 일정',
                style: AppText.small.copyWith(
                  color: urgent ? AppColors.alert : AppColors.accent,
                  fontWeight: AppText.semibold,
                ),
              ),
              Text(
                '${_sourceText(alert.source)} · ${clockText(at.hour * 60 + at.minute)}',
                style: AppText.caption.copyWith(color: AppColors.muted),
              ),
              if (isNew)
                Text(
                  'NEW',
                  style: AppText.caption.copyWith(
                    color: AppColors.alert,
                    fontWeight: AppText.semibold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(alert.body, style: AppText.body),
        ],
      ),
    );
  }

  static String _sourceText(AlertSource source) => switch (source) {
    AlertSource.lms => '사이버캠퍼스',
    AlertSource.event => '일정',
    AlertSource.disaster => '재난문자',
    AlertSource.notif => '알림',
  };
}
