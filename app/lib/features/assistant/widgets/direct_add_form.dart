// 06 AI 비서의 직접 추가 폼. docs/screens.md '직접 추가 폼'·'06 AI 비서'.
//
// [일정 | 반복 일정 | 할 일]을 말 없이 바로 넣는 전체 화면이다. 06의 [직접 추가](대화가 없을 때의 안내와 위
// 막대), 카드의 [고치기], 못 알아들음·찾지 못함 안내와 보내지 못한 카드의 [직접 추가], AI를 쓸 수 없어 보내지
// 못했을 때(동의 안 함, 오늘 사용량 다 씀, AI 닫힘, 오프라인)는 대화 위에 덮개(`layer` 모션)로 열고 닫으면
// 대화로 돌아간다. 06을 폼으로 열라고 했거나(03 할 일 '할 일 추가', 20 시스템 '직접 입력하기') AI가 아직 닫혀
// 있으면 06 화면 자체가 이 폼이다([DirectAddOrigin.screen]. 뒤로 가면 06을 닫음).
//
// 값과 검사는 `domain/assistant/direct_add.dart`, 저장은 06의 컨트롤러(`saveDirect`)가 한다. 겹침은 06 일정
// 카드와 같은 것으로 바로 알리기만 하고, 할 일은 넣으면 놓일 자리를 미리 보인다. 폼이 화면 자체면 저장한 뒤에도
// 남아 같은 종류의 새 폼으로 비우고 저장 띠([캘린더 보기]/[할 일 보기])를 보인다. 문구는 디자인 전 임시 문구이고
// 최종 프로토타입의 직접 추가 폼을 따른다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/motion/pop.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_toast.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/design/widgets/time_range_fields.dart';
import 'package:cnu_ai_assistant/design/widgets/time_wheel_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/weekday_picker.dart';
import 'package:cnu_ai_assistant/domain/assistant/assistant_text.dart';
import 'package:cnu_ai_assistant/domain/assistant/direct_add.dart';
import 'package:cnu_ai_assistant/domain/text/task_kind_text.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_context.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_controller.dart';
import 'package:cnu_ai_assistant/features/assistant/widgets/card_parts.dart';
import 'package:cnu_ai_assistant/features/tasks/task_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 직접 추가 폼.
class DirectAddForm extends ConsumerStatefulWidget {
  const DirectAddForm({
    super.key,
    required this.initial,
    required this.origin,
    this.cardId,
    this.notice,
    this.quote,
    this.ruleMode = false,
    this.onChat,
    this.onAiOn,
    this.onRules,
  });

  /// 처음 값. 폼이 처음 그려질 때만 읽는다.
  final DirectAddDraft initial;

  /// 어디서 열었는지(저장한 뒤 할 일과 위의 버튼이 다름).
  final DirectAddOrigin origin;

  /// [DirectAddOrigin.card]면 고치는 카드.
  final int? cardId;

  /// 폼 위에 보일 AI를 쓸 수 없는 까닭.
  final DirectAddNotice? notice;

  /// 보내려던 문장.
  final String? quote;

  /// 규칙 모드(12 '말로 정하기')에서 열었다. 규칙은 12의 폼으로 정한다는 띠를 둔다.
  final bool ruleMode;

  /// '말로 넣기'(폼이 화면 자체이고 AI를 쓸 수 있을 때). null이면 두지 않는다.
  final VoidCallback? onChat;

  /// 까닭이 [DirectAddNotice.aiOff]일 때의 [AI 켜기].
  final VoidCallback? onAiOn;

  /// 규칙 띠를 눌렀다(12 내 규칙으로 돌아감).
  final VoidCallback? onRules;

  @override
  ConsumerState<DirectAddForm> createState() => _DirectAddFormState();
}

/// 저장 띠(폼이 화면 자체일 때 저장한 뒤).
typedef _SavedBand = ({String text, String link, String location});

class _DirectAddFormState extends ConsumerState<DirectAddForm> {
  late DirectAddDraft _draft = widget.initial;
  late final _title = TextEditingController(text: widget.initial.title);
  late final _place = TextEditingController(text: widget.initial.place);
  late final _prep = TextEditingController(text: widget.initial.prep);
  final _titleFocus = FocusNode();
  final _scroll = ScrollController();

