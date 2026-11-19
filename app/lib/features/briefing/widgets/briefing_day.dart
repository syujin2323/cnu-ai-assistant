// 01 계획의 '오늘 일정'. docs/screens.md '01 계획'.
//
// 최종 프로토타입의 작은 세로 시간표(한 시간 40pt, 임시)다. 왼쪽에 시 글자와 줄을 두고, 수업·일정·고정 일정·
// 이동·점심 카드와 할 일 블록(체크한 할 일과, 확정해도 남는 오늘 블록)을 그린다. 휴강 수업과 종일 일정은 그리지
// 않는다. 지난 카드는 흐리게 그리고, 지금 선은 시각 알약과 점선이다. 누를 곳이 없으므로 읽기 도구에는 요약 한
// 줄만 준다.

import 'dart:math' as math;

import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 시간표에 그릴 할 일 블록 하나.
final class BriefingDayTask {
  const BriefingDayTask({
    required this.title,
    required this.span,
    this.dim = false,
  });

  final String title;
  final TimeSpan span;

  /// 끝냈거나 지난 블록(흐리게 그림).
  final bool dim;
}

/// 01 계획의 '오늘 일정'.
class BriefingDay extends StatelessWidget {
  const BriefingDay({
    super.key,
    required this.day,
    required this.now,
    required this.items,
    required this.tasks,
    required this.windowEndMin,
    required this.courseNames,
    required this.semanticsLabel,
  });

  /// 논리적 하루(그날 0시).
  final DateTime day;

  final DateTime now;

  /// 그날의 시간표 항목. 할 일 블록과 휴강 수업은 그리지 않는다([tasks]로 따로 받음).
  final List<DayItem> items;

  final List<BriefingDayTask> tasks;

  /// 하루 창 끝(그날 0시부터 분). 23:00보다 이르면 23:00까지 그린다.
  final int windowEndMin;

  /// 수업 칸의 과목 id에서 과목 이름으로.
  final Map<int, String> courseNames;

  /// 읽기 도구가 읽을 요약.
  final String semanticsLabel;

  /// 한 시간의 높이(임시, 최종 프로토타입).
  static const double hourHeight = 40;

  /// 시 글자 칸의 너비와 카드가 시작하는 자리.
  static const double _labelWidth = 34;
  static const double _lineLeft = 38;
  static const double _cardLeft = 44;

  /// 카드가 두 줄(제목·시각)이 되는 높이.
  static const double _twoLines = 40;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final item in items)
        if (item is! BlockItem && !(item is ClassItem && item.cancelled)) item,
    ];
    final nowMin = _minuteOf(now);
    final live = [
      for (final item in cards)
        if (item.span.end.isAfter(now)) _minuteOf(item.span.start),
      for (final task in tasks)
        if (task.span.end.isAfter(now)) _minuteOf(task.span.start),
    ];
    final startHour = nowMin < 600
        ? 8
        : math.max(8, ([...live, nowMin].reduce(math.min)) ~/ 60);
    final top = startHour * 60;
    // 자정이 지나 하루 경계 전(논리적 하루의 끝, 그날 0시부터 1440분 넘음)에는 남은 일정이 없으면 위가 지금
    // 시각까지 내려오므로, 아래 끝을 늘 위보다 한 시간 뒤로 둔다(그러지 않으면 높이가 음수).
    final end = math.max(math.max(1380, windowEndMin), top + 60);
    double toY(int minute) => (minute - top) / 60 * hourHeight;
    final showNow = nowMin >= top && nowMin <= end;

    Widget place(TimeSpan span, Widget child) {
      final from = math.max(_minuteOf(span.start), top);
      final y = toY(from) + 1;
      final height = math.max(toY(_minuteOf(span.end)) - toY(from) - 2, 20.0);
      return Positioned(
        left: _cardLeft,
        right: 0,
        top: y,
        height: height,
        child: Opacity(
          opacity: span.end.isAfter(now) ? 1 : 0.45,
          child: LayoutBuilder(
            builder: (context, constraints) => _card(
              context,
              child,
              twoLines: constraints.maxHeight >= _twoLines,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: (end - top) / 60 * hourHeight + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var hour = startHour; hour <= end ~/ 60; hour++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: toY(hour * 60),
                  height: 0,
                  child: _HourLine(
                    hour: hour > 24 ? hour - 24 : hour,
                    hidden:
                        showNow &&
                        (hour * 60 - nowMin).abs() / 60 * hourHeight < 17,
                  ),
                ),
              for (final item in cards)
                if (_minuteOf(item.span.end) > top)
                  place(item.span, _ItemContent(item, courseNames)),
              for (final task in tasks)
                if (_minuteOf(task.span.end) > top)
                  place(task.span, _TaskContent(task)),
              if (showNow)
                Positioned(
                  left: 0,
                  right: 0,
                  top: toY(nowMin),
                  height: 0,
                  child: _NowLine(label: _hhmm(now)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Widget child, {required bool twoLines}) =>
      _CardLines(twoLines: twoLines, child: child);

  /// 그날 0시부터 [at]까지의 분(자정을 넘으면 1440을 넘음).
  int _minuteOf(DateTime at) => at.difference(day).inMinutes;
}

/// 카드 안이 한 줄인지 두 줄인지 아래 위젯에 알린다.
class _CardLines extends InheritedWidget {
  const _CardLines({required this.twoLines, required super.child});

  final bool twoLines;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardLines>()?.twoLines ??
      false;

  @override
  bool updateShouldNotify(_CardLines oldWidget) =>
      twoLines != oldWidget.twoLines;
}

/// 시 글자와 가로줄.
class _HourLine extends StatelessWidget {
  const _HourLine({required this.hour, required this.hidden});

  final int hour;

  /// 지금 알약과 겹쳐 글자를 숨긴다.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: -9,
          width: BriefingDay._labelWidth,
          child: Opacity(
            opacity: hidden ? 0 : 1,
            child: Text.rich(
              TextSpan(
                text: '$hour',
                children: [
                  TextSpan(
                    text: '시',
                    style: AppText.caption.copyWith(
                      fontSize: 10,
                      color: colors.icon,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: AppText.caption.copyWith(
                fontWeight: AppText.medium,
                color: colors.icon,
                height: 1.5,
              ),
            ),
          ),
        ),
        Positioned(
          left: BriefingDay._lineLeft,
          right: 0,
          top: 0,
          height: 1,
          child: ColoredBox(color: colors.edge),
        ),
      ],
    );
  }
}

/// 수업·일정·고정 일정·이동·점심 카드.
class _ItemContent extends StatelessWidget {
  const _ItemContent(this.item, this.courseNames);

  final DayItem item;
  final Map<int, String> courseNames;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final range = '${_hhmm(item.span.start)}–${_hhmm(item.span.end)}';
    switch (item) {
      case TravelItem() || MealItem():
        final travel = item is TravelItem;
        final body = Row(
          children: [
            AppIcon(
              travel ? AppIconName.bus : AppIconName.meal,
              size: 13,
              color: colors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _Line(
                travel ? '이동 ${durationText(item.span.minutes)}' : '점심',
                style: AppText.caption.copyWith(
                  fontWeight: AppText.medium,
                  color: colors.muted,
                ),
              ),
            ),
            Flexible(
              child: _Line(
                range,
                style: AppText.caption.copyWith(color: colors.icon),
              ),
            ),
          ],
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: travel ? colors.surface : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: travel ? colors.edge : colors.edge2),
          ),
          child: body,
        );
      case ClassItem(:final slot, :final place):
        return _Colored(
          title: courseNames[slot.courseId] ?? '수업',
          time: range,
          sub: place == null ? range : '$range · $place',
          tint: CourseColors.of(context, slot.courseId).tint,
          line: CourseColors.of(context, slot.courseId).line,
          ink: CourseColors.of(context, slot.courseId).ink,
        );
      case EventItem(:final event):
        return _Colored(
          title: event.title,
          time: range,
          sub: range,
          tint: colors.personalTint,
          line: colors.personalLine,
          ink: colors.personalInk,
        );
      case FixedItem(:final block):
        return _Colored(
          title: block.name,
          time: range,
          sub: range,
          tint: colors.personalTint,
          line: colors.personalLine,
          ink: colors.personalInk,
        );
      case BlockItem():
        return const SizedBox.shrink();
    }
  }
}

/// 색이 있는 카드(수업·일정·고정 일정).
class _Colored extends StatelessWidget {
  const _Colored({
    required this.title,
    required this.time,
    required this.sub,
    required this.tint,
    required this.line,
    required this.ink,
  });

  final String title;
  final String time;

  /// 두 줄일 때 아래 줄.
  final String sub;
  final Color tint;
  final Color line;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _Box(
      background: tint,
      border: Border.all(color: line),
      title: title,
      titleColor: colors.ink,
      time: time,
      sub: sub,
      metaColor: ink,
    );
  }
}

