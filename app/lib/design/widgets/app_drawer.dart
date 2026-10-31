// 왼쪽 드로어. docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 화면 위에 떠 있는 둥근 패널이다. 위에서부터 닫기·톱니바퀴(나), 보기(년·월·주·일·일정),
// 데일리 브리핑·미배정 할 일, '내 폰'(캘린더 켜고 끄기) 순서이고 점선으로 나눈다. 보기끼리는
// go로 바꾸고, 그 밖의 화면은 push로 쌓아 뒤로 가면 보던 보기로 돌아온다. '내 폰'의 동그라미를
// 누르면 그 캘린더의 항목을 모든 보기와 검색에서 숨기거나 다시 보인다(`settings`의
// `hiddenCalendars`). 미배정 할 일은 숨긴 캘린더도 그대로 보여 준다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/calendar_items.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 보기. 드로어에서 지금 보기를 표시하는 데 쓴다.
enum CalendarView {
  year('년', AppIconName.calendar),
  month('월', AppIconName.calendar),
  week('주', AppIconName.calendar),
  day('일', AppIconName.calendar),
  agenda('일정', AppIconName.agenda);

  const CalendarView(this.label, this.icon);

  final String label;
  final AppIconName icon;

  /// 이 보기의 경로. 일간은 [selected]의 날짜로 연다.
  String route(DateTime selected) => switch (this) {
    CalendarView.year => Routes.calendarYear,
    CalendarView.month => Routes.calendar,
    CalendarView.week => Routes.calendarWeek,
    CalendarView.day => Routes.calendarDay(isoDate(selected)),
    CalendarView.agenda => Routes.calendarAgenda,
  };
}

/// 캘린더 보기들의 드로어.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.current, required this.selected});

  /// 지금 보기.
  final CalendarView current;

  /// 선택한 날. 일간을 열 때 쓴다.
  final DateTime selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden =
        ref.watch(hiddenCalendarsProvider).value ?? const <CalendarSource>{};

    void go(String route) {
      Navigator.of(context).pop();
      context.go(route);
    }

    void push(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s12),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: '메뉴 닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const AppIcon(AppIconName.menu, color: AppColors.ink),
                ),
                IconButton(
                  tooltip: AppStrings.me,
                  onPressed: () => push(Routes.me),
                  icon: const AppIcon(
                    AppIconName.settings,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const _DottedDivider(),
            for (final view in CalendarView.values)
              _DrawerItem(
                icon: view.icon,
                label: view.label,
                selected: view == current,
                onTap: () => go(view.route(selected)),
              ),
            const _DottedDivider(),
            _DrawerItem(
              icon: AppIconName.briefing,
              label: AppStrings.dailyBriefing,
              onTap: () => push(Routes.briefing),
            ),
            _DrawerItem(
              icon: AppIconName.tasks,
              label: AppStrings.unassignedTasks,
              onTap: () => push(Routes.tasks),
            ),
            const _DottedDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  '내 폰',
                  style: AppText.small.copyWith(color: AppColors.muted),
                ),
              ),
            ),
            for (final source in CalendarSource.values)
              _CalendarToggle(
                label: _calendarLabel(source),
                color: _calendarColor(source),
                shown: !hidden.contains(source),
                onTap: () async {
                  final result = await setCalendarShown(
                    ref,
                    source,
                    shown: hidden.contains(source),
                  );
                  if (result is Err<void> && context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('설정을 저장하지 못했어요')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _calendarLabel(CalendarSource source) => switch (source) {
  CalendarSource.classes => '수업',
  CalendarSource.mine => '내 일정',
  CalendarSource.lms => '충남대 사이버캠퍼스',
  CalendarSource.notification => '알림에서 추가',
};

Color _calendarColor(CalendarSource source) => switch (source) {
  CalendarSource.classes => AppColors.accent,
  CalendarSource.mine => AppColors.saturday,
  CalendarSource.lms => AppColors.alert,
  CalendarSource.notification => AppColors.icon,
};

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final AppIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.smallCard);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppColors.tint : null,
            borderRadius: radius,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s12,
                vertical: AppSpace.s8,
              ),
              child: Row(
                children: [
                  AppIcon(icon, color: AppColors.ink),
                  const SizedBox(width: AppSpace.s16),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: selected ? AppText.semibold : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// '내 폰'의 캘린더 한 줄. 보이면 색을 채운 동그라미에 체크, 숨기면 빈 동그라미다.
class _CalendarToggle extends StatelessWidget {
  const _CalendarToggle({
    required this.label,
    required this.color,
    required this.shown,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: shown,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s8,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: AppSize.icon,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: shown ? color : null,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: shown
                        ? const CustomPaint(painter: _CheckPainter())
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpace.s16),
                Expanded(child: Text(label, style: AppText.bodyLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 동그라미 안의 체크 표시.
class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

/// 드로어 묶음 사이의 점선.
class _DottedDivider extends StatelessWidget {
  const _DottedDivider();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const dot = 2.0;
            const gap = 4.0;
            final count = (constraints.maxWidth / (dot + gap)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < count; i++)
                  const SizedBox(
                    width: dot,
                    height: dot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.edge,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
