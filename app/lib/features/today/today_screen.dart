// 02 홈(오늘 탭 `/today`). docs/screens.md '02 홈'.
//
// 위에서부터 머리(날짜와 '{지금} · 남은 일정 N개 · 할 일 N개', 오른쪽에 01 계획을 여는 [계획]), 다시 로그인 칩,
// 피드백 카드, 오늘 시간표다. [계획]은 01 계획을 push로 열어 닫으면 이 화면으로 돌아온다(docs/decisions.md
// 2026-11-19 ''아침 브리핑'을 '계획'으로 부르고 02 홈에서도 연다').
// 시간표에는 확정한 할 일만 있고(제안은 보이지 않음), 지난 일정은 '지난 일정 N개 보기'로 접으며 '일간 보기 ›'가
// 09 일간을 연다. 블록의 체크는 블록 완료를 켜고 끈다. 블록을 누르면 근거 시트, 수업·일정·고정 일정을 누르면 일정
// 정보 시트를 연다. 빈 시간을 눌러 여는 빈 시간에 놓기 시트와 시간 부족·빈 시간 없음 카드, 끌어 옮기기는 그
// 시트·카드 PR(W5–W8, S3)에서 붙인다.
// 화면을 떠나면(다른 탭이나 전체 화면이 덮음) 피드백 카드의 방금 한 답과 그 되돌리기 기록을 버린다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline.dart';
import 'package:cnu_ai_assistant/design/widgets/day_timeline_layout.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/home_feedback.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/today/block_actions.dart';
import 'package:cnu_ai_assistant/features/today/event_info_actions.dart';
import 'package:cnu_ai_assistant/features/today/today_controller.dart';
import 'package:cnu_ai_assistant/features/today/widgets/feedback_card.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_system_band_slot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 02 홈.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// 지난 일정을 펼쳤는지.
  bool _showPast = false;

  /// 이 화면이 보이는지(다른 탭이나 덮는 전체 화면이면 false).
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // 전에 있던 02 홈에서 한 답은 이 화면의 것이 아니다(그 화면을 떠난 것).
    _leaveLater();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 하단 탭의 다른 가지로 가거나 전체 화면이 이 화면을 덮으면 그 아래 화면의 티커가 꺼진다. 그때를 화면을
    // 떠난 것으로 본다(시트는 덮어도 티커가 남으므로 떠난 것이 아님).
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible && !visible) _leaveLater();
    _visible = visible;
  }

  /// 피드백 카드의 방금 한 답을 버린다. 위젯 생명 주기 안에서는 provider를 바꿀 수 없으므로 그 뒤에 한다.
  void _leaveLater() => Future.microtask(() {
    if (mounted) ref.read(homeAnswerProvider.notifier).leave();
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final home = ref.watch(todayHomeProvider);
    final answer = ref.watch(homeAnswerProvider)?.answer;
    final status = ref.watch(lmsStatusProvider);
    final value = home.value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: value == null
            ? (home.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.screen),
                        child: Text(
                          '오늘 일정을 불러오지 못했어요',
                          style: AppText.body.copyWith(color: colors.muted),
                        ),
                      ),
                    )
                  : const SizedBox.shrink())
            : _content(context, value, answer, status),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    TodayHome home,
    HomeAnswer? answer,
    LmsStatus? status,
  ) {
    final colors = AppColors.of(context);
    final answers = ref.read(homeAnswerProvider.notifier);
    final layout = layoutDayTimeline(
      day: home.date,
      items: home.items,
      free: home.free,
      now: home.now,
      today: true,
      windowEndMin: home.windowEndMin,
      showPast: _showPast,
      showTravelMeal: home.showTravelMeal,
    );
    final pastCount = layout.pastCount;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s16,
        AppSpace.screen,
        MediaQuery.paddingOf(context).bottom + AppSpace.s24,
      ),
      children: [
        Rise(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        monthDayText(home.date, today: home.date),
                        style: AppText.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      homeSummaryText(
                        now: home.now,
                        events: home.eventsLeft,
                        tasks: home.tasksLeft,
                      ),
                      style: AppText.small.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              const _PlanButton(),
            ],
          ),
        ),
        if (status != null && status.kind == LmsStatusKind.reloginNeeded) ...[
          const SizedBox(height: AppSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: LmsReloginChip(
              status: status,
              onTap: () => openRelogin(context, ref),
            ),
          ),
        ],
        const LmsSystemBandSlot(),
        const SizedBox(height: AppSpace.s12),
        Rise(
          delay: const Duration(milliseconds: 150),
          child: FeedbackCard(
            feedback: homeFeedback(
              now: home.now,
              blocks: home.blocks,
              free: home.free,
              answer: answer,
            ),
            now: home.now,
            dayBoundaryMin: home.dayBoundaryMin,
            actions: FeedbackActions(
              onDid: (block) => answers.answer(block, did: true),
              onDidNot: (block) => answers.answer(block, did: false),
              onUndo: answers.undo,
              onRetry: answers.retry,
              onSkipRetry: answers.skipRetry,
              onDismiss: answers.dismiss,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Semantics(
          container: true,
          label: '오늘 일정',
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 두 링크가 한 줄에 들어가지 않으면(글자를 키운 경우) '일간 보기'가 다음 줄로 내려간다. 지난 일정이
              // 없을 때도 '일간 보기'가 오른쪽에 오도록 빈 자리를 앞에 둔다.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (pastCount > 0 || _showPast)
                    _TextLink(
                      icon: AppIconName.chevronUp,
                      iconTurns: _showPast ? 0 : 0.5,
                      text: _showPast ? '지난 일정 접기' : '지난 일정 $pastCount개 보기',
                      onTap: () => setState(() => _showPast = !_showPast),
                      leading: true,
                    )
                  else
                    const SizedBox.shrink(),
                  _TextLink(
                    icon: AppIconName.chevronRight,
                    text: '일간 보기',
                    onTap: () => context.go(Routes.day(home.date)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              DayTimeline(
                layout: layout,
                day: home.date,
                now: home.now,
                dayBoundaryMin: home.dayBoundaryMin,
                courseNames: home.courseNames,
                onItemTap: (item) => openEventInfoSheet(context, ref, item),
                onBlockTap: (item) => openBlockSheet(context, ref, item.block),
                onBlockCheck: answers.toggleBlock,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 시간표 위의 작은 글자 링크('지난 일정 N개 보기', '일간 보기 ›').
class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.icon,
    required this.text,
    required this.onTap,
    this.leading = false,
    this.iconTurns = 0,
  });

  final AppIconName icon;
  final String text;
  final VoidCallback onTap;

  /// 아이콘을 글자 앞에 둔다(아니면 뒤).
  final bool leading;

  /// 아이콘을 돌리는 정도(바퀴).
  final double iconTurns;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final glyph = RotationTransition(
      turns: AlwaysStoppedAnimation(iconTurns),
      child: AppIcon(icon, size: 14, color: colors.muted),
    );
    return Press(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading) ...[glyph, const SizedBox(width: 6)],
                Text(text, style: AppText.small.copyWith(color: colors.muted)),
                if (!leading) ...[const SizedBox(width: 2), glyph],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 머리 오른쪽의 [계획]. 01 계획을 열어 오늘 할 일을 고르거나 더한다.
class _PlanButton extends StatelessWidget {
  const _PlanButton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Press(
      child: TextButton.icon(
        onPressed: () => context.push(Routes.briefing),
        style: TextButton.styleFrom(
          backgroundColor: colors.tint,
          foregroundColor: colors.accent,
          minimumSize: const Size(0, AppSize.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          shape: const StadiumBorder(),
        ),
        icon: AppIcon(AppIconName.checkSquare, size: 18, color: colors.accent),
        label: Text(
          '계획',
          style: AppText.small.copyWith(fontWeight: AppText.semibold),
        ),
      ),
    );
  }
}
