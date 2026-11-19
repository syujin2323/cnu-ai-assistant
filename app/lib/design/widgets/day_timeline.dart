// 세로 하루 시간표(02 홈·09 일간 공용). docs/screens.md '02 홈'의 오늘 시간표·'09 일간'·'할 일 블록'.
//
// 자리는 [layoutDayTimeline]이 계산하고(부르는 화면이 지난 일정 접기 상태와 함께 넘김) 여기서는 그린다. 모양은
// 최종 프로토타입을 따른다.
// - 수업은 수업 색, 일정·고정 일정은 개인 색의 실선 카드다. 휴강한 수업은 흐린 회색에 취소선이다.
// - 할 일 블록은 할 일 색 점선이다(확정해도). 제안은 배경 없이 '제안'을 붙이고, 완료는 흐리게 취소선과 체크,
//   놓침은 흐리게 '놓침'이다. LMS에서 사라진 할 일의 블록은 회색으로 흐리게 그린다.
// - 끝난 카드는 흐리게, 지금 하는 카드는 '진행 중 · N분 남음'과 아래 진행 막대를 그린다.
// - 이동·점심은 작은 흐린 카드, 빈 시간은 점선 카드다(누를 수 있으면 '놓기'를 붙임). 지금 선은 시 칸의 시각
//   알약과 점선이다.
// 카드 높이는 시간으로 정해지므로, 글자를 키우면 카드 안 글자는 잘린다(넘침 오류는 내지 않음). 읽기 도구에는
// 카드마다 제목·시각·종류와, 누를 수 있으면 할 수 있는 일을 한 번에 읽어 준다(눌러도 반응 없는 자리를 알리지
// 않게).
// 누르면: 할 일 블록 → [DayTimeline.onBlockTap](근거 시트), 블록의 체크 → [DayTimeline.onBlockCheck], 수업·일정 →
// [DayTimeline.onItemTap](일정 정보 시트), 빈 시간 → [DayTimeline.onFreeTap](빈 시간에 놓기 시트). 넘기지 않은 쪽은
// 누를 수 없다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/dashed_border.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline_layout.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/planner/time_span.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 세로 하루 시간표.
class DayTimeline extends StatelessWidget {
  const DayTimeline({
    super.key,
    required this.layout,
    required this.day,
    required this.now,
    required this.dayBoundaryMin,
    this.courseNames = const {},
    this.onItemTap,
    this.onBlockTap,
    this.onBlockCheck,
    this.onFreeTap,
  });

  /// 자리 계산 결과([layoutDayTimeline]).
  final TimelineLayout layout;

  /// 그리는 논리적 하루의 날짜.
  final DateTime day;
  final DateTime now;
  final int dayBoundaryMin;

  /// 과목 id → 과목 이름(수업 카드의 제목).
  final Map<int, String> courseNames;

  /// 할 일 블록이 아닌 카드(수업·일정·고정 일정)를 누를 때.
  final ValueChanged<DayItem>? onItemTap;

  /// 할 일 블록을 누를 때(근거 시트).
  final ValueChanged<BlockItem>? onBlockTap;

  final ValueChanged<BlockItem>? onBlockCheck;
  final ValueChanged<TimeSpan>? onFreeTap;

