// 요일 고르기. docs/screens.md '13 시간표·고정 일정'의 수업·고정 일정 시트, '14 온보딩' 3단계의 작은 폼,
// '직접 추가 폼'의 반복 일정이 함께 쓴다. 월–일 일곱 개의 둥근 단추이고 여러 개를 고른다. 좁은 화면이나 큰
// 글자에서는 다음 줄로 넘긴다(누르는 칸은 늘 48pt 이상).

import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 요일 고르기. [selected]는 고른 요일(1(월)–7(일))이다.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<int> selected;

  /// 누르면 바뀐 요일 집합을 받는다. null이면 바꿀 수 없다.
  final ValueChanged<Set<int>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Semantics(
      container: true,
      label: '요일 고르기',
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpace.s4,
        runSpacing: AppSpace.s8,
        children: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            _DayButton(
              label: weekdayText(day),
              selected: selected.contains(day),
              onTap: onChanged == null
                  ? null
                  : () {
                      final next = {...selected};
                      if (!next.remove(day)) next.add(day);
                      onChanged(next);
                    },
            ),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      toggled: selected,
      label: '$label요일',
      excludeSemantics: true,
      onTap: onTap,
      child: Press(
        enabled: onTap != null,
        child: Material(
          color: selected ? colors.strong : colors.surface,
          shape: CircleBorder(
            side: selected ? BorderSide.none : BorderSide(color: colors.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSize.minTouch,
                minHeight: AppSize.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    style: AppText.body.copyWith(
                      fontWeight: AppText.semibold,
                      color: selected ? colors.onStrong : colors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
