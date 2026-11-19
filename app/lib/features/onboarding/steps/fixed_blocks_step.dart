// 온보딩 3단계: 고정 일정. docs/screens.md '14 온보딩'의 '3단계 · 고정 일정'.
//
// '빠르게 더하기'(알바·운동·통학·기타)를 누르면 그 아래에 작은 폼이 열리고, 넣은 시간에는 할 일을 놓지 않는다.
// 점심은 두지 않는다(배치 엔진이 점심을 기본으로 비워 둠. 관리자 결정 2026-11-19).
// - 알바·운동·기타는 고정 일정(`fixed_blocks`)이다. 폼은 이름·요일·시간이고(`design/widgets/
//   fixed_block_sheet.dart`의 [FixedBlockFormMode.quick]), 종류·앞뒤 여유·준비물은 고른 칩의 처음 값이다
//   (`domain/fixed_block_templates.dart`. 운동의 준비물 기본값은 '운동복').
// - '통학'은 돌려서 고르는 휠(5분 단위 5분–3시간, 기본 40분, 임시)로 골라 내 규칙의 이동 시간(`travel`, 하루 첫
//   수업 전·마지막 수업 뒤)으로 저장하며, 13 시간표·고정 일정의 '통학'(매주 정해진 시각의 고정 일정)과 다르다.
// 넣은 것은 위 목록에 보이고, 고정 일정은 지우고 통학은 고친다(되돌리기 토스트). 온보딩에서 건너뛸 수 있는 단계는
// 이 단계뿐이고, 건너뛰면 4단계로 가며 고정 일정은 나중에 10 나에서 넣는다. 문구는 최종 프로토타입의 문구다(임시).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/fixed_block_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/minute_wheel.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// '빠르게 더하기' 칩. [commute]는 고정 일정이 아니라 내 규칙의 이동 시간이다.
enum QuickAdd {
  work('알바', AppIconName.work, FixedBlockKind.work),
  exercise('운동', AppIconName.exercise, FixedBlockKind.exercise),
  commute('통학', AppIconName.bus, null),
  other('기타', AppIconName.place, FixedBlockKind.other);

  const QuickAdd(this.label, this.icon, this.kind);

  final String label;

  final AppIconName icon;

  /// 고정 일정 종류. 통학(이동 시간 규칙)은 null이다.
  final FixedBlockKind? kind;
}

/// 통학 시간 휠의 값(분, 임시)과 처음 값.
abstract final class CommuteChoices {
  static const int step = 5;
  static const int min = 5;
  static const int max = 180;
  static const int initial = 40;

  static final List<int> minutes = [for (var m = min; m <= max; m += step) m];

  /// [minutes]에 가장 가까운 휠 값(저장된 값이 5분 단위가 아닐 때).
  static int nearest(int value) =>
      ((value / step).round() * step).clamp(min, max).toInt();
}

/// 3단계.
class FixedBlocksStep extends ConsumerStatefulWidget {
  const FixedBlocksStep({super.key, required this.onNext});

  /// '다음': 다음 단계로 간다. 건너뛰기는 화면 위 머리에 있다.
  final VoidCallback onNext;

  @override
  ConsumerState<FixedBlocksStep> createState() => _FixedBlocksStepState();
}

class _FixedBlocksStepState extends ConsumerState<FixedBlocksStep> {
  QuickAdd? _open;
  FixedBlockDraft? _draft;
  int _commuteMin = CommuteChoices.initial;
  bool _busy = false;
  bool _failed = false;

  /// 지금 켜진 통학(하루 첫 수업 전·마지막 수업 뒤, 매일) 이동 시간 규칙. 여럿이면 나중에 저장한 것이다.
  Rule? _commuteRule(List<Rule> rules) {
    Rule? latest;
    for (final rule in rules) {
      if (rule.kind != RuleKind.travel ||
          !rule.active ||
          rule.isUnreadable ||
          rule.weekdays != null ||
          rule.params.position != TravelPosition.dayEdges) {
        continue;
      }
      if (latest == null || rule.updatedAt.isAfter(latest.updatedAt)) {
        latest = rule;
      }
    }
    return latest;
  }

  void _toggle(QuickAdd quick, Rule? commute) => setState(() {
    _failed = false;
    if (_open == quick) {
      _open = null;
      return;
    }
    _open = quick;
    _draft = switch (quick.kind) {
      final kind? => fixedBlockTemplate(kind),
      null => null,
    };
    _commuteMin = CommuteChoices.nearest(
      commute?.params.minutes ?? CommuteChoices.initial,
    );
  });

