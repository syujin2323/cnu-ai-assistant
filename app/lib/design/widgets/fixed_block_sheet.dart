// 고정 일정 폼과 시트. docs/screens.md '13 시간표·고정 일정'의 고정 일정 시트, '14 온보딩' 3단계의 작은 폼.
//
// [FixedBlockForm]은 칸들이다. 값은 [FixedBlockDraft]로 주고받고, 저장은 부르는 쪽이 한다.
// - [FixedBlockFormMode.full](13 시트): 이름, 종류(식사·알바·운동·통학·기타), 요일, 시간, 앞뒤 여유(0–60분, 5분
//   단위), 준비물.
// - [FixedBlockFormMode.quick](14 온보딩 3단계 '빠르게 더하기'의 작은 폼): 이름, 요일, 시간, 준비물. 종류와 앞뒤
//   여유는 고른 칩의 처음 값(`domain/fixed_block_templates.dart`) 그대로다.
// 수업과 겹치면 알리기만 하고 막지 않는다. 식사 종류는 점심 시간대와 겹치는 날 점심을 대신한다고 알린다. 준비물의
// 알림 안내는 적지 않는다(알림은 재설계 예정). 시작은 05:00–23:45이고, 끝은 다음 날 06:00까지 받아 밤 알바처럼
// 자정을 넘는 일정도 넣는다(임시).
//
// [showFixedBlockSheet]는 13의 시트다. `FixedBlockRepository`로 넣고 고치고 지운 뒤 되돌리기 토스트를 띄우고 닫는다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/time_range_fields.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/timetable_checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 고정 일정 폼이 보이는 칸.
enum FixedBlockFormMode {
  /// 13 시트: 모든 칸.
  full,

  /// 14 온보딩 3단계의 작은 폼: 이름, 요일, 시간, 준비물.
  quick,
}

/// 고정 일정 폼의 범위(임시).
abstract final class FixedBlockFormLimits {
  static const int startLow = 300;
  static const int startHigh = 1425;

  /// 끝의 가장 늦은 값(다음 날 06:00). 시작에서 하루가 넘지 않게 함께 줄인다.
  static const int endHigh = 1800;
  static const int step = 15;
  static const int bufferStep = 5;
  static const int nameLength = 40;
  static const int prepLength = 40;
}

/// [draft]를 저장할 수 있는지(이름, 요일, 시간, 앞뒤 여유).
bool fixedBlockDraftValid(FixedBlockDraft draft) =>
    draft.name.trim().isNotEmpty &&
    checkFixedBlock(
      weekdays: draft.weekdays.toList(),
      startMin: draft.startMin,
      endMin: draft.endMin,
      bufferMin: draft.bufferMin,
    ).isEmpty;

/// 고정 일정 폼의 칸들.
class FixedBlockForm extends ConsumerStatefulWidget {
  const FixedBlockForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.mode = FixedBlockFormMode.full,
    this.enabled = true,
  });

  /// 처음 값. 폼이 처음 그려질 때만 읽는다.
  final FixedBlockDraft initial;

  final ValueChanged<FixedBlockDraft> onChanged;

  final FixedBlockFormMode mode;

  final bool enabled;

  @override
  ConsumerState<FixedBlockForm> createState() => _FixedBlockFormState();
}

class _FixedBlockFormState extends ConsumerState<FixedBlockForm> {
  late FixedBlockDraft _draft = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _prep = TextEditingController(text: widget.initial.prep);

  @override
  void dispose() {
    _name.dispose();
    _prep.dispose();
    super.dispose();
  }