  DirectAddIssue? _issue;
  bool _busy = false;
  _SavedBand? _saved;
  int _savedCount = 0;

  bool get _root => widget.origin == DirectAddOrigin.screen;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _prep.dispose();
    _titleFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 값을 바꾼다. 그 칸의 까닭은 지운다(최종 프로토타입).
  void _set(DirectAddDraft next) => setState(() {
    _draft = next;
    _issue = null;
  });

  Future<void> _save() async {
    if (_busy) return;
    final now = ref.read(clockProvider).now();
    final draft = _draft;
    final issue = directAddIssue(draft, now: now);
    if (issue != null) {
      setState(() => _issue = issue);
      if (issue == DirectAddIssue.title) _titleFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final band = _bandOf(draft, now);
    final saved = await ref
        .read(assistantControllerProvider.notifier)
        .saveDirect(
          draft,
          origin: widget.origin,
          cardId: widget.cardId,
          onUndone: _root ? _clearBand : null,
        );
    if (!mounted) return;
    if (!saved) {
      setState(() => _busy = false);
      return;
    }
    if (!_root) {
      Navigator.of(context).pop();
      return;
    }
    // 화면 자체면 남아서 같은 종류의 새 폼으로 비우고 저장 띠를 보인다.
    _title.clear();
    _place.clear();
    _prep.clear();
    setState(() {
      _busy = false;
      _draft = DirectAddDraft.initial(draft.kind, now: now);
      _saved = band;
      _savedCount++;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clearBand() {
    if (mounted) setState(() => _saved = null);
  }

  _SavedBand _bandOf(DirectAddDraft draft, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (draft.kind == DirectAddKind.task) {
      return (
        text: '할 일에 넣었어요 · ${draft.title.trim()}',
        link: '할 일 보기',
        location: Routes.tasksTab(TaskListTab.all),
      );
    }
    final event = draft.toEventDraft();
    return (
      text: '캘린더에 넣었어요 · ${eventWhenText(event, today: today)} ${event.title}',
      link: '캘린더 보기',
      // 한 번뿐인 일정은 그날의 09 일간, 반복 일정은 11 주간.
      location: event.date == null ? Routes.calendar : Routes.day(event.date!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final draft = _draft;
    final now = ref.watch(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final isTask = draft.kind == DirectAddKind.task;
    final title = switch (widget.origin) {
      DirectAddOrigin.card => isTask ? '할 일 고치기' : '일정 고치기',
      _ => '직접 추가',
    };
    final lede = widget.origin == DirectAddOrigin.card
        ? '고친 내용 그대로 저장해요'
        : isTask
        ? '마감과 예상 시간을 알려 주면 빈 시간에 놓아 둘게요'
        : '입력한 그대로 저장해요 · 겹치는 일정은 미리 알려 드려요';
    final quote = widget.quote?.trim();
    final saved = _saved;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(root: _root, onChat: widget.onChat),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.s4,
                  AppSpace.screen,
                  AppSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: AppText.heading),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      lede,
                      style: AppText.small.copyWith(color: colors.muted),
                    ),
                    if (widget.notice case final notice?)
                      _NoticeCard(notice: notice, onAiOn: widget.onAiOn),
                    if (widget.ruleMode && widget.onRules != null)
                      _RulesBand(onTap: widget.onRules!),
                    if (quote != null && quote.isNotEmpty) _QuoteBox(quote),
                    if (saved != null)
                      Pop(
                        trigger: _savedCount,
                        child: _SavedBandView(
                          band: saved,
                          onOpen: () => context.go(saved.location),
                        ),
                      ),
                    const FormLabel('종류'),
                    SegmentedButton<DirectAddKind>(
                      segments: const [
                        ButtonSegment(
                          value: DirectAddKind.event,
                          label: Text('일정'),
                        ),
                        ButtonSegment(
                          value: DirectAddKind.repeating,
                          label: Text('반복 일정'),
                        ),
                        ButtonSegment(
                          value: DirectAddKind.task,
                          label: Text('할 일'),
                        ),
                      ],
                      selected: {draft.kind},
                      showSelectedIcon: false,
                      expandedInsets: EdgeInsets.zero,
                      onSelectionChanged: _busy
                          ? null
                          : (kinds) => _set(draft.copyWith(kind: kinds.single)),
                    ),
                    const FormLabel('제목'),
                    TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      enabled: !_busy,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          DirectAddLimits.titleLength,
                        ),
                      ],
                      decoration: formInputDecoration(
                        context,
                        hint: switch (draft.kind) {
                          DirectAddKind.event => '예: 팀플 회의',
                          DirectAddKind.repeating => '예: 알바, 헬스',
                          DirectAddKind.task => '예: 도서관 책 반납',
                        },
                      ),
                      onChanged: (text) => _set(draft.copyWith(title: text)),
                    ),
                    if (_issue == DirectAddIssue.title)
                      _IssueLine(directAddIssueText(DirectAddIssue.title)),
                    if (isTask && draft.courseName != null)
                      FormHint(
                        '${draft.courseName} · '
                        '${taskKindText(draft.toTaskDraft().kind)}로 넣어요',
                      ),
                    ...switch (draft.kind) {
                      DirectAddKind.event => _eventFields(draft, today, now),
                      DirectAddKind.repeating => _repeatingFields(draft),
                      DirectAddKind.task => _taskFields(draft, today, now),
                    },
                    if (!isTask) ..._extraFields(draft),
                  ],
                ),
              ),
            ),
            ToastAnchor(
              child: ColoredBox(
                color: colors.bg,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.screen,
                    AppSpace.s8,
                    AppSpace.screen,
                    AppSpace.s12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(isTask ? '할 일에 추가' : '캘린더에 추가'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _eventFields(
    DirectAddDraft draft,
    DateTime today,
    DateTime now,
  ) {
    final colors = AppColors.of(context);
    final unknown = draft.timeUnknown;
    final overlaps = unknown
        ? null
        : ref.watch(
            eventOverlapsProvider(draft.copyWith(title: '').toEventDraft()),
          );
    final past = directAddPastNote(draft, now: now);
    return [
      FormLabel(
        '날짜',
        trailing:
            '${monthDayText(draft.date, today: today)} · '
            '${relativeDayText(draft.date, today: today)}',
      ),
      _DayStrip(
        days: directAddDays(today, include: draft.date),
        today: today,
        selected: draft.date,
        enabled: !_busy,
        onPick: (day) => _set(draft.copyWith(date: day)),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: FormLabel(
              '시간',
              trailing: unknown
                  ? null
                  : durationText(draft.endMin - draft.startMin),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s4),
            child: ChoiceChipButton(
              label: '시간 미정',
              selected: unknown,
              onTap: _busy
                  ? null
                  : () => _set(draft.copyWith(timeUnknown: !unknown)),
            ),
          ),
        ],
      ),
      Opacity(
        opacity: unknown ? .38 : 1,
        child: _timeFields(draft, enabled: !unknown),
      ),
      if (unknown)
        const FormHint('시간 없이 그날 일정으로 넣어요 · 캘린더에는 종일로 보여요')
      else ...[
        if (overlaps != null) OverlapLine(overlaps),
        if (past != null) CardNote(icon: AppIconName.clock, text: past),
        const FormLabel('알림'),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final minutes in {
              ...DirectAddLimits.reminderChoices,
              ?draft.reminderMinutes,
            })
              ChoiceChipButton(
                label: switch (minutes) {
                  0 => '없음',
                  60 => '1시간 전',
                  _ => '$minutes분 전',
                },
                selected: (draft.reminderMinutes ?? 0) == minutes,
                onTap: _busy
                    ? null
                    : () => _set(
                        draft.copyWith(
                          reminderMinutes: () => minutes == 0 ? null : minutes,
                        ),
                      ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.s4),
          child: Text(
            '알림은 다시 설계하고 있어요 · 지금은 고른 값만 저장해요',
            style: AppText.caption.copyWith(color: colors.muted),
          ),
        ),
      ],
    ];
  }

  List<Widget> _repeatingFields(DirectAddDraft draft) {
    final days = draft.weekdays.toList()..sort();
    final overlaps = days.isEmpty
        ? null
        : ref.watch(
            eventOverlapsProvider(draft.copyWith(title: '').toEventDraft()),
          );
    return [
      FormLabel(
        '요일',
        trailing: days.isEmpty ? '고른 요일마다 반복해요' : repeatText(days),
        trailingAccent: days.isNotEmpty,
      ),
      WeekdayPicker(
        selected: draft.weekdays,
        onChanged: _busy
            ? null
            : (weekdays) => _set(draft.copyWith(weekdays: weekdays)),
      ),
      if (_issue == DirectAddIssue.weekdays)
        _IssueLine(directAddIssueText(DirectAddIssue.weekdays)),
      FormLabel('시간', trailing: durationText(draft.endMin - draft.startMin)),
      _timeFields(draft, enabled: true),
      if (overlaps != null) OverlapLine(overlaps),
    ];
  }

  /// 시작·끝 칸(단추는 30분 단위, 시각을 누르면 5분 단위 휠. 끝은 다음 날 06:00까지이고 시작에서 하루를 넘지 않음).
  Widget _timeFields(DirectAddDraft draft, {required bool enabled}) {
    const step = DirectAddLimits.step;
    final endHigh = draft.startMin + 1440 - step < DirectAddLimits.endHigh
        ? draft.startMin + 1440 - step
        : DirectAddLimits.endHigh;
    return TimeRangeFields(
      startMin: draft.startMin,
      endMin: draft.endMin,
      startLow: DirectAddLimits.startLow,
      startHigh: DirectAddLimits.startHigh,
      endHigh: endHigh,
      step: step,
      pickStep: DirectAddLimits.pickStep,
      onChanged: enabled && !_busy
          ? (start, end) => _set(draft.copyWith(startMin: start, endMin: end))
          : null,
    );
  }

  List<Widget> _taskFields(DirectAddDraft draft, DateTime today, DateTime now) {
    final colors = AppColors.of(context);
    final task = draft.toTaskDraft();
    final due = draft.dueDate;
    final dueAt = draft.dueAt;
    final left = dueAt?.difference(now).inMinutes;
    final courseId = task.courseName == null
        ? null
        : ref
              .watch(selectableCoursesProvider)
              .value
              ?.where((course) => course.name == task.courseName)
              .firstOrNull
              ?.id;
    final estimate = taskEstimateOf(
      task,
      courseId: courseId,
      config: ref.watch(plannerConfigProvider),
    ).minutes;
    // 제목은 자리에 영향이 없으므로 빼고 견준다(쓰는 동안 다시 계산하지 않게).
    final preview = ref.watch(
      directTaskPreviewProvider(draft.copyWith(title: '').toTaskDraft()),
    );
    return [
      FormLabel(
        '마감',
        trailing: due == null
            ? '마감 없음'
            : '${monthDayText(due, today: today)} ${hhmmText(draft.dueTimeMin)}',
      ),
      _DayStrip(
        days: directAddDays(today, include: due),
        today: today,
        selected: due,
        noneChip: true,
        enabled: !_busy,
        onPick: (day) => _set(draft.copyWith(dueDate: () => day)),
      ),
      if (due != null) ...[
        const SizedBox(height: AppSpace.s8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.listGroup),
            border: Border.all(color: colors.edge),
          ),
          child: StepperRow(
            label: '마감 시각',
            value: hhmmText(draft.dueTimeMin),
            onValueTap: _busy
                ? null
                : () async {
                    final picked = await showTimeWheelSheet(
                      context,
                      title: '마감 시각',
                      initial: draft.dueTimeMin,
                      low: 0,
                      high: 1435,
                      step: DirectAddLimits.pickStep,
                    );
                    if (picked != null && mounted) {
                      _set(draft.copyWith(dueTimeMin: picked));
                    }
                  },
            decLabel: '마감 30분 앞당기기',
            incLabel: '마감 30분 늦추기',
            onDec: _busy
                ? null
                : switch (stepDueTime(draft.dueTimeMin, later: false)) {
                    final minute? => () => _set(
                      draft.copyWith(dueTimeMin: minute),
                    ),
                    null => null,
                  },
            onInc: _busy
                ? null
                : switch (stepDueTime(draft.dueTimeMin, later: true)) {
                    final minute? => () => _set(
                      draft.copyWith(dueTimeMin: minute),
                    ),
                    null => null,
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s8,
            AppSpace.s4,
            0,
          ),
          child: Text(
            left != null && left > 0
                ? '마감까지 ${remainingText(left)}'
                : '마감 시각이 지났어요',
            style: AppText.caption.copyWith(
              color: left != null && left > 1440 ? colors.muted : colors.alert,
              fontWeight: AppText.semibold,
            ),
          ),
        ),
      ],
      if (_issue == DirectAddIssue.pastDue)
        _IssueLine(directAddIssueText(DirectAddIssue.pastDue)),
      const FormLabel('예상 시간'),
      Wrap(
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          for (final minutes in estimateChoices(estimate))
            ChoiceChipButton(
              label: durationText(minutes),
              selected: minutes == estimate,
              onTap: _busy
                  ? null
                  : () =>
                        _set(draft.copyWith(pickedEstimateMin: () => minutes)),
            ),
        ],
      ),
      if (preview != null)
        CardNote(
          icon: AppIconName.calendar,
          text: preview.text,
          alert: preview.alert,
        ),
    ];
  }

  /// 장소·준비물(선택). 일정과 반복 일정에 둔다.
  List<Widget> _extraFields(DirectAddDraft draft) => [
    const FormLabel('장소', trailing: '선택'),
    TextField(
      controller: _place,
      enabled: !_busy,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        LengthLimitingTextInputFormatter(DirectAddLimits.fieldLength),
      ],
      decoration: formInputDecoration(context, hint: '예: 학생회관 2층'),
      onChanged: (text) => _set(_draft.copyWith(place: text)),
    ),
    const FormLabel('준비물', trailing: '선택'),
    TextField(
      controller: _prep,
      enabled: !_busy,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        LengthLimitingTextInputFormatter(DirectAddLimits.fieldLength),
      ],
      decoration: formInputDecoration(context, hint: '예: 노트북, 운동복'),
      onChanged: (text) => _set(_draft.copyWith(prep: text)),
    ),
  ];
}

