// 0~24시 시간표. 실시간 하루 시간표(한 날)와 주간·일간 보기(여러 날)가 함께 쓴다.
// docs/architecture.md '화면 이동'.
//
// 날짜마다 한 열이고, 같은 열에서 겹치는 일정은 나란히 놓는다. [TimeGrid.now]가 그 열들 안의 날이면
// 지금 선을 긋고 지난 일정을 흐리게 한다. 종일 일정과 마감은 여기 그리지 않는다(위의 띠가 맡는다).

import 'dart:math' show max;

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/widgets/item_colors.dart';
import 'package:material_ui/material_ui.dart';

/// 0~24시 시간표.
class TimeGrid extends StatelessWidget {
  const TimeGrid({
    super.key,
    required this.days,
    required this.data,
    this.now,
    this.showTimes = true,
  });

  /// 열마다의 날(시각 없음).
  final List<DateTime> days;
  final CalendarData data;

  /// 지금 시각. 어느 열의 날이 아니면 지금 선을 긋지 않는다.
  final DateTime? now;

  /// 블록 안에 시각 줄도 적는지(열이 좁은 주간은 false).
  final bool showTimes;

  /// 시각 글자 칸의 너비.
  static const double labelWidth = 44;

  /// 시간표의 전체 높이.
  static const double height = 24 * AppSize.timelineHour + AppSpace.s8;

  @override
  Widget build(BuildContext context) {
    final now = this.now;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - labelWidth) / days.length;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var h = 0; h < 24; h++) ...[
                Positioned(
                  top: h * AppSize.timelineHour,
                  left: labelWidth,
                  right: 0,
                  child: const Divider(height: 1, color: AppColors.edge),
                ),
                Positioned(
                  top: h * AppSize.timelineHour - AppSpace.s8,
                  left: 0,
                  width: labelWidth - AppSpace.s4,
                  child: ExcludeSemantics(
                    child: Text(
                      h == 0 ? '' : clockText(h * 60).replaceAll('시', ''),
                      textAlign: TextAlign.right,
                      style: AppText.tiny.copyWith(color: AppColors.muted),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ],
              for (var c = 1; c < days.length; c++)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: labelWidth + columnWidth * c,
                  child: const VerticalDivider(width: 1, color: AppColors.edge),
                ),
              for (var c = 0; c < days.length; c++)
                for (final (item, lane, laneCount) in _lanes(_timed(days[c])))
                  Positioned(
                    top: _y(days[c], item.start!),
                    height: max(
                      AppSpace.s20,
                      _y(days[c], item.end!) - _y(days[c], item.start!) - 2,
                    ),
                    left:
                        labelWidth +
                        columnWidth * c +
                        columnWidth * lane / laneCount +
                        1,
                    width: columnWidth / laneCount - 2,
                    child: Opacity(
                      opacity: now != null && !item.end!.isAfter(now)
                          ? 0.45
                          : 1,
                      child: _Block(item: item, showTime: showTimes),
                    ),
                  ),
              if (now != null)
                for (var c = 0; c < days.length; c++)
                  if (_sameDay(days[c], now))
                    Positioned(
                      top: _y(days[c], now) - 1,
                      left: labelWidth + columnWidth * c - AppSpace.s4,
                      width: columnWidth + AppSpace.s4,
                      child: Semantics(
                        label: '지금 ${hm(now)}',
                        child: Row(
                          children: [
                            Container(
                              width: AppSpace.s8,
                              height: AppSpace.s8,
                              decoration: const BoxDecoration(
                                color: AppColors.alert,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: AppColors.alert,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  /// [day] 열의 맨 위에서 지금 1시간 전(없으면 8시)까지의 높이. 처음 스크롤 위치에 쓴다.
  static double initialOffset(DateTime? now) {
    final hour = now == null
        ? 8.0
        : max(0, (now.hour * 60 + now.minute) / 60 - 1).toDouble();
    return hour * AppSize.timelineHour;
  }

  List<CalendarItem> _timed(DateTime day) => [
    for (final i in itemsOn(day, data))
      if (i.start != null && i.end != null) i,
  ];

  static bool _sameDay(DateTime day, DateTime at) =>
      day.year == at.year && day.month == at.month && day.day == at.day;

  static double _y(DateTime day, DateTime at) {
    final minutes = at.difference(day).inMinutes.clamp(0, 24 * 60);
    return minutes / 60 * AppSize.timelineHour;
  }

  /// 겹치는 묶음마다 열 번호와 열 수를 매긴다.
  static List<(CalendarItem, int, int)> _lanes(List<CalendarItem> timed) {
    final sorted = [...timed]..sort((a, b) => a.start!.compareTo(b.start!));
    final out = <(CalendarItem, int, int)>[];
    var group = <(CalendarItem, int)>[];
    var columnsEnd = <DateTime>[];
    DateTime? groupEnd;
    void flush() {
      for (final (item, lane) in group) {
        out.add((item, lane, columnsEnd.length));
      }
      group = [];
      columnsEnd = [];
      groupEnd = null;
    }

    for (final item in sorted) {
      final end = groupEnd;
      if (end != null && !item.start!.isBefore(end)) flush();
      var lane = columnsEnd.indexWhere((e) => !e.isAfter(item.start!));
      if (lane < 0) {
        lane = columnsEnd.length;
        columnsEnd.add(item.end!);
      } else {
        columnsEnd[lane] = item.end!;
      }
      group.add((item, lane));
      final current = groupEnd;
      groupEnd = current == null || item.end!.isAfter(current)
          ? item.end
          : current;
    }
    flush();
    return out;
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.item, required this.showTime});

  final CalendarItem item;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.title}, ${hm(item.start!)}부터 ${hm(item.end!)}까지',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: itemTint(item.kind),
          borderRadius: BorderRadius.circular(AppRadius.tag),
          border: Border(left: BorderSide(color: itemBar(item.kind), width: 3)),
        ),
        clipBehavior: Clip.hardEdge,
        // 짧은 일정에서도 넘침 예외 없이 잘라 낸다.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: showTime ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                style: (showTime ? AppText.caption : AppText.tiny).copyWith(
                  fontWeight: AppText.medium,
                ),
              ),
              if (showTime)
                Text(
                  '${hm(item.start!)} - ${hm(item.end!)}',
                  maxLines: 1,
                  style: AppText.tiny.copyWith(color: AppColors.ink2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
