// LMS 상태 줄과 '다시 로그인' 칩. docs/screens.md 'LMS 상태 줄과 다시 로그인'.
//
// 상태 줄은 아이콘과 문구 한 줄이다(최종 프로토타입: 12pt 글자). 연동됨·데모는 새로 고침 아이콘, 연결 실패는
// 경고 아이콘과 경고색, 다시 로그인 필요는 강조색, 그 밖은 안내 아이콘과 보조 글자색이다. 다시 로그인이 필요하면
// 강조색 칩([LmsReloginChip])으로 그린다. 누르면 하는 일은 화면마다 달라(01 계획은 새로 고침, 03 할 일은
// LMS 정보 시트) 부르는 화면이 정한다. 상태는 `lmsStatusProvider`(`app/providers.dart`)가 준다. 글자를 키우면
// 줄을 바꾼다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:material_ui/material_ui.dart';

/// 상태 줄의 글자·아이콘 색.
Color lmsStatusColor(AppColors colors, LmsStatusKind kind) => switch (kind) {
  LmsStatusKind.connectionFailed => colors.alert,
  LmsStatusKind.reloginNeeded => colors.accent,
  _ => colors.muted,
};

/// 상태 줄의 아이콘.
AppIconName lmsStatusIcon(LmsStatusKind kind) => switch (kind) {
  LmsStatusKind.synced ||
  LmsStatusKind.demo ||
  LmsStatusKind.reloginNeeded => AppIconName.refresh,
  LmsStatusKind.connectionFailed => AppIconName.warning,
  LmsStatusKind.maintenance ||
  LmsStatusKind.paused ||
  LmsStatusKind.beforeLogin => AppIconName.info,
};

/// LMS 상태 줄. [onTap]이 있으면 누를 수 있고, 읽기 도구는 문구 뒤에 [tapHint]를 읽는다.
class LmsStatusLine extends StatelessWidget {
  const LmsStatusLine({
    super.key,
    required this.status,
    this.onTap,
    this.tapHint,
    this.busy = false,
  });

  final LmsStatus status;

  /// 눌렀을 때. null이면 누를 수 없다.
  final VoidCallback? onTap;

  /// 누르면 하는 일(예: '눌러서 새로 고침', '자세히 보기'). 읽기 도구가 문구 뒤에 읽는다.
  final String? tapHint;

  /// 새로 고치는 중이면 '{busyText}'를 보이고 누를 수 없다.
  final bool busy;

  /// 새로 고치는 동안의 문구.
  static const String busyText = 'LMS 정보 불러오는 중';

  static const double _icon = 14;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = lmsStatusColor(colors, status.kind);
    final text = busy ? busyText : status.text;
    final tap = busy ? null : onTap;
    final hint = tapHint;
    final line = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSize.minTouch),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(lmsStatusIcon(status.kind), size: _icon, color: color),
          const SizedBox(width: AppSpace.s8),
          Flexible(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                fontWeight: AppText.medium,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      button: tap != null,
      label: tap == null || hint == null ? text : '$text, $hint',
      onTap: tap,
      excludeSemantics: true,
      child: tap == null
          ? line
          : InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: line,
            ),
    );
  }
}

/// '다시 로그인' 칩. 다시 로그인이 필요할 때 상태 줄 대신 그리고, 누르면 다시 로그인 화면을 연다([onTap]).
class LmsReloginChip extends StatelessWidget {
  const LmsReloginChip({super.key, required this.status, required this.onTap});

  final LmsStatus status;
  final VoidCallback onTap;

  static const double _icon = 15;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      container: true,
      button: true,
      label: status.text,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.edge),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    AppIconName.refresh,
                    size: _icon,
                    color: colors.accent,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Flexible(
                    child: Text(
                      status.text,
                      style: AppText.small.copyWith(
                        fontWeight: AppText.semibold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
