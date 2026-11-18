// 10 나의 묶음과 줄. docs/screens.md '10 나'.
//
// 모양은 최종 프로토타입의 설정 묶음을 따른다: 묶음 제목(작은 흐린 글자) 아래 테두리 있는 목록, 줄마다 왼쪽
// 아이콘 칸(32pt, 틴트 바탕), 제목과 한 줄 설명, 오른쪽 값과 화살표(스위치 줄은 스위치). 위험한 동작(데이터
// 삭제·로그아웃)은 경고 색이다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 제목과 줄 목록.
class MeGroup extends StatelessWidget {
  const MeGroup({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// 목록 아래 한 줄(안내).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: AppSpace.s8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppText.small.copyWith(
                  fontWeight: AppText.semibold,
                  color: colors.muted,
                ),
              ),
            ),
          ),
          // 줄의 눌림 효과(InkWell)는 가장 가까운 Material에 그려지므로, 색 있는 상자 대신 Material로 감싼다.
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.listGroup),
              side: BorderSide(color: colors.edge),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: colors.edge),
                      ),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer case final widget?)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, AppSpace.s8, 6, 0),
              child: widget,
            ),
        ],
      ),
    );
  }
}

/// 설정 줄 하나.
class MeRow extends StatelessWidget {
  const MeRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    this.subColor,
    this.value,
    this.onTap,
    this.alert = false,
    this.accent = false,
    this.chevron = true,
    this.semanticsLabel,
  });

  final AppIconName icon;
  final String label;

  /// 제목 아래 한 줄.
  final String? sub;
  final Color? subColor;

  /// 오른쪽 값.
  final String? value;

  /// 누를 때. null이면 누를 수 없다(값만 보이는 줄).
  final VoidCallback? onTap;

  /// 위험한 동작(경고 색).
  final bool alert;

  /// 제목을 강조 색으로(다시 로그인 등).
  final bool accent;

  /// 누를 수 있을 때 오른쪽 화살표를 둘지.
  final bool chevron;

  /// 읽기 도구 문구. 없으면 제목·설명·값을 잇는다.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final row = _RowLayout(
      icon: icon,
      label: label,
      sub: sub,
      subColor: subColor,
      alert: alert,
      accent: accent,
      trailing: (maxWidth) => [
        if (value case final text?) ...[
          const SizedBox(width: AppSpace.s8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.46),
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: AppText.small.copyWith(color: colors.muted),
            ),
          ),
        ],
        if (onTap != null && chevron) ...[
          const SizedBox(width: AppSpace.s4),
          AppIcon(AppIconName.chevronRight, size: 16, color: colors.icon),
        ],
      ],
    );
    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? [label, ?sub, ?value].join(', '),
      excludeSemantics: true,
      child: Press(
        enabled: onTap != null,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// 스위치 줄 하나. 줄 어디를 눌러도 켜고 끈다.
class MeSwitchRow extends StatelessWidget {
  const MeSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
  });

  final AppIconName icon;
  final String label;

  /// 제목 아래 한 줄.
  final String? sub;

  /// 켜져 있는지.
  final bool value;

  /// 바꿀 때 바꿀 값을 받는다. null이면 바꿀 수 없다.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final toggle = onChanged == null ? null : () => onChanged(!value);
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      label: [label, ?sub].join(', '),
      excludeSemantics: true,
      onTap: toggle,
      child: InkWell(
        onTap: toggle,
        child: _RowLayout(
          icon: icon,
          label: label,
          sub: sub,
          trailing: (_) => [
            const SizedBox(width: AppSpace.s8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 줄의 모양: 왼쪽 아이콘 칸, 제목과 한 줄 설명, 오른쪽 [trailing](줄 너비를 받음).
class _RowLayout extends StatelessWidget {
  const _RowLayout({
    required this.icon,
    required this.label,
    required this.trailing,
    this.sub,
    this.subColor,
    this.alert = false,
    this.accent = false,
  });

  final AppIconName icon;
  final String label;
  final String? sub;
  final Color? subColor;
  final bool alert;
  final bool accent;
  final List<Widget> Function(double maxWidth) trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labelColor = alert
        ? colors.alert
        : accent
        ? colors.accent
        : colors.ink;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: alert ? colors.alertSoft : colors.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppIcon(
                  icon,
                  size: 18,
                  color: alert ? colors.alert : colors.accent,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppText.body.copyWith(
                        fontWeight: accent ? AppText.semibold : AppText.medium,
                        height: 1.4,
                        color: labelColor,
                      ),
                    ),
                    if (sub case final text?) ...[
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: AppText.caption.copyWith(
                          color: subColor ?? colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...trailing(constraints.maxWidth),
            ],
          ),
        ),
      ),
    );
  }
}

/// 가운데 글자만 있는 줄(로그아웃).
class MeCenterRow extends StatelessWidget {
  const MeCenterRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Press(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  fontWeight: AppText.semibold,
                  color: colors.alert,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
