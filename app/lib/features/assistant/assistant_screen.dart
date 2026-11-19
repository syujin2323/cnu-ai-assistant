// 06 AI 비서(셸 밖 전체 화면 `/assistant`). docs/screens.md '06 AI 비서'·'AI 사용 동의'.
//
// 위에서부터 머리(뒤로, 'AI 비서'와 한 줄 설명, 대화가 있으면 '새 대화') → 대화(사용자의 말과 카드) → 입력창과
// '확인 버튼을 누르기 전에는 저장하지 않아요'다. 대화가 없으면 한 줄 안내를 보이고, 규칙 모드(12 '말로 정하기')면
// [폼으로 정하기]를 둔다. 입력은 300자까지이고 240자부터 글자 수를 보인다.
//
// screens.md '들어오는 길'의 곳에서 push로 열고, 닫으면 연 화면으로 돌아간다. 받은 인자([AssistantArgs]) 가운데
// 미리 채울 문장은 입력창에 넣고, 01 계획의 말로 추가처럼 바로 보내라고 하면 열자마자 보낸다. AI 사용에
// 동의하지 않았으면 보내기 전에 AI 사용 동의 시트를 열어 그 문장을 '동의하면 보낼 문장'으로 보인다. 대화와 카드
// 동작은 `assistant_controller.dart`가 한다.
//
// 직접 추가 폼(`widgets/direct_add_form.dart`)은 [직접 추가](대화가 없을 때의 안내, 대화가 시작되면 위 막대),
// 카드의 [고치기], 못 알아들음·찾지 못함 안내와 보내지 못한 카드의 [직접 추가], AI를 쓸 수 없어 보내지 못했을 때
// (동의 안 함, 오늘 사용량 다 씀, AI 닫힘, 오프라인. 그 까닭과 보내려던 문장을 함께) 대화 위에 덮개로 연다.
// 폼으로 열라는 인자([AssistantArgs.form])를 받았거나 AI가 아직 닫혀 있으면(Remote Config `ai_open`, 데모 모드는
// 아님) 이 화면 자체가 폼이다. 그 폼에서는 AI를 쓸 수 있으면 '말로 넣기'로 대화로 가고, 동의하지 않았으면
// [AI 켜기]로 동의를 묻는다. 새 폼의 처음 날짜·시각은 받은 [AssistantArgs.at]이 있으면 그것이다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/layer_route.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/direct_add.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/answer_card.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/assistant_cards.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/change_cards.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/direct_add_form.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/rule_cards.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 06 AI 비서.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.args = const AssistantArgs()});

  /// 연 곳이 넘긴 인자. 넘기지 않았으면 기본값(탭바 옆 버튼으로 연 것과 같음)이다.
  final AssistantArgs args;

  /// 입력할 수 있는 글자 수(서버의 상한과 같음).
  static const int maxLength = 300;

  /// 글자 수를 보이기 시작하는 길이.
  static const int countFrom = 240;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  /// 대화 줄마다의 키(새 줄이 붙으면 그 줄로 내림).
  final _keys = <int, GlobalKey>{};

  /// 이 화면 자체가 직접 추가 폼인지('말로 넣기'나 [AI 켜기]로 대화로 가면 false).
  late bool _formRoot;

  /// 화면 자체인 폼의 처음 값과 그 위에 보일 보내려던 문장(AI가 닫혀 있는데 문장을 받았을 때).
  late final DirectAddDraft _rootInitial;
  String? _rootQuote;

  bool get _ruleMode => widget.args.mode == AssistantMode.rule;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    final closed =
        ref.read(appModeProvider) != AppMode.demo &&
        !ref.read(parseClientProvider).isOpen;
    _formRoot = args.form != null || closed;
    _rootInitial = DirectAddDraft.initial(
      args.form ?? DirectAddKind.event,
      now: ref.read(clockProvider).now(),
      at: args.at,
    );
    final prefill = args.prefill;
    if (prefill != null && prefill.isNotEmpty) {
      _input.text = String.fromCharCodes(
        prefill.runes.take(AssistantScreen.maxLength),
      );
      if (closed) {
        // AI가 닫혀 있으면 보내지 않고 폼 위에 그 문장을 보인다.
        _rootQuote = _input.text;
      } else if (args.sendNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_send());
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 직접 추가 폼을 대화 위에 덮개로 연다. [initial]이 없으면 일정 폼의 처음 값([AssistantArgs.at]이 있으면 그 날짜·
  /// 시각)이다.
  void _openForm({
    DirectAddDraft? initial,
    DirectAddOrigin origin = DirectAddOrigin.chat,
    int? cardId,
    DirectAddNotice? notice,
    String? quote,
  }) {
    FocusScope.of(context).unfocus();
    final draft =
        initial ??
        DirectAddDraft.initial(
          DirectAddKind.event,
          now: ref.read(clockProvider).now(),
          at: widget.args.at,
        );
    unawaited(
      Navigator.of(context).push(
        layerRoute<void>(
          motion: MotionScope.of(context),
          builder: (_) => DirectAddForm(
            initial: draft,
            origin: origin,
            cardId: cardId,
            notice: notice,
            quote: quote,
            ruleMode: _ruleMode,
            onAiOn: () => unawaited(_turnAiOn(quote, layer: true)),
            onRules: _ruleMode ? _leave : null,
          ),
        ),
      ),
    );
  }

  /// 폼의 [AI 켜기]: 동의를 묻고, 동의하면 대화로 가서 보내려던 [quote]를 보낸다.
  Future<void> _turnAiOn(String? quote, {required bool layer}) async {
    final route = ModalRoute.of(context);
    final yes = await showAiConsentSheet(
      context,
      ref.read(motionLevelProvider),
      pendingText: quote,
    );
    if (!mounted || !yes) return;
    final controller = ref.read(assistantControllerProvider.notifier);
    if (!await controller.acceptConsent() || !mounted) return;
    if (layer) {
      Navigator.of(context).popUntil((other) => other == route);
    } else {
      setState(() => _formRoot = false);
    }
    if (quote != null && quote.isNotEmpty) unawaited(_send(quote));
  }

  /// 규칙 띠: 위에 연 폼까지 닫고 이 화면을 닫는다(12 내 규칙으로 돌아감).
  void _leave() {
    final route = ModalRoute.of(context);
    Navigator.of(context).popUntil((other) => other == route);
    context.pop();
  }

  /// 화면 자체인 폼의 '말로 넣기': 대화로 가서 입력창에 둔다.
  void _toChat() {
    setState(() => _formRoot = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  /// 예시 문장을 입력창에 넣는다(보내지 않음).
  void _fill(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 입력창의 문장(없으면 [text])을 보낸다. AI 사용에 동의하지 않았으면 먼저 동의 시트를 연다.
  Future<void> _send([String? text]) async {
    final sentence = (text ?? _input.text).trim();
    if (sentence.isEmpty) return;
    final controller = ref.read(assistantControllerProvider.notifier);
    if (ref.read(assistantControllerProvider).sending) return;
    if (await controller.gate() == AiGate.needsConsent) {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      final yes = await showAiConsentSheet(
        context,
        ref.read(motionLevelProvider),
        pendingText: sentence,
      );
      if (!mounted) return;
      if (!yes) {
        if (text == null) _input.clear();
        controller.decline(sentence);
        _openForm(notice: DirectAddNotice.aiOff, quote: sentence);
        return;
      }
      if (!await controller.acceptConsent() || !mounted) return;
    }
    if (text == null) _input.clear();
    final notice = await controller.send(sentence, ruleMode: _ruleMode);
    // AI를 쓸 수 없어 보내지 못했으면 그 까닭과 문장으로 직접 추가 폼을 연다.
    if (notice != null && mounted) _openForm(notice: notice, quote: sentence);
  }

  /// 새로 붙은 줄 가운데 첫 줄이 화면 위에 오게 내린다(대화가 짧으면 맨 아래까지만). 보낸 문장과 카드의
  /// 첫머리가 보이게 하려는 것이다(글자를 키우면 카드가 화면보다 길어 맨 아래로 내리면 첫머리가 가려짐).
  void _reveal(int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[id]?.currentContext;
      if (!mounted || target == null) return;
      final off = ref.read(motionLevelProvider) == MotionLevel.off;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: off ? Duration.zero : AppMotion.standard,
          curve: AppEase.standard,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(assistantControllerProvider);
    ref.listen(assistantControllerProvider.select((state) => state.messages), (
      previous,
      next,
    ) {
      final seen = {for (final message in previous ?? const []) message.id};
      final added = next.where((message) => !seen.contains(message.id));
      if (added.firstOrNull case final first?) _reveal(first.id);
      _keys.removeWhere((id, _) => !next.any((message) => message.id == id));
    });
    if (_formRoot) {
      final gate = ref.watch(aiGateProvider);
      return DirectAddForm(
        initial: _rootInitial,
        origin: DirectAddOrigin.screen,
        notice: switch (gate) {
          AiGate.closed => DirectAddNotice.closed,
          AiGate.needsConsent || AiGate.declined => DirectAddNotice.aiOff,
          AiGate.limitReached => DirectAddNotice.limit,
          AiGate.open || AiGate.demo || null => null,
        },
        quote: _rootQuote,
        ruleMode: _ruleMode,
        onChat: gate == AiGate.open || gate == AiGate.demo ? _toChat : null,
        onAiOn: () => unawaited(_turnAiOn(_rootQuote, layer: false)),
        onRules: _ruleMode ? () => context.pop() : null,
      );
    }
    final now = ref.watch(clockProvider).now();
    // 안내 카드의 [직접 추가]가 보일 문장: 그 카드 앞의 마지막 사용자 말.
    final saidBefore = <int, String>{};
    String? lastSaid;
    for (final message in state.messages) {
      if (message is UserMessage) lastSaid = message.text;
      if (lastSaid != null) saidBefore[message.id] = lastSaid;
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              sub: _ruleMode ? '내 규칙을 말로 정해요' : '말로 일정과 규칙을 정해요',
              onDirect: state.messages.isEmpty || _ruleMode ? null : _openForm,
              onReset: state.messages.isEmpty || state.sending
                  ? null
                  : ref.read(assistantControllerProvider.notifier).reset,
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _Empty(ruleMode: _ruleMode, onDirect: _openForm)
                  // 대화는 길지 않으므로 모두 그려 두고(카드의 위치로 내리려고) 한 번에 스크롤한다.
                  : SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s16,
                        AppSpace.s8,
                        AppSpace.s16,
                        AppSpace.s24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, message) in state.messages.indexed)
                            Padding(
                              key: _keys.putIfAbsent(message.id, GlobalKey.new),
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : AppSpace.s12 + 2,
                              ),
                              child: _message(
                                message,
                                sending: state.sending,
                                now: now,
                                said: saidBefore[message.id],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            ToastAnchor(
              child: _Composer(
                controller: _input,
                focusNode: _inputFocus,
                sending: state.sending,
                hint: _ruleMode ? '예: 하루 공부는 4시간까지만' : '예: 목요일 7시 동아리',
                onSend: () => unawaited(_send()),
              ),
            ),
            ColoredBox(
              color: colors.bg,
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(
    AssistantMessage message, {
    required bool sending,
    required DateTime now,
    required String? said,
  }) => switch (message) {
    UserMessage(:final text) => UserBubble(text),
    WaitingMessage() => const WaitingBubble(),
    EventCard(:final say) => _withSay(
      say,
      EventCardView(
        card: message,
        onEdit: () => _openForm(
          initial: DirectAddDraft.fromEvent(message.draft, now: now),
          origin: DirectAddOrigin.card,
          cardId: message.id,
        ),
      ),
    ),
    TaskCard(:final say) => _withSay(
      say,
      TaskCardView(
        card: message,
        onEdit: () => _openForm(
          initial: DirectAddDraft.fromTask(message.draft, now: now),
          origin: DirectAddOrigin.card,
          cardId: message.id,
        ),
      ),
    ),
    AskCard() => AskCardView(card: message),
    ExceptionCard(:final say) => _withSay(
      say,
      ExceptionCardView(card: message),
    ),
    ChangeCard(:final say) => _withSay(say, ChangeCardView(card: message)),
    TargetPickCard(:final say) => _withSay(
      say,
      TargetPickCardView(card: message),
    ),
    AnswerCard(:final say) => _withSay(say, AnswerCardView(card: message)),
    RuleCard(:final say) => _withSay(say, RuleCardView(card: message)),
    RuleRemoveCard(:final say) => _withSay(
      say,
      RuleRemoveCardView(card: message),
    ),
    RulePickCard(:final say) => _withSay(say, RulePickCardView(card: message)),
    InfoCard() => InfoCardView(
      card: message,
      onExample: _fill,
      onDirect: _ruleMode ? null : () => _openForm(quote: said),
    ),
    FailCard(:final text, :final kind) => FailCardView(
      card: message,
      onRetry: sending ? null : () => unawaited(_send(text)),
      onDirect: () => _openForm(
        notice: kind == FailKind.offline
            ? DirectAddNotice.offline
            : DirectAddNotice.failed,
        quote: text,
      ),
    ),
  };

  Widget _withSay(String? say, Widget card) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (say != null) SayLine(say), card],
  );
}

/// 머리: 뒤로, 'AI 비서'와 한 줄 설명, [직접 추가](대화가 시작되면), '새 대화'.
class _Header extends StatelessWidget {
  const _Header({
    required this.sub,
    required this.onDirect,
    required this.onReset,
  });

  final String sub;
  final VoidCallback? onDirect;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s8,
        AppSpace.s4,
      ),
      child: Row(
        children: [
          const BackButton(),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'AI 비서',
                    style: AppText.bodyLarge.copyWith(
                      fontWeight: AppText.semibold,
                    ),
                  ),
                ),
                Text(sub, style: AppText.caption.copyWith(color: colors.muted)),
              ],
            ),
          ),
          if (onDirect != null)
            TextButton.icon(
              onPressed: onDirect,
              icon: AppIcon(AppIconName.plus, size: 15, color: colors.accent),
              label: const Text('직접 추가'),
            ),
          if (onReset != null)
            IconButton(
              tooltip: '새 대화',
              onPressed: onReset,
              icon: AppIcon(AppIconName.pencil, size: 20, color: colors.ink2),
            ),
        ],
      ),
    );
  }
}

