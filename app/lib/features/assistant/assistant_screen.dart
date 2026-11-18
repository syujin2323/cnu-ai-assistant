// 06 AI 비서(셸 밖 전체 화면 `/assistant`). docs/screens.md '06 AI 비서'·'AI 사용 동의'.
//
// 위에서부터 머리(뒤로, 'AI 비서'와 한 줄 설명, 대화가 있으면 '새 대화') → 대화(사용자의 말과 카드) → 입력창과
// '확인 버튼을 누르기 전에는 저장하지 않아요'다. 대화가 없으면 한 줄 안내를 보이고, 규칙 모드(12 '말로 정하기')면
// [폼으로 정하기]를 둔다. 입력은 300자까지이고 240자부터 글자 수를 보인다.
//
// screens.md '들어오는 길'의 곳에서 push로 열고, 닫으면 연 화면으로 돌아간다. 받은 인자([AssistantArgs]) 가운데
// 미리 채울 문장은 입력창에 넣고, 01 계획의 말로 추가처럼 바로 보내라고 하면 열자마자 보낸다. AI 사용에
// 동의하지 않았으면 보내기 전에 AI 사용 동의 시트를 열어 그 문장을 '동의하면 보낼 문장'으로 보인다. 대화와 카드
// 동작은 `assistant_controller.dart`가 한다. 직접 추가 폼([직접 추가], 카드의 [고치기], AI를 못 쓸 때 여는 폼,
// [AssistantArgs.form])과 날짜·시각 채우기([AssistantArgs.at])는 그 폼을 만드는 PR(S8b)에서 붙인다.

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/assistant_cards.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
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
  final _scroll = ScrollController();

  /// 대화 줄마다의 키(새 줄이 붙으면 그 줄로 내림).
  final _keys = <int, GlobalKey>{};

  bool get _ruleMode => widget.args.mode == AssistantMode.rule;

  @override
  void initState() {
    super.initState();
    final prefill = widget.args.prefill;
    if (prefill != null && prefill.isNotEmpty) {
      _input.text = String.fromCharCodes(
        prefill.runes.take(AssistantScreen.maxLength),
      );
      if (widget.args.sendNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_send());
        });
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
        return;
      }
      if (!await controller.acceptConsent() || !mounted) return;
    }
    if (text == null) _input.clear();
    await controller.send(sentence, ruleMode: _ruleMode);
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              sub: _ruleMode ? '내 규칙을 말로 정해요' : '말로 일정과 규칙을 정해요',
              onReset: state.messages.isEmpty || state.sending
                  ? null
                  : ref.read(assistantControllerProvider.notifier).reset,
            ),
            Expanded(
              child: state.messages.isEmpty
                  ? _Empty(ruleMode: _ruleMode)
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
                              child: _message(message, sending: state.sending),
                            ),
                        ],
                      ),
                    ),
            ),
            ToastAnchor(
              child: _Composer(
                controller: _input,
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

  Widget _message(AssistantMessage message, {required bool sending}) =>
      switch (message) {
        UserMessage(:final text) => UserBubble(text),
        WaitingMessage() => const WaitingBubble(),
        EventCard(:final say) => _withSay(say, EventCardView(card: message)),
        TaskCard(:final say) => _withSay(say, TaskCardView(card: message)),
        AskCard() => AskCardView(card: message),
        InfoCard() => InfoCardView(card: message),
        FailCard(:final text) => FailCardView(
          card: message,
          onRetry: sending ? null : () => unawaited(_send(text)),
        ),
      };

  Widget _withSay(String? say, Widget card) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (say != null) SayLine(say), card],
  );
}

/// 머리: 뒤로, 'AI 비서'와 한 줄 설명, '새 대화'.
class _Header extends StatelessWidget {
  const _Header({required this.sub, required this.onReset});

  final String sub;
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

/// 대화가 없을 때의 한 줄 안내. 규칙 모드면 [폼으로 정하기](12 내 규칙으로 돌아감)를 둔다.
class _Empty extends StatelessWidget {
  const _Empty({required this.ruleMode});

  final bool ruleMode;

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
                if (ruleMode) ...[
                  const SizedBox(height: AppSpace.s16),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('폼으로 정하기'),
                  ),
                ],
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
    required this.sending,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
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
