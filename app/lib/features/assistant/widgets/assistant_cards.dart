// 06 AI 비서의 카드: 새 일정, 새 할 일, 되묻기, 안내, 보내지 못함. docs/screens.md '06 AI 비서'의 카드 1·2·7과
// 되묻기. 수업 변경·바꾸기·지우기는 `change_cards.dart`, 질문 답은 `answer_card.dart`에 있다. 문구는 디자인 전
// 임시 문구이고 최종 프로토타입의 06 문구를 따른다.
//
// 저장하는 카드는 확인 버튼을 눌러야 저장하고, 저장하면 '…에 넣었어요'와 다시 계산한 제안을 적는다. 일정·할 일
// 카드의 [고치기]와 못 알아들음·찾지 못함·보내지 못함의 [직접 추가]는 직접 추가 폼을 연다(여는 것은 화면이 함).
// 폼으로 넣거나 고쳐 넣은 카드는 카드 위 이름과 저장한 줄이 다르다('직접 추가'·'고친 일정', '직접 넣었어요').

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_message.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_reply.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_rules.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/models/parse_result.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_context.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 새 일정 카드.
class EventCardView extends ConsumerWidget {
  const EventCardView({super.key, required this.card, this.onEdit});

  final EventCard card;

  /// [고치기](직접 추가 폼). null이면 두지 않는다.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final draft = card.draft;
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = card.status != CardStatus.saved;
    final saving = card.status == CardStatus.saving;
    final weekdays = draft.weekdays;
    final date = draft.date;
    final chips = pending && date != null && draft.timeUnknown
        ? ref.watch(freeHourChipsProvider(date))
        : null;
    final overlaps = pending && !draft.timeUnknown
        ? ref.watch(eventOverlapsProvider(draft))
        : null;
    return AssistantCardFrame(
      icon: AppIconName.calendar,
      kicker:
          '${switch (card.origin) {
            CardOrigin.ai => '새 일정',
            CardOrigin.edited => '고친 일정',
            CardOrigin.manual => '직접 추가',
          }}${weekdays == null ? '' : ' · 반복'}',
      tag: weekdays == null ? '개인 일정' : '고정 일정',
      children: [
        CardTitle(draft.title),
        const SizedBox(height: AppSpace.s12),
        if (weekdays != null)
          CardDetailRow(label: '반복', value: repeatText(weekdays))
        else
          CardDetailRow(
            label: '날짜',
            value:
                '${monthDayText(date!, today: today)} · '
                '${relativeDayText(date, today: today)}',
          ),
        CardDetailRow(
          label: '시간',
          value: eventSpanText(draft),
          valueColor: draft.timeUnknown ? colors.muted : null,
        ),
        if (chips != null && chips.isNotEmpty)
          CardDetailRow(
            label: '시간 고르기',
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final start in chips)
                  ChoiceChip(
                    label: Text(hhmmText(start)),
                    selected: false,
                    onSelected: saving
                        ? null
                        : (_) => controller.pickEventTime(card.id, start),
                  ),
              ],
            ),
          ),
        if (pending && card.editPlace)
          _FieldRow(
            label: '장소',
            initial: draft.place,
            hint: '예: 공대 5호관 204',
            onChanged: (value) => controller.setPlace(card.id, value),
          )
        else if (draft.place case final place?)
          CardDetailRow(label: '장소', value: place),
        if (pending && card.editPrep)
          _FieldRow(
            label: '준비물',
            initial: draft.prep,
            hint: '예: 노트북',
            onChanged: (value) => controller.setPrep(card.id, value),
          )
        else if (draft.prep case final prep?)
          CardDetailRow(label: '준비물', value: prep),
        if (pending &&
            ((draft.place == null && !card.editPlace) ||
                (draft.prep == null && !card.editPrep)))
          _OptionalFields(
            showPlace: draft.place == null && !card.editPlace,
            showPrep: draft.prep == null && !card.editPrep,
            onPlace: saving ? null : () => controller.openPlace(card.id),
            onPrep: saving ? null : () => controller.openPrep(card.id),
          ),
        if (overlaps case final overlaps?) OverlapLine(overlaps),
        if (pending)
          CardActions(
            primary: FilledButton(
              onPressed: saving ? null : () => controller.saveEvent(card.id),
              child: Text(draft.timeUnknown ? '시간 없이 넣기' : '캘린더에 추가'),
            ),
            secondary: onEdit == null
                ? null
                : OutlinedButton(
                    onPressed: saving ? null : onEdit,
                    child: const Text('고치기'),
                  ),
          )
        else
          CardDone(
            text:
                '${card.origin == CardOrigin.manual ? '직접 넣었어요' : '캘린더에 넣었어요'} · '
                '${eventWhenText(draft, today: today)}',
            note: card.planNote,
          ),
      ],
    );
  }
}

