// 13 시간표·고정 일정(`/me/timetable`, 셸 밖 전체 화면). docs/screens.md '13 시간표·고정 일정'.
//
// 10 나와 일정 정보 시트의 '시간표·고정 일정에서 바꾸기'(고정 일정 탭)에서 push로 열고, 닫으면 연 화면으로 돌아온다.
// 위에 [시간표 | 고정 일정] 두 탭을 둔다. 처음 열 탭은 `/me/timetable?tab=fixed`처럼 받는다(`Routes.meTimetableTab`).
// - 시간표 탭: 14 온보딩 1단계에서 로그인할 때 통합정보시스템에서 불러온 이번 학기 시간표의 격자와 수업 목록(같은
//   과목·시각·장소의 요일은 한 수업). 수업을 누르면 수업 시트(`design/widgets/class_slot_sheet.dart`). [새로 고침]은
//   누를 때만 다시 불러오고, 바뀌거나 없어진 수업은 '바뀐 수업' 시트에서 고른 것만 반영한다(`timetable_controller.dart`).
// - 고정 일정 탭: 고정 일정 카드와 '자주 넣는 일정' 칩. 누르면 고정 일정 시트(`design/widgets/fixed_block_sheet.dart`).
// 아래에 [+ 수업 추가]/[+ 고정 일정 추가]를 둔다. 문구는 최종 프로토타입을 따른 임시 문구다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/course_colors.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:cnu_ai_assistant/design/widgets/class_slot_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/fixed_block_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/timetable_grid.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/me/timetable_controller.dart';
import 'package:cnu_ai_assistant/features/me/widgets/timetable_diff_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 13 시간표·고정 일정의 탭. 따로 고르지 않으면 [timetable]이 열린다.
enum TimetableTab {
  /// 시간표.
  timetable,

  /// 고정 일정. 일정 정보 시트의 [시간표·고정 일정에서 바꾸기]가 이 탭으로 연다.
  fixed,
}

