// 온보딩 2단계: 불러온 시간표 확인. docs/screens.md '14 온보딩'의 '2단계 · 불러온 시간표 확인'.
//
// 1단계에서 로그인할 때 통합정보시스템에서 불러온 이번 학기 시간표를 격자(`design/widgets/timetable_grid.dart`)로
// 보이고 '통합정보시스템에서 불러옴'을 적는다. 수업을 누르면 수업 시트(`design/widgets/class_slot_sheet.dart`의
// [ClassSheetMode.placeOnly])로 실시간 온라인과 장소만 고치고, '맞아요'로 넘어간다. 건너뛰기와 뒤로 가기는 없다
// (시스템 뒤로 가기도 받지 않음). 로그아웃 뒤 로그인했으면 이 단계를 거치지 않는다.
//
// 불러오기에 실패했거나 불러온 수업이 0개여도 이 단계로 온다(docs/decisions.md 2026-11-15 '시간표는 처음 로그인
// 뒤 과목마다 물어 불러온다'). 그때는 빈 격자 위에 13 시간표·고정 일정에서 새로 고치거나 직접 넣는다고 알린다.
// 문구는 최종 프로토타입의 문구다(임시).

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/class_slot_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/timetable_grid.dart';
import 'package:cnu_ai_assistant/domain/class_groups.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/models/class_slot_entry.dart';
import 'package:cnu_ai_assistant/features/onboarding/onboarding_controller.dart';
import 'package:cnu_ai_assistant/features/onboarding/widgets/onboarding_step_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 2단계.
class TimetableStep extends ConsumerWidget {
  const TimetableStep({super.key, required this.onConfirm});

  /// '맞아요': 다음 단계로 간다.
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final entries = ref.watch(classSlotEntriesProvider).value ?? const [];
    final boundary =
        ref.watch(settingsProvider.select((s) => s.value?.dayBoundaryMin)) ??
        Defaults.dayBoundaryMin;
    final today = logicalDate(
      ref.watch(minuteClockProvider),
      dayBoundaryMin: boundary,
    ).weekday;
    final groups = groupClassSlots(entries);
    final courses = {for (final e in entries) e.slot.courseId}.length;
    final empty = entries.isEmpty;

    void open(ClassSlotEntry entry) {
      final group = groups.firstWhere((g) => g.slotIds.contains(entry.slot.id));
      showClassSlotSheet(
        context,
        ref,
        group: group,
        mode: ClassSheetMode.placeOnly,
      );
    }

    return OnboardingStepLayout(
      actions: [FilledButton(onPressed: onConfirm, child: const Text('맞아요'))],
      content: [
        OnboardingKicker(
          icon: AppIconName.calendar,
          text: OnboardingStep.timetable.title,
        ),
        const SizedBox(height: AppSpace.s8),
        Semantics(
          header: true,
          child: Text(
            empty ? '불러온 수업이 없어요' : '이번 학기 시간표를 불러왔어요',
            style: AppText.heading,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          empty
              ? '시간표 화면에서 새로 고치거나 수업을 직접 넣을 수 있어요. 시간표가 생기기 전에는 빈 시간을 짐작하지 않아요.'
              : '학기 중에는 바뀌지 않아서 처음 한 번만 불러와요. 수강 정정이 있으면 시간표 화면에서 새로 고침을 눌러 주세요.',
          style: AppText.body.copyWith(color: colors.ink2),
        ),
        const SizedBox(height: AppSpace.s16),
        if (!empty)
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '수업 $courses개 · 주 ${entries.length}회',
                style: AppText.small.copyWith(
                  fontWeight: AppText.semibold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '통합정보시스템에서 불러옴',
                style: AppText.caption.copyWith(color: colors.muted),
              ),
            ],
          ),
        const SizedBox(height: AppSpace.s12),
        TimetableGrid(
          entries: entries,
          today: today,
          showTime: true,
          onTap: open,
          empty: _EmptyCard(),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
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
        children: [
          Text(
            '아직 수업이 없어요',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(fontWeight: AppText.semibold),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            '‘나’ 탭 › 시간표·고정 일정에서 넣을 수 있어요',
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
