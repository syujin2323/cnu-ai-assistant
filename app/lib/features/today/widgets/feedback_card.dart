// 02 홈 피드백 카드. docs/screens.md '02 홈'의 피드백 카드 표.
//
// 무엇을 보일지는 `domain/home_feedback.dart`의 [homeFeedback]이 정하고, 여기서는 문구와 버튼을 그린다. 모양은
// 최종 프로토타입의 홈 카드를 따른다: 위 줄에 아이콘(지금 할 일은 퍼지는 점)과 머리말·오른쪽 값, 제목, 한 줄
// 설명, 지금 할 일의 진행 막대, 버튼 줄. 상태가 바뀌면 rise로 다시 나타난다. '과제 자세히'·'강의 자세히' 링크와
// 7번의 [빈 시간에 할 일 놓기]는 여는 화면(할 일 상세는 재설계 예정, 빈 시간에 놓기 시트는 W6 PR)이 생길 때까지
// 두지 않는다(눌러도 반응 없는 버튼을 두지 않음).

import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/pulse.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/home_feedback.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';
import 'package:cnu_ai_assistant/domain/planner/day_items.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:material_ui/material_ui.dart';

/// 피드백 카드의 버튼이 부르는 동작.
final class FeedbackActions {
  const FeedbackActions({
    required this.onDid,
    required this.onDidNot,
    required this.onUndo,
    required this.onRetry,
    required this.onSkipRetry,
    required this.onDismiss,
  });

  /// '했어요'·'끝냈어요'(지금 할 일 포함).
  final ValueChanged<BlockItem> onDid;

  /// '못 했어요'.
  final ValueChanged<BlockItem> onDidNot;

  /// 카드 안 [되돌리기].
  final VoidCallback onUndo;

  /// [다시 놓기].
  final VoidCallback onRetry;

  /// [오늘은 괜찮아요].
  final VoidCallback onSkipRetry;

  /// 다시 놓을 자리가 없을 때의 [확인].
  final VoidCallback onDismiss;
}

