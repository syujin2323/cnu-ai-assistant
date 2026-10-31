// 왼쪽 드로어. docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 화면 위에 떠 있는 둥근 패널이다. 위에서부터 닫기·톱니바퀴(나), 보기(년·월·주·일·일정),
// 데일리 브리핑·미배정 할 일 순서이고 점선으로 나눈다. 보기끼리는 go로 바꾸고, 그 밖의 화면은
// push로 쌓아 뒤로 가면 보던 보기로 돌아온다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
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
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.current, required this.selected});

  /// 지금 보기.
  final CalendarView current;

  /// 선택한 날. 일간을 열 때 쓴다.
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}

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
