// 캘린더 보기들의 틀. docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 상단바는 메뉴 · 가운데 제목 · 검색 · 오늘(날짜 숫자 상자)이다. 하단에는 'N월 N일에 추가'
// 알약(글자 부분은 직접 입력, +는 말로 입력)과 그 오른쪽 원형 중요 브리핑 버튼을 띄운다.
// 추가 시트는 부르는 화면이 [CalendarScaffold.onAdd]로 넘긴다. 중요 브리핑 시트는 다음 PR에서
// 만들고, 그전까지는 만들고 있다는 시트를 띄운다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 보기 하나의 틀.
class CalendarScaffold extends StatelessWidget {
  const CalendarScaffold({
    super.key,
    required this.view,
    required this.title,
    required this.selected,
    required this.today,
    required this.onToday,
    required this.onAdd,
    required this.body,
  });

  /// 지금 보기(드로어 표시).
  final CalendarView view;

  /// 가운데 제목(월간은 'N월').
  final String title;

  /// 선택한 날. 추가 알약의 'N월 N일'과 드로어의 일간에 쓴다.
  final DateTime selected;

  /// 오늘(상단 오늘 버튼의 숫자).
  final DateTime today;

  /// 오늘 버튼을 눌렀을 때.
  final VoidCallback onToday;

  /// 추가 알약을 눌렀을 때. 인자는 말로 입력(+)인지다.
  final ValueChanged<bool> onAdd;

  /// 본문. 아래 [CalendarBottomBar.height] 만큼은 하단 바가 덮는다.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: AppDrawer(current: view, selected: selected),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(title: title, today: today, onToday: onToday),
                Expanded(child: body),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CalendarBottomBar(selected: selected, onAdd: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.today,
    required this.onToday,
  });

  final String title;
  final DateTime today;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s8,
        AppSpace.s4,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const AppIcon(AppIconName.menu, color: AppColors.ink),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            tooltip: '검색',
            onPressed: () => context.push(Routes.search),
            icon: const AppIcon(AppIconName.search, color: AppColors.ink),
          ),
          IconButton(
            tooltip: '오늘로 이동',
            onPressed: onToday,
            icon: Container(
              width: AppSize.icon + AppSpace.s4,
              height: AppSize.icon + AppSpace.s4,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ink, width: 1.6),
                borderRadius: BorderRadius.circular(AppRadius.tag + 3),
              ),
              child: ExcludeSemantics(
                child: Text(
                  '${today.day}',
                  style: AppText.caption.copyWith(fontWeight: AppText.semibold),
                  textScaler: TextScaler.noScaling,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단의 추가 알약과 원형 중요 브리핑 버튼.
class CalendarBottomBar extends StatelessWidget {
  const CalendarBottomBar({
    super.key,
    required this.selected,
    required this.onAdd,
  });

  /// 하단 바가 덮는 높이(본문 목록의 아래 여백에 쓴다).
  static const double height = AppSize.bottomBar + AppSpace.s16 * 2;

  final DateTime selected;

  /// 인자는 말로 입력(+)인지다.
  final ValueChanged<bool> onAdd;

  @override
  Widget build(BuildContext context) {
    final pillRadius = BorderRadius.circular(AppRadius.pill);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Material(
                color: AppColors.tint,
                borderRadius: pillRadius,
                elevation: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: pillRadius,
                        onTap: () => onAdd(false),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSize.bottomBar,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s20,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${selected.month}월 ${selected.day}일에 추가',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyLarge.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '말로 일정 추가',
                      onPressed: () => onAdd(true),
                      icon: const AppIcon(
                        AppIconName.plus,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Material(
            color: AppColors.tint,
            shape: const CircleBorder(),
            elevation: 3,
            child: SizedBox.square(
              dimension: AppSize.bottomBar,
              child: IconButton(
                tooltip: '중요 브리핑',
                onPressed: () => showInProgressSheet(context, '중요 브리핑'),
                icon: const AppIcon(AppIconName.briefing, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 아직 만들지 않은 시트 자리. [title]과 '이 화면은 아직 만들고 있어요'를 보여 준다.
Future<void> showInProgressSheet(BuildContext context, String title) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.screen,
          0,
          AppSpace.screen,
          AppSpace.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.title),
            const SizedBox(height: AppSpace.s8),
            Text(
              AppStrings.inProgress,
              style: AppText.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