/// 02 홈 피드백 카드.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.feedback,
    required this.now,
    required this.dayBoundaryMin,
    required this.actions,
  });

  final HomeFeedback feedback;

  /// 지금(분 단위).
  final DateTime now;

  final int dayBoundaryMin;
  final FeedbackActions actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final look = _look();
    return Rise(
      key: ValueKey(look.key),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s12,
            AppSpace.s16,
            AppSpace.s16,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.edge),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (look.live)
                    const _LiveDot()
                  else if (look.icon case final icon?)
                    AppIcon(icon, size: 15, color: colors.accent),
                  const SizedBox(width: AppSpace.s4 + 2),
                  Expanded(
                    child: Text(
                      look.kicker,
                      style: AppText.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (look.right case final right?)
                    Text(
                      right,
                      style: AppText.caption.copyWith(color: colors.muted),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Text(look.title, style: AppText.title),
              if (look.sub case final sub?) ...[
                const SizedBox(height: 2),
                Text(sub, style: AppText.small.copyWith(color: colors.ink2)),
              ],
              if (look.progress case (final ratio, final left)) ...[
                const SizedBox(height: AppSpace.s8 + 2),
                _ProgressRow(ratio: ratio, left: left),
              ],
              if (look.buttons.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s12),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: look.buttons,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _Look _look() => switch (feedback) {
    FeedbackRecorded(:final block, :final left) => _Look(
      key: 'recorded-${block.block.id}',
      icon: AppIconName.check,
      kicker: '기록했어요',
      title:
          '${withJosa(_title(block), Josa.eulReul)} '
          '${_isVideo(block) ? '다 봤어요' : '끝냈어요'}',
      sub: left.isEmpty
          ? '오늘 남은 할 일은 없어요'
          : '오늘 남은 할 일 ${left.length}개 · 다음은 '
                '${_hhmm(left.first.block.startAt)} ${_title(left.first)}',
      buttons: [
        OutlinedButton(onPressed: actions.onUndo, child: const Text('되돌리기')),
      ],
    ),
    FeedbackRetry(:final block, :final slot) => _Look(
      key: 'retry-${block.block.id}',
      icon: AppIconName.clock,
      kicker: '못 했어도 괜찮아요',
      title: slot == null
          ? '오늘은 다시 놓을 빈 시간이 없어요'
          : '${_tomorrow(slot.start) ? '내일 ' : ''}'
                '${_hhmm(slot.start)}에 다시 놓을까요?',
      sub:
          '${_title(block)} · '
          '${durationText(slot?.minutes ?? block.span.minutes)} · '
          '${_due(block)}',
      buttons: slot == null
          ? [
              OutlinedButton(
                onPressed: actions.onDismiss,
                child: const Text('확인'),
              ),
            ]
          : [
              FilledButton(
                onPressed: actions.onRetry,
                child: const Text('다시 놓기'),
              ),
              OutlinedButton(
                onPressed: actions.onSkipRetry,
                child: const Text('오늘은 괜찮아요'),
              ),
            ],
    ),
    FeedbackAsk(:final block) => _Look(
      key: 'ask-${block.block.id}',
      icon: AppIconName.checkSquare,
      kicker: '끝난 할 일',
      title: '${_title(block)}, ${_isVideo(block) ? '보셨나요?' : '하셨나요?'}',
      sub:
          '${_hhmm(block.block.startAt)}–${_hhmm(block.block.endAt)} · '
          '${_endedText(block)}',
      buttons: [
        FilledButton(
          onPressed: () => actions.onDid(block),
          child: Text(_isVideo(block) ? '봤어요' : '했어요'),
        ),
        OutlinedButton(
          onPressed: () => actions.onDidNot(block),
          child: Text(_isVideo(block) ? '못 봤어요' : '못 했어요'),
        ),
      ],
    ),
    FeedbackLive(:final block) => _Look(
      key: 'live-${block.block.id}',
      live: true,
      kicker: '지금 할 일',
      right: '${_hhmm(block.block.endAt)}까지',
      title: '지금 ${_title(block)} ${_isVideo(block) ? '볼' : '할'} 시간이에요',
      progress: (
        _ratio(block),
        '${durationText(block.block.endAt.difference(now).inMinutes)} 남음',
      ),
      buttons: [
        FilledButton(
          onPressed: () => actions.onDid(block),
          child: const Text('끝냈어요'),
        ),
      ],
    ),
    FeedbackNext(:final block, :final left) => _Look(
      key: 'next-${block.block.id}',
      icon: AppIconName.clock,
      kicker: '다음 할 일',
      right: '${durationText(block.block.startAt.difference(now).inMinutes)} 뒤',
      title: '${_hhmm(block.block.startAt)} ${_title(block)}',
      sub:
          '${durationText(block.span.minutes)} · ${_due(block)}'
          '${left > 1 ? ' · 오늘 할 일 $left개' : ''}',
    ),
    FeedbackAllDone(:final done, :final missed, :final doneMin) => _Look(
      key: 'all',
      icon: AppIconName.check,
      kicker: '오늘 할 일',
      title: missed > 0 ? '오늘 할 일을 정리했어요' : '오늘 할 일을 모두 끝냈어요',
      sub: missed == 0
          ? '$done개 · ${durationText(doneMin)}'
          : done > 0
          ? '했어요 $done개 · 못 했어요 $missed개'
          : '못 한 일은 다음 빈 시간에 다시 추천할게요',
    ),
    FeedbackNone(:final freeMin, :final nearest) => _Look(
      key: 'none',
      icon: AppIconName.freeTime,
      kicker: '오늘 할 일',
      title: '오늘 놓은 할 일이 없어요',
      sub: nearest == null
          ? '오늘은 남은 빈 시간이 없어요'
          : '남은 빈 시간 ${durationText(freeMin)} · 가장 가까운 빈 시간은 '
                '${_hhmm(nearest.start)}',
    ),
  };

  /// 블록이 끝난 지 얼마나 됐는지.
  String _endedText(BlockItem block) {
    final ago = now.difference(block.block.endAt).inMinutes;
    return ago < 1 ? '방금 끝났어요' : '끝난 지 ${durationText(ago)}';
  }

  /// 지금 하는 블록의 지난 비율(0–1).
  double _ratio(BlockItem block) {
    final total = block.block.endAt.difference(block.block.startAt).inSeconds;
    if (total <= 0) return 1;
    final done = now.difference(block.block.startAt).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  String _due(BlockItem block) {
    final task = block.entry?.task;
    return dueText(
      task?.dueAt,
      dueTimeUnknown: task?.dueTimeUnknown ?? false,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    );
  }

  bool _tomorrow(DateTime at) =>
      logicalDate(at, dayBoundaryMin: dayBoundaryMin) !=
      logicalDate(now, dayBoundaryMin: dayBoundaryMin);
}

/// 카드 하나의 모양.
final class _Look {
  const _Look({
    required this.key,
    required this.kicker,
    required this.title,
    this.icon,
    this.live = false,
    this.right,
    this.sub,
    this.progress,
    this.buttons = const [],
  });

  /// 상태가 바뀌었는지 가르는 값(바뀌면 rise로 다시 나타남).
  final String key;
  final AppIconName? icon;
  final bool live;
  final String kicker;
  final String? right;
  final String title;
  final String? sub;

  /// 진행 막대의 비율과 남은 시간 문구.
  final (double, String)? progress;
  final List<Widget> buttons;
}

/// '지금 할 일'의 점(뒤에서 고리가 퍼짐).
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget dot(Color color) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return SizedBox(
      width: 15,
      height: 15,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Pulse(child: dot(colors.stripe)),
            dot(colors.strong),
          ],
        ),
      ),
    );
  }
}

/// 지금 할 일의 진행 막대와 남은 시간.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.ratio, required this.left});

  final double ratio;
  final String left;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: colors.edge),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.strong,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s8 + 2),
        Text(left, style: AppText.caption.copyWith(color: colors.muted)),
      ],
    );
  }
}

/// 블록의 할 일 이름.
String _title(BlockItem block) => block.entry?.task.title ?? '할 일';

bool _isVideo(BlockItem block) => block.entry?.task.kind == TaskKind.video;

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);