  /// 왼쪽 시 칸의 너비(카드는 그 오른쪽부터).
  static const double hourColumn = 48;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final hour in layout.hours)
            if (hour.visible)
              Positioned(
                left: 0,
                top: hour.top - 10,
                width: 38,
                child: ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      text: '${hour.hour}',
                      children: const [
                        TextSpan(text: '시', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    maxLines: 1,
                    style: AppText.small.copyWith(
                      fontWeight: AppText.medium,
                      height: 20 / 13,
                      color: colors.icon,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          for (var i = 0; i < layout.entries.length; i++)
            Positioned(
              left: hourColumn,
              right: 0,
              top: layout.entries[i].top,
              height: layout.entries[i].height,
              child: Rise(
                style: RiseStyle.homeCard,
                delay:
                    Duration(milliseconds: 140) +
                    AppMotion.staggerListHomeCard * i,
                child: _entry(layout.entries[i]),
              ),
            ),
          if (layout.nowTop case final top?)
            Positioned(
              left: 0,
              right: 0,
              top: top - 10,
              height: 20,
              child: _NowLine(now: now),
            ),
        ],
      ),
    );
  }

  Widget _entry(TimelineEntry entry) => switch (entry) {
    TimelineCard() => _ItemCard(
      card: entry,
      title: _title(entry.item),
      now: now,
      dayBoundaryMin: dayBoundaryMin,
      onTap: switch (entry.item) {
        final BlockItem item when onBlockTap != null => () => onBlockTap!(item),
        BlockItem() => null,
        final item when onItemTap != null => () => onItemTap!(item),
        _ => null,
      },
      onCheck: entry.item is BlockItem && onBlockCheck != null
          ? () => onBlockCheck!(entry.item as BlockItem)
          : null,
    ),
    TimelineSoft(:final item) => _SoftCard(item: item),
    TimelineFree(:final span) => _FreeCard(
      span: span,
      onTap: onFreeTap == null ? null : () => onFreeTap!(span),
    ),
    TimelineSlot(:final span) =>
      onFreeTap == null
          ? const SizedBox.shrink()
          : _SlotButton(span: span, onTap: () => onFreeTap!(span)),
  };

  String _title(DayItem item) => switch (item) {
    ClassItem(:final slot) => courseNames[slot.courseId] ?? '수업',
    EventItem(:final event) => event.title,
    FixedItem(:final block) => block.name,
    BlockItem(:final entry) => entry?.task.title ?? '할 일',
    TravelItem() || MealItem() => '',
  };
}

/// 시각 범위 'HH:MM–HH:MM'.
String _range(TimeSpan span) {
  final start = span.start.hour * 60 + span.start.minute;
  return timeRangeText(start, start + span.minutes);
}

/// 카드의 색과 아이콘.
typedef _Look = ({
  Color? background,
  Color border,
  bool dashed,
  double width,
  Color ink,
  AppIconName? icon,
});

_Look _lookOf(DayItem item, AppColors colors) => switch (item) {
  ClassItem(cancelled: true) => (
    background: colors.surface,
    border: colors.edge,
    dashed: false,
    width: 1,
    ink: colors.muted,
    icon: AppIconName.calendar,
  ),
  ClassItem() => (
    background: colors.classTint,
    border: colors.classLine,
    dashed: false,
    width: 1,
    ink: colors.classInk,
    icon: AppIconName.calendar,
  ),
  EventItem() || FixedItem() => (
    background: colors.personalTint,
    border: colors.personalLine,
    dashed: false,
    width: 1,
    ink: colors.personalInk,
    icon: item is FixedItem && item.block.kind == FixedBlockKind.exercise
        ? AppIconName.exercise
        : AppIconName.person,
  ),
  BlockItem(:final block) => (
    background: block.status == PlanBlockStatus.suggested ? null : colors.bg,
    border: colors.taskInk,
    dashed: true,
    width: 1.5,
    ink: colors.taskInk,
    icon: null,
  ),
  TravelItem() || MealItem() => (
    background: colors.surface,
    border: colors.edge2,
    dashed: false,
    width: 1,
    ink: colors.muted,
    icon: null,
  ),
};

