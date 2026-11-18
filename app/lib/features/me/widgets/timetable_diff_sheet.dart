// 13 새로 고침의 '바뀐 수업' 시트. docs/screens.md '13 시간표·고정 일정', docs/lms.md '시간표 (통합정보시스템)'.
//
// 새로 고침이 물을 바뀜(학교 쪽 시간·강의실이 바뀐 수업, 학교 시간과 다르게 고친 수업, 학교 시간표에서 없어진 수업)을
// 수업마다 전·후로 보이고, 고른 것만 [반영하기]로 반영한다(되돌리기 한 번. 제안은 재계산이 다시 놓고 확정은 그대로).
// [그대로 두기]는 아무것도 바꾸지 않고, 다음 새로 고침 때 다시 묻는다. 새로 생긴 수업은 코디네이터가 이미 넣었다.
// 문구는 최종 프로토타입을 따른 임시 문구다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/imported_class_slot.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/domain/timetable_refresh.dart';
import 'package:cnu_ai_assistant/features/me/timetable_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 바뀐 수업 시트를 연다. [courseNames]는 `courses.id` → 과목 이름이다. 반영했으면 true다.
Future<bool> showTimetableDiffSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<TimetableChange> changes,
  required Map<int, String> courseNames,
  int added = 0,
  bool partial = false,
}) async =>
    await showAppSheet<bool>(
      context: context,
      motion: ref.read(motionLevelProvider),
      builder: (context) => TimetableDiffSheet(
        changes: changes,
        courseNames: courseNames,
        added: added,
        partial: partial,
      ),
    ) ??
    false;

/// 바뀜 하나의 한 줄 요약.
typedef TimetableChangeText = ({String title, String from, String to});

/// [change]의 제목과 전·후. [course]는 과목 이름이다.
TimetableChangeText timetableChangeText(TimetableChange change, String course) {
  final slot = change.slot;
  String when(int weekday, int start, int end) =>
      '${weekdayText(weekday)} ${timeRangeText(start, end)}';
  final now = when(slot.weekday, slot.startMin, slot.endMin);
  switch (change) {
    case TimetableSlotRemoval():
      return (
        title: '${withJosa('$course 수업', Josa.iGa)} 학교 시간표에서 없어졌어요',
        from: now,
        to: '지움',
      );
    case TimetableSlotUpdate(:final to, :final reasons):
      final ImportedClassSlot next = to;
      final timeMoved =
          next.weekday != slot.weekday ||
          next.startMin != slot.startMin ||
          next.endMin != slot.endMin;
      final placeMoved = next.place != slot.place;
      final title = reasons.contains(TimetableUpdateReason.schoolTime)
          ? '$course 수업 시간이 바뀌었어요'
          : reasons.contains(TimetableUpdateReason.userTime)
          ? '$course 수업을 학교 시간으로 맞출까요?'
          : '${withJosa('$course 강의실', Josa.iGa)} 바뀌었어요';
      String side(int weekday, int start, int end, String? place) => [
        if (timeMoved || !placeMoved) when(weekday, start, end),
        if (placeMoved) place ?? '장소 없음',
      ].join(' · ');
      return (
        title: title,
        from: side(slot.weekday, slot.startMin, slot.endMin, slot.place),
        to: side(next.weekday, next.startMin, next.endMin, next.place),
      );
  }
}

/// 바뀐 수업 시트의 몸통.
class TimetableDiffSheet extends ConsumerStatefulWidget {
  const TimetableDiffSheet({
    super.key,
    required this.changes,
    required this.courseNames,
    this.added = 0,
    this.partial = false,
  });

  final List<TimetableChange> changes;

  final Map<int, String> courseNames;

  /// 바로 넣은 새 수업 칸 수.
  final int added;

  /// 일부 과목을 불러오지 못했는지.
  final bool partial;

  @override
  ConsumerState<TimetableDiffSheet> createState() => _TimetableDiffSheetState();
}

class _TimetableDiffSheetState extends ConsumerState<TimetableDiffSheet> {
  late final List<bool> _picked = [for (final _ in widget.changes) true];
  bool _busy = false;
  bool _failed = false;

  Future<void> _apply() async {
    final chosen = [
      for (var i = 0; i < widget.changes.length; i++)
        if (_picked[i]) widget.changes[i],
    ];
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await ref
        .read(timetableRefreshRepositoryProvider)
        .apply(chosen, now: ref.read(clockProvider).now());
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        ref
            .read(toastControllerProvider.notifier)
            .show(
              value > 0 ? '바뀐 수업 $value개를 반영했어요' : '그사이 바뀐 수업은 건너뛰었어요',
              undoable: value > 0,
            );
        Navigator.of(context).pop(value > 0);
      case Err():
        setState(() {
          _busy = false;
          _failed = true;
        });
    }
  }

  void _keep() {
    ref
        .read(toastControllerProvider.notifier)
        .show('지금 시간표를 그대로 둘게요 · 새로 고침하면 다시 알려 드려요');
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = _picked.where((on) => on).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '통합정보시스템 시간표를 다시 확인했어요',
            style: AppText.caption.copyWith(
              fontWeight: AppText.semibold,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Semantics(
            header: true,
            child: Text(
              '바뀐 수업이 ${widget.changes.length}개 있어요',
              style: AppText.title,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            '반영할 수업을 골라 주세요. 반영하면 시간표를 바꾸고 빈 시간을 다시 계산해요',
            style: AppText.small.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: AppSpace.s12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.listGroup),
              border: Border.all(color: colors.edge),
            ),
            child: Column(
              children: [
                for (var i = 0; i < widget.changes.length; i++) ...[
                  if (i > 0)
                    SizedBox(height: 1, child: ColoredBox(color: colors.edge)),
                  _ChangeRow(
                    text: timetableChangeText(
                      widget.changes[i],
                      widget.courseNames[widget.changes[i].slot.courseId] ??
                          '수업',
                    ),
                    picked: _picked[i],
                    onChanged: _busy
                        ? null
                        : (on) => setState(() => _picked[i] = on),
                  ),
                ],
              ],
            ),
          ),
          if (widget.added > 0) FormNote('새 수업 ${widget.added}칸은 바로 넣었어요'),
          if (widget.partial)
            const FormNote('일부 과목은 불러오지 못했어요', icon: AppIconName.warning),
          const FormNote('반영해도 확정한 할 일은 그대로이고, 제안은 바뀐 빈 시간에 다시 놓아요'),
          if (_failed)
            const FormNote('반영하지 못했어요. 다시 눌러 주세요', icon: AppIconName.warning),
          const SizedBox(height: AppSpace.s20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _keep,
                  child: const Text('그대로 두기'),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy || count == 0 ? null : _apply,
                  child: const Text('반영하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.text,
    required this.picked,
    required this.onChanged,
  });

  final TimetableChangeText text;

  final bool picked;

  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;
    return Semantics(
      checked: picked,
      enabled: onChanged != null,
      label: '${text.title}, ${text.from}에서 ${text.to}',
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged(!picked),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!picked),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s8,
            AppSpace.s16,
            AppSpace.s8,
          ),
          child: Row(
            children: [
              Checkbox(
                value: picked,
                onChanged: onChanged == null
                    ? null
                    : (value) => onChanged(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.title,
                      style: AppText.body.copyWith(
                        fontWeight: AppText.semibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpace.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          text.from,
                          style: AppText.small.copyWith(
                            color: colors.muted,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: colors.faint,
                          ),
                        ),
                        AppIcon(
                          AppIconName.chevronRight,
                          size: 14,
                          color: colors.icon,
                        ),
                        Text(
                          text.to,
                          style: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
