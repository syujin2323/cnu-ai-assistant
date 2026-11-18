// 10 나의 시트: 로그아웃(지우는 것과 두는 것)과 데이터 삭제(되돌릴 수 없음)의 확인, 하루 경계와 아침 브리핑 시각
// 고르기. docs/screens.md '10 나', docs/lms.md '로그아웃, 데이터 삭제'. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 로그아웃 시트를 연다. [로그아웃]을 누르면 true, 닫거나 [취소]면 false다.
Future<bool> showLogoutSheet(BuildContext context, MotionLevel motion) async =>
    await showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _ConfirmSheet(
        title: '로그아웃할까요?',
        groups: [
          (
            '이 폰에서 지우는 것',
            [
              '학번·비밀번호와 LMS 로그인 정보',
              '불러온 시간표(휴강·시험 같은 수업 변경 포함)',
              'LMS 할 일과 거기에 놓은 블록',
            ],
          ),
          ('그대로 두는 것', ['직접 넣은 일정·고정 일정·수업·할 일', '내 규칙', 'LMS 과목과 바뀜·동기화 기록']),
        ],
        note: '다시 로그인하면 시간표와 할 일을 새로 불러와요',
        confirm: '로그아웃',
      ),
    ) ??
    false;

/// 데이터 삭제 시트를 연다. [모두 지우기]를 누르면 true, 닫거나 [취소]면 false다.
Future<bool> showDeleteDataSheet(
  BuildContext context,
  MotionLevel motion,
) async =>
    await showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _ConfirmSheet(
        title: '이 폰의 데이터를 모두 지울까요?',
        warning: '지운 데이터는 되돌릴 수 없어요',
        groups: [
          (
            '지우는 것',
            [
              '시간표·고정 일정·일정·할 일·내 규칙과 기록',
              '학번·비밀번호와 LMS 로그인 정보',
              '앱 설정(온보딩부터 다시 시작해요)',
            ],
          ),
        ],
        confirm: '모두 지우기',
      ),
    ) ??
    false;

/// 하루 경계 시트를 연다. 고르면 그 값(자정 기준 분, [Defaults.dayBoundaryChoices] 가운데 하나), 닫으면 null이다.
/// [current]는 지금 값이다.
Future<int?> showDayBoundarySheet(
  BuildContext context,
  MotionLevel motion, {
  required int current,
}) => showAppSheet<int>(
  context: context,
  motion: motion,
  builder: (context) => _DayBoundarySheet(current: current),
);

/// 아침 브리핑 시각 시트를 연다. [확인]을 누르면 고른 시각(자정 기준 분, [RuleLimits.briefingChoices] 가운데
/// 하나), 닫으면 null이다. 칩은 14 온보딩 5단계와 같다. [current]는 지금 값이다.
Future<int?> showBriefingTimeSheet(
  BuildContext context,
  MotionLevel motion, {
  required int current,
}) => showAppSheet<int>(
  context: context,
  motion: motion,
  builder: (context) => _BriefingTimeSheet(current: current),
);

/// 시트의 제목과 한 줄 설명.
class _SheetHead extends StatelessWidget {
  const _SheetHead({required this.title, required this.sub});

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.title)),
        const SizedBox(height: AppSpace.s4),
        Text(
          sub,
          style: AppText.small.copyWith(color: AppColors.of(context).muted),
        ),
      ],
    );
  }
}

class _DayBoundarySheet extends StatelessWidget {
  const _DayBoundarySheet({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          const _SheetHead(
            title: '하루를 몇 시에 나눌까요?',
            sub: '이 시각 전까지는 전날로 봐요. 새벽까지 이어지는 일정이 그날 일로 남아요',
          ),
          const SizedBox(height: AppSpace.s16),
          // 줄 어디를 눌러도 그 값으로 닫는다(지금 값을 눌러도 닫힘). 라디오는 모양이고, 키보드로 고를 때만 받는다.
          RadioGroup<int>(
            groupValue: current,
            onChanged: (minute) => Navigator.of(context).pop(minute),
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.listGroup),
                side: BorderSide(color: colors.edge),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final minute in Defaults.dayBoundaryChoices)
                    _ChoiceRow(
                      label: minute == Defaults.dayBoundaryMin
                          ? '${hhmmText(minute)} · 기본'
                          : hhmmText(minute),
                      value: minute,
                      selected: minute == current,
                      onTap: () => Navigator.of(context).pop(minute),
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

/// 고르는 줄 하나: 글자와 오른쪽 라디오.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.body)),
                IgnorePointer(child: Radio<int>(value: value)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BriefingTimeSheet extends StatefulWidget {
  const _BriefingTimeSheet({required this.current});

  final int current;

  @override
  State<_BriefingTimeSheet> createState() => _BriefingTimeSheetState();
}

class _BriefingTimeSheetState extends State<_BriefingTimeSheet> {
  late int _selected = widget.current;

  @override
  Widget build(BuildContext context) {
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
          const _SheetHead(
            title: '아침 브리핑을 몇 시에 받을까요?',
            sub: "고른 시각은 '내 규칙'에 저장해요",
          ),
          const SizedBox(height: AppSpace.s16),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final minute in RuleLimits.briefingChoices)
                ChoiceChip(
                  label: Text(shortClockText(minute)),
                  selected: minute == _selected,
                  onSelected: (_) => setState(() => _selected = minute),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

/// 확인 시트의 몸통.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.groups,
    required this.confirm,
    this.warning,
    this.note,
  });

  final String title;

  /// 제목과 항목 목록들.
  final List<(String, List<String>)> groups;

  final String confirm;

  /// 제목 아래 경고(붉게).
  final String? warning;

  /// 목록 아래 안내.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          Semantics(header: true, child: Text(title, style: AppText.title)),
          if (warning case final text?) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              text,
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.alert,
              ),
            ),
          ],
          for (final (heading, items) in groups) ...[
            const SizedBox(height: AppSpace.s16),
            Text(
              heading,
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '·  ',
                      style: AppText.body.copyWith(color: colors.muted),
                    ),
                    Expanded(child: Text(item, style: AppText.body)),
                  ],
                ),
              ),
          ],
          if (note case final text?) ...[
            const SizedBox(height: AppSpace.s16),
            Text(text, style: AppText.small.copyWith(color: colors.muted)),
          ],
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.alert,
              foregroundColor: colors.onStrong,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(confirm),
          ),
          const SizedBox(height: AppSpace.s8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSize.minTouch),
            ),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
