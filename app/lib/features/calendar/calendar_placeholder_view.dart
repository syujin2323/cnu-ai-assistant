// 아직 내용이 없는 캘린더 보기(년·주·일·일정)의 자리. 상단바·드로어·하단 바는 월간과 같다.
// 각 보기를 만드는 PR에서 본문을 실제 내용으로 바꾼다.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/design/widgets/screen_placeholder.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/important_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 틀 안의 '만들고 있어요' 본문.
class CalendarPlaceholderView extends ConsumerWidget {
  const CalendarPlaceholderView({
    super.key,
    required this.view,
    required this.title,
  });

  final CalendarView view;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    return CalendarScaffold(
      view: view,
      title: title,
      selected: selected,
      today: ref.watch(calendarTodayProvider),
      onToday: ref.read(selectedDateProvider.notifier).today,
      onAdd: (sentence) =>
          showAddSheet(context, day: selected, sentenceFirst: sentence),
      onBriefing: () => showImportantSheet(context),
      hasUnseenAlerts: ref.watch(hasUnseenAlertsProvider),
      body: const ScreenPlaceholder(),
    );
  }
}
