// 캘린더 보기(년·주·일·일정) 하나의 틀. 상단바·드로어·하단 바와 선택한 날, 추가 시트, 중요 브리핑을
// 한곳에서 잇는다. 월간도 같은 것을 쓴다. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:cnu_ai_assistant/design/widgets/calendar_bars.dart';
import 'package:cnu_ai_assistant/features/add/add_sheet.dart';
import 'package:cnu_ai_assistant/features/briefing/briefing_controller.dart';
import 'package:cnu_ai_assistant/features/briefing/important_sheet.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 보기의 틀.
class CalendarFrame extends ConsumerWidget {
  const CalendarFrame({
    super.key,
    required this.view,
    required this.title,
    required this.body,
    this.onToday,
  });

  final CalendarView view;
  final String title;
  final Widget body;

  /// 오늘 버튼. 없으면 선택한 날을 오늘로 돌린다.
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    return CalendarScaffold(
      view: view,
      title: title,
      selected: selected,
      today: ref.watch(calendarTodayProvider),
      onToday: onToday ?? ref.read(selectedDateProvider.notifier).today,
      onAdd: (sentence) =>
          showAddSheet(context, day: selected, sentenceFirst: sentence),
      onBriefing: () => showImportantSheet(context),
      hasUnseenAlerts: ref.watch(hasUnseenAlertsProvider),
      body: body,
    );
  }
}
