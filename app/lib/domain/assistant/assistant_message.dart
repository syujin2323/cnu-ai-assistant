// 06 AI 비서의 대화 한 줄과 카드. docs/screens.md '06 AI 비서'.
//
// 대화는 사용자가 보낸 문장([UserMessage])과 비서의 카드가 차례로 쌓인 목록이다. 저장하는 카드는 저장 전
// ([CardStatus.pending])에서 확인 버튼을 누르면 저장하고([CardStatus.saved]), 토스트의 '되돌리기'로 저장을
// 되돌리면 다시 저장 전이 된다. 확인 버튼을 누르기 전에는 아무것도 저장하지 않는다. 대화는 화면이 열려 있는
// 동안만 메모리에 두고 폰 DB에 남기지 않는다(사용자가 쓴 문장이 들어 있음).
//
// 카드 위의 한 줄과 카드 문구는 `assistant_reply.dart`가 만든다. 겹치는 일정처럼 폰 DB를 봐야 아는 것은
// 화면 쪽이 계산한다.

import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/models/class_exception.dart';
import 'package:cnu_ai_assistant/domain/models/fixed_block.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/models/plan_block.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
import 'package:cnu_ai_assistant/domain/models/task.dart';

/// 대화의 한 줄.
sealed class AssistantMessage {
  const AssistantMessage(this.id);

  /// 대화 안에서 줄을 가리키는 번호. 화면의 키와 카드 동작이 쓴다.
  final int id;
}

/// 사용자가 보낸 문장.
final class UserMessage extends AssistantMessage {
  const UserMessage(super.id, this.text);

  final String text;

  /// 문장 내용은 적지 않는다(디버그 출력에 사용자 문장이 남지 않게).
  @override
  String toString() => 'UserMessage($id, ${text.length}자)';
}

/// AI의 답을 기다리는 중.
final class WaitingMessage extends AssistantMessage {
  const WaitingMessage(super.id);
}

/// 저장하는 카드의 상태.
enum CardStatus {
  /// 저장 전. 확인 버튼을 누를 수 있다.
  pending,

  /// 저장하는 중(버튼을 막음).
  saving,

  /// 저장함.
  saved,

  /// 그대로 두기로 했다(수업 변경의 [취소], 바꾸기·지우기의 [그대로 두기]).
  declined,
}

/// 일정·할 일 카드가 어디서 왔는지.
enum CardOrigin {
  /// AI가 문장에서 읽었다.
  ai,

  /// AI 카드를 직접 추가 폼으로 고쳐 넣었다(06 카드의 [고치기]).
  edited,

  /// 직접 추가 폼으로 넣었다(대화에서 연 폼).
  manual,
}

/// 새 일정 카드(screens.md '06 AI 비서'의 카드 1). 한 번뿐인 일정은 `events`, 매주 반복이면 `fixed_blocks`에
/// 저장한다.
final class EventCard extends AssistantMessage {
  const EventCard(
    super.id, {
    required this.draft,
    this.say,
    this.status = CardStatus.pending,
    this.planNote,
    this.editPlace = false,
    this.editPrep = false,
    this.origin = CardOrigin.ai,
  });

  final EventDraft draft;

  /// 카드 위 한 줄.
  final String? say;

  final CardStatus status;

  /// 저장한 뒤 다시 계산한 제안('겹치던 제안 N개를 다른 빈 시간으로 옮겼어요'). 없으면 null이다.
  final String? planNote;

  /// 장소·준비물 칸을 열었는지(카드의 [+ 장소]·[+ 준비물]).
  final bool editPlace;
  final bool editPrep;

  /// 어디서 온 카드인지(카드 위 이름과 저장한 줄의 문구).
  final CardOrigin origin;