/// 장소·준비물을 넣는 칸(40자).
class _FieldRow extends StatefulWidget {
  const _FieldRow({
    required this.label,
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final String? initial;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  late final _text = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CardDetailRow(
    label: widget.label,
    child: TextField(
      controller: _text,
      autofocus: true,
      maxLength: 40,
      buildCounter: (
        context, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      decoration: InputDecoration(hintText: widget.hint, isDense: true),
      onChanged: widget.onChanged,
    ),
  );
}

/// [+ 장소]·[+ 준비물] 줄(선택).
class _OptionalFields extends StatelessWidget {
  const _OptionalFields({
    required this.showPlace,
    required this.showPrep,
    required this.onPlace,
    required this.onPrep,
  });

  final bool showPlace;
  final bool showPrep;
  final VoidCallback? onPlace;
  final VoidCallback? onPrep;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget add(String label, VoidCallback? onPressed) => TextButton.icon(
      onPressed: onPressed,
      icon: AppIcon(AppIconName.plus, size: 14, color: colors.accent),
      label: Text(label),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.edge)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpace.s4,
        children: [
          if (showPlace) add('장소', onPlace),
          if (showPrep) add('준비물', onPrep),
          Text('선택', style: AppText.caption.copyWith(color: colors.muted)),
        ],
      ),
    );
  }
}

/// 새 할 일 카드.
class TaskCardView extends ConsumerWidget {
  const TaskCardView({super.key, required this.card, this.onEdit});

  final TaskCard card;

  /// [고치기](직접 추가 폼). null이면 두지 않는다.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final draft = card.draft;
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = card.status != CardStatus.saved;
    final saving = card.status == CardStatus.saving;
    final courseName = draft.courseName;
    final courseId = courseName == null
        ? null
        : ref
              .watch(selectableCoursesProvider)
              .value
              ?.where((course) => course.name == courseName)
              .firstOrNull
              ?.id;
    final estimate = taskEstimateOf(
      draft,
      courseId: courseId,
      config: ref.watch(plannerConfigProvider),
    );
    final due = draft.dueDate;
    final dueSoon =
        due != null && !due.isAfter(today.add(const Duration(days: 1)));
    final note = estimateNote(estimate.source, draft.kind);
    return AssistantCardFrame(
      icon: AppIconName.checkSquare,
      kicker: switch (card.origin) {
        CardOrigin.ai => '새 할 일',
        CardOrigin.edited => '고친 할 일',
        CardOrigin.manual => '직접 추가 · 할 일',
      },
      tag: courseName ?? '개인',
      children: [
        CardTitle(draft.title),
        const SizedBox(height: AppSpace.s12),
        CardDetailRow(
          label: '마감',
          value: due == null
              ? '마감 없음'
              : '${monthDayText(due, today: today)} '
                    '${hhmmText(draft.dueTimeMin ?? 23 * 60 + 59)} · '
                    '${relativeDayText(due, today: today)}',
          valueColor: due == null
              ? colors.muted
              : dueSoon
              ? colors.alert
              : null,
        ),
        if (courseName != null && pending)
          CardDetailRow(
            label: '종류',
            child: Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final kind in courseTaskKinds)
                  ChoiceChip(
                    label: Text(taskKindText(kind)),
                    selected: kind == draft.kind,
                    onSelected: saving
                        ? null
                        : (_) => controller.setTaskKind(card.id, kind),
                  ),
              ],
            ),
          )
        else
          CardDetailRow(
            label: '종류',
            value: courseName == null
                ? '개인 할 일'
                : '$courseName · ${taskKindText(draft.kind)}',
          ),
        if (pending)
          CardDetailRow(
            label: '예상 시간',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final minutes in estimateChoices(estimate.minutes))
                      ChoiceChip(
                        label: Text(durationText(minutes)),
                        selected: minutes == estimate.minutes,
                        onSelected: saving
                            ? null
                            : (_) =>
                                  controller.setTaskEstimate(card.id, minutes),
                      ),
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    note,
                    style: AppText.caption.copyWith(color: colors.muted),
                  ),
                ],
              ],
            ),
          )
        else
          CardDetailRow(
            label: '예상 시간',
            value: estimate.minutes == null
                ? '정하지 않음'
                : durationText(estimate.minutes!),
          ),
        if (pending)
          CardActions(
            primary: FilledButton(
              onPressed: saving ? null : () => controller.saveTask(card.id),
              child: const Text('할 일에 추가'),
            ),
            secondary: onEdit == null
                ? null
                : OutlinedButton(
                    onPressed: saving ? null : onEdit,
                    child: const Text('고치기'),
                  ),
          )
        else
          CardDone(
            text: [
              card.origin == CardOrigin.manual ? '직접 넣었어요' : '할 일에 넣었어요',
              if (estimate.minutes case final minutes?)
                '${durationText(minutes)} 걸린다고 보고 놓아요',
            ].join(' · '),
            note: card.planNote,
          ),
      ],
    );
  }
}

