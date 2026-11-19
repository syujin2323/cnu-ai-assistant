// 이번 학기 시간표 격자. docs/screens.md '13 시간표·고정 일정'의 시간표 탭, '14 온보딩'의 2단계가 함께 쓴다.
//
// 요일 열(월–금, 토·일에 수업이 있으면 월–일)마다 수업 칸을 시각 자리에 그린다. 시간대는 9–18시이고 더 이르거나
// 늦은 수업이 있으면 늘린다(`domain/class_groups.dart`의 [timetableGridLayout]). 한 시간 높이와 모양은 최종
// 프로토타입의 값이다(임시). 칸을 누르면 [TimetableGrid.onTap]이 그 칸을 받는다. 글자를 키워도 칸 높이는 시각을
// 따르고, 칸 안 글자는 넘치면 줄여 끊는다.

import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot_entry.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 시간표 격자.
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.entries,
    required this.today,
    this.onTap,
    this.showTime = false,
    this.empty,
  });

  /// 그릴 수업 칸(숨긴 수업은 넣지 않는다).
  final List<ClassSlotEntry> entries;

  /// 오늘 요일(1–7). 그 요일 이름을 강조한다(열은 칠하지 않는다).
  final int today;

  /// 칸을 누르면 받는다. null이면 누를 수 없다.
  final ValueChanged<ClassSlotEntry>? onTap;

  /// 칸에 시각도 적는지(14 온보딩 2단계).
  final bool showTime;

  /// 수업이 없을 때 격자 위 가운데에 둘 것.
  final Widget? empty;

  /// 한 시간 높이(임시, 최종 프로토타입).
  static const double hourHeight = 64;

  /// 열 사이 간격.
  static const double columnGap = 3;

  @override
  Widget build(BuildContext context) {
    final layout = timetableGridLayout(entries);
    final scaler = MediaQuery.textScalerOf(context);
    final labelWidth = scaler.scale(AppText.caption.fontSize!) * 1.5 + 6;
    final bodyHeight = layout.spanMin / 60 * hourHeight;
    final empty = this.empty;

    Widget column(int day) {
      return Expanded(
        child: SizedBox(
          height: bodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in layout.byDay[day] ?? const <ClassSlotEntry>[])
                _blockFor(entry, layout),
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: '이번 학기 시간표',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                SizedBox(width: labelWidth),
                for (var i = 0; i < layout.days.length; i++) ...[
                  if (i > 0) const SizedBox(width: columnGap),
                  Expanded(
                    child: _DayLabel(
                      text: weekdayText(layout.days[i]),
                      today: layout.days[i] == today,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: bodyHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (
                  var hour = layout.firstHour;
                  hour <= layout.lastHour;
                  hour++
                )
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (hour - layout.firstHour) * hourHeight,
                    child: ExcludeSemantics(
                      child: _HourLine(hour: hour, labelWidth: labelWidth),
                    ),
                  ),
                Positioned(
                  left: labelWidth,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < layout.days.length; i++) ...[
                        if (i > 0) const SizedBox(width: columnGap),
                        column(layout.days[i]),
                      ],
                    ],
                  ),
                ),
                if (layout.byDay.isEmpty && empty != null)
                  Positioned(
                    left: labelWidth + AppSpace.s12,
                    right: AppSpace.s8,
                    top: bodyHeight * .2,
                    child: empty,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockFor(ClassSlotEntry entry, TimetableGridLayout layout) {
    final slot = entry.slot;
    final end = slot.endMin < 1440 ? slot.endMin : 1440;
    final top = (slot.startMin - layout.firstHour * 60) / 60 * hourHeight + 1;
    final height = (end - slot.startMin) / 60 * hourHeight - 2;
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      height: height < 20 ? 20 : height,
      child: _ClassBlock(entry: entry, showTime: showTime, onTap: onTap),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.text, required this.today});

  final String text;

  final bool today;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      decoration: BoxDecoration(
        color: today ? colors.strong : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppText.small.copyWith(
          fontWeight: AppText.semibold,
          color: today ? colors.onStrong : colors.muted,
        ),
      ),
    );
  }
}

class _HourLine extends StatelessWidget {
  const _HourLine({required this.hour, required this.labelWidth});

  final int hour;

  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: labelWidth,
            right: 0,
            top: 0,
            height: 1,
            child: ColoredBox(color: colors.edge),
          ),
          Positioned(
            left: 0,
            width: labelWidth - 4,
            top:
                -AppText.caption.fontSize! *
                MediaQuery.textScalerOf(context).scale(1) *
                .75,
            child: Text(
              '$hour',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppText.caption.copyWith(
                fontWeight: AppText.medium,
                color: colors.icon,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  const _ClassBlock({
    required this.entry,
    required this.showTime,
    required this.onTap,
  });

  final ClassSlotEntry entry;

  final bool showTime;

  final ValueChanged<ClassSlotEntry>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final slot = entry.slot;
    final look = CourseColors.of(context, slot.courseId);
    final place = slot.online ? '온라인' : slot.place;
    final time = timeRangeText(slot.startMin, slot.endMin);
    final where = slot.online ? '실시간 온라인' : slot.place;
    final onTap = this.onTap;
    final tap = onTap == null ? null : () => onTap(entry);
    return Semantics(
      button: tap != null,
      label: [
        '${weekdayText(slot.weekday)}요일 ${entry.course.name}',
        time,
        ?where,
      ].join(', '),
      onTapHint: tap == null ? null : '고치기',
      excludeSemantics: true,
      onTap: tap,
      child: Press(
        enabled: tap != null,
        child: Material(
          color: slot.online ? colors.surface : look.tint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.timetableBlock),
            side: BorderSide(color: look.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 칸에 온전히 들어가는 줄만 쓴다(반쯤 잘린 줄을 두지 않음). 넘치는 글은 '…'로 줄인다.
                  final lineHeight =
                      MediaQuery.textScalerOf(context)
                          .scale(AppText.caption.fontSize!) *
                      AppText.caption.height!;
                  final lines = (constraints.maxHeight / lineHeight).floor();
                  return Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: entry.course.name,
                          style: AppText.caption.copyWith(
                            fontWeight: AppText.semibold,
                            color: colors.ink,
                          ),
                        ),
                        if (showTime)
                          TextSpan(
                            text: '\n$time',
                            style: AppText.caption.copyWith(
                              color: colors.ink2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        if (place != null && place.isNotEmpty)
                          TextSpan(
                            text: '\n$place',
                            style: AppText.caption.copyWith(color: look.ink),
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: lines < 1 ? 1 : lines,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
