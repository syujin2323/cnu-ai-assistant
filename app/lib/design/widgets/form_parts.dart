// 시트 안 폼의 작은 조각. docs/screens.md '13 시간표·고정 일정'의 수업·고정 일정 시트, '14 온보딩' 3단계의 작은
// 폼이 함께 쓴다. 모양은 최종 프로토타입의 칸 이름·도움말·알림 상자·입력 칸·칩이다(임시값).

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 칸 이름 줄. 오른쪽에 짧은 값([trailing], 요일 요약 등)을 둔다.
class FormLabel extends StatelessWidget {
  const FormLabel(
    this.label, {
    super.key,
    this.trailing,
    this.trailingAccent = false,
  });

  final String label;

  final String? trailing;

  /// [trailing]을 포인트 색으로 쓸지(고른 값). false면 보조 글자색이다.
  final bool trailingAccent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s20,
        AppSpace.s4,
        AppSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.small.copyWith(
                fontWeight: AppText.semibold,
                color: colors.ink2,
              ),
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing,
                textAlign: TextAlign.end,
                style: AppText.small.copyWith(
                  fontWeight: trailingAccent ? AppText.semibold : null,
                  color: trailingAccent ? colors.accent : colors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 칸 아래 도움말 한 줄.
class FormHint extends StatelessWidget {
  const FormHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s8,
      AppSpace.s4,
      0,
    ),
    child: Text(
      text,
      style: AppText.caption.copyWith(color: AppColors.of(context).muted),
    ),
  );
}

/// 알리기만 하는 상자(겹침 등).
class FormNote extends StatelessWidget {
  const FormNote(this.text, {super.key, this.icon = AppIconName.info});

  final String text;

  final AppIconName icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(AppRadius.notice),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 16, color: colors.accent),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              text,
              style: AppText.small.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// 입력 칸 모양(옅은 바탕, 테두리, 모서리 14).
InputDecoration formInputDecoration(BuildContext context, {String? hint}) {
  final colors = AppColors.of(context);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.body.copyWith(color: colors.icon),
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpace.s16,
      vertical: AppSpace.s16,
    ),
    border: border(colors.edge),
    enabledBorder: border(colors.edge),
    focusedBorder: border(colors.accent, 1.5),
  );
}

/// 고르는 칩. 고르면 진한 바탕이다.
class ChoiceChipButton extends StatelessWidget {
  const ChoiceChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;

  final bool selected;

  final VoidCallback? onTap;

  final AppIconName? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = selected ? colors.onStrong : colors.accent;
    final icon = this.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Press(
        enabled: onTap != null,
        child: Material(
          color: selected ? colors.strong : colors.surface,
          shape: StadiumBorder(
            side: selected ? BorderSide.none : BorderSide(color: colors.edge),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.minTouch,
                minWidth: AppSize.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      AppIcon(icon, size: 16, color: ink),
                      const SizedBox(width: AppSpace.s4),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppText.small.copyWith(
                          fontWeight: AppText.semibold,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 켜고 끄는 줄(제목, 한 줄 설명, 스위치). 줄 어디를 눌러도 바꾼다.
class FormSwitchRow extends StatelessWidget {
  const FormSwitchRow({
    super.key,
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;

  final String? sub;

  final bool value;

  /// null이면 바꿀 수 없다.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onChanged = this.onChanged;
    final sub = this.sub;
    final toggle = onChanged == null ? null : () => onChanged(!value);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: [label, ?sub].join(', '),
      excludeSemantics: true,
      onTap: toggle,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.listGroup),
          side: BorderSide(color: colors.edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s12,
              AppSpace.s12,
              AppSpace.s12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppText.body),
                      if (sub != null)
                        Text(
                          sub,
                          style: AppText.caption.copyWith(color: colors.muted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