/// 카드의 종류 글자(덧붙임 앞).
String _label(DayItem item) => switch (item) {
  ClassItem(:final cancelled, :final exam, :final makeup) =>
    cancelled
        ? '휴강'
        : exam
        ? '시험'
        : makeup
        ? '보강'
        : '수업',
  EventItem() || FixedItem() => '개인',
  BlockItem(:final block, :final partial) =>
    '${switch (block.status) {
      PlanBlockStatus.suggested => '제안',
      PlanBlockStatus.done => '완료',
      PlanBlockStatus.missed => '놓침',
      _ => '할 일',
    }}${partial ? ' · 부분' : ''}',
  TravelItem() || MealItem() => '',
};

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.card,
    required this.title,
    required this.now,
    required this.dayBoundaryMin,
    required this.onTap,
    required this.onCheck,
  });

  final TimelineCard card;
  final String title;
  final DateTime now;
  final int dayBoundaryMin;
  final VoidCallback? onTap;
  final VoidCallback? onCheck;

  String? _sub(DayItem item) => switch (item) {
    ClassItem(:final slot, :final place) => slot.online ? '실시간 온라인' : place,
    EventItem(:final event) => event.place,
    FixedItem(:final block) => block.place,
    BlockItem(:final entry) when entry != null =>
      '${taskKindText(entry.task.kind)} · ${dueText(entry.task.dueAt, dueTimeUnknown: entry.task.dueTimeUnknown, now: now, dayBoundaryMin: dayBoundaryMin)}',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final item = card.item;
    final look = _lookOf(item, colors);
    final label = _label(item);
    final sub = _sub(item);
    final range = _range(item.span);
    final block = item is BlockItem ? item.block : null;
    final done = block?.status == PlanBlockStatus.done;
    final cancelled = item is ClassItem && item.cancelled;
    final faded =
        (card.past && !card.current) ||
        done ||
        block?.status == PlanBlockStatus.missed;
    final checkable =
        block != null &&
        block.status != PlanBlockStatus.suggested &&
        block.status != PlanBlockStatus.missed;
    final short = card.mode == TimelineCardMode.short;
    final titleColor = faded || cancelled ? colors.muted : colors.ink;
    final metaColor = card.current
        ? colors.accent
        : faded || cancelled
        ? colors.muted
        : look.ink;
    final remaining = item.span.end.difference(now).inMinutes;
    final meta = card.current
        ? ['진행 중', '$remaining분 남음', item is BlockItem ? label : sub]
        : [label, sub, if (card.mode == TimelineCardMode.mid) range];
    final metaText = meta
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final padding = switch (card.mode) {
      TimelineCardMode.short => const EdgeInsets.fromLTRB(14, 11, 14, 11),
      TimelineCardMode.mid => const EdgeInsets.fromLTRB(14, 11, 14, 10),
      TimelineCardMode.tall => const EdgeInsets.fromLTRB(14, 13, 14, 12),
    };

    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontSize: short ? 14 : 15,
                        fontWeight: AppText.semibold,
                        letterSpacing: -0.3,
                        color: titleColor,
                        decoration: done || cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (!short)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          metaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            color: metaColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (short)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, left: 8),
                    child: Text(
                      block != null && block.status != PlanBlockStatus.confirmed
                          ? '$label · $range'
                          : range,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: metaColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              if (look.icon case final icon?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: AppIcon(icon, size: 17, color: look.ink),
                ),
              if (checkable) const SizedBox(width: 30),
            ],
          ),
          if (card.mode == TimelineCardMode.tall) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 9, bottom: 7),
              color: look.dashed ? colors.taskLine : look.border,
            ),
            Row(
              children: [
                AppIcon(AppIconName.clock, size: 14, color: colors.ink2),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    range,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: colors.ink2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    Widget body = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.timetableBlock),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: content,
      ),
    );
    body = look.dashed
        ? DashedBorder(
            color: look.border,
            radius: AppRadius.timetableBlock,
            width: look.width,
            background: look.background,
            child: body,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: look.background,
              borderRadius: BorderRadius.circular(AppRadius.timetableBlock),
              border: Border.all(color: look.border, width: look.width),
            ),
            child: body,
          );
    if (card.current) {
      final total = item.span.minutes;
      final passed = now.difference(item.span.start).inMinutes;
      body = Stack(
        children: [
          Positioned.fill(child: body),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: total == 0 ? 0 : (passed / total).clamp(0, 1),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.timetableBlock),
                  ),
                  child: Container(height: 3, color: colors.strong),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final gone = item is BlockItem && item.gone;
    if (gone) {
      body = Opacity(
        opacity: 0.5,
        child: ColorFiltered(colorFilter: _grayscale, child: body),
      );
    } else if (faded) {
      body = Opacity(opacity: 0.55, child: body);
    }

    final semantics = [
      title,
      '${hhmmText(item.span.start.hour * 60 + item.span.start.minute)}부터 '
          '${hhmmText(item.span.end.hour * 60 + item.span.end.minute)}',
      label,
      if (onTap != null) item is BlockItem ? '근거 보기' : '정보 보기',
    ].join(', ');
    final card0 = Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Press(enabled: onTap != null, child: card0),
        if (checkable)
          Positioned(
            right: 0,
            top: 0,
            width: AppSize.minTouch,
            height: AppSize.minTouch,
            child: _CheckButton(
              done: done,
              label: done ? '$title 완료 취소' : '$title 완료로 표시',
              onTap: onCheck,
            ),
          ),
      ],
    );
  }
}