/// 되묻기 카드. 고르면 고른 것만 남는다.
class AskCardView extends ConsumerWidget {
  const AskCardView({super.key, required this.card});

  final AskCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final controller = ref.read(assistantControllerProvider.notifier);
    final picked = card.picked;
    return AssistantCardFrame(
      icon: switch (card.topic) {
        AskTopic.meridiem || AskTopic.pastTime => AppIconName.clock,
        _ => AppIconName.calendar,
      },
      kicker: '확인해 주세요',
      children: [
        CardTitle(card.question),
        if (picked == null) ...[
          if (card.sub case final sub?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: Text(
                sub,
                style: AppText.small.copyWith(color: colors.muted),
              ),
            ),
          const SizedBox(height: AppSpace.s8),
          for (final (index, option) in card.options.indexed)
            CardOptionRow(
              label: option.label,
              sub: option.sub,
              onTap: () => controller.pick(card.id, index),
            ),
        ] else
          CardDone(text: card.options[picked].label),
      ],
    );
  }
}

/// 안내 카드.
class InfoCardView extends StatelessWidget {
  const InfoCardView({
    super.key,
    required this.card,
    this.onExample,
    this.onDirect,
  });

  final InfoCard card;

  /// 정할 수 없는 규칙 안내의 예시 칩을 누르면 그 문장을 입력창에 넣는다. null이면 칩을 두지 않는다.
  final ValueChanged<String>? onExample;