  EventCard copyWith({
    EventDraft? draft,
    CardStatus? status,
    String? Function()? planNote,
    bool? editPlace,
    bool? editPrep,
    CardOrigin? origin,
  }) => EventCard(
    id,
    draft: draft ?? this.draft,
    say: say,
    status: status ?? this.status,
    planNote: planNote == null ? this.planNote : planNote(),
    editPlace: editPlace ?? this.editPlace,
    editPrep: editPrep ?? this.editPrep,
    origin: origin ?? this.origin,
  );
}

/// 새 할 일 카드(screens.md '06 AI 비서'의 카드 2).
final class TaskCard extends AssistantMessage {
  const TaskCard(
    super.id, {
    required this.draft,
    this.say,
    this.status = CardStatus.pending,
    this.savedTaskId,
    this.planNote,
    this.origin = CardOrigin.ai,
  });

  final TaskDraft draft;

  /// 카드 위 한 줄.
  final String? say;

  final CardStatus status;

  /// 저장한 할 일의 id(K1 할 일 시트를 열 때 씀). 저장 전이면 null이다.
  final int? savedTaskId;

  /// 저장한 뒤 놓인 자리('먼저 내일 15:00–16:00에 놓았어요 · 확정 전 제안이에요'). 없으면 null이다.
  final String? planNote;

  /// 어디서 온 카드인지(카드 위 이름과 저장한 줄의 문구).
  final CardOrigin origin;

  TaskCard copyWith({
    TaskDraft? draft,
    CardStatus? status,
    int? Function()? savedTaskId,
    String? Function()? planNote,
    CardOrigin? origin,
  }) => TaskCard(
    id,
    draft: draft ?? this.draft,
    say: say,
    status: status ?? this.status,
    savedTaskId: savedTaskId == null ? this.savedTaskId : savedTaskId(),
    planNote: planNote == null ? this.planNote : planNote(),
    origin: origin ?? this.origin,
  );
}

/// 되묻는 것(screens.md '06 AI 비서'의 되묻기). 앱 코드가 날짜·시각을 확인해 고르게 한다.
enum AskTopic {
  /// 한 번뿐인 일정에 날짜가 없다.
  date,

  /// 할 일에 마감 날짜가 없다(마감 없음도 고를 수 있음).
  taskDue,

  /// 'N일'처럼 날만 말했다.
  dayOnly,

  /// '주말'처럼 하루를 가리키지 않았다.
  weekend,

  /// '다음 주'만 말하고 요일을 말하지 않았다.
  nextWeek,

  /// 날짜와 문장 속 요일이 어긋난다.
  weekdayMismatch,

  /// 8–11시인데 오전·오후를 말하지 않았다.
  meridiem,

  /// 지난 날짜다.
  pastDate,

  /// 오늘인데 지난 시각이다.
  pastTime,

  /// 수업 변경의 날짜가 없거나 그날 그 과목 수업이 없다(2주 안의 수업에서 고름).
  session,

  /// 이동 시간 규칙의 자리(매 수업 앞뒤, 하루 첫 수업 전·마지막 수업 뒤)를 말하지 않았다.
  rulePosition,
}

/// 되묻기 카드의 고를 것 하나.
final class AskOption {
  const AskOption({
    required this.label,
    this.sub,
    this.items = const [],
    this.rules = const [],
  });

  final String label;
  final String? sub;

  /// 고르면 이어서 처리할 항목(날짜·시각을 채운 것). '토·일 이틀 모두'면 둘이다.
  final List<ParseItem> items;

  /// 고르면 이어서 처리할 내 규칙(오전·오후나 이동 시간의 자리를 채운 것). 내 규칙 되묻기만 쓴다.
  final List<ParsedRule> rules;
}

/// 되묻기 카드. 고르면([picked]) 고른 항목으로 이어서 카드를 만든다.
final class AskCard extends AssistantMessage {
  const AskCard(
    super.id, {
    required this.topic,
    required this.question,
    this.sub,
    required this.options,
    required this.intent,
    required this.answered,
    this.picked,
  });

  final AskTopic topic;
  final String question;
  final String? sub;
  final List<AskOption> options;