/// 위 막대: 뒤로(폼이 화면 자체) 또는 닫기, '말로 넣기'.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.root, required this.onChat});

  final bool root;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s12,
        AppSpace.s4,
      ),
      child: Row(
        children: [
          if (root)
            const BackButton()
          else
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: AppIcon(AppIconName.close, size: 22, color: colors.ink2),
            ),
          const Spacer(),
          if (onChat != null)
            TextButton.icon(
              onPressed: onChat,
              icon: AppIcon(
                AppIconName.assistant,
                size: 16,
                color: colors.accent,
              ),
              label: const Text('말로 넣기'),
            ),
        ],
      ),
    );
  }
}

/// AI를 쓸 수 없는 까닭(최종 프로토타입).
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onAiOn});

  final DirectAddNotice notice;
  final VoidCallback? onAiOn;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (icon, title, body) = switch (notice) {
      DirectAddNotice.aiOff => (
        AppIconName.info,
        'AI를 쓰지 않도록 설정했어요',
        '직접 추가로 일정과 할 일을 넣어요. AI를 켜면 말로 넣고 규칙도 말로 정할 수 있어요.',
      ),
      DirectAddNotice.limit => (
        AppIconName.hourglass,
        '오늘 AI 사용량을 다 썼어요',
        '내일 다시 쓸 수 있어요. 지금은 직접 넣어 주세요.',
      ),
      DirectAddNotice.closed => (
        AppIconName.assistant,
        'AI 비서는 아직 준비 중이에요',
        '지금은 직접 추가로 일정과 할 일을 넣어요.',
      ),
      DirectAddNotice.offline => (
        AppIconName.offline,
        '인터넷에 연결되어 있지 않아요',
        '말로 넣기는 연결되면 다시 쓸 수 있어요. 직접 넣은 일정은 폰에 바로 저장돼요.',
      ),
      DirectAddNotice.failed => (
        AppIconName.warning,
        'AI가 답하지 않아 직접 추가로 열었어요',
        '보낸 문장은 저장하지 않았어요. 아래에 넣어 주세요.',
      ),
    };
    final onAiOn = notice == DirectAddNotice.aiOff ? this.onAiOn : null;
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s16),
      padding: const EdgeInsets.all(AppSpace.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.smallCard),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: AppIcon(icon, size: 20, color: colors.accent),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(
                        fontWeight: AppText.semibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: AppText.small.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onAiOn != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s12, left: 52),
              child: OutlinedButton(
                onPressed: onAiOn,
                child: const Text('AI 켜기'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 규칙 모드의 띠: 규칙은 12 내 규칙의 폼으로 정한다.
class _RulesBand extends StatelessWidget {
  const _RulesBand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: Semantics(
        button: true,
        child: Material(
          color: colors.tint,
          borderRadius: BorderRadius.circular(AppRadius.notice),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                child: Row(
                  children: [
                    AppIcon(AppIconName.rule, size: 18, color: colors.accent),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        '규칙은 내 규칙 화면의 폼으로 정해요',
                        style: AppText.small.copyWith(color: colors.ink2),
                      ),
                    ),
                    AppIcon(
                      AppIconName.chevronRight,
                      size: 15,
                      color: colors.icon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보내려던 문장.
class _QuoteBox extends StatelessWidget {
  const _QuoteBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(AppRadius.notice),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보내려던 문장',
            style: AppText.caption.copyWith(
              color: colors.muted,
              fontWeight: AppText.semibold,
            ),
          ),
          Text(text, style: AppText.body),
        ],
      ),
    );
  }
}

/// 저장 띠: 넣은 것과 [캘린더 보기]/[할 일 보기].
class _SavedBandView extends StatelessWidget {
  const _SavedBandView({required this.band, required this.onOpen});

  final _SavedBand band;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.s12),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s12,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: colors.classTint,
        borderRadius: BorderRadius.circular(AppRadius.notice),
      ),
      child: Row(
        children: [
          AppIcon(AppIconName.check, size: 16, color: colors.accent),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              band.text,
              style: AppText.small.copyWith(color: colors.ink),
            ),
          ),
          TextButton(onPressed: onOpen, child: Text(band.link)),
        ],
      ),
    );
  }
}

