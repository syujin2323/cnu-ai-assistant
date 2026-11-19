// 06 AI 비서의 대화와 카드 동작. docs/screens.md '06 AI 비서'·'AI 사용 동의', docs/architecture.md 'POST
// /v1/parse'·'데모 모드'·'폰 DB'의 되돌리기.
//
// 문장을 보내기 전에 AI를 쓸 수 있는지 본다([AssistantController.gate]). AI 사용에 동의하지 않았으면 화면이 AI
// 사용 동의 시트를 열고(먼저 쓴 문장은 '동의하면 보낼 문장'), 동의하면 적은 뒤 보낸다. 오늘 사용량을 다 썼으면
// 보내지 않는다. 데모 모드는 서버·AI를 부르지 않고 미리 적은 응답 가운데 가장 비슷한 것을 쓴다
// (`data/demo/demo_parse.dart`). 응답은 오전·오후를 말하지 않은 1–7시를 오후로 고친 뒤 카드로 바꾼다
// (`domain/assistant/assistant_reply.dart`).
//
// 수업 변경·일정 바꾸기·지우기·내 규칙은 보낼 때 읽어 둔 폰 DB의 값(과목·수업 칸·수업 예외·고정 일정·오늘부터
// 60일(임시)의 일정·내 규칙, [AssistantSnapshot])으로 대상과 지금 값을 찾는다. 내 규칙을 저장하면 저장 전과
// 뒤의 배치 설정으로 새 규칙과 겹치게 된 확정 블록을 찾아 카드에서 [옮기기]·[그대로 두기]를 묻는다.
//
// 확인 버튼을 누를 때만 저장하고, 저장할 때마다 되돌리기 토스트를 띄운다. 토스트의 '되돌리기'로 되돌리면 그
// 카드를 저장 전으로 돌린다. 저장한 뒤에는 바로 다시 계산해 옮겨진 제안이나 놓인 자리를 카드에 적는다. 대화는
// 화면을 닫으면 버린다(autoDispose). 로그에는 문장·제목을 남기지 않고 의도 이름과 카드 수만 남긴다.
//
// 직접 추가 폼([DirectAddDraft])도 여기서 저장한다([AssistantController.saveDirect]). 대화에서 연 폼은 넣은
// 것을 카드로 남기고, 카드의 [고치기]로 연 폼은 그 카드를 넣은 것으로 바꾸며, 폼이 화면 자체면 대화에 남기지
// 않는다. AI를 쓸 수 없어 보내지 못하면(동의 안 함, 오늘 사용량 다 씀, AI 닫힘, 오프라인) 화면이 폼을 열도록
// 그 까닭([DirectAddNotice])을 돌려준다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/api/parse_client.dart';
import 'package:cnu_ai_assistant/data/demo/demo_parse.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_rules.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_targets.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/assistant/direct_add.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/fixed_block_templates.dart';
import 'package:cnu_ai_assistant/domain/free_slots.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/parse_checks.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/planner/rule_conflicts.dart';
import 'package:cnu_ai_assistant/domain/planner/schedule.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 문장을 지금 보낼 수 있는지.
enum AiGate {
  /// 보낼 수 있다.
  open,

  /// AI 경로가 닫혀 있다(Remote Config `ai_open`). 06 AI 비서는 직접 추가 폼으로 연다.
  closed,

  /// AI 사용에 동의하지 않았다(화면이 동의 시트를 연다).
  needsConsent,

  /// 이 화면에서 동의하지 않기로 했다(다시 묻지 않음).
  declined,

  /// 오늘 사용량을 다 썼다.
  limitReached,

  /// 데모 모드(미리 적은 응답).
  demo,
}

/// AI를 쓸 수 없어 직접 추가 폼을 열 때 폼 위에 보이는 까닭(docs/screens.md '06 AI 비서').
enum DirectAddNotice {
  /// AI 사용에 동의하지 않았다([AI 켜기]를 둠).
  aiOff,

  /// 오늘 AI 사용량을 다 썼다.
  limit,

  /// AI 경로가 아직 닫혀 있다(Remote Config `ai_open`).
  closed,

  /// 인터넷에 연결하지 못했다.
  offline,

  /// AI가 답하지 않았다(못 보낸 카드의 [직접 추가]).
  failed,
}

/// 직접 추가 폼을 어디서 열었는지. 저장한 뒤 할 일이 다르다.
enum DirectAddOrigin {
  /// 대화에서 열었다: 넣은 것을 대화에 카드로 남긴다.
  chat,

  /// 카드의 [고치기]로 열었다: 그 카드를 넣은 것으로 바꾼다.
  card,

  /// 폼이 화면 자체다: 대화에 남기지 않는다(폼이 저장 띠를 보임).
  screen,
}

/// 지금 AI를 쓸 수 있는지(화면이 폼 위의 까닭과 '말로 넣기'를 정할 때 봄). 보낼 때는 [AssistantController.gate]가
/// 폰 DB를 새로 읽어 정한다. 설정을 읽는 중이면 null이다.
final aiGateProvider = Provider.autoDispose<AiGate?>((ref) {
  if (ref.watch(appModeProvider) == AppMode.demo) return AiGate.demo;
  if (!ref.watch(parseClientProvider).isOpen) return AiGate.closed;
  if (ref.watch(
    assistantControllerProvider.select((state) => state.declined),
  )) {
    return AiGate.declined;
  }
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return null;
  if (!settings.aiEnabled) return AiGate.needsConsent;
  if (settings.aiLimitReachedOn == isoDate(ref.watch(clockProvider).now())) {
    return AiGate.limitReached;
  }
  return AiGate.open;
});

/// 대화.
final class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.sending = false,
    this.declined = false,
  });

  final List<AssistantMessage> messages;

  /// 답을 기다리는 중(보내기를 막음).
  final bool sending;

  /// 이 화면에서 AI 사용에 동의하지 않기로 했다.
  final bool declined;

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? sending,
    bool? declined,
  }) => AssistantState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    declined: declined ?? this.declined,
  );
}

/// 06 AI 비서의 대화. 화면을 닫으면 버린다.
final assistantControllerProvider =
    NotifierProvider.autoDispose<AssistantController, AssistantState>(
      AssistantController.new,
    );

class AssistantController extends Notifier<AssistantState> {
  /// 데모 응답을 보이기 전에 기다리는 시간(답을 읽는 것처럼 보이게, 임시).
  static const demoDelay = Duration(milliseconds: 700);

  /// 바꾸거나 지울 일정을 찾는 날 수(오늘부터, 임시).
  static const targetSearchDays = 60;

