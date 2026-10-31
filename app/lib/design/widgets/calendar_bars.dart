// 캘린더 보기들의 틀. docs/architecture.md '화면 이동'(2026-10-31 삼성 캘린더 골자).
//
// 상단바는 메뉴 · 가운데 제목 · 검색 · 오늘(날짜 숫자 상자)이다. 하단에는 'N월 N일에 추가'
// 알약(글자 부분은 직접 입력, +는 말로 입력)과 그 오른쪽 원형 중요 브리핑 버튼을 띄운다.
// 추가 시트는 부르는 화면이 [CalendarScaffold.onAdd]로 넘긴다. 중요 브리핑 시트는 모달이 아니라
// 이 틀이 하단 바 아래 겹으로 띄우므로, 열린 동안 원형 버튼이 같은 자리에서 닫기 X가 된다.
// 시트는 손잡이를 아래로 끌거나 바깥을 누르거나 뒤로 가기로도 닫는다. 안 본 중요 알림이 있으면
// 원형 버튼에 레드닷을 단다. 월간의 데일리 스케줄처럼 본문이 하단 바를 숨기라고 하면
// ([CalendarScaffold.showBottomBar]) 하단 바를 그리지 않는다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 캘린더 보기 하나의 틀.
class CalendarScaffold extends StatefulWidget {
  const CalendarScaffold({
    super.key,
    required this.view,
    required this.title,
    required this.selected,
    required this.today,
    required this.onToday,
    required this.onAdd,
    required this.importantBriefing,
    required this.hasUnseenAlerts,
    required this.body,
    this.showBottomBar = true,
    this.animate = true,
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

  /// 중요 브리핑 시트의 본문. 두 번째 인자는 시트를 닫는 함수다.
  final Widget Function(BuildContext context, VoidCallback close)
  importantBriefing;

  /// 안 본 중요 알림이 있는지(레드닷).
  final bool hasUnseenAlerts;

  /// 본문. 아래 [CalendarBottomBar.height] 만큼은 하단 바가 덮는다.
  final Widget body;

  /// 하단 바를 그리는지. 월간의 데일리 스케줄을 펼친 동안은 false다.
  final bool showBottomBar;

  /// 시트가 올라오는 움직임을 쓰는지(모션 등급이 꺼짐이면 false).
  final bool animate;

  @override
  State<CalendarScaffold> createState() => _CalendarScaffoldState();
}

class _CalendarScaffoldState extends State<CalendarScaffold> {
  /// 중요 브리핑 시트가 열렸는지.
  bool _briefingOpen = false;

  /// 시트 손잡이를 아래로 끈 거리.
  double _sheetDrag = 0;

  /// 이만큼 끌어 내리거나 이 빠르기로 튕기면 시트를 닫는다.
  static const double _closeDistance = 80;
  static const double _closeVelocity = 300;

  void _setBriefing(bool open) => setState(() {
    _briefingOpen = open;
    _sheetDrag = 0;
  });

  void _closeBriefing() => _setBriefing(false);

  void _onSheetDragEnd(DragEndDetails details) {
    if (_sheetDrag >= _closeDistance ||
        (details.primaryVelocity ?? 0) >= _closeVelocity) {
      _closeBriefing();
    } else {
      setState(() => _sheetDrag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _briefingOpen;
    return PopScope(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeBriefing();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        drawer: AppDrawer(current: widget.view, selected: widget.selected),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(
                    title: widget.title,
                    today: widget.today,
                    onToday: widget.onToday,
                  ),
                  Expanded(child: widget.body),
                ],
              ),
              if (open) ...[
                // 바깥을 누르면 닫는다.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeBriefing,
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: AppSize.minTouch,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: widget.animate
                          ? AppMotion.sheet
                          : Duration.zero,
                      curve: AppEase.emphasized,
                      builder: (context, t, child) => FractionalTranslation(
                        translation: Offset(0, t),
                        child: child,
                      ),
                      child: Transform.translate(
                        offset: Offset(0, _sheetDrag),
                        child: _BriefingSheet(
                          showBottomBar: widget.showBottomBar,
                          onDrag: (dy) => setState(
                            () => _sheetDrag = (_sheetDrag + dy).clamp(
                              0,
                              double.infinity,
                            ),
                          ),
                          onDragEnd: _onSheetDragEnd,
                          child: widget.importantBriefing(
                            context,
                            _closeBriefing,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // 하단 바는 시트 위에 그려 원형 버튼이 시트가 열린 동안 닫기 X가 된다.
              if (widget.showBottomBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CalendarBottomBar(
                    selected: widget.selected,
                    onAdd: (sentence) {
                      if (open) _closeBriefing();
                      widget.onAdd(sentence);
                    },
                    onBriefing: () => _setBriefing(!open),
                    hasUnseenAlerts: widget.hasUnseenAlerts,
                    briefingOpen: open,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 중요 브리핑 시트의 겉(둥근 위 모서리, 손잡이). 아래는 하단 바 높이만큼 비운다.
class _BriefingSheet extends StatelessWidget {
  const _BriefingSheet({
    required this.showBottomBar,
    required this.onDrag,
    required this.onDragEnd,
    required this.child,
  });

  final bool showBottomBar;
  final ValueChanged<double> onDrag;
  final GestureDragEndCallback onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
            onVerticalDragEnd: onDragEnd,
            child: const SizedBox(
              width: double.infinity,
              height: AppSize.minTouch / 2 + AppSpace.s8,
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.edge,
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Flexible(child: child),
          if (showBottomBar) const SizedBox(height: CalendarBottomBar.height),
        ],
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
    required this.onBriefing,
    this.hasUnseenAlerts = false,
    this.briefingOpen = false,
  });

  /// 하단 바가 덮는 높이(본문 목록의 아래 여백에 쓴다).
  static const double height = AppSize.bottomBar + AppSpace.s16 * 2;

  final DateTime selected;

  /// 인자는 말로 입력(+)인지다.
  final ValueChanged<bool> onAdd;

  final VoidCallback onBriefing;

  /// 안 본 중요 알림이 있으면 원형 버튼에 레드닷을 단다.
  final bool hasUnseenAlerts;

  /// 중요 브리핑 시트가 열렸는지. 열렸으면 원형 버튼이 닫기 X다.
  final bool briefingOpen;

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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: briefingOpen
                        ? '중요 브리핑 닫기'
                        : hasUnseenAlerts
                        ? '중요 브리핑, 새 알림 있음'
                        : '중요 브리핑',
                    onPressed: onBriefing,
                    icon: AppIcon(
                      briefingOpen ? AppIconName.close : AppIconName.briefing,
                      color: AppColors.ink,
                    ),
                  ),
                  if (hasUnseenAlerts && !briefingOpen)
                    const Positioned(
                      top: AppSpace.s12,
                      right: AppSpace.s12,
                      child: IgnorePointer(
                        child: SizedBox.square(
                          dimension: AppSpace.s8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.alert,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
