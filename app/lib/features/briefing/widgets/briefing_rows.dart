// 01 계획의 '어제 못 한 일'과 '오늘 할 일' 줄. docs/screens.md '01 계획'.
//
// 모양은 최종 프로토타입의 목록 묶음을 따른다: 왼쪽 네모 체크, 제목과 '{종류} · {마감} · {길이}' 한 줄, 오른쪽에
// 시각과 꼬리표('추천'·'확정'·잠긴 줄의 상태). 체크는 pop으로 바뀐다. 잠긴 줄은 체크가 흐리고 누를 수 없다(근거
// 시트는 W5 PR에서 붙임).

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/pop.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 목록 묶음: 테두리 있는 카드 안에 줄을 겹치지 않게 쌓고, 줄 사이에 왼쪽을 띄운 가는 줄을 긋는다.
class BriefingList extends StatelessWidget {
  const BriefingList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.s16),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.edge),
                ),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 네모 체크. 켜지면 strong 바탕에 체크.
class BriefingCheck extends StatelessWidget {
  const BriefingCheck({super.key, required this.on, this.faded = false});

  final bool on;

  /// 잠긴 줄·체크할 수 없는 줄(흐리게).
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final box = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: on ? colors.strong : colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: on ? null : Border.all(color: colors.faint, width: 1.6),
      ),
      alignment: Alignment.center,
      child: on
          ? AppIcon(AppIconName.check, size: 14, color: colors.onStrong)
          : null,
    );
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: on ? Pop(key: const ValueKey('on'), child: box) : box,
    );
  }
}

/// 오늘 할 일 한 줄.
class BriefingTaskRow extends StatelessWidget {
  const BriefingTaskRow({
    super.key,
    required this.title,
    required this.meta,
    required this.due,
    required this.dueSoon,
    required this.on,
    required this.locked,
    required this.semanticsLabel,
    this.tail = '',
    this.time,
    this.timeMuted = false,
    this.tag,
    this.tagColor,
    this.onTap,
  });

  final String title;

  /// '{종류} · '.
  final String meta;

  /// 마감 문구. [dueSoon]이면 붉고 굵게.
  final String due;
  final bool dueSoon;

  /// 마감 뒤에 붙는 ' · {길이}'.
  final String tail;

  /// 체크됐는지(잠긴 줄은 늘 켜짐).
  final bool on;
  final bool locked;

  /// 오른쪽 시각('HH:MM–HH:MM'). 체크한 것·잠긴 줄은 진하게, 추천은 흐리게([timeMuted]).
  final String? time;
  final bool timeMuted;

  /// 오른쪽 아래 꼬리표('추천'·'확정'·잠긴 줄의 상태)와 그 색.
  final String? tag;
  final Color? tagColor;

  /// 누를 때. 잠긴 줄은 null이다.
  final VoidCallback? onTap;

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              BriefingCheck(on: on, faded: locked),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        fontWeight: AppText.semibold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        text: meta,
                        children: [
                          TextSpan(
                            text: due,
                            style: dueSoon
                                ? TextStyle(
                                    color: colors.alert,
                                    fontWeight: AppText.semibold,
                                  )
                                : null,
                          ),
                          TextSpan(text: tail),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (time != null || tag != null) ...[
                const SizedBox(width: AppSpace.s8),
                // 오른쪽은 필요한 만큼만 쓰되 줄의 40%를 넘지 않는다(글자를 키우면 줄임표).
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (time case final value?)
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.copyWith(
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: timeMuted
                                ? AppText.medium
                                : AppText.semibold,
                            color: timeMuted ? colors.muted : colors.ink2,
                          ),
                        ),
                      if (tag case final value?)
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(
                            fontWeight: AppText.semibold,
                            height: 16 / 12,
                            color: tagColor ?? colors.accent,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      toggled: locked ? null : on,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Press(
        enabled: onTap != null,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// 어제 못 한 일 한 줄: 왼쪽은 체크(오늘 일정에 넣기), 오른쪽은 [했어요].
class BriefingMissedRow extends StatelessWidget {
  const BriefingMissedRow({
    super.key,
    required this.title,
    required this.when,
    required this.whenPlaced,
    required this.due,
    required this.dueSoon,
    required this.on,
    required this.onToggle,
    required this.onDone,
    required this.toggleLabel,
    required this.doneLabel,
    this.canPlace = true,
  });

  final String title;

  /// '어제 HH:MM–HH:MM' 또는 체크하면 '오늘 HH:MM–HH:MM'.
  final String when;

  /// 오늘에 넣었는지(진하게).
  final bool whenPlaced;

  final String due;
  final bool dueSoon;
  final bool on;
  final VoidCallback onToggle;
  final VoidCallback onDone;

  /// 오늘에 넣을 수 있는지. 마감이 지났으면 false이고 체크가 흐리며 누를 수 없다([했어요]만 됨).
  final bool canPlace;

  /// 체크 쪽과 [했어요]의 읽기 도구 문구.
  final String toggleLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final metaStyle = AppText.caption.copyWith(color: colors.muted);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: canPlace,
              toggled: canPlace ? on : null,
              label: toggleLabel,
              excludeSemantics: true,
              child: Press(
                enabled: canPlace,
                child: InkWell(
                  onTap: canPlace ? onToggle : null,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: canPlace ? 1 : 0.35,
                          child: BriefingCheck(on: on),
                        ),
                        const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  fontWeight: AppText.semibold,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: when,
                                      style: whenPlaced
                                          ? TextStyle(
                                              color: colors.accent,
                                              fontWeight: AppText.semibold,
                                            )
                                          : null,
                                    ),
                                    const TextSpan(text: ' · '),
                                    TextSpan(
                                      text: due,
                                      style: dueSoon
                                          ? TextStyle(
                                              color: colors.alert,
                                              fontWeight: AppText.semibold,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              label: doneLabel,
              button: true,
              excludeSemantics: true,
              child: OutlinedButton(
                onPressed: onDone,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppSize.minTouch),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('했어요'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