const _grayscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      checked: done,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: MotionScope.of(context)
                .duration(const Duration(milliseconds: 300)),
            curve: AppEase.emphasized,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? colors.strong : null,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: done ? colors.strong : colors.icon,
                width: 1.6,
              ),
            ),
            child: done
                ? Center(
                    child: AppIcon(
                      AppIconName.check,
                      size: 12,
                      color: colors.onStrong,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.item});

  /// [TravelItem]이나 [MealItem].
  final DayItem item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final travel = item is TravelItem;
    final minutes = item.span.minutes;
    final startMin = item.span.start.hour * 60 + item.span.start.minute;
    final lunch =
        startMin < Defaults.lunchBandEndMin &&
        startMin + minutes > Defaults.lunchBandStartMin;
    final text = travel
        ? '이동 ${durationText(minutes)}'
        : '${lunch ? '점심' : '식사'} · ${durationText(minutes)} 비워 뒀어요';
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          AppIcon(
            travel ? AppIconName.bus : AppIconName.meal,
            size: 14,
            color: colors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
    final body = ClipRect(
      child: OverflowBox(minHeight: 0, maxHeight: double.infinity, child: row),
    );
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: travel
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.edge2),
              ),
              child: body,
            )
          : DashedBorder(
              color: colors.edge2,
              radius: 12,
              width: 1,
              child: body,
            ),
    );
  }
}

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.span, required this.onTap});

  final TimeSpan span;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = '빈 시간 ${durationText(span.minutes)}';
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          AppIcon(AppIconName.freeTime, size: 15, color: colors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small.copyWith(color: colors.muted),
            ),
          ),
          if (onTap != null) ...[
            AppIcon(AppIconName.plus, size: 13, color: colors.accent),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                '놓기',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontWeight: AppText.semibold,
                  color: colors.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label:
          '${hhmmText(span.start.hour * 60 + span.start.minute)}부터 '
          '${durationText(span.minutes)} 빈 시간${onTap == null ? '' : ', 할 일 놓기'}',
      excludeSemantics: true,
      child: Press(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DashedBorder(
            color: colors.edge2,
            radius: AppRadius.input,
            background: colors.bg,
            child: ClipRect(
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                child: row,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 46,
            right: 0,
            top: 9,
            height: 1.5,
            child: CustomPaint(painter: _DashLinePainter(colors.strong)),
          ),
          Positioned(
            left: 0,
            top: 0,
            height: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.strong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    hhmmText(now.hour * 60 + now.minute),
                    maxLines: 1,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      height: 1,
                      fontWeight: AppText.semibold,
                      color: colors.onStrong,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

/// 가로 점선(지금 선).
class _DashLinePainter extends CustomPainter {
  const _DashLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    const dash = 4.5;
    const gap = 3.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 09 일간 빈 시간 카드 아래의 'HH:MM에 놓기' 칸. 글자는 오른쪽에 두고, 누르면 그 시부터 빈 시간에 놓기 시트를
/// 연다(최종 프로토타입). 누르는 동안 옅은 바탕과 테두리를 보인다.
class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.span, required this.onTap});

  final TimeSpan span;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final time = hhmmText(span.start.hour * 60 + span.start.minute);
    return Semantics(
      container: true,
      button: true,
      label: '$time부터 빈 시간, 할 일 놓기',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          highlightColor: colors.surface,
          child: ClipRect(
            child: OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppIcon(AppIconName.plus, size: 12, color: colors.accent),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '$time에 놓기',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          fontWeight: AppText.semibold,
                          color: colors.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
