// 06 AI 비서의 고쳐 말하기. docs/screens.md '06 AI 비서', docs/decisions.md 2026-11-19 '카드가 떠 있을 때 이어 쓴
// 말은 앞 문장과 함께 보낸다'.
//
// 마지막으로 보낸 문장의 답에 아직 저장하지 않은 확인 카드나 답하지 않은 되묻기가 남아 있으면, 이어 쓴 말은 그
// 문장을 고치거나 답하는 말로 보고 앞 문장과 함께 보낸다([followUpOf]). 답이 같은 종류의 카드로 오면 앞의 열린
// 카드는 고친 카드로 바꾼다([replacedByFollowUp]). 같은 입력이면 늘 같은 결과다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';

/// 이어 쓴 말이 기대는 앞 답.
final class FollowUp {
  const FollowUp({required this.openIds, this.question});

  /// 마지막 답에서 아직 열려 있는 카드(저장 전 확인 카드, 답하지 않은 되묻기)의 id.
  final List<int> openIds;

  /// 마지막 답이 AI가 돌려준 질문이면 그 질문.
  final String? question;
}

/// 함께 보내는 앞 문장 수(서버가 받는 수).
const int maxPreviousTexts = 3;

/// [messages]의 마지막 문장에 대한 답이 아직 열려 있으면 그것을, 아니면 null을 준다.
FollowUp? followUpOf(List<AssistantMessage> messages) {
  final last = messages.lastIndexWhere((message) => message is UserMessage);
  if (last < 0) return null;
  final openIds = <int>[];
  String? question;
  var asks = false;
  for (final message in messages.skip(last + 1)) {
    switch (message) {
      case EventCard(:final status) ||
          TaskCard(:final status) ||
          ExceptionCard(:final status) ||
          ChangeCard(:final status) ||
          RuleCard(:final status) ||
          RuleRemoveCard(:final status):
        if (status == CardStatus.pending) openIds.add(message.id);
      case AskCard(:final picked) ||
          TargetPickCard(:final picked) ||
          RulePickCard(:final picked):
        if (picked == null) openIds.add(message.id);
      case InfoCard(kind: InfoKind.serverQuestion, question: final asked):
        question = asked;
        asks = true;
      case InfoCard(:final kind):
        if (_needsMore.contains(kind)) asks = true;
      default:
        break;
    }
  }
  if (openIds.isEmpty && !asks) return null;
  return FollowUp(openIds: openIds, question: question);
}

/// 값이 모자라 더 말해 달라고 한 안내. 이어 쓴 말을 앞 문장과 함께 받는다.
const _needsMore = {
  InfoKind.ruleQuestion,
  InfoKind.changeNeedsHow,
  InfoKind.makeupNeedsWhen,
  InfoKind.placeNeeded,
  InfoKind.repeatIncomplete,
};

/// 이어 쓴 말의 답이 [intent]로 왔을 때, [messages] 가운데 고친 카드로 바뀌어 지울 열린 카드([openIds] 안)의 id.
/// 같은 종류의 카드만 지운다(다른 것을 새로 말했으면 앞 카드는 그대로 둔다).
Set<int> replacedByFollowUp(
  List<AssistantMessage> messages, {
  required List<int> openIds,
  required ParseIntent intent,
}) {
  final open = openIds.toSet();
  return {
    for (final message in messages)
      if (open.contains(message.id) && _sameKind(message, intent)) message.id,
  };
}

bool _sameKind(AssistantMessage message, ParseIntent intent) =>
    switch (intent) {
      ParseIntent.createEvent => message is EventCard || message is AskCard,
      ParseIntent.createTask => message is TaskCard || message is AskCard,
      ParseIntent.classException =>
        message is ExceptionCard || message is AskCard,
      ParseIntent.update ||
      ParseIntent.delete => message is ChangeCard || message is TargetPickCard,
      ParseIntent.setRule =>
        message is RuleCard ||
            message is RuleRemoveCard ||
            message is RulePickCard ||
            message is AskCard,
      ParseIntent.query || ParseIntent.other => false,
    };