/// 대화가 없을 때의 한 줄 안내와 [직접 추가]. 규칙 모드면 [폼으로 정하기](12 내 규칙으로 돌아감)를 둔다.
class _Empty extends StatelessWidget {
  const _Empty({required this.ruleMode, required this.onDirect});

  final bool ruleMode;
  final VoidCallback onDirect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lines = ruleMode
        ? const ['이동 시간이나 공부할 시간대처럼', '배치 규칙을 말로 적어 주세요']
        : const ['일정 추가·변경이나 배치 규칙처럼', '원하는 걸 적어 주세요'];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final line in lines)
                  Rise(
                    child: Text(
                      line,
                      textAlign: TextAlign.center,
                      style: AppText.bodyLarge.copyWith(color: colors.ink2),
                    ),
                  ),
                const SizedBox(height: AppSpace.s16),
                if (ruleMode)
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('폼으로 정하기'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onDirect,
                    icon: const AppIcon(AppIconName.plus, size: 16),
                    label: const Text('직접 추가'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 입력창과 보내기 버튼, 저장 안내.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final String hint;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ready = widget.controller.text.trim().isNotEmpty && !widget.sending;
    return ColoredBox(
      color: colors.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(color: colors.edge),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: AssistantScreen.maxLength,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => widget.onSend(),
                      style: AppText.body,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => currentLength < AssistantScreen.countFrom
                          ? null
                          : Text(
                              '$currentLength/${AssistantScreen.maxLength}',
                              style: AppText.caption.copyWith(
                                color:
                                    currentLength >= AssistantScreen.maxLength
                                    ? colors.alert
                                    : colors.muted,
                              ),
                            ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        semanticCounterText: '',
                        hintText: widget.hint,
                        hintStyle: AppText.body.copyWith(color: colors.muted),
                        labelText: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Press(
                    enabled: ready,
                    child: IconButton(
                      tooltip: '보내기',
                      onPressed: ready ? widget.onSend : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(44),
                        backgroundColor: ready ? colors.strong : colors.tint,
                        disabledBackgroundColor: colors.tint,
                      ),
                      icon: AppIcon(
                        AppIconName.send,
                        size: 18,
                        color: ready ? colors.onStrong : colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              '확인 버튼을 누르기 전에는 저장하지 않아요',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
