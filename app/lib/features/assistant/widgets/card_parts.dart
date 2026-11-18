// 06 AI 비서 카드의 공용 부품. 모양은 최종 프로토타입의 06(카드 24 모서리·surface 배경·edge 테두리, 머리말 줄,
// 줄마다 위 테두리가 있는 값 줄, 안내 상자, 저장한 뒤의 줄)을 따른다. docs/screens.md '06 AI 비서'.

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 카드 틀: 머리말 줄(아이콘·머리말·오른쪽 꼬리표)과 내용. 처음 그릴 때 떠오른다.
class AssistantCardFrame extends StatelessWidget {
  const AssistantCardFrame({
    super.key,
    required this.icon,
    required this.kicker,
    this.tag,
    this.alert = false,
    required this.children,
  });

  final AppIconName icon;
  final String kicker;

  /// 머리말 줄 오른쪽 꼬리표('개인 일정'·'고정 일정'·과목 이름).
  final String? tag;

  /// 경고 카드(AI 응답 없음 등)면 머리말을 경고 색으로 쓴다.
  final bool alert;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final kickerColor = alert ? colors.alert : colors.accent;
    return Rise(
      child: Semantics(
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.card),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.edge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(icon, size: 15, color: kickerColor),
                  const SizedBox(width: AppSpace.s4 + 2),
                  Expanded(
                    child: Text(
                      kicker,
                      style: AppText.caption.copyWith(
                        color: kickerColor,
                        fontWeight: AppText.semibold,
                      ),
                    ),
                  ),
                  if (tag case final tag?)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.tint,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(color: colors.ink2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 제목.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s4),
    child: Semantics(header: true, child: Text(text, style: AppText.title)),
  );
}

/// 값 줄(위 테두리, 왼쪽 이름·오른쪽 값). [value] 대신 [child]를 주면 이름 아래에 그린다(칩 줄 등).
class CardDetailRow extends StatelessWidget {
  const CardDetailRow({
    super.key,
    required this.label,
    this.value,
    this.valueColor,
    this.child,
  }) : assert((value == null) != (child == null), '값이나 내용 하나만 준다');

  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labelText = Text(
      label,
      style: AppText.small.copyWith(color: colors.muted),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.edge)),
      ),
      child: switch (child) {
        final child? => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelText,
            const SizedBox(height: AppSpace.s8),
            child,
          ],
        ),
        null => Row(
          children: [
            SizedBox(width: 64, child: labelText),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                style: AppText.body.copyWith(
                  color: valueColor ?? colors.ink,
                  fontWeight: AppText.medium,
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

/// 안내 상자(옅은 바탕, 아이콘과 한두 줄). [alert]면 경고 색이다.
class CardNote extends StatelessWidget {
  const CardNote({
    super.key,
    required this.icon,
    required this.text,
    this.sub,
    this.alert = false,
  });

  final AppIconName icon;
  final String text;
  final String? sub;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = alert ? colors.alert : colors.ink2;
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12 + 2,
        vertical: AppSpace.s12,
      ),
      decoration: BoxDecoration(
        color: alert ? colors.alertSoft : colors.tint,
        borderRadius: BorderRadius.circular(AppRadius.notice),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 17, color: color),
          const SizedBox(width: AppSpace.s8 + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppText.small.copyWith(
                    color: color,
                    fontWeight: AppText.semibold,
                  ),
                ),
                if (sub case final sub?)
                  Text(sub, style: AppText.caption.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 확인 표시와 한 줄('겹치는 일정이 없어요').
class CardOkLine extends StatelessWidget {
  const CardOkLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: Row(
        children: [
          AppIcon(AppIconName.check, size: 15, color: colors.accent),
          const SizedBox(width: AppSpace.s4 + 2),
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

/// 저장한 뒤의 줄(옅은 바탕, 확인 표시). 아래에 [note](다시 계산한 제안)를 붙인다.
class CardDone extends StatelessWidget {
  const CardDone({super.key, required this.text, this.note});

  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: AppSpace.s12 + 2),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12 + 2,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            color: colors.tint,
            borderRadius: BorderRadius.circular(AppRadius.notice),
          ),
          child: Row(
            children: [
              AppIcon(AppIconName.check, size: 16, color: colors.accent),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  text,
                  style: AppText.small.copyWith(
                    color: colors.accent,
                    fontWeight: AppText.semibold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (note case final note?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s8),
            child: Text(
              note,
              style: AppText.small.copyWith(color: colors.ink2),
            ),
          ),
      ],
    );
  }
}

/// 카드 아래 버튼 줄. 첫 버튼(주 버튼)이 남은 폭을 채운다.
class CardActions extends StatelessWidget {
  const CardActions({super.key, required this.primary, this.secondary});

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s12 + 2),
    child: Row(
      children: [
        Expanded(child: primary),
        if (secondary case final secondary?) ...[
          const SizedBox(width: AppSpace.s8),
          secondary,
        ],
      ],
    ),
  );
}

/// 카드 위의 한 줄(비서의 말).
class SayLine extends StatelessWidget {
  const SayLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Rise(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s8,
      ),
      child: Text(text, style: AppText.body),
    ),
  );
}

/// 사용자가 보낸 문장(오른쪽 말풍선).
class UserBubble extends StatelessWidget {
  const UserBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Rise(
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.84,
          alignment: Alignment.centerRight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8 + 3,
              ),
              decoration: BoxDecoration(
                color: colors.tint,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Text(
                text,
                style: AppText.body.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 답을 기다리는 중('문장을 읽고 있어요').
class WaitingBubble extends StatelessWidget {
  const WaitingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Rise(
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              AppIcon(AppIconName.assistant, size: 15, color: colors.accent),
              const SizedBox(width: AppSpace.s4 + 2),
              Text(
                '문장을 읽고 있어요',
                style: AppText.small.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