/// 저장하지 못하게 하는 까닭 한 줄.
class _IssueLine extends StatelessWidget {
  const _IssueLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s8,
          AppSpace.s4,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AppIcon(
                AppIconName.warning,
                size: 14,
                color: colors.alert,
              ),
            ),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: Text(
                text,
                style: AppText.small.copyWith(
                  color: colors.alert,
                  fontWeight: AppText.semibold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 날짜 칩 줄(가로로 넘김). [noneChip]이면 맨 앞에 '마감 없음'을 둔다(고르면 null).
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.today,
    required this.selected,
    required this.enabled,
    required this.onPick,
    this.noneChip = false,
  });

  final List<DateTime> days;
  final DateTime today;
  final DateTime? selected;
  final bool enabled;
  final ValueChanged<DateTime?> onPick;
  final bool noneChip;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (noneChip)
          _DayChip(
            top: '마감',
            bottom: '없음',
            label: '마감 없음',
            selected: selected == null,
            onTap: enabled ? () => onPick(null) : null,
          ),
        for (final day in days)
          _DayChip(
            top: switch (DateTime.utc(day.year, day.month, day.day)
                .difference(DateTime.utc(today.year, today.month, today.day))
                .inDays) {
              0 => '오늘',
              1 => '내일',
              _ => weekdayText(day.weekday),
            },
            bottom: '${day.day}',
            label: monthDayText(day, today: today),
            selected: day == selected,
            onTap: enabled ? () => onPick(day) : null,
          ),
      ],
    ),
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.top,
    required this.bottom,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String bottom;

  /// 화면 낭독기가 읽는 이름('11월 20일 (금)').
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = selected ? colors.onStrong : colors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Press(
          enabled: onTap != null,
          child: Material(
            color: selected ? colors.strong : colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              side: selected ? BorderSide.none : BorderSide(color: colors.edge),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 52,
                  minHeight: AppSize.minTouch + AppSpace.s8,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s8,
                    vertical: AppSpace.s4 + 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        top,
                        style: AppText.caption.copyWith(
                          color: selected ? ink : colors.muted,
                        ),
                      ),
                      Text(
                        bottom,
                        style: AppText.bodyLarge.copyWith(
                          color: ink,
                          fontWeight: AppText.semibold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