  /// 이 항목이 나온 응답의 의도(일정·할 일·수업 변경·바꾸기·지우기·내 규칙).
  final ParseIntent intent;

  /// 이 항목에서 이미 답한 것. 다음 확인에서 다시 묻지 않는다(문장 속 표현은 그대로 남으므로).
  final Set<AskTopic> answered;

  /// 고른 것의 순번. 고르기 전이면 null이다.
  final int? picked;

  AskCard pick(int index) => AskCard(
    id,
    topic: topic,
    question: question,
    sub: sub,
    options: options,
    intent: intent,
    answered: answered,
    picked: index,
  );
}

/// 안내 카드의 종류.
enum InfoKind {
  /// 일정·할 일을 찾지 못했다(`other`).
  notUnderstood,

  /// AI가 카드 대신 질문을 돌려줬다(한 문장에 의도 둘, 대상 모름). 질문은 [InfoCard.question]이다.
  serverQuestion,

  /// 매주가 아닌 반복(격주·매달 등)이다.
  unsupportedRepeat,

  /// 반복 일정인데 요일이나 시각이 없다(고정 일정으로 저장할 수 없음).
  repeatIncomplete,

  /// 규칙 모드(12 '말로 정하기')에서 규칙이 아닌 것을 말했다.
  ruleOnly,

  /// 정할 수 없는 내 규칙 조건이다(`unsupportedRule`, 알림). 종류는 [InfoCard.unsupported]다.
  ruleUnsupported,

  /// 내 규칙의 값이 없거나 범위를 벗어났다. 되묻는 문장은 [InfoCard.question]이다.
  ruleQuestion,

  /// 지울 내 규칙이 없다. 그 종류의 이름은 [InfoCard.question]이다.
  noRuleToRemove,

  /// 수업 변경의 과목을 모르거나 2주 안에 그 과목 수업이 없다.
  noClass,

  /// 보강인데 날짜나 시각이 없다.
  makeupNeedsWhen,

  /// 강의실 변경인데 바뀐 강의실이 없다.
  placeNeeded,

  /// 바꾸거나 지울 일정을 찾지 못했다. 찾던 말은 [InfoCard.question]이다.
  targetNotFound,

  /// 바꾸기인데 어떻게 바꿀지(날짜·시각·옮길 분·요일)가 없다. 대상을 가리킨 말은 [InfoCard.question]이다.
  changeNeedsHow,

  /// 할 일을 바꾸거나 지우려 했다(할 일은 03 할 일에서 바꿈).
  taskChange,

  /// AI 사용에 동의하지 않아 보내지 않았다.
  aiDeclined,

  /// 오늘 AI 사용량을 다 썼다.
  limitReached,

  /// AI 비서를 아직 열지 않았다(Remote Config `ai_open`).
  aiClosed,
}

/// 안내 카드.
final class InfoCard extends AssistantMessage {
  const InfoCard(super.id, this.kind, {this.question, this.unsupported});

  final InfoKind kind;

  /// [InfoKind.serverQuestion]의 질문(AI가 쓴 문장), [InfoKind.targetNotFound]·[InfoKind.changeNeedsHow]의
  /// 대상을 가리킨 말, [InfoKind.ruleQuestion]의 되묻는 문장, [InfoKind.noRuleToRemove]의 규칙 종류 이름.
  final String? question;

  /// [InfoKind.ruleUnsupported]의 조건 종류. 알 수 없으면 null이다.
  final UnsupportedRuleKind? unsupported;
}

/// 수업 변경 카드(screens.md '06 AI 비서'의 카드 3). 그날 하루만 휴강·시험·강의실 변경·보강으로 바꾼다.
final class ExceptionCard extends AssistantMessage {
  const ExceptionCard(
    super.id, {
    required this.draft,
    this.say,
    this.status = CardStatus.pending,
    this.planNote,
  });

  final ExceptionDraft draft;
  final String? say;
  final CardStatus status;

