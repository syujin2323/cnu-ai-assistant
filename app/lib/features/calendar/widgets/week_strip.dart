// 주간·일간 보기 위쪽의 요일 줄과 종일·마감 띠. docs/architecture.md '화면 이동'.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/time_grid.dart';
import 'package:material_ui/material_ui.dart';

/// [day]가 든 주(일요일 시작)의 7일.
List<DateTime> weekOf(DateTime day) {
  final sunday = DateTime(day.year, day.month, day.day - day.weekday % 7);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(sunday.year, sunday.month, sunday.day + i),
  ];
}

/// 일요일 빨강, 토요일 파랑, 나머지 [other].
Color weekdayColor(int weekday, {Color other = AppColors.muted}) =>
    switch (weekday) {
      DateTime.sunday => AppColors.sunday,
      DateTime.saturday => AppColors.saturday,
      _ => other,
    };

/// 요일·날짜 줄. 날짜를 누르면 [onTap]이다.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.today,
    required this.onTap,
    this.selected,
  });

  final List<DateTime> days;
  final DateTime today;

  /// 강조할 날(일간). 없으면 오늘만 강조한다.
  final DateTime? selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: TimeGrid.labelWidth),
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                button: true,
                selected: day == selected,
                label:
                    '${day.month}월 ${day.day}일 ${weekdayText(day.weekday)}요일'
                    '${day == today ? ', 오늘' : ''}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onTap(day),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                    child: Column(
                      children: [
                        Text(
                          weekdayText(day.weekday),
                          style: AppText.caption.copyWith(
                            color: weekdayColor(day.weekday),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: day == today ? AppColors.accent : null,
                            border: day == selected && day != today
                                ? Border.all(color: AppColors.icon)
                                : null,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${day.day}',
                            style: AppText.body.copyWith(
                              fontWeight: AppText.semibold,
                              color: day == today
                                  ? AppColors.bg
                                  : weekdayColor(
                                      day.weekday,
                                      other: AppColors.ink,
                                    ),
                            ),
                          ),
                        ),
                      ],
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

/// 날짜 열마다의 종일 일정·마감 칩.
class AllDayRow extends StatelessWidget {
  const AllDayRow({super.key, required this.days, required this.data});

  final List<DateTime> days;
  final CalendarData data;

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final day in days)
        [
          for (final i in itemsOn(day, data))
            if (i.allDay || i.kind == CalendarItemKind.deadline) i,
        ],
    ];
    if (columns.every((c) => c.isEmpty)) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.edge)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: TimeGrid.labelWidth,
            child: Text(
              '종일',
              textAlign: TextAlign.center,
              style: AppText.tiny.copyWith(color: AppColors.muted),
            ),
          ),
          for (final column in columns)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in column)
                    Container(
                      margin: const EdgeInsets.all(1),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: itemTint(item.kind),
                        borderRadius: BorderRadius.circular(AppRadius.tag),
                      ),
                      child: Text(
                        item.kind == CalendarItemKind.deadline
                            ? '마감 ${item.title}'
                            : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tiny,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
