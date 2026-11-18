// 20 시스템의 점검·오프라인 띠. docs/screens.md '20 시스템'.
//
// 01 계획·02 홈·03 할 일 맨 위에 둔다(docs/decisions.md 2026-11-19 '점검·오프라인 안내는 01·02·03 맨 위의 띠이고
// 연결 없음·주소 해석 실패를 오프라인으로 본다'). 내용은 `domain/lms_status.dart`의 [lmsBand]가 정하고, 이 위젯은
// 그리기만 한다. [다시 확인]은 지금 다시 받고([LmsSystemBand.onRetry]), 오프라인이면 [직접 입력하기]로 직접 추가
// 폼을 연다([LmsSystemBand.onDirectAdd]). 모양은 최종 프로토타입의 '20 시스템 · 사캠 점검 중' 띠다.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:material_ui/material_ui.dart';

/// 점검·연결 실패·오프라인 띠.
class LmsSystemBand extends StatelessWidget {
  const LmsSystemBand({
    super.key,
    required this.band,
    this.busy = false,
    this.onRetry,
    this.onDirectAdd,
  });

  final LmsBand band;

  /// 지금 LMS 정보를 받는 중인지. 그동안 [다시 확인]을 막는다.
  final bool busy;

  /// [다시 확인]. 없으면 버튼을 두지 않는다.
  final VoidCallback? onRetry;

  /// [직접 입력하기]. [LmsBand.directAdd]일 때만 둔다.
  final VoidCallback? onDirectAdd;

  /// 받는 중의 [다시 확인] 글자.
  static const busyText = '확인하는 중';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alert = band.kind == LmsStatusKind.connectionFailed;
    final icon = switch (band.kind) {
      LmsStatusKind.offline => AppIconName.offline,
      LmsStatusKind.connectionFailed => AppIconName.warning,
      _ => AppIconName.info,
    };
    final retry = onRetry;
    final directAdd = band.directAdd ? onDirectAdd : null;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpace.s16, 14, AppSpace.s16, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.listGroup),
          border: Border.all(color: colors.edge),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alert ? colors.alertSoft : colors.tint,
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
                children: [
                  Text(
                    band.title,
                    style: AppText.body.copyWith(fontWeight: AppText.semibold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    band.sub,
                    style: AppText.small.copyWith(
                      color: colors.ink2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (directAdd != null || retry != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        if (directAdd != null)
                          _BandAction(
                            label: '직접 입력하기',
                            icon: AppIconName.pencil,
                            onTap: directAdd,
                          ),
                        if (retry != null)
                          _BandAction(
                            label: busy ? busyText : '다시 확인',
                            icon: AppIconName.refresh,
                            onTap: busy ? null : retry,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 띠 안의 알약 버튼(프로토타입의 `.chip.chip-tap`).
class _BandAction extends StatelessWidget {
  const _BandAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final AppIconName icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = onTap == null ? colors.muted : colors.accent;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Press(
        enabled: onTap != null,
        child: Material(
          color: colors.surface,
          shape: StadiumBorder(side: BorderSide(color: colors.edge)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSize.minTouch,
                minWidth: AppSize.minTouch,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(icon, size: 15, color: ink),
                    const SizedBox(width: 6),
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