/// 13 시간표·고정 일정.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key, this.initialTab = TimetableTab.timetable});

  /// 처음 열 탭.
  final TimetableTab initialTab;

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late TimetableTab _tab = widget.initialTab;
  bool _refreshing = false;

  @override
  void didUpdateWidget(TimetableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab;
  }

  void _toast(String text) =>
      ref.read(toastControllerProvider.notifier).show(text);

  Future<void> _refresh() async {
    if (ref.read(appModeProvider) == AppMode.demo) {
      _toast(AppStrings.demoNoLms);
      return;
    }
    setState(() => _refreshing = true);
    final result = await ref.read(timetableRefreshProvider)();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final message = timetableRefreshMessage(result);
    if (message != null) {
      _toast(message);
      return;
    }
    final entries = ref.read(classSlotEntriesProvider).value ?? const [];
    await showTimetableDiffSheet(
      context,
      ref,
      changes: result.timetableChanges,
      courseNames: {for (final e in entries) e.course.id: e.course.name},
      added: result.changedCount,
      partial: result.kind == SyncResultKind.partial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final timetable = _tab == TimetableTab.timetable;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.timetableAndFixed),
        actions: [
          if (timetable)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s8),
              child: TextButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: AppIcon(
                  AppIconName.refresh,
                  size: 18,
                  color: _refreshing ? colors.muted : colors.accent,
                ),
                label: Text(_refreshing ? '불러오는 중…' : '새로 고침'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.s8,
                  AppSpace.screen,
                  AppSpace.s24,
                ),
                children: [
                  SegmentedButton<TimetableTab>(
                    segments: const [
                      ButtonSegment(
                        value: TimetableTab.timetable,
                        label: Text('시간표'),
                      ),
                      ButtonSegment(
                        value: TimetableTab.fixed,
                        label: Text('고정 일정'),
                      ),
                    ],
                    selected: {_tab},
                    showSelectedIcon: false,
                    onSelectionChanged: (tabs) =>
                        setState(() => _tab = tabs.single),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  if (timetable)
                    const _TimetableTabBody()
                  else
                    const _FixedTabBody(),
                ],
              ),
            ),
            ToastAnchor(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.s8,
                  AppSpace.screen,
                  AppSpace.s16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => timetable
                        ? showClassSlotSheet(context, ref)
                        : showFixedBlockSheet(context, ref),
                    icon: AppIcon(
                      AppIconName.plus,
                      size: 18,
                      color: colors.onStrong,
                    ),
                    label: Text(timetable ? '수업 추가' : '고정 일정 추가'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimetableTabBody extends ConsumerWidget {
  const _TimetableTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final entries = ref.watch(classSlotEntriesProvider).value ?? const [];
    final settings = ref.watch(settingsProvider).value;
    final boundary = settings?.dayBoundaryMin ?? Defaults.dayBoundaryMin;
    final today = logicalDate(
      ref.watch(minuteClockProvider),
      dayBoundaryMin: boundary,
    );
    final importedAt = settings?.lmsTimetableImportedAt;
    final loggedIn = !(settings?.lmsSessionState.beforeLogin ?? true);
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    final groups = groupClassSlots(entries);
    final weekly = entries.where((e) => !e.slot.recorded).length;

    void open(ClassGroup group) =>
        showClassSlotSheet(context, ref, group: group);

    final sub = importedAt != null
        ? '통합정보시스템에서 불러온 이번 학기 시간표 · '
              '${importedOnText(logicalDate(importedAt, dayBoundaryMin: boundary), today: today)}'
        : demo
        ? '샘플 학생의 이번 학기 시간표'
        : loggedIn
        ? '새로 고침을 누르면 이번 학기 시간표를 불러와요'
        : 'LMS에 로그인하면 이번 학기 시간표를 불러와요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(sub, style: AppText.small.copyWith(color: colors.muted)),
        const SizedBox(height: AppSpace.s12),
        TimetableGrid(
          entries: entries,
          today: today.weekday,
          onTap: (entry) =>
              open(groups.firstWhere((g) => g.slotIds.contains(entry.slot.id))),
          empty: _EmptyNote(
            title: '아직 수업이 없어요',
            text: loggedIn
                ? '새로 고침으로 시간표를 다시 불러오거나 수업을 직접 넣어 주세요. 그전에는 빈 시간을 짐작하지 않아요'
                : '수업을 직접 넣을 수도 있어요. 시간표가 생기기 전에는 빈 시간을 짐작하지 않아요',
          ),
        ),
        if (groups.isNotEmpty) ...[
          FormLabel('수업 ${groups.length}개', trailing: '주 $weekly회'),
          _Group(
            children: [
              for (final group in groups)
                _ListRow(
                  tint: CourseColors.of(context, group.course.id).tint,
                  ink: CourseColors.of(context, group.course.id).ink,
                  icon: AppIconName.school,
                  title: group.course.name,
                  sub: group.recorded
                      ? '녹화 강의 · 시간표에 그리지 않아요'
                      : '${group.whenText} · ${_where(group)}',
                  onTap: () => open(group),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _where(ClassGroup group) =>
      group.online ? '실시간 온라인' : group.place ?? '장소 없음';
}

class _FixedTabBody extends ConsumerWidget {
  const _FixedTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final blocks = ref.watch(fixedBlocksProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '매주 같은 시간에 하는 일이에요. 이 시간에는 할 일을 놓지 않아요',
          style: AppText.small.copyWith(color: colors.muted),
        ),
        const SizedBox(height: AppSpace.s12),
        if (blocks.isEmpty)
          const _EmptyNote(
            title: '고정 일정이 없어요',
            text: '점심·알바·운동처럼 매주 하는 일을 넣어 두면 그 시간은 비워 둬요',
          )
        else
          _Group(
            children: [
              for (final block in blocks)
                _ListRow(
                  tint: colors.personalTint,
                  ink: colors.personalInk,
                  icon: fixedBlockKindIcon(block.kind),
                  title: block.name,
                  sub: _when(block),
                  onTap: () => showFixedBlockSheet(context, ref, block: block),
                ),
            ],
          ),
        const FormLabel('자주 넣는 일정'),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final kind in FixedBlockKind.values)
              ChoiceChipButton(
                label: kind == FixedBlockKind.meal
                    ? fixedBlockTemplate(kind).name
                    : fixedBlockKindText(kind),
                icon: fixedBlockKindIcon(kind),
                selected: false,
                onTap: () => showFixedBlockSheet(context, ref, template: kind),
              ),
          ],
        ),
        FormNote(
          '종류를 식사로 고른 일정이 점심 시간(${hhmmText(Defaults.mealWindowStartMin)}–'
          '${hhmmText(Defaults.mealWindowEndMin)})과 겹치면 그 일정이 점심을 대신해요',
        ),
      ],
    );
  }

  static String _when(FixedBlock block) => [
    '${weekdaysText(block.weekdays)} ${timeRangeText(block.startMin, block.endMin)}',
    if (block.bufferMin > 0) '앞뒤 ${block.bufferMin}분',
    if (block.prep case final prep? when prep.isNotEmpty) '준비물 $prep',
  ].join(' · ');
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.title, required this.text});

  final String title;

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.body.copyWith(fontWeight: AppText.semibold),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(text, style: AppText.small.copyWith(color: colors.muted)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        side: BorderSide(color: colors.edge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.s16),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.edge),
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.tint,
    required this.ink,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final Color tint;

  final Color ink;

  final AppIconName icon;

  final String title;

  final String sub;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: '$title, $sub',
      onTapHint: '고치기',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s12,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpace.s8),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: AppIcon(icon, size: 18, color: ink),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(
                          fontWeight: AppText.semibold,
                        ),
                      ),
                      Text(
                        sub,
                        style: AppText.small.copyWith(
                          color: colors.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon(AppIconName.chevronRight, size: 18, color: colors.icon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
