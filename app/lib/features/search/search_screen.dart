// 검색(`/search`). 삼성 캘린더 검색처럼 뒤로가기만 있는 전체 화면이다. 위에는 종류 필터, 아래에는
// 둥근 검색창이 있다. 제목·장소로 석 달 전부터 여섯 달 뒤까지의 일정·할 일 시간·마감을 찾아 날짜순으로
// 보여 주고, 결과를 누르면 월간에서 그날을 고른다. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 검색.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  final Set<CalendarItemKind> _kinds = {};

  static const int _daysBefore = 90;
  static const int _daysAfter = 180;

  static String kindText(CalendarItemKind kind) => switch (kind) {
    CalendarItemKind.classSession => '수업',
    CalendarItemKind.fixed => '고정 일정',
    CalendarItemKind.event => '일정',
    CalendarItemKind.block => '할 일 시간',
    CalendarItemKind.deadline => '마감',
  };

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<(DateTime, CalendarItem)> _results(CalendarData data, DateTime today) {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty && _kinds.isEmpty) return const [];
    return [
      for (var i = -_daysBefore; i <= _daysAfter; i++)
        if (DateTime(today.year, today.month, today.day + i) case final day)
          for (final item in itemsOn(day, data))
            if ((_kinds.isEmpty || _kinds.contains(item.kind)) &&
                (query.isEmpty ||
                    item.title.toLowerCase().contains(query) ||
                    (item.place?.toLowerCase().contains(query) ?? false)))
              (day, item),
    ];
  }

  void _open(DateTime day) {
    ref.read(selectedDateProvider.notifier).select(day);
    context.go(Routes.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(calendarDataProvider).value ?? const CalendarData();
    final today = ref.watch(calendarTodayProvider);
    final results = _results(data, today);
    final searching = _query.text.trim().isNotEmpty || _kinds.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: '캘린더로 가기',
                onPressed: () => context.go(Routes.calendar),
                icon: const AppIcon(AppIconName.back, color: AppColors.ink),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.screen,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.card),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppColors.edge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '종류',
                          style: AppText.small.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: AppSpace.s8),
                        Wrap(
                          spacing: AppSpace.s8,
                          runSpacing: AppSpace.s8,
                          children: [
                            for (final kind in CalendarItemKind.values)
                              FilterChip(
                                avatar: CircleAvatar(
                                  backgroundColor: itemBar(kind),
                                  radius: 5,
                                ),
                                label: Text(kindText(kind)),
                                selected: _kinds.contains(kind),
                                onSelected: (on) => setState(
                                  () => on
                                      ? _kinds.add(kind)
                                      : _kinds.remove(kind),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  if (searching)
                    Text(
                      results.isEmpty ? '찾은 일정이 없어요.' : '${results.length}건',
                      style: AppText.small.copyWith(color: AppColors.muted),
                    ),
                  for (final (day, item) in results)
                    _ResultRow(day: day, item: item, onTap: () => _open(day)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '검색',
                  filled: true,
                  fillColor: AppColors.tint,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(AppSpace.s12),
                    child: AppIcon(AppIconName.search, color: AppColors.muted),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.day,
    required this.item,
    required this.onTap,
  });

  final DateTime day;
  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = item.start, end = item.end;
    final time = start == null
        ? '종일'
        : item.kind == CalendarItemKind.deadline
        ? '${hm(start)} 마감'
        : end == null
        ? hm(start)
        : '${hm(start)} - ${hm(end)}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                '${day.month}/${day.day}',
                style: AppText.body.copyWith(fontWeight: AppText.medium),
              ),
            ),
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
                    '${weekdayText(day.weekday)}요일 · $time'
                    '${item.place == null ? '' : ' · ${item.place}'}',
                    style: AppText.small.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