  Future<void> _run(
    Future<Result<Object?>> Function() action,
    String toast,
  ) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case Ok():
          _open = null;
          ref
              .read(toastControllerProvider.notifier)
              .show(toast, undoable: true);
        case Err():
          _failed = true;
      }
    });
  }

  void _addBlock() {
    final draft = _draft!;
    final name = draft.name.trim();
    final prep = draft.prep.trim();
    _run(
      () => ref
          .read(fixedBlockRepositoryProvider)
          .add(
            name: name,
            weekdays: draft.weekdays.toList(),
            startMin: draft.startMin,
            endMin: draft.endMin,
            bufferMin: draft.bufferMin,
            kind: draft.kind,
            prep: prep.isEmpty ? null : prep,
            source: EntrySource.manual,
            now: ref.read(clockProvider).now(),
          ),
      '${withJosa(name, Josa.eulReul)} 매주 일정으로 넣었어요',
    );
  }

  void _saveCommute() {
    final minutes = _commuteMin;
    _run(
      () => ref
          .read(rulesRepositoryProvider)
          .save(
            kind: RuleKind.travel,
            params: RuleParams(
              minutes: minutes,
              position: TravelPosition.dayEdges,
            ),
            source: EntrySource.manual,
            now: ref.read(clockProvider).now(),
          ),
      '통학 시간을 ${withJosa(durationText(minutes), Josa.euroRo)} 정했어요',
    );
  }

  void _deleteBlock(FixedBlock block) => _run(
    () => ref
        .read(fixedBlockRepositoryProvider)
        .delete(block.id, now: ref.read(clockProvider).now()),
    '${withJosa(block.name, Josa.eulReul)} 지웠어요',
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final blocks = ref.watch(fixedBlocksProvider).value ?? const [];
    final commute = _commuteRule(ref.watch(rulesProvider).value ?? const []);
    final hasItems = blocks.isNotEmpty || commute != null;
    final open = _open;

    return OnboardingStepLayout(
      actions: [
        FilledButton(
          onPressed: _busy ? null : widget.onNext,
          child: const Text('다음'),
        ),
      ],
      content: [
        OnboardingKicker(
          icon: AppIconName.calendar,
          text: OnboardingStep.fixedBlocks.title,
        ),
        const SizedBox(height: AppSpace.s8),
        Semantics(
          header: true,
          child: Text('매주 반복되는 일정이 있나요?', style: AppText.heading),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          '알바·운동처럼 매주 같은 시간에 하는 일에는 할 일을 놓지 않을게요.',
          style: AppText.body.copyWith(color: colors.ink2),
        ),
        const SizedBox(height: AppSpace.s16),
        if (!hasItems)
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 넣은 고정 일정이 없어요',
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  '아래에서 골라 넣으면 그 시간은 비워 둘게요. 없으면 그대로 다음으로 가도 돼요',
                  style: AppText.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          )
        else
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final block in blocks)
                  _ItemRow(
                    icon: fixedBlockKindIcon(block.kind),
                    title: block.name,
                    sub: [
                      '${weekdaysText(block.weekdays)} '
                          '${timeRangeText(block.startMin, block.endMin)}',
                      if (block.prep case final prep? when prep.isNotEmpty)
                        '준비물 $prep',
                    ].join(' · '),
                    actionIcon: AppIconName.trash,
                    actionLabel: '${block.name} 지우기',
                    onAction: _busy ? null : () => _deleteBlock(block),
                  ),
                if (commute != null)
                  _ItemRow(
                    icon: AppIconName.bus,
                    title: '통학 ${durationText(commute.params.minutes ?? 0)}',
                    sub: '내 규칙 · 첫 수업 전과 마지막 수업 뒤',
                    actionIcon: AppIconName.pencil,
                    actionLabel: '통학 시간 바꾸기',
                    onAction: _busy
                        ? null
                        : () => _toggle(QuickAdd.commute, commute),
                  ),
              ],
            ),
          ),
        const FormLabel('빠르게 더하기'),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final quick in QuickAdd.values)
              ChoiceChipButton(
                label: quick.label,
                icon: quick.icon,
                selected: open == quick,
                onTap: _busy ? null : () => _toggle(quick, commute),
              ),
          ],
        ),
        if (open != null) ...[
          const SizedBox(height: AppSpace.s12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  switch (open) {
                    QuickAdd.commute => '학교까지 얼마나 걸려요?',
                    QuickAdd.other => '새 고정 일정',
                    _ => '${open.label} 일정',
                  },
                  style: AppText.bodyLarge.copyWith(
                    fontWeight: AppText.semibold,
                  ),
                ),
                if (open == QuickAdd.commute) ...[
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    '하루 첫 수업 전과 마지막 수업 뒤에 이만큼 비워 두고 할 일을 놓지 않을게요. '
                    "'내 규칙'의 이동 시간에 저장해요.",
                    style: AppText.small.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  MinuteWheel(
                    key: ValueKey(open),
                    label: '통학 시간',
                    values: CommuteChoices.minutes,
                    value: _commuteMin,
                    enabled: !_busy,
                    onChanged: (minutes) =>
                        setState(() => _commuteMin = minutes),
                  ),
                ] else
                  FixedBlockForm(
                    key: ValueKey(open),
                    initial: _draft!,
                    mode: FixedBlockFormMode.quick,
                    enabled: !_busy,
                    onChanged: (draft) => setState(() => _draft = draft),
                  ),
                if (_failed)
                  const FormNote(
                    '저장하지 못했어요. 다시 눌러 주세요',
                    icon: AppIconName.warning,
                  ),
                const SizedBox(height: AppSpace.s16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _open = null),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : open == QuickAdd.commute
                            ? _saveCommute
                            : fixedBlockDraftValid(_draft!)
                            ? _addBlock
                            : null,
                        child: Text(open == QuickAdd.commute ? '저장' : '추가'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.card),
  });

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: child,
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  final AppIconName icon;

  final String title;

  final String sub;

  final AppIconName actionIcon;

  final String actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s4,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.s8),
            decoration: BoxDecoration(
              color: colors.personalTint,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: AppIcon(icon, size: 18, color: colors.personalInk),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: AppText.semibold),
                ),
                Text(
                  sub,
                  style: AppText.caption.copyWith(
                    color: colors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAction,
            tooltip: actionLabel,
            icon: AppIcon(actionIcon, size: 20, color: colors.icon),
          ),
        ],
      ),
    );
  }
}