  int _lastId = 0;

  /// 마지막으로 보낼 때 읽은 폰 DB의 값. 되묻기를 고른 뒤 이어지는 카드도 이것으로 찾는다.
  AssistantSnapshot _snapshot = const AssistantSnapshot();

  int _nextId() => ++_lastId;

  @override
  AssistantState build() => const AssistantState();

  /// 지금 문장을 보낼 수 있는지. 설정을 읽지 못하면 동의를 다시 묻는다.
  Future<AiGate> gate() async {
    if (ref.read(appModeProvider) == AppMode.demo) return AiGate.demo;
    if (!ref.read(parseClientProvider).isOpen) return AiGate.closed;
    if (state.declined) return AiGate.declined;
    switch (await ref.read(settingsRepositoryProvider).read()) {
      case Err(:final error):
        appLog(
          'assistant_settings_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        return AiGate.needsConsent;
      case Ok(:final value):
        if (!value.aiEnabled) return AiGate.needsConsent;
        // 오늘은 서버가 한도를 세는 한국 달력 날짜다(하루 경계와 관계없음).
        if (value.aiLimitReachedOn == isoDate(ref.read(clockProvider).now())) {
          return AiGate.limitReached;
        }
        return AiGate.open;
    }
  }

  /// AI 사용에 동의했다고 적는다(`aiEnabled`, `aiConsentAt`). 적지 못하면 false다.
  Future<bool> acceptConsent() async {
    final saved = await ref.read(settingsRepositoryProvider).writeAll({
      SettingKeys.aiEnabled: true,
      SettingKeys.aiConsentAt: ref.read(clockProvider).now(),
    });
    if (!ref.mounted) return false;
    final toast = ref.read(toastControllerProvider.notifier);
    switch (saved) {
      case Ok():
        // 이 화면에서 동의하지 않았다가 [AI 켜기]로 동의했으면 다시 보낼 수 있다.
        state = state.copyWith(declined: false);
        toast.show('AI 사용에 동의했어요 · ‘나’ 탭 › AI에서 언제든 끌 수 있어요');
        return true;
      case Err(:final error):
        appLog(
          'assistant_consent_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        toast.show(AppStrings.saveFailed);
        return false;
    }
  }

  /// 동의하지 않기로 했다. [text]는 보내지 않고 대화에 남기며, 이 화면에서는 다시 묻지 않는다.
  void decline(String text) {
    state = state.copyWith(
      declined: true,
      messages: [
        ...state.messages,
        UserMessage(_nextId(), text),
        InfoCard(_nextId(), InfoKind.aiDeclined),
      ],
    );
  }

  /// [raw]를 보낸다. 화면은 먼저 [gate]를 보고 동의를 받는다. 보낼 수 없으면 문장을 남기고 까닭을 안내하며, 직접
  /// 추가 폼을 열어야 하면(AI를 쓸 수 없음) 그 까닭을 돌려준다. 그 밖에는 null이다.
  Future<DirectAddNotice?> send(String raw, {required bool ruleMode}) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return null;
    final gate = await this.gate();
    if (!ref.mounted) return null;
    switch (gate) {
      case AiGate.needsConsent || AiGate.declined:
        decline(text);
        return DirectAddNotice.aiOff;
      case AiGate.limitReached:
        _append([
          UserMessage(_nextId(), text),
          InfoCard(_nextId(), InfoKind.limitReached),
        ]);
        return DirectAddNotice.limit;
      case AiGate.closed:
        _append([
          UserMessage(_nextId(), text),
          InfoCard(_nextId(), InfoKind.aiClosed),
        ]);
        return DirectAddNotice.closed;
      case AiGate.open || AiGate.demo:
        break;
    }
    final waiting = WaitingMessage(_nextId());
    state = state.copyWith(
      sending: true,
      messages: [...state.messages, UserMessage(_nextId(), text), waiting],
    );
    final watch = Stopwatch()..start();
    final now = ref.read(clockProvider).now();
    final courses = await _courses();
    if (!ref.mounted) return null;
    _snapshot = await _readSnapshot(courses, now);
    if (!ref.mounted) return null;
    final Result<ParseResult> result;
    if (gate == AiGate.demo) {
      await Future<void>.delayed(demoDelay);
      result = Ok(
        demoParseResult(
          text,
          now: now,
          courseNames: [for (final course in courses) course.name],
        ),
      );
    } else {
      result = await ref
          .read(parseClientProvider)
          .parse(
            ParseRequest.at(
              text,
              now: now,
              courseNames: [for (final course in courses) course.name],
            ),
          );
    }
    if (!ref.mounted) return null;
    final replies = switch (result) {
      Ok(:final value) => _replyTo(value, now: now, ruleMode: ruleMode),
      Err(:final error) => await _failed(error, text, now),
    };
    if (!ref.mounted) return null;
    appLog(
      'assistant_reply',
      area: 'assistant',
      data: {
        'intent': switch (result) {
          Ok(:final value) => value.intent.name,
          Err() => 'failed',
        },
        'cards': replies.length,
        'ms': watch.elapsedMilliseconds,
      },
    );
    state = state.copyWith(
      sending: false,
      messages: [
        for (final message in state.messages)
          if (message.id != waiting.id) message,
        ...replies,
      ],
    );
    return switch (result) {
      Err(error: ApiError(status: 429)) => DirectAddNotice.limit,
      Err(error: ApiError(code: 'ai_closed')) => DirectAddNotice.closed,
      Err(error: ApiError(status: null, code: null)) => DirectAddNotice.offline,
      _ => null,
    };
  }

  List<AssistantMessage> _replyTo(
    ParseResult result, {
    required DateTime now,
    required bool ruleMode,
  }) => replyCards(
    withAfternoonDefault(result),
    now: now,
    ruleMode: ruleMode,
    nextId: _nextId,
    snapshot: _snapshot,
  );

  /// 수업 변경·바꾸기·지우기가 찾을 폰 DB의 값. 읽지 못한 것은 빈 목록이다(찾지 못한 것으로 안내).
  Future<AssistantSnapshot> _readSnapshot(
    List<Course> courses,
    DateTime now,
  ) async {
    final today = _dateOf(now);
    final slots = switch (await ref.read(classSlotRepositoryProvider).read()) {
      Ok(:final value) => value,
      Err(:final error) => _logged(error, const <ClassSlotEntry>[]),
    };
    final schedule = switch (await ref
        .read(scheduleRepositoryProvider)
        .read(
          start: today,
          end: DateTime(today.year, today.month, today.day + targetSearchDays),
        )) {
      Ok(:final value) => value,
      Err(:final error) => _logged<Schedule?>(error, null),
    };
    final rules = await _rules() ?? const <Rule>[];
    return AssistantSnapshot(
      rules: rules,
      courses: courses,
      slots: slots,
      exceptions: schedule?.classExceptions ?? const [],
      fixedBlocks: schedule?.fixedBlocks ?? const [],
      events: [
        // 지난 일정은 바꾸지 않는다(오늘 0시 이후에 시작하는 일정만).
        for (final event in schedule?.events ?? const <Event>[])
          if (!event.startAt.isBefore(today)) event,
      ],
    );
  }

  T _logged<T>(AppError error, T fallback) {
    appLog(
      'assistant_snapshot_failed',
      area: 'assistant',
      data: errorLogData(error),
    );
    return fallback;
  }

  /// 보내지 못한 까닭의 카드. 오늘 사용량을 다 썼으면(429) 그날을 적어 두고 그날은 다시 보내지 않는다
  /// (docs/decisions.md 2026-11-15 '오늘 AI 사용량을 다 쓴 날을 기억한다').
  Future<List<AssistantMessage>> _failed(
    AppError error,
    String text,
    DateTime now,
  ) async {
    appLog(
      'assistant_parse_failed',
      area: 'assistant',
      data: errorLogData(error),
    );
    if (error case ApiError(status: 429)) {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .write(SettingKeys.aiLimitReachedOn, isoDate(now));
      if (saved case Err(error: final writeError)) {
        appLog(
          'assistant_limit_save_failed',
          area: 'assistant',
          data: errorLogData(writeError),
        );
      }
      return [InfoCard(_nextId(), InfoKind.limitReached)];
    }
    return switch (error) {
      ApiError(code: 'ai_closed') => [InfoCard(_nextId(), InfoKind.aiClosed)],
      ApiError(code: 'timeout') => [
        FailCard(_nextId(), FailKind.timeout, text: text),
      ],
      ApiError(status: null, code: null) => [
        FailCard(_nextId(), FailKind.offline, text: text),
      ],
      _ => [FailCard(_nextId(), FailKind.failed, text: text)],
    };
  }

  /// 되묻기 카드 [cardId]의 [index]번째를 고른다. 고른 날짜·시각으로 이어서 카드를 만든다.
  void pick(int cardId, int index) {
    final card = _find<AskCard>(cardId);
    if (card == null || card.picked != null) return;
    if (index < 0 || index >= card.options.length) return;
    final next = afterPick(
      card,
      index,
      now: ref.read(clockProvider).now(),
      nextId: _nextId,
      snapshot: _snapshot,
    );
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == cardId ? card.pick(index) : message,
        ...next,
      ],
    );
  }

  /// 시간 미정 일정 카드에 [startMin]부터 한 시간(임시)을 고른다.
  void pickEventTime(int cardId, int startMin) {
    final card = _pendingEvent(cardId);
    if (card == null || card.draft.repeating) return;
    _replace(
      card.copyWith(draft: card.draft.withTime(startMin, startMin + 60)),
    );
  }

  /// 일정 카드의 장소 칸을 연다.
  void openPlace(int cardId) {
    final card = _pendingEvent(cardId);
    if (card != null) _replace(card.copyWith(editPlace: true));
  }

  /// 일정 카드의 준비물 칸을 연다.
  void openPrep(int cardId) {
    final card = _pendingEvent(cardId);
    if (card != null) _replace(card.copyWith(editPrep: true));
  }

  /// 일정 카드의 장소를 바꾼다(40자까지, 빈 값이면 없앰).
  void setPlace(int cardId, String value) {
    final card = _pendingEvent(cardId);
    if (card != null) {
      _replace(card.copyWith(draft: card.draft.withPlace(_field(value))));
    }
  }

  /// 일정 카드의 준비물을 바꾼다(40자까지, 빈 값이면 없앰).
  void setPrep(int cardId, String value) {
    final card = _pendingEvent(cardId);
    if (card != null) {
      _replace(card.copyWith(draft: card.draft.withPrep(_field(value))));
    }
  }

  /// 일정 카드를 저장한다(한 번뿐이면 `events`, 매주 반복이면 `fixed_blocks`, 출처 `ai`).
  Future<void> saveEvent(int cardId) async {
    final card = _pendingEvent(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final before = ref.read(planControllerProvider);
    final now = ref.read(clockProvider).now();
    final draft = card.draft;
    final saved = await _saveDraft(draft, now);
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (saved case Err(:final error)) {
      appLog(
        'assistant_save_failed',
        area: 'assistant',
        data: errorLogData(error),
      );
      _replace(card.copyWith(status: CardStatus.pending));
      toast.show(AppStrings.saveFailed);
      return;
    }
    _replace(card.copyWith(status: CardStatus.saved, planNote: () => null));
    toast.show(
      '${withJosa(draft.title, Josa.eulReul)} '
      '${eventWhenText(draft, today: _dateOf(now))}에 넣었어요',
      undoable: true,
      onUndone: () => _unsave(cardId),
    );
    final after = await _recalculated();
    if (!ref.mounted) return;
    _noteIfSaved(cardId, eventPlanNote(before, after));
  }

  /// [draft]를 저장한다. [source]는 출처이고, [templatePrep]이면 준비물을 말하지 않은 반복 일정에 종류별 처음
  /// 준비물을 넣는다(직접 추가 폼은 준비물 칸을 보였으므로 비운 채면 그대로 둠).
  Future<Result<int>> _saveDraft(
    EventDraft draft,
    DateTime now, {
    EntrySource source = EntrySource.ai,
    bool templatePrep = true,
  }) async {
    try {
      if (draft.weekdays case final weekdays?) {
        final kind = draft.fixedKind ?? FixedBlockKind.other;
        final template = fixedBlockTemplate(kind);
        return await ref
            .read(fixedBlockRepositoryProvider)
            .add(
              name: draft.title,
              weekdays: weekdays,
              startMin: draft.startMin!,
              endMin: draft.endMin!,
              // 고정 일정 시트의 종류별 처음 값(앞뒤 여유, 운동이면 준비물)을 쓴다.
              bufferMin: template.bufferMin,
              kind: kind,
              prep:
                  draft.prep ??
                  (templatePrep && template.prep.isNotEmpty
                      ? template.prep
                      : null),
              place: draft.place,
              source: source,
              now: now,
            );
      }
      final date = draft.date!;
      return await ref
          .read(eventRepositoryProvider)
          .add(
            title: draft.title,
            // 시간 미정 일정은 종일 일정으로, 그날 0시부터 다음 날 0시까지다.
            startAt: draft.startAt ?? date,
            endAt: draft.endAt ?? DateTime(date.year, date.month, date.day + 1),
            allDay: draft.timeUnknown,
            place: draft.place,
            prep: draft.prep,
            reminderMinutes: draft.reminderMinutes,
            source: switch (source) {
              EntrySource.ai => EventSource.ai,
              EntrySource.manual => EventSource.manual,
            },
            now: now,
          );
    } on ArgumentError {
      // 카드·폼이 만든 값은 검사를 통과하므로 여기에 오지 않는다(오면 저장하지 못한 것으로 알림).
      return const Err(
        StorageError('assistant.saveEvent', causeType: 'ArgumentError'),
      );
    }
  }

  /// 할 일 카드의 종류를 고른다(과목 할 일만).
  void setTaskKind(int cardId, TaskKind kind) {
    final card = _pendingTask(cardId);
    if (card == null || card.draft.courseName == null) return;
    if (!courseTaskKinds.contains(kind)) return;
    _replace(card.copyWith(draft: card.draft.withKind(kind)));
  }

  /// 할 일 카드의 예상 시간을 고른다(분).
  void setTaskEstimate(int cardId, int minutes) {
    final card = _pendingTask(cardId);
    if (card == null || minutes <= 0) return;
    _replace(card.copyWith(draft: card.draft.withEstimate(minutes)));
  }

  /// 할 일 카드를 저장한다(출처 `ai`, 과목 할 일이면 과목을 함께 저장).
  Future<void> saveTask(int cardId) async {
    final card = _pendingTask(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final draft = card.draft;
    final courses = await _courses();
    if (!ref.mounted) return;
    final courseId = draft.courseName == null
        ? null
        : courses
              .where((course) => course.name == draft.courseName)
              .firstOrNull
              ?.id;
    final now = ref.read(clockProvider).now();
    final Result<int> saved;
    try {
      saved = await ref
          .read(taskRepositoryProvider)
          .add(
            title: draft.title,
            kind: draft.kind,
            dueAt: draft.dueAt,
            dueTimeUnknown: draft.dueTimeUnknown,
            estimateMin: draft.estimateToStore,
            courseId: courseId,
            source: EntrySource.ai,
            now: now,
          );
    } on ArgumentError {
      return _taskSaveFailed(
        card,
        const StorageError('assistant.saveTask', causeType: 'ArgumentError'),
      );
    }
    if (!ref.mounted) return;
    final int taskId;
    switch (saved) {
      case Err(:final error):
        return _taskSaveFailed(card, error);
      case Ok(:final value):
        taskId = value;
    }
    _replace(
      card.copyWith(
        status: CardStatus.saved,
        savedTaskId: () => taskId,
        planNote: () => null,
      ),
    );
    ref
        .read(toastControllerProvider.notifier)
        .show(
          '${withJosa(draft.title, Josa.eulReul)} 할 일에 넣었어요',
          undoable: true,
          onUndone: () => _unsave(cardId),
        );
    await _noteTaskPlan(cardId, draft, taskId: taskId, courseId: courseId);
  }

  /// 넣은 할 일 카드 [cardId]에 다시 계산한 뒤 놓인 자리를 적는다.
  Future<void> _noteTaskPlan(
    int cardId,
    TaskDraft draft, {
    required int taskId,
    required int? courseId,
  }) async {
    final after = await _recalculated();
    if (!ref.mounted) return;
    final estimate = taskEstimateOf(
      draft,
      courseId: courseId,
      config: ref.read(plannerConfigProvider),
    ).minutes;
    final settings = ref.read(settingsProvider).value;
    final hasTimetable = switch (await ref
        .read(classSlotRepositoryProvider)
        .read()) {
      Ok(:final value) => value.isNotEmpty,
      // 읽지 못하면 시간표가 있는 것으로 보고 결과만 적는다.
      Err() => true,
    };
    if (!ref.mounted) return;
    _noteIfSaved(
      cardId,
      taskPlanNote(
        draft: draft,
        taskId: taskId,
        estimate: estimate,
        plan: after,
        hasTimetable: hasTimetable,
        now: ref.read(clockProvider).now(),
        dayBoundaryMin: settings?.dayBoundaryMin ?? Defaults.dayBoundaryMin,
      ),
    );
  }

  /// 직접 추가 폼의 [form]을 저장한다(폼에서 새로 넣은 것은 출처 `manual`, 카드의 [고치기]로 고친 것은 출처
  /// `ai`). 저장하면 되돌리기 토스트를 띄우고, [origin]에 따라 대화에 카드를 남기거나([DirectAddOrigin.chat]) 고친
  /// 카드 [cardId]를 넣은 것으로 바꾼다([DirectAddOrigin.card]). 되돌리면 그 카드를 빼거나 저장 전으로 돌리고
  /// [onUndone]을 부른다. 저장하지 못하면 알리고 false다.
  Future<bool> saveDirect(
    DirectAddDraft form, {
    required DirectAddOrigin origin,
    int? cardId,
    void Function()? onUndone,
  }) async {
    final edited = origin == DirectAddOrigin.card;
    final source = edited ? EntrySource.ai : EntrySource.manual;
    final before = ref.read(planControllerProvider);
    final now = ref.read(clockProvider).now();
    final toast = ref.read(toastControllerProvider.notifier);
    final previous = cardId == null ? null : _find<AssistantMessage>(cardId);
    final say = switch (previous) {
      EventCard(:final say) || TaskCard(:final say) => say,
      _ => null,
    };
    // 고친 카드가 그사이 없어졌으면 대화에 새로 남긴다.
    final where = edited && previous == null ? DirectAddOrigin.chat : origin;
    if (form.kind == DirectAddKind.task) {
      final draft = form.toTaskDraft();
      final courseName = draft.courseName;
      final courses = courseName == null ? const <Course>[] : await _courses();
      if (!ref.mounted) return false;
      final courseId = courses
          .where((course) => course.name == courseName)
          .firstOrNull
          ?.id;
      final Result<int> saved;
      try {
        saved = await ref
            .read(taskRepositoryProvider)
            .add(
              title: draft.title,
              kind: draft.kind,
              dueAt: draft.dueAt,
              dueTimeUnknown: draft.dueTimeUnknown,
              estimateMin: draft.estimateToStore,
              courseId: courseId,
              source: source,
              now: now,
            );
      } on ArgumentError {
        return _directFailed(
          const StorageError(
            'assistant.saveDirect',
            causeType: 'ArgumentError',
          ),
        );
      }
      if (!ref.mounted) return false;
      final int taskId;
      switch (saved) {
        case Err(:final error):
          return _directFailed(error);
        case Ok(:final value):
          taskId = value;
      }
      final card = switch (where) {
        DirectAddOrigin.screen => null,
        DirectAddOrigin.chat => TaskCard(
          _nextId(),
          draft: draft,
          status: CardStatus.saved,
          savedTaskId: taskId,
          origin: CardOrigin.manual,
        ),
        DirectAddOrigin.card => TaskCard(
          cardId!,
          draft: draft,
          say: say,
          status: CardStatus.saved,
          savedTaskId: taskId,
          origin: CardOrigin.edited,
        ),
      };
      _placeDirect(card, where);
      toast.show(
        '${withJosa(draft.title, Josa.eulReul)} 할 일에 넣었어요',
        undoable: true,
        onUndone: () => _undoDirect(card?.id, where, onUndone),
      );
      // 다시 계산은 기다리지 않는다(폼은 바로 닫고, 놓인 자리는 카드에 나중에 적음).
      if (card != null) {
        unawaited(
          _noteTaskPlan(card.id, draft, taskId: taskId, courseId: courseId),
        );
      }
      return true;
    }
    final draft = form.toEventDraft();
    final saved = await _saveDraft(
      draft,
      now,
      source: source,
      templatePrep: false,
    );
    if (!ref.mounted) return false;
    if (saved case Err(:final error)) return _directFailed(error);
    final card = switch (where) {
      DirectAddOrigin.screen => null,
      DirectAddOrigin.chat => EventCard(
        _nextId(),
        draft: draft,
        status: CardStatus.saved,
        origin: CardOrigin.manual,
      ),
      DirectAddOrigin.card => EventCard(
        cardId!,
        draft: draft,
        say: say,
        status: CardStatus.saved,
        origin: CardOrigin.edited,
      ),
    };
    _placeDirect(card, where);
    toast.show(
      '${withJosa(draft.title, Josa.eulReul)} '
      '${eventWhenText(draft, today: _dateOf(now))}에 넣었어요',
      undoable: true,
      onUndone: () => _undoDirect(card?.id, where, onUndone),
    );
    if (card != null) unawaited(_noteEventPlan(card.id, before));
    return true;
  }

  /// 넣은 일정 카드 [cardId]에 다시 계산한 뒤 옮긴 제안을 적는다. [before]는 넣기 직전의 배치 결과다.
  Future<void> _noteEventPlan(int cardId, PlanResult? before) async {
    final after = await _recalculated();
    if (!ref.mounted) return;
    _noteIfSaved(cardId, eventPlanNote(before, after));
  }

  /// 폼으로 넣은 카드를 대화에 붙이거나 고친 카드와 바꾼다.
  void _placeDirect(AssistantMessage? card, DirectAddOrigin where) {
    if (card == null) return;
    if (where == DirectAddOrigin.card) {
      _replace(card);
    } else {
      _append([card]);
    }
  }

  /// 폼으로 넣은 것을 되돌렸다. 대화에 남긴 카드는 빼고, 고친 카드는 고친 값 그대로 저장 전으로 돌린다.
  void _undoDirect(int? cardId, DirectAddOrigin where, void Function()? done) {
    if (ref.mounted && cardId != null) {
      switch (where) {
        case DirectAddOrigin.chat:
          state = state.copyWith(
            messages: [
              for (final message in state.messages)
                if (message.id != cardId) message,
            ],
          );
        case DirectAddOrigin.card:
          switch (_find<AssistantMessage>(cardId)) {
            case final EventCard card when card.status == CardStatus.saved:
              _replace(
                card.copyWith(
                  status: CardStatus.pending,
                  planNote: () => null,
                  origin: CardOrigin.ai,
                ),
              );
            case final TaskCard card when card.status == CardStatus.saved:
              _replace(
                card.copyWith(
                  status: CardStatus.pending,
                  savedTaskId: () => null,
                  planNote: () => null,
                  origin: CardOrigin.ai,
                ),
              );
            default:
              break;
          }
        case DirectAddOrigin.screen:
          break;
      }
    }
    done?.call();
  }

  bool _directFailed(AppError error) {
    appLog(
      'assistant_save_failed',
      area: 'assistant',
      data: errorLogData(error),
    );
    if (ref.mounted) {
      ref.read(toastControllerProvider.notifier).show(AppStrings.saveFailed);
    }
    return false;
  }

  void _taskSaveFailed(TaskCard card, AppError error) {
    appLog(
      'assistant_save_failed',
      area: 'assistant',
      data: errorLogData(error),
    );
    _replace(card.copyWith(status: CardStatus.pending));
    ref.read(toastControllerProvider.notifier).show(AppStrings.saveFailed);
  }

  /// 수업 변경 카드를 적용한다(그날 하루만, 출처 `ai`). 이미 그 상태면 쓰지 않고 알린다.
  Future<void> applyException(int cardId) async {
    final card = _pendingException(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final before = ref.read(planControllerProvider);
    final now = ref.read(clockProvider).now();
    final draft = card.draft;
    final freeBefore = await _freeMinutesOn(draft.date);
    if (!ref.mounted) return;
    final repository = ref.read(classExceptionRepositoryProvider);
    Result<bool> saved;
    try {
      if (draft.kind == ClassExceptionKind.makeup) {
        saved = switch (await repository.addMakeup(
          draft.slotId,
          draft.date,
          startMin: draft.startMin,
          endMin: draft.endMin,
          place: draft.place,
          source: EntrySource.ai,
          now: now,
        )) {
          Ok() => const Ok(true),
          Err(:final error) => Err(error),
        };
      } else {
        saved = await repository.setDayChange(
          draft.slotId,
          draft.date,
          kind: draft.kind,
          place: draft.kind == ClassExceptionKind.cancelled
              ? null
              : draft.place,
          source: EntrySource.ai,
          now: now,
        );
      }
    } on ArgumentError {
      saved = const Err(
        StorageError('assistant.applyException', causeType: 'ArgumentError'),
      );
    }
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    final name = exceptionKindName(draft.kind);
    switch (saved) {
      case Err(:final error):
        appLog(
          'assistant_save_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        _replace(card.copyWith(status: CardStatus.pending));
        toast.show(AppStrings.saveFailed);
        return;
      case Ok(value: false):
        // 이미 그 상태라 아무것도 쓰지 않았다(되돌릴 것이 없음).
        _replace(card.copyWith(status: CardStatus.saved, planNote: () => null));
        toast.show('이미 ${withJosa(name, Josa.euroRo)} 표시돼 있어요');
        return;
      case Ok():
        _replace(card.copyWith(status: CardStatus.saved, planNote: () => null));
        toast.show(
          '${draft.date.month}월 ${draft.date.day}일 ${draft.courseName} '
          '${withJosa(name, Josa.euroRo)} 표시했어요',
          undoable: true,
          onUndone: () => _unsave(cardId),
        );
    }
    final after = await _recalculated();
    if (!ref.mounted) return;
    final freeAfter = await _freeMinutesOn(draft.date);
    if (!ref.mounted) return;
    final freed = freeBefore == null || freeAfter == null
        ? 0
        : freeAfter - freeBefore;
    final notes = [
      if (freed > 0) '이동·여유 시간까지 빈 시간 ${durationText(freed)}이 생겼어요',
      ?replanNote(before, after),
    ];
    _noteIfSaved(cardId, notes.isEmpty ? null : notes.join(' · '));
  }

  /// 수업 변경·내 규칙 카드를 적용하지 않는다([취소]) · 바꾸기·지우기·규칙 지우기 카드를 그대로 둔다
  /// ([그대로 두기]).
  void skipCard(int cardId) {
    switch (_find<AssistantMessage>(cardId)) {
      case final ExceptionCard card when card.status == CardStatus.pending:
        _replace(card.copyWith(status: CardStatus.declined));
      case final ChangeCard card when card.status == CardStatus.pending:
        _replace(card.copyWith(status: CardStatus.declined));
      case final RuleCard card when card.status == CardStatus.pending:
        _replace(card.copyWith(status: CardStatus.declined));
      case final RuleRemoveCard card when card.status == CardStatus.pending:
        _replace(card.copyWith(status: CardStatus.declined));
      default:
        break;
    }
  }

  /// 내 규칙 카드를 저장한다(출처 `ai`, 사용자가 보낸 문장과 함께). 저장한 뒤 다시 계산하고, 새 규칙과
  /// 겹치게 된 확정 블록을 찾아 카드에 적는다.
  Future<void> saveRule(int cardId) async {
    final card = _pendingRule(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final draft = card.draft;
    final before = ref.read(planControllerProvider);
    final beforeRules = await _rules();
    if (!ref.mounted) return;
    final now = ref.read(clockProvider).now();
    Result<Rule> saved;
    try {
      saved = await ref
          .read(rulesRepositoryProvider)
          .save(
            kind: draft.kind,
            params: draft.params,
            weekdays: draft.weekdays,
            source: EntrySource.ai,
            sentence: _sentenceBefore(cardId),
            now: now,
          );
    } on ArgumentError {
      saved = const Err(
        StorageError('assistant.saveRule', causeType: 'ArgumentError'),
      );
    }
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (saved case Err(:final error)) {
      appLog(
        'assistant_save_failed',
        area: 'assistant',
        data: errorLogData(error),
      );
      _replace(card.copyWith(status: CardStatus.pending));
      toast.show(AppStrings.saveFailed);
      return;
    }
    _replace(
      card.copyWith(
        status: CardStatus.saved,
        planNote: () => null,
        conflicts: const [],
      ),
    );
    toast.show(
      '${withJosa(ruleKindName(draft.kind), Josa.eulReul)} 저장했어요',
      undoable: true,
      onUndone: () => _unsave(cardId),
    );
    final after = await _recalculated();
    if (!ref.mounted) return;
    final afterRules = await _rules();
    if (!ref.mounted) return;
    final conflicts = beforeRules == null || afterRules == null
        ? const <RuleConflict>[]
        : await _conflicts(beforeRules, afterRules);
    if (!ref.mounted) return;
    if (_find<RuleCard>(cardId) case final current?
        when current.status == CardStatus.saved) {
      _replace(
        current.copyWith(
          planNote: () => replanNote(before, after),
          conflicts: conflicts,
        ),
      );
    }
  }

  /// 새 규칙과 겹치게 된 확정 블록([옮기기])을 지우고 다시 계산한다. 그 할 일의 다음 제안을 카드에 적는다.
  Future<void> moveConflict(int cardId, int blockId) async {
    final conflict = _askingConflict(cardId, blockId);
    if (conflict == null) return;
    final now = ref.read(clockProvider).now();
    final dismissed = await ref
        .read(planBlockRepositoryProvider)
        .dismiss(blockId, now: now);
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    switch (dismissed) {
      case Err(:final error):
        appLog(
          'assistant_save_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        toast.show(AppStrings.saveFailed);
        return;
      case Ok(value: false):
        // 그사이 끝냈거나 지운 블록이다. 옮길 것이 없으므로 그대로 둔 것으로 적는다.
        _answerConflict(cardId, conflict.answered(ConflictAnswer.kept));
        return;
      case Ok():
        break;
    }
    toast.show(
      '${withJosa(conflict.title, Josa.eulReul)} 다른 빈 시간에 다시 놓았어요',
      undoable: true,
      onUndone: () => _answerConflict(cardId, conflict),
    );
    _answerConflict(cardId, conflict.answered(ConflictAnswer.moved));
    final after = await _recalculated();
    if (!ref.mounted) return;
    final next = [
      for (final block in after?.blocks ?? const <BlockDraft>[])
        // 지금 시작하는 제안도 든다(배치는 지금부터 놓음).
        if (block.taskId == conflict.block.taskId &&
            !block.startAt.isBefore(now))
          block,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (next.firstOrNull case final first?) {
      final current = _find<RuleCard>(cardId)?.conflicts
          .where((item) => item.block.id == blockId)
          .firstOrNull;
      if (current?.answer == ConflictAnswer.moved) {
        _answerConflict(
          cardId,
          conflict.answered(
            ConflictAnswer.moved,
            movedStart: first.startAt,
            movedEnd: first.endAt,
          ),
        );
      }
    }
  }

  /// 새 규칙과 겹치게 된 확정 블록을 그대로 둔다([그대로 두기]).
  void keepConflict(int cardId, int blockId) {
    final conflict = _askingConflict(cardId, blockId);
    if (conflict != null) {
      _answerConflict(cardId, conflict.answered(ConflictAnswer.kept));
    }
  }

  /// 내 규칙 지우기 카드를 적용한다. 그사이 규칙이 없어졌으면 알린다.
  Future<void> removeRule(int cardId) async {
    final card = _pendingRuleRemove(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final before = ref.read(planControllerProvider);
    final now = ref.read(clockProvider).now();
    final deleted = await ref
        .read(rulesRepositoryProvider)
        .delete(card.rule.id, now: now);
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    switch (deleted) {
      case Err(:final error):
        appLog(
          'assistant_save_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        _replace(card.copyWith(status: CardStatus.pending));
        toast.show(AppStrings.saveFailed);
        return;
      case Ok(value: false):
        _replace(card.copyWith(status: CardStatus.pending));
        toast.show('그 규칙을 찾지 못했어요 · 이미 지웠을 수 있어요');
        return;
      case Ok():
        _replace(card.copyWith(status: CardStatus.saved, planNote: () => null));
        toast.show(
          '${ruleKindName(card.rule.kind)} 규칙을 지웠어요',
          undoable: true,
          onUndone: () => _unsave(cardId),
        );
    }
    final after = await _recalculated();
    if (!ref.mounted) return;
    _noteIfSaved(cardId, replanNote(before, after));
  }

  /// 지울 규칙이 여럿일 때 [index]번째를 고른다. 고른 규칙의 지우기 카드를 이어서 붙인다.
  void pickRule(int cardId, int index) {
    final card = _find<RulePickCard>(cardId);
    if (card == null || card.picked != null) return;
    if (index < 0 || index >= card.rules.length) return;
    final next = afterRulePick(card, index, nextId: _nextId);
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == cardId ? card.pick(index) : message,
        next,
      ],
    );
  }

  /// 저장 전과 뒤의 규칙으로, 새 규칙과 겹치게 된 확정 블록(오늘부터 배치 지평). 읽지 못하면 빈 목록이다.
  Future<List<RuleConflict>> _conflicts(
    List<Rule> before,
    List<Rule> after,
  ) async {
    final now = ref.read(clockProvider).now();
    final boundary = switch (await ref
        .read(settingsRepositoryProvider)
        .read()) {
      Ok(:final value) => value.dayBoundaryMin,
      Err() => Defaults.dayBoundaryMin,
    };
    final today = logicalDate(now, dayBoundaryMin: boundary);
    final schedule = await ref
        .read(scheduleRepositoryProvider)
        .read(
          start: logicalDayStart(today, dayBoundaryMin: boundary),
          end: logicalDayEnd(
            DateTime(
              today.year,
              today.month,
              today.day + Defaults.planHorizonDays - 1,
            ),
            dayBoundaryMin: boundary,
          ),
        );
    final Schedule range;
    switch (schedule) {
      case Ok(:final value):
        range = value;
      case Err(:final error):
        return _logged(error, const <RuleConflict>[]);
    }
    final titles = switch (await ref.read(taskRepositoryProvider).read()) {
      Ok(:final value) => {
        for (final entry in value) entry.task.id: entry.task.title,
      },
      Err() => const <int, String>{},
    };
    final broken = blocksBrokenBy(
      range,
      before: PlannerConfig.from(before),
      after: PlannerConfig.from(after),
      now: now,
      dayBoundaryMin: boundary,
    );
    return [
      for (final block in broken)
        RuleConflict(block: block, title: titles[block.taskId] ?? '할 일'),
    ];
  }

  RuleConflict? _askingConflict(int cardId, int blockId) {
    final card = _find<RuleCard>(cardId);
    if (card == null || card.status != CardStatus.saved) return null;
    return card.conflicts
        .where(
          (conflict) =>
              conflict.block.id == blockId &&
              conflict.answer == ConflictAnswer.ask,
        )
        .firstOrNull;
  }

  void _answerConflict(int cardId, RuleConflict answered) {
    final card = _find<RuleCard>(cardId);
    if (card == null) return;
    _replace(
      card.copyWith(
        conflicts: [
          for (final conflict in card.conflicts)
            conflict.block.id == answered.block.id ? answered : conflict,
        ],
      ),
    );
  }

  /// 내 규칙 전부. 읽지 못하면 null이다.
  Future<List<Rule>?> _rules() async {
    switch (await ref.read(rulesRepositoryProvider).read()) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        return _logged<List<Rule>?>(error, null);
    }
  }

  /// [cardId] 카드를 만든 사용자 문장(그 카드 앞의 마지막 문장). 없으면 null이다.
  String? _sentenceBefore(int cardId) {
    String? sentence;
    for (final message in state.messages) {
      if (message.id == cardId) return sentence;
      if (message is UserMessage) sentence = message.text;
    }
    return null;
  }

  /// 바꾸거나 지울 일정이 여럿일 때 [index]번째를 고른다. 고른 일정의 카드를 이어서 붙인다.
  void pickTarget(int cardId, int index) {
    final card = _find<TargetPickCard>(cardId);
    if (card == null || card.picked != null) return;
    if (index < 0 || index >= card.candidates.length) return;
    final next = afterTargetPick(card, index, nextId: _nextId);
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == cardId ? card.pick(index) : message,
        next,
      ],
    );
  }

  /// 바꾸기·지우기 카드를 적용한다. 일정이 그사이 없어졌으면 알린다.
  Future<void> applyChange(int cardId) async {
    final card = _pendingChange(cardId);
    if (card == null) return;
    _replace(card.copyWith(status: CardStatus.saving));
    final now = ref.read(clockProvider).now();
    Result<bool> saved;
    try {
      saved = await switch ((card.target, card.after)) {
        (EventTarget(:final event), _) when card.delete =>
          ref.read(eventRepositoryProvider).delete(event.id, now: now),
        (FixedTarget(:final block), _) when card.delete =>
          ref.read(fixedBlockRepositoryProvider).delete(block.id, now: now),
        (
          EventTarget(:final event),
          EventAfter(:final startAt, :final endAt, :final allDay),
        ) =>
          ref
              .read(eventRepositoryProvider)
              .update(
                event.id,
                title: event.title,
                startAt: startAt,
                endAt: endAt,
                allDay: allDay,
                place: event.place,
                prep: event.prep,
                reminderMinutes: event.reminderMinutes,
                now: now,
              ),
        (
          FixedTarget(:final block),
          FixedAfter(:final weekdays, :final startMin, :final endMin),
        ) =>
          ref
              .read(fixedBlockRepositoryProvider)
              .update(
                block.id,
                name: block.name,
                weekdays: weekdays,
                startMin: startMin,
                endMin: endMin,
                bufferMin: block.bufferMin,
                kind: block.kind,
                prep: block.prep,
                place: block.place,
                now: now,
              ),
        // 카드가 만든 값은 짝이 맞으므로 여기에 오지 않는다.
        _ => Future.value(
          const Err<bool>(
            StorageError('assistant.applyChange', causeType: 'StateError'),
          ),
        ),
      };
    } on ArgumentError {
      saved = const Err(
        StorageError('assistant.applyChange', causeType: 'ArgumentError'),
      );
    }
    if (!ref.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    switch (saved) {
      case Err(:final error):
        appLog(
          'assistant_save_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        _replace(card.copyWith(status: CardStatus.pending));
        toast.show(AppStrings.saveFailed);
      case Ok(value: false):
        _replace(card.copyWith(status: CardStatus.pending));
        toast.show('그 일정을 찾지 못했어요 · 이미 지웠을 수 있어요');
      case Ok():
        _replace(card.copyWith(status: CardStatus.saved));
        final title = card.target.title;
        final after = card.after;
        toast.show(
          card.delete || after == null
              ? '${withJosa(title, Josa.eulReul)} 지웠어요'
              : '${withJosa(title, Josa.eulReul)} '
                    '${withJosa(afterWhenText(after, today: _dateOf(now)), Josa.euroRo)} '
                    '바꿨어요',
          undoable: true,
          onUndone: () => _unsave(cardId),
        );
    }
  }

  /// 그날(논리적 하루) 빈 시간의 합(분). 읽지 못하면 null이다.
  Future<int?> _freeMinutesOn(DateTime date) async {
    final settings = await ref.read(settingsRepositoryProvider).read();
    final rules = await ref.read(rulesRepositoryProvider).read();
    if (!ref.mounted) return null;
    final boundary = switch (settings) {
      Ok(:final value) => value.dayBoundaryMin,
      Err() => Defaults.dayBoundaryMin,
    };
    final List<Rule> ruleList;
    switch (rules) {
      case Ok(:final value):
        ruleList = value;
      case Err():
        return null;
    }
    final day = DateTime(date.year, date.month, date.day);
    final schedule = await ref
        .read(scheduleRepositoryProvider)
        .read(
          start: logicalDayStart(day, dayBoundaryMin: boundary),
          end: logicalDayEnd(day, dayBoundaryMin: boundary),
        );
    return switch (schedule) {
      Ok(:final value) => dayAvailability(
        day,
        schedule: value,
        config: PlannerConfig.from(ruleList),
        dayBoundaryMin: boundary,
      ).free.fold<int>(0, (sum, span) => sum + span.minutes),
      Err() => null,
    };
  }

  /// 대화를 비운다(위 막대의 '새 대화').
  void reset() {
    if (state.sending) return;
    state = state.copyWith(messages: const []);
  }

  /// 되돌린 카드를 저장 전으로 돌린다.
  void _unsave(int cardId) {
    if (!ref.mounted) return;
    switch (_find<AssistantMessage>(cardId)) {
      case final EventCard card when card.status == CardStatus.saved:
        _replace(
          card.copyWith(status: CardStatus.pending, planNote: () => null),
        );
      case final TaskCard card when card.status == CardStatus.saved:
        _replace(
          card.copyWith(
            status: CardStatus.pending,
            savedTaskId: () => null,
            planNote: () => null,
          ),
        );
      case final ExceptionCard card when card.status == CardStatus.saved:
        _replace(
          card.copyWith(status: CardStatus.pending, planNote: () => null),
        );
      case final ChangeCard card when card.status == CardStatus.saved:
        _replace(card.copyWith(status: CardStatus.pending));
      case final RuleCard card when card.status == CardStatus.saved:
        _replace(
          card.copyWith(
            status: CardStatus.pending,
            planNote: () => null,
            conflicts: const [],
          ),
        );
      case final RuleRemoveCard card when card.status == CardStatus.saved:
        _replace(
          card.copyWith(status: CardStatus.pending, planNote: () => null),
        );
      default:
        break;
    }
  }

  /// 아직 저장한 채라면 [note]를 적는다(그사이 되돌렸으면 적지 않음).
  void _noteIfSaved(int cardId, String? note) {
    switch (_find<AssistantMessage>(cardId)) {
      case final EventCard card when card.status == CardStatus.saved:
        _replace(card.copyWith(planNote: () => note));
      case final TaskCard card when card.status == CardStatus.saved:
        _replace(card.copyWith(planNote: () => note));
      case final ExceptionCard card when card.status == CardStatus.saved:
        _replace(card.copyWith(planNote: () => note));
      case final RuleRemoveCard card when card.status == CardStatus.saved:
        _replace(card.copyWith(planNote: () => note));
      default:
        break;
    }
  }

  /// 바로 다시 계산한 결과. 다른 계산이 돌던 중이었으면 그것이 끝난 뒤 한 번 더 돌려, 방금 저장한 것을 넣은
  /// 결과를 본다. 계산하지 못했으면 null이다.
  Future<PlanResult?> _recalculated() async {
    final plans = ref.read(planControllerProvider.notifier);
    await plans.recalculate();
    await plans.recalculate();
    if (!ref.mounted) return null;
    return ref.read(planControllerProvider);
  }

  /// 고를 수 있는 과목. 읽지 못하면 빈 목록이다(과목 없이 보냄).
  Future<List<Course>> _courses() async {
    switch (await ref.read(courseRepositoryProvider).readSelectable()) {
      case Ok(:final value):
        return value;
      case Err(:final error):
        appLog(
          'assistant_courses_failed',
          area: 'assistant',
          data: errorLogData(error),
        );
        return const [];
    }
  }

  EventCard? _pendingEvent(int cardId) {
    final card = _find<EventCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  TaskCard? _pendingTask(int cardId) {
    final card = _find<TaskCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  ExceptionCard? _pendingException(int cardId) {
    final card = _find<ExceptionCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  ChangeCard? _pendingChange(int cardId) {
    final card = _find<ChangeCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  RuleCard? _pendingRule(int cardId) {
    final card = _find<RuleCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  RuleRemoveCard? _pendingRuleRemove(int cardId) {
    final card = _find<RuleRemoveCard>(cardId);
    return card?.status == CardStatus.pending ? card : null;
  }

  T? _find<T extends AssistantMessage>(int id) {
    for (final message in state.messages) {
      if (message.id == id && message is T) return message;
    }
    return null;
  }

  void _replace(AssistantMessage card) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          message.id == card.id ? card : message,
      ],
    );
  }

  void _append(List<AssistantMessage> messages) {
    state = state.copyWith(messages: [...state.messages, ...messages]);
  }
}

/// 장소·준비물 칸의 값. 앞뒤 공백을 지우고 40자까지, 비면 null이다.
String? _field(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final runes = text.runes.toList();
  return runes.length <= 40 ? text : String.fromCharCodes(runes.take(40));
}

DateTime _dateOf(DateTime at) => DateTime(at.year, at.month, at.day);
