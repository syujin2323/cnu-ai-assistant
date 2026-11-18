// 06 AI 비서의 대화와 카드 동작. docs/screens.md '06 AI 비서'·'AI 사용 동의', docs/architecture.md 'POST
// /v1/parse'·'데모 모드'·'폰 DB'의 되돌리기.
//
// 문장을 보내기 전에 AI를 쓸 수 있는지 본다([AssistantController.gate]). AI 사용에 동의하지 않았으면 화면이 AI
// 사용 동의 시트를 열고(먼저 쓴 문장은 '동의하면 보낼 문장'), 동의하면 적은 뒤 보낸다. 오늘 사용량을 다 썼으면
// 보내지 않는다. 데모 모드는 서버·AI를 부르지 않고 미리 적은 응답 가운데 가장 비슷한 것을 쓴다
// (`data/demo/demo_parse.dart`). 응답은 오전·오후를 말하지 않은 1–7시를 오후로 고친 뒤 카드로 바꾼다
// (`domain/assistant/assistant_reply.dart`).
//
// 확인 버튼을 누를 때만 저장하고, 저장할 때마다 되돌리기 토스트를 띄운다. 토스트의 '되돌리기'로 되돌리면 그
// 카드를 저장 전으로 돌린다. 저장한 뒤에는 바로 다시 계산해 옮겨진 제안이나 놓인 자리를 카드에 적는다. 대화는
// 화면을 닫으면 버린다(autoDispose). 로그에는 문장·제목을 남기지 않고 의도 이름과 카드 수만 남긴다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/data/api/parse_client.dart';
import 'package:cnu_ai_assistant/data/demo/demo_parse.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/clock.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/parse_checks.dart';
import 'package:cnu_ai_assistant/domain/planner/plan_range.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 문장을 지금 보낼 수 있는지.
enum AiGate {
  /// 보낼 수 있다.
  open,

  /// AI 사용에 동의하지 않았다(화면이 동의 시트를 연다).
  needsConsent,

  /// 이 화면에서 동의하지 않기로 했다(다시 묻지 않음).
  declined,

  /// 오늘 사용량을 다 썼다.
  limitReached,

  /// 데모 모드(미리 적은 응답).
  demo,
}

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

/// 06 AI 비서가 고를 수 있는 과목(직접 만든 과목과 가장 최근 학기의 LMS 과목). 할 일 카드의 예상 시간 규칙에 쓴다.
final assistantCoursesProvider = StreamProvider.autoDispose<List<Course>>(
  (ref) => ref.watch(courseRepositoryProvider).watchSelectable(),
);

class AssistantController extends Notifier<AssistantState> {
  /// 데모 응답을 보이기 전에 기다리는 시간(답을 읽는 것처럼 보이게, 임시).
  static const demoDelay = Duration(milliseconds: 700);

  int _lastId = 0;

  int _nextId() => ++_lastId;

  @override
  AssistantState build() => const AssistantState();

  /// 지금 문장을 보낼 수 있는지. 설정을 읽지 못하면 동의를 다시 묻는다.
  Future<AiGate> gate() async {
    if (ref.read(appModeProvider) == AppMode.demo) return AiGate.demo;
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
        toast.show('AI 사용에 동의했어요 · 나 › AI에서 언제든 끌 수 있어요');
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

  /// [raw]를 보낸다. 화면은 먼저 [gate]를 보고 동의를 받는다. 보낼 수 없으면 문장을 남기고 까닭을 안내한다.
  Future<void> send(String raw, {required bool ruleMode}) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return;
    final gate = await this.gate();
    if (!ref.mounted) return;
    switch (gate) {
      case AiGate.needsConsent || AiGate.declined:
        decline(text);
        return;
      case AiGate.limitReached:
        _append([
          UserMessage(_nextId(), text),
          InfoCard(_nextId(), InfoKind.limitReached),
        ]);
        return;
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
    if (!ref.mounted) return;
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
    if (!ref.mounted) return;
    final replies = switch (result) {
      Ok(:final value) => _replyTo(value, now: now, ruleMode: ruleMode),
      Err(:final error) => await _failed(error, text, now),
    };
    if (!ref.mounted) return;
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
  );

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

  Future<Result<int>> _saveDraft(EventDraft draft, DateTime now) async {
    try {
      if (draft.weekdays case final weekdays?) {
        return await ref
            .read(fixedBlockRepositoryProvider)
            .add(
              name: draft.title,
              weekdays: weekdays,
              startMin: draft.startMin!,
              endMin: draft.endMin!,
              bufferMin: 0,
              kind: draft.fixedKind ?? FixedBlockKind.other,
              prep: draft.prep,
              place: draft.place,
              source: EntrySource.ai,
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
            source: EventSource.ai,
            now: now,
          );
    } on ArgumentError {
      // 카드가 만든 값은 검사를 통과하므로 여기에 오지 않는다(오면 저장하지 못한 것으로 알림).
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
    final after = await _recalculated();
    if (!ref.mounted) return;
    final estimate = taskEstimateOf(
      draft,
      courseId: courseId,
      config: ref.read(plannerConfigProvider),
    ).minutes;
    final settings = ref.read(settingsProvider).value;
    _noteIfSaved(
      cardId,
      taskPlanNote(
        draft: draft,
        taskId: taskId,
        estimate: estimate,
        plan: after,
        now: ref.read(clockProvider).now(),
        dayBoundaryMin: settings?.dayBoundaryMin ?? Defaults.dayBoundaryMin,
      ),
    );
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