  /// 적용한 뒤 다시 계산한 것('빈 시간 1시간 40분이 생겼어요'). 없으면 null이다.
  final String? planNote;

  ExceptionCard copyWith({CardStatus? status, String? Function()? planNote}) =>
      ExceptionCard(
        id,
        draft: draft,
        say: say,
        status: status ?? this.status,
        planNote: planNote == null ? this.planNote : planNote(),
      );
}

/// 저장 전 수업 변경.
final class ExceptionDraft {
  const ExceptionDraft({
    required this.kind,
    required this.slotId,
    required this.courseName,
    required this.date,
    required this.startMin,
    required this.endMin,
    this.originalPlace,
    this.place,
  });

  final ClassExceptionKind kind;
  final int slotId;
  final String courseName;

  /// 그 날짜(0시).
  final DateTime date;

  /// 그날의 수업 시각(보강이면 보강 시각, 그 날짜 0시 기준 분).
  final int startMin;
  final int endMin;

  /// 그날 원래 강의실.
  final String? originalPlace;

  /// 바뀐 강의실·시험 장소·보강 장소.
  final String? place;
}

/// 바꾸기·지우기 카드(screens.md '06 AI 비서'의 카드 5).
final class ChangeCard extends AssistantMessage {
  const ChangeCard(
    super.id, {
    required this.delete,
    required this.target,
    this.after,
    this.say,
    this.status = CardStatus.pending,
  }) : assert(delete || after != null, '바꾸기에는 바꾼 뒤의 값이 있다');

  /// 지우기인지(아니면 바꾸기).
  final bool delete;
  final ChangeTarget target;

  /// 바꾼 뒤의 값(바꾸기만).
  final ChangeAfter? after;
  final String? say;
  final CardStatus status;

  ChangeCard copyWith({CardStatus? status}) => ChangeCard(
    id,
    delete: delete,
    target: target,
    after: after,
    say: say,
    status: status ?? this.status,
  );
}

/// 바꾸거나 지울 일정이 여럿이면 고르는 카드. 고르면 [ChangeCard]를 만든다.
final class TargetPickCard extends AssistantMessage {
  const TargetPickCard(
    super.id, {
    required this.delete,
    required this.item,
    required this.candidates,
    this.say,
    this.picked,
  });

  final bool delete;

  /// 새 값이 든 항목(바꾸기).
  final ParseItem item;
  final List<ChangeTarget> candidates;
  final String? say;
  final int? picked;

  TargetPickCard pick(int index) => TargetPickCard(
    id,
    delete: delete,
    item: item,
    candidates: candidates,
    say: say,
    picked: index,
  );
}

/// 질문 답 카드(screens.md '06 AI 비서'의 카드 6). 폰 안 데이터로 답하므로 내용은 화면이 그때그때 계산한다.
final class AnswerCard extends AssistantMessage {
  const AnswerCard(
    super.id, {
    required this.type,
    required this.from,
    required this.to,
    this.courseName,
    this.say,
  });

  final ParseQueryType type;

  /// 질문이 말한 기간(그날 0시, 그날 포함). 하루 계획·빈 시간은 [from] 하루만 본다.
  final DateTime from;
  final DateTime to;

  /// 마감 질문의 과목.
  final String? courseName;
  final String? say;
}

/// 저장 전 내 규칙.
final class RuleDraft {
  const RuleDraft({
    required this.kind,
    required this.params,
    required this.merged,
    this.weekdays,
    this.courseName,
  });

  final RuleKind kind;

  /// 저장소에 넘길 값(말하지 않은 값을 채운 것).
  final RuleParams params;

  /// 저장하면 행에 남을 값. 하나만 두는 종류는 지금 행과 합친 값이고, 그 밖에는 [params]다. 미리보기 문장에
  /// 쓴다.
  final RuleParams merged;

  /// 걸리는 요일 1–7(정렬함). null이면 매일이다.
  final List<int>? weekdays;