  void _set(FixedBlockDraft next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final full = widget.mode == FixedBlockFormMode.full;
    final enabled = widget.enabled;
    final draft = _draft;
    final entries = ref.watch(classSlotEntriesProvider).value ?? const [];
    final overlapDays = {
      for (final entry in overlappingClasses(
        entries,
        weekdays: draft.weekdays,
        startMin: draft.startMin,
        endMin: draft.endMin,
      ))
        entry.slot.weekday,
    };
    final endHigh =
        draft.startMin + 1440 - FixedBlockFormLimits.step <
            FixedBlockFormLimits.endHigh
        ? draft.startMin + 1440 - FixedBlockFormLimits.step
        : FixedBlockFormLimits.endHigh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormLabel('이름'),
        TextField(
          controller: _name,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            LengthLimitingTextInputFormatter(FixedBlockFormLimits.nameLength),
          ],
          decoration: formInputDecoration(
            context,
            hint: switch (draft.kind) {
              FixedBlockKind.work => '예: 편의점 알바',
              FixedBlockKind.other => '예: 동아리 연습',
              _ => '이름',
            },
          ),
          onChanged: (text) => _set(draft.copyWith(name: text)),
        ),
        if (full) ...[
          const FormLabel('종류'),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final kind in FixedBlockKind.values)
                ChoiceChipButton(
                  label: fixedBlockKindText(kind),
                  icon: fixedBlockKindIcon(kind),
                  selected: draft.kind == kind,
                  onTap: enabled
                      ? () {
                          // 운동을 고르면 비어 있는 준비물에 기본값(운동복)을 넣는다.
                          final prep =
                              kind == FixedBlockKind.exercise &&
                                  draft.prep.trim().isEmpty
                              ? fixedBlockTemplate(kind).prep
                              : null;
                          if (prep != null) _prep.text = prep;
                          _set(draft.copyWith(kind: kind, prep: prep));
                        }
                      : null,
                ),
            ],
          ),
        ],
        FormLabel(
          '요일',
          trailing: draft.weekdays.isEmpty
              ? '요일을 골라 주세요'
              : weekdaysText(draft.weekdays),
          trailingAccent: true,
        ),
        WeekdayPicker(
          selected: draft.weekdays,
          onChanged: enabled
              ? (days) => _set(draft.copyWith(weekdays: days))
              : null,
        ),
        FormLabel('시간', trailing: durationText(draft.endMin - draft.startMin)),
        TimeRangeFields(
          startMin: draft.startMin,
          endMin: draft.endMin,
          startLow: FixedBlockFormLimits.startLow,
          startHigh: FixedBlockFormLimits.startHigh,
          endHigh: endHigh,
          step: FixedBlockFormLimits.step,
          onChanged: enabled
              ? (start, end) =>
                    _set(draft.copyWith(startMin: start, endMin: end))
              : null,
        ),
        if (full) ...[
          const SizedBox(height: AppSpace.s8),
          _BufferRow(
            minutes: draft.bufferMin,
            onChanged: enabled
                ? (minutes) => _set(draft.copyWith(bufferMin: minutes))
                : null,
          ),
          const FormHint('앞뒤 여유는 이동하거나 준비할 시간이에요. 이 시간에도 할 일을 놓지 않아요'),
        ],
        if (overlapDays.isNotEmpty)
          FormNote('${weekdaysText(overlapDays)}요일 수업과 겹쳐요. 막지 않고 알려만 드려요'),
        if (full && draft.kind == FixedBlockKind.meal)
          const FormNote('점심 시간과 겹치는 날은 이 일정이 점심을 대신해요'),
        const FormLabel('준비물'),
        TextField(
          controller: _prep,
          enabled: enabled,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(FixedBlockFormLimits.prepLength),
          ],
          decoration: formInputDecoration(context, hint: '예: 운동복'),
          onChanged: (text) => _set(draft.copyWith(prep: text)),
        ),
      ],
    );
  }
}

/// 고정 일정 종류의 아이콘. 알바·기타는 맞는 캔버스 아이콘이 들어오기 전까지 임시 아이콘이다.
AppIconName fixedBlockKindIcon(FixedBlockKind kind) => switch (kind) {
  FixedBlockKind.meal => AppIconName.meal,
  FixedBlockKind.work => AppIconName.clock,
  FixedBlockKind.exercise => AppIconName.exercise,
  FixedBlockKind.commute => AppIconName.bus,
  FixedBlockKind.other => AppIconName.pencil,
};

class _BufferRow extends StatelessWidget {
  const _BufferRow({required this.minutes, required this.onChanged});