  /// 못 알아들음·찾지 못함 안내의 [직접 추가](직접 추가 폼). null이면 두지 않는다.
  final VoidCallback? onDirect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (kicker, title, body) = switch (card.kind) {
      InfoKind.notUnderstood => (
        '다시 말해 주세요',
        '이 문장에서는 일정을 찾지 못했어요',
        '날짜나 시간을 같이 말해 주세요. 예: 목요일 7시 동아리, 금요일까지 보고서 쓰기',
      ),
      InfoKind.serverQuestion => ('다시 물어볼게요', card.question ?? '', null),
      InfoKind.unsupportedRepeat => (
        '반복 일정',
        '격주·매달 반복은 아직 넣을 수 없어요',
        '매주 반복이나 날짜를 같이 말해 주세요. 예: 매주 화요일 7시 동아리',
      ),
      InfoKind.repeatIncomplete => (
        '반복 일정',
        '반복 일정은 요일과 시간을 같이 말해 주세요',
        '예: 주말마다 2시부터 5시까지 알바',
      ),
      InfoKind.ruleOnly => (
        '내 규칙',
        unsavableRuleText,
        '정해진 규칙 종류에 맞지 않아 저장하지 않았어요. 지금 정할 수 있는 건 아래와 같아요.',
      ),
      InfoKind.ruleUnsupported => (
        '내 규칙',
        unsavableRuleText,
        switch (card.unsupported) {
          UnsupportedRuleKind.notification =>
            '알림은 다시 설계하고 있어서 지금은 정할 수 없어요. 지금 정할 수 있는 건 아래와 같아요.',
          UnsupportedRuleKind.specificDate =>
            '특정 날짜 하루만 바꾸는 규칙은 아직 없어요. 그날 일정은 일정으로 넣어 주세요.',
          UnsupportedRuleKind.mode =>
            '시험 기간·방학 모드는 다음 버전에 넣을 예정이에요. 지금은 아래 조건으로 정해 주세요.',
          UnsupportedRuleKind.priority =>
            '할 일 사이의 우선순위는 아직 정할 수 없어요. 순서는 마감과 남은 시간으로 정해요.',
          UnsupportedRuleKind.other ||
          null => '정해진 규칙 종류에 맞지 않아 저장하지 않았어요. 지금 정할 수 있는 건 아래와 같아요.',
        },
      ),
      InfoKind.ruleQuestion => ('내 규칙', card.question ?? '', null),
      InfoKind.noRuleToRemove => (
        '내 규칙',
        '켜진 ${card.question ?? ''} 규칙이 없어요',
        '지울 규칙이 없어 아무것도 바꾸지 않았어요.',
      ),
      InfoKind.noClass => (
        '수업 변경',
        '2주 안에 그 수업이 없어요',
        '시간표에 있는 과목인지 확인해 주세요. 시간표는 나 › 시간표·고정 일정에서 고칠 수 있어요.',
      ),
      InfoKind.makeupNeedsWhen => (
        '수업 변경',
        '보강 날짜와 시간을 알려 주세요',
        '예: 공학설계 보강 토요일 10시',
      ),
      InfoKind.placeNeeded => (
        '수업 변경',
        '바뀐 강의실을 알려 주세요',
        '예: 금요일 공학설계 강의실이 공대 5호관 204로 바뀌었어',
      ),
      InfoKind.targetNotFound => (
        '일정 바꾸기·지우기',
        '「${card.question ?? ''}」 일정을 찾지 못했어요',
        '캘린더에 아직 없어요. 먼저 넣어 주세요. 예: 주말마다 2시부터 5시까지 알바 있어',
      ),
      InfoKind.changeNeedsHow => (
        '일정 바꾸기',
        '어떻게 바꿀지 알려 주세요',
        '바꿀 시간이나 날짜를 같이 말해 주세요. '
            '예: ${card.question ?? '알바'} 3시로 바꿔 줘',
      ),
      InfoKind.taskChange => (
        '할 일',
        '할 일은 아직 말로 바꾸거나 지울 수 없어요',
        '지금은 일정만 말로 바꾸거나 지울 수 있어요.',
      ),
      InfoKind.aiDeclined => (
        'AI 사용 안 함',
        '문장을 보내지 않았어요',
        'AI 사용에 동의하지 않아 보내지 않았어요. 나 › AI에서 언제든 켤 수 있어요.',
      ),
      InfoKind.limitReached => ('오늘 사용량', '오늘 AI 사용량을 다 썼어요', '내일 다시 쓸 수 있어요.'),
      InfoKind.aiClosed => ('AI 비서', '아직 AI 비서를 쓸 수 없어요', '지금은 문장을 보내지 않아요.'),
    };
    return AssistantCardFrame(
      icon: AppIconName.info,
      kicker: kicker,
      children: [
        CardTitle(title),
        if (body != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s4),
            child: Text(
              body,
              style: AppText.small.copyWith(color: colors.ink2),
            ),
          ),
        if (onExample case final onExample?)
          if (card.kind == InfoKind.ruleOnly ||
              (card.kind == InfoKind.ruleUnsupported &&
                  card.unsupported != UnsupportedRuleKind.specificDate &&
                  card.unsupported != UnsupportedRuleKind.priority))
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s12),
              child: Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  for (final (kind, sentence) in ruleExamples)
                    ActionChip(
                      label: Text(ruleKindName(kind)),
                      onPressed: () => onExample(sentence),
                    ),
                ],
              ),
            ),
        if (onDirect case final onDirect?)
          if (card.kind == InfoKind.notUnderstood ||
              card.kind == InfoKind.targetNotFound)
            CardActions(
              primary: OutlinedButton.icon(
                onPressed: onDirect,
                icon: const AppIcon(AppIconName.plus, size: 16),
                label: const Text('직접 추가'),
              ),
            ),
      ],
    );
  }
}

/// 보내지 못한 카드. [다시 보내기]가 같은 문장을 다시 보내고, [직접 추가]는 그 문장과 함께 직접 추가 폼을 연다.
class FailCardView extends StatelessWidget {
  const FailCardView({
    super.key,
    required this.card,
    required this.onRetry,
    this.onDirect,
  });

  final FailCard card;
  final VoidCallback? onRetry;
  final VoidCallback? onDirect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (kicker, title, body) = switch (card.kind) {
      FailKind.timeout => (
        'AI 응답 없음',
        'AI가 8초 안에 답하지 않았어요',
        '보낸 문장은 어디에도 저장하지 않았어요.',
      ),
      FailKind.offline => ('연결 안 됨', '인터넷에 연결하지 못했어요', '연결을 확인한 뒤 다시 보내 주세요.'),
      FailKind.failed => (
        'AI 응답 없음',
        'AI가 지금 답하지 못했어요',
        '보낸 문장은 어디에도 저장하지 않았어요. 잠시 뒤 다시 보내 주세요.',
      ),
    };
    return AssistantCardFrame(
      icon: AppIconName.warning,
      kicker: kicker,
      alert: true,
      children: [
        CardTitle(title),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(body, style: AppText.small.copyWith(color: colors.ink2)),
        ),
        CardActions(
          primary: OutlinedButton(
            onPressed: onRetry,
            child: const Text('다시 보내기'),
          ),
          secondary: onDirect == null
              ? null
              : OutlinedButton(onPressed: onDirect, child: const Text('직접 추가')),
        ),
      ],
    );
  }
}