  /// 예상 시간 규칙의 과목 이름(미리보기 문장).
  final String? courseName;
}

/// 내 규칙 미리보기 카드(screens.md '06 AI 비서'의 카드 4).
final class RuleCard extends AssistantMessage {
  const RuleCard(
    super.id, {
    required this.draft,
    this.replaced = const [],
    this.say,
    this.status = CardStatus.pending,
    this.planNote,
    this.conflicts = const [],
  });

  final RuleDraft draft;

  /// 저장하면 바뀌거나 꺼지는 지금 켜진 규칙(최근 것 먼저). 하나만 두는 종류는 합쳐질 행이다.
  final List<Rule> replaced;
  final String? say;
  final CardStatus status;

  /// 저장한 뒤 다시 계산한 것('제안 2개를 다시 놓았어요'). 없으면 null이다.
  final String? planNote;

  /// 저장한 뒤 새 규칙과 겹치게 된 확정 블록.
  final List<RuleConflict> conflicts;

  RuleCard copyWith({
    CardStatus? status,
    String? Function()? planNote,
    List<RuleConflict>? conflicts,
  }) => RuleCard(
    id,
    draft: draft,
    replaced: replaced,
    say: say,
    status: status ?? this.status,
    planNote: planNote == null ? this.planNote : planNote(),
    conflicts: conflicts ?? this.conflicts,
  );
}

/// 새 규칙과 겹치는 확정 블록의 답.
enum ConflictAnswer {
  /// 아직 답하지 않았다([옮기기]·[그대로 두기]).
  ask,

  /// 블록을 지우고 다시 계산했다.
  moved,

  /// 겹친 채로 둔다.
  kept,
}

/// 새 규칙과 겹치는 확정 블록 하나.
final class RuleConflict {
  const RuleConflict({
    required this.block,
    required this.title,
    this.answer = ConflictAnswer.ask,
    this.movedStart,
    this.movedEnd,
  });

  final PlanBlock block;

  /// 블록의 할 일 제목.
  final String title;
  final ConflictAnswer answer;

  /// 옮긴 뒤 그 할 일에 다시 놓인 첫 제안. 없으면 null이다(다음 빈 시간에 놓음).
  final DateTime? movedStart;
  final DateTime? movedEnd;

  RuleConflict answered(
    ConflictAnswer answer, {
    DateTime? movedStart,
    DateTime? movedEnd,
  }) => RuleConflict(
    block: block,
    title: title,
    answer: answer,
    movedStart: movedStart,
    movedEnd: movedEnd,
  );
}

/// 내 규칙 지우기 카드.
final class RuleRemoveCard extends AssistantMessage {
  const RuleRemoveCard(
    super.id, {
    required this.rule,
    this.courseName,
    this.say,
    this.status = CardStatus.pending,
    this.planNote,
  });

  final Rule rule;

  /// 예상 시간 규칙의 과목 이름.
  final String? courseName;
  final String? say;
  final CardStatus status;

  /// 지운 뒤 다시 계산한 것. 없으면 null이다.
  final String? planNote;

  RuleRemoveCard copyWith({CardStatus? status, String? Function()? planNote}) =>
      RuleRemoveCard(
        id,
        rule: rule,
        courseName: courseName,
        say: say,
        status: status ?? this.status,
        planNote: planNote == null ? this.planNote : planNote(),
      );
}

/// 지울 내 규칙이 여럿이면 고르는 카드. 고르면 [RuleRemoveCard]를 만든다.
final class RulePickCard extends AssistantMessage {
  const RulePickCard(
    super.id, {
    required this.kind,
    required this.rules,
    this.courseNames = const {},
    this.say,
    this.picked,
  });

  final RuleKind kind;

  /// 고를 규칙(최근 것 먼저).
  final List<Rule> rules;

  /// 과목 id와 이름(예상 시간 규칙의 문장).
  final Map<int, String> courseNames;
  final String? say;
  final int? picked;