/// 할 일 블록(흰 바탕에 할 일 색 테두리).
class _TaskContent extends StatelessWidget {
  const _TaskContent(this.task);

  final BriefingDayTask task;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final range = '${_hhmm(task.span.start)}–${_hhmm(task.span.end)}';
    return Opacity(
      opacity: task.dim ? 0.45 : 1,
      child: _Box(
        background: colors.bg,
        border: Border.all(color: colors.taskInk, width: 1.5),
        title: task.title,
        titleColor: colors.ink,
        time: range,
        sub: range,
        metaColor: colors.taskInk,
      ),
    );
  }
}

/// 카드 상자: 한 줄이면 제목과 오른쪽 시각, 두 줄이면 제목 아래 [sub].
class _Box extends StatelessWidget {
  const _Box({
    required this.background,
    required this.border,
    required this.title,
    required this.titleColor,
    required this.time,
    required this.sub,
    required this.metaColor,
  });

  final Color background;
  final BoxBorder border;
  final String title;
  final Color titleColor;
  final String time;
  final String sub;
  final Color metaColor;

  @override
  Widget build(BuildContext context) {
    final twoLines = _CardLines.of(context);
    final titleStyle = AppText.small.copyWith(
      fontSize: 13,
      fontWeight: AppText.semibold,
      height: 16 / 13,
      letterSpacing: -0.2,
      color: titleColor,
    );
    final metaStyle = AppText.caption.copyWith(
      height: 16 / 12,
      color: metaColor,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: twoLines
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Line(title, style: titleStyle),
                const SizedBox(height: 1),
                _Line(sub, style: metaStyle),
              ],
            )
          : Row(
              children: [
                Expanded(child: _Line(title, style: titleStyle)),
                const SizedBox(width: 8),
                Flexible(child: _Line(time, style: metaStyle)),
              ],
            ),
    );
  }
}

/// 한 줄 글자(넘치면 줄임표, 글자를 키워도 카드 높이는 그대로라 잘림).
class _Line extends StatelessWidget {
  const _Line(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

/// 지금 선: 시각 알약과 점선.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 42,
          right: 0,
          top: -1,
          height: 1.5,
          child: CustomPaint(painter: _DashPainter(colors.strong)),
        ),
        Positioned(
          left: 0,
          top: -9,
          height: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.strong,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppText.caption.copyWith(
                fontSize: 11,
                fontWeight: AppText.semibold,
                height: 18 / 11,
                color: colors.onStrong,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 가로 점선.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    const dash = 4.0;
    const gap = 3.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => color != oldDelegate.color;
}

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);
