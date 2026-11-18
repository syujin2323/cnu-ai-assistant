// 근거 시트의 내용. docs/screens.md '근거 시트'.
//
// 할 일 블록을 누르면 여는 시트가 무엇을 보일지 정한다(01 아침 브리핑의 잠긴 줄, 02 홈, 09 일간, 11 주간, 06 AI
// 비서). 머리 표시, 이름, 시각 줄, 엔진이 고른 블록의 근거 네 줄(마감까지 남은 시간, 이 자리의 빈 분, 급한 순번,
// 고른 이유), 직접 정한 블록의 한 줄, 놓친 블록의 탓하지 않는 문장과 다음 제안 자리, 상태별 버튼이다. 문구는 디자인 전
// 임시 문구다.

import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';

/// 근거 시트의 버튼.
enum BlockSheetAction {
  /// 제안을 엔진 자리 그대로 확정.
  confirm,

  /// 완료.
  complete,

  /// 완료 취소.
  uncomplete,

  /// 다른 시간으로 옮기기(옮기기 시트).
  move,

  /// 지우기(다른 빈 시간에 제안만 다시 만듦).
  dismiss,
}

/// 근거 시트에 보일 것.
final class BlockSheetContent {
  const BlockSheetContent({
    required this.kicker,
    required this.title,
    required this.time,
    required this.manual,
    required this.reasons,
    required this.missedText,
    required this.actions,
  });

  /// 머리 표시('제안 · 아직 확정 전', '확정', '확정 · 부분', '완료', '놓침').
  final String kicker;

  /// 할 일 이름.
  final String title;

  /// '{날짜 말} HH:MM–HH:MM · {길이} · {마감 문구}'.
  final String time;

  /// 사용자가 직접 정한 블록인지('직접 정한 시간이에요').
  final bool manual;

  /// 엔진이 고른 블록의 근거 줄(근거가 없으면 비어 있음).
  final List<String> reasons;

  /// 놓친 블록의 문장(놓친 블록이 아니면 null).
  final String? missedText;

  /// 보일 버튼(앞에서부터. 첫 버튼이 주 버튼이다).
  final List<BlockSheetAction> actions;
}

/// [block]의 근거 시트 내용. [entry]는 블록의 할 일, [courseName]은 그 할 일의 과목 이름(없으면 null)이다.
/// [nextSuggestionAt]은 놓친 블록의 할 일에 지금 뒤로 놓인 가장 이른 제안의 시작이다(없으면 null). [canMove]가
/// false면 [옮기기]를 두지 않는다. [now]에는 `Clock.now`의 값을 넘긴다.
BlockSheetContent blockSheetContent({
  required PlanBlock block,
  required TaskEntry entry,
  required String? courseName,
  required DateTime now,
  required int dayBoundaryMin,
  required DateTime? nextSuggestionAt,
  bool canMove = true,
}) {
  final task = entry.task;
  final minutes = block.endAt.difference(block.startAt).inMinutes;
  final kicker = switch (block.status) {
    PlanBlockStatus.suggested => '제안 · 아직 확정 전',
    PlanBlockStatus.confirmed => task.partialGoalMin != null ? '확정 · 부분' : '확정',
    PlanBlockStatus.done => '완료',
    PlanBlockStatus.missed => '놓침',
    PlanBlockStatus.dismissed => '지움',
  };
  final day = dayWord(block.startAt, now: now, dayBoundaryMin: dayBoundaryMin);
  final startMin = block.startAt.hour * 60 + block.startAt.minute;
  final length = minutes.clamp(1, 1439).toInt();
  final time = [
    '$day ${timeRangeText(startMin, startMin + length)}',
    durationText(length),
    dueText(
      task.dueAt,
      dueTimeUnknown: task.dueTimeUnknown,
      now: now,
      dayBoundaryMin: dayBoundaryMin,
    ),
  ].join(' · ');

  final reason = block.reason;
  final manual = block.source == BlockSource.manual;
  final reasons = manual || reason == null
      ? const <String>[]
      : [
          reason.dueAt.isAfter(now)
              ? '마감까지 ${remainingText(reason.dueAt.difference(now).inMinutes)} 남았어요'
              : '마감이 지났어요',
          '이 자리는 ${reason.gapMin}분 비어 있어요',
          '지금 할 일 가운데 ${reason.rank}번째로 급해요',
          _factorLine(reason, courseName),
        ];

  final missedText = block.status != PlanBlockStatus.missed
      ? null
      : nextSuggestionAt == null
      ? '못 했어도 괜찮아요. 다음 빈 시간에 다시 놓을게요'
      : '못 했어도 괜찮아요. '
            '${dayWord(nextSuggestionAt, now: now, dayBoundaryMin: dayBoundaryMin)} '
            '${_hhmm(nextSuggestionAt)}에 다시 놓아 뒀어요';

  final actions = switch (block.status) {
    PlanBlockStatus.suggested => [
      BlockSheetAction.confirm,
      BlockSheetAction.complete,
      if (canMove) BlockSheetAction.move,
      BlockSheetAction.dismiss,
    ],
    PlanBlockStatus.confirmed => [
      BlockSheetAction.complete,
      if (canMove) BlockSheetAction.move,
      BlockSheetAction.dismiss,
    ],
    PlanBlockStatus.done => [BlockSheetAction.uncomplete],
    PlanBlockStatus.missed ||
    PlanBlockStatus.dismissed => const <BlockSheetAction>[],
  };

  return BlockSheetContent(
    kicker: kicker,
    title: task.title,
    time: time,
    manual: manual,
    reasons: reasons,
    missedText: missedText,
    actions: actions,
  );
}

/// 고른 이유 한 줄.
String _factorLine(BlockReason reason, String? courseName) =>
    switch (reason.factor) {
      BlockFactor.nearClass =>
        '${courseName == null ? '관련' : courseName.trim()} 수업과 가까워 내용이 이어져요',
      BlockFactor.preferred => '평소 집중하는 시간이에요',
      BlockFactor.unsplit => '나누지 않고 한 번에 할 수 있어요',
      BlockFactor.fit => '${durationText(reason.gapMin)} 비어 있어 한 조각을 끝낼 수 있어요',
    };

String _hhmm(DateTime at) => hhmmText(at.hour * 60 + at.minute);