  RulePickCard pick(int index) => RulePickCard(
    id,
    kind: kind,
    rules: rules,
    courseNames: courseNames,
    say: say,
    picked: index,
  );
}

/// 보내지 못한 까닭.
enum FailKind {
  /// 8초(임시) 안에 답이 없었다.
  timeout,

  /// 서버에 연결하지 못했다(오프라인 등).
  offline,

  /// 서버가 답하지 못했다(제공사 오류, 서버 오류, 응답 꼴이 틀림).
  failed,
}

/// 보내지 못한 카드. [다시 보내기]가 [text]를 다시 보낸다.
final class FailCard extends AssistantMessage {
  const FailCard(super.id, this.kind, {required this.text});

  final FailKind kind;

  /// 보내려던 문장.
  final String text;

  /// 문장 내용은 적지 않는다.
  @override
  String toString() => 'FailCard($id, $kind, ${text.length}자)';
}

/// 저장 전 일정. 날짜·시각은 한국 시각이고 하루 안의 시각은 자정 기준 분이다(폰 DB의 시간표와 같음).
final class EventDraft {
  const EventDraft({
    required this.title,
    this.date,
    this.weekdays,
    this.startMin,
    this.endMin,
    this.place,
    this.prep,
    this.fixedKind,
    this.reminderMinutes,
  }) : assert(
         (date == null) != (weekdays == null),
         '한 번뿐인 일정은 날짜, 반복 일정은 요일 가운데 하나만 둔다',
       ),
       assert((startMin == null) == (endMin == null), '시작과 끝은 함께 있거나 함께 없다');

  final String title;

  /// 한 번뿐인 일정의 날짜(그날 0시). 반복 일정이면 null이다.
  final DateTime? date;

  /// 매주 반복하는 요일(1–7, 오름차순). 한 번뿐인 일정이면 null이다.
  final List<int>? weekdays;

  /// 시작(자정 기준 분, 0–1439). 시간 미정이면 null이다.
  final int? startMin;

  /// 끝(자정 기준 분). [startMin]보다 크고, 자정을 넘으면 1440을 더한 값이다.
  final int? endMin;

  final String? place;
  final String? prep;

  /// 반복 일정의 종류(`fixed_blocks.kind`). AI가 정하지 않았으면 null이고 `other`로 저장한다.
  final FixedBlockKind? fixedKind;

  /// AI가 읽은 알림 시각(분 전). 값만 저장한다(알림은 재설계 예정).
  final int? reminderMinutes;

  /// 매주 반복하는 일정(고정 일정으로 저장)인지.
  bool get repeating => weekdays != null;

  /// 시간 미정인지.
  bool get timeUnknown => startMin == null;

  /// 한 번뿐인 일정의 시작 시각. 반복이거나 시간 미정이면 null이다.
  DateTime? get startAt => _at(startMin);

  /// 한 번뿐인 일정의 끝 시각. 반복이거나 시간 미정이면 null이다.
  DateTime? get endAt => _at(endMin);

  DateTime? _at(int? minute) {
    final day = date;
    if (day == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, 0, minute);
  }

  EventDraft withTime(int start, int end) => EventDraft(
    title: title,
    date: date,
    weekdays: weekdays,
    startMin: start,
    endMin: end,
    place: place,
    prep: prep,
    fixedKind: fixedKind,
    reminderMinutes: reminderMinutes,
  );

  EventDraft withPlace(String? value) => EventDraft(
    title: title,
    date: date,
    weekdays: weekdays,
    startMin: startMin,
    endMin: endMin,
    place: value,
    prep: prep,
    fixedKind: fixedKind,
    reminderMinutes: reminderMinutes,
  );