  final int minutes;

  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;
    const step = FixedBlockFormLimits.bufferStep;
    final limits = TimetableLimits.bufferMin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: StepperRow(
        label: '앞뒤 여유',
        value: '$minutes분',
        decLabel: '앞뒤 여유 $step분 줄이기',
        incLabel: '앞뒤 여유 $step분 늘리기',
        onDec: onChanged != null && minutes - step >= limits.low
            ? () => onChanged(minutes - step)
            : null,
        onInc: onChanged != null && minutes + step <= limits.high
            ? () => onChanged(minutes + step)
            : null,
      ),
    );
  }
}

/// 13의 고정 일정 시트를 연다. [block]이 null이면 [template] 종류의 처음 값으로 새로 넣는다. 저장하거나 지웠으면
/// true, 그냥 닫으면 false다.
Future<bool> showFixedBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  FixedBlock? block,
  FixedBlockKind template = FixedBlockKind.other,
}) async =>
    await showAppSheet<bool>(
      context: context,
      motion: ref.read(motionLevelProvider),
      builder: (context) => FixedBlockSheet(block: block, template: template),
    ) ??
    false;

/// 고정 일정 시트의 몸통.
class FixedBlockSheet extends ConsumerStatefulWidget {
  const FixedBlockSheet({
    super.key,
    this.block,
    this.template = FixedBlockKind.other,
  });

  final FixedBlock? block;

  final FixedBlockKind template;

  @override
  ConsumerState<FixedBlockSheet> createState() => _FixedBlockSheetState();
}

class _FixedBlockSheetState extends ConsumerState<FixedBlockSheet> {
  late FixedBlockDraft _draft = switch (widget.block) {
    final block? => FixedBlockDraft.of(block),
    null => fixedBlockTemplate(widget.template),
  };
  bool _busy = false;
  bool _failed = false;

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
    switch (result) {
      case Ok():
        ref.read(toastControllerProvider.notifier).show(toast, undoable: true);
        Navigator.of(context).pop(true);
      case Err():
        setState(() {
          _busy = false;
          _failed = true;
        });
    }
  }

  void _save() {
    final draft = _draft;
    final name = draft.name.trim();
    final prep = draft.prep.trim();
    final repo = ref.read(fixedBlockRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final block = widget.block;
    _run(
      () => block == null
          ? repo.add(
              name: name,
              weekdays: draft.weekdays.toList(),
              startMin: draft.startMin,
              endMin: draft.endMin,
              bufferMin: draft.bufferMin,
              kind: draft.kind,
              prep: prep.isEmpty ? null : prep,
              place: draft.place,
              source: EntrySource.manual,
              now: now,
            )
          : repo.update(
              block.id,
              name: name,
              weekdays: draft.weekdays.toList(),
              startMin: draft.startMin,
              endMin: draft.endMin,
              bufferMin: draft.bufferMin,
              kind: draft.kind,
              prep: prep.isEmpty ? null : prep,
              place: draft.place,
              now: now,
            ),
      '${withJosa(name, Josa.eulReul)} ${block == null ? '넣었어요' : '고쳤어요'}',
    );
  }

  void _delete() {
    final block = widget.block!;
    _run(
      () => ref
          .read(fixedBlockRepositoryProvider)
          .delete(block.id, now: ref.read(clockProvider).now()),
      '${withJosa(block.name, Josa.eulReul)} 지웠어요',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final block = widget.block;
    final canSave = !_busy && fixedBlockDraftValid(_draft);
    final title = _draft.name.trim();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            block == null ? '고정 일정 추가' : '고정 일정 고치기',
            style: AppText.caption.copyWith(
              fontWeight: AppText.semibold,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Semantics(
            header: true,
            child: Text(
              title.isEmpty ? '새 고정 일정' : title,
              style: AppText.title,
            ),
          ),
          FixedBlockForm(
            initial: _draft,
            enabled: !_busy,
            onChanged: (draft) => setState(() => _draft = draft),
          ),
          if (_failed)
            const FormNote('저장하지 못했어요. 다시 눌러 주세요', icon: AppIconName.warning),
          const SizedBox(height: AppSpace.s20),
          if (block == null)
            FilledButton(
              onPressed: canSave ? _save : null,
              child: const Text('고정 일정 넣기'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const AppIcon(AppIconName.trash, size: 18),
                    label: const Text('지우기'),
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