  EventDraft withPrep(String? value) => EventDraft(
    title: title,
    date: date,
    weekdays: weekdays,
    startMin: startMin,
    endMin: endMin,
    place: place,
    prep: value,
    fixedKind: fixedKind,
    reminderMinutes: reminderMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is EventDraft &&
      other.title == title &&
      other.date == date &&
      _sameDays(other.weekdays, weekdays) &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.place == place &&
      other.prep == prep &&
      other.fixedKind == fixedKind &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode => Object.hash(
    title,
    date,
    weekdays == null ? null : Object.hashAll(weekdays!),
    startMin,
    endMin,
    place,
    prep,
    fixedKind,
    reminderMinutes,
  );

  /// 제목·장소·준비물은 적지 않는다(사용자가 쓴 말).
  @override
  String toString() =>
      'EventDraft(date: $date, weekdays: $weekdays, $startMin–$endMin)';
}

/// 저장 전 할 일.
final class TaskDraft {
  const TaskDraft({
    required this.title,
    this.courseName,
    required this.kind,
    this.dueDate,
    this.dueTimeMin,
    this.saidEstimateMin,
    this.pickedEstimateMin,
  }) : assert(
         courseName == null || kind != TaskKind.personal,
         '과목 할 일의 종류에는 개인이 없다',
       );

  final String title;

  /// 과목 이름(요청에 보낸 과목 가운데 하나). 개인 할 일이면 null이다.
  final String? courseName;

  /// 종류. 개인 할 일은 [TaskKind.personal], 과목 할 일은 카드의 종류 칩에서 고른다.
  final TaskKind kind;

  /// 마감 날짜(그날 0시). 마감이 없으면 null이다.
  final DateTime? dueDate;

  /// 마감 시각(자정 기준 분). 말하지 않았으면 null이고 23:59로 저장한다.
  final int? dueTimeMin;

  /// 문장에서 말한 예상 시간(분).
  final int? saidEstimateMin;

  /// 카드의 예상 시간 칩으로 고른 값(분).
  final int? pickedEstimateMin;

  /// 마감 시각. 시각을 말하지 않았으면 그날 23:59다.
  DateTime? get dueAt {
    final day = dueDate;
    if (day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      0,
      dueTimeMin ?? 23 * 60 + 59,
    );
  }

  /// 마감 시각을 말하지 않았는지(`tasks.dueTimeUnknown`).
  bool get dueTimeUnknown => dueDate != null && dueTimeMin == null;

  /// 할 일에 저장할 예상 시간: 고른 값, 없으면 말한 값. 규칙·종류별 기본값은 저장하지 않는다(배치가 그때그때
  /// 규칙과 기본값을 쓰므로, 나중에 규칙을 바꾸면 따라가게).
  int? get estimateToStore => pickedEstimateMin ?? saidEstimateMin;

  TaskDraft withKind(TaskKind value) => TaskDraft(
    title: title,
    courseName: courseName,
    kind: value,
    dueDate: dueDate,
    dueTimeMin: dueTimeMin,
    saidEstimateMin: saidEstimateMin,
    pickedEstimateMin: pickedEstimateMin,
  );

  TaskDraft withEstimate(int minutes) => TaskDraft(
    title: title,
    courseName: courseName,
    kind: kind,
    dueDate: dueDate,
    dueTimeMin: dueTimeMin,
    saidEstimateMin: saidEstimateMin,
    pickedEstimateMin: minutes,
  );

  @override
  bool operator ==(Object other) =>
      other is TaskDraft &&
      other.title == title &&
      other.courseName == courseName &&
      other.kind == kind &&
      other.dueDate == dueDate &&
      other.dueTimeMin == dueTimeMin &&
      other.saidEstimateMin == saidEstimateMin &&
      other.pickedEstimateMin == pickedEstimateMin;

  @override
  int get hashCode => Object.hash(
    title,
    courseName,
    kind,
    dueDate,
    dueTimeMin,
    saidEstimateMin,
    pickedEstimateMin,
  );

  /// 제목·과목은 적지 않는다(사용자가 쓴 말).
  @override
  String toString() => 'TaskDraft($kind, due: $dueAt)';
}

bool _sameDays(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
