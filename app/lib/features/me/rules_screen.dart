// 12 내 규칙(`/me/rules`). docs/screens.md '12 내 규칙'.
//
// 말이나 폼으로 정한 배치 조건의 목록이다. 카드마다 종류 이름, 짧은 값(`domain/rule_text.dart`), 말로 정했으면 원래
// 문장, 출처('말로 정함'/'직접 정함'), 스위치와 [지우기]를 둔다. 저장된 값을 읽지 못한 규칙은 '읽을 수 없는 규칙'
// 카드로 보이고 [지우기]만 둔다. 켜고 끄거나 지우면 되돌리기 토스트를 띄우고, 표가 바뀌면 배치는 다시 계산된다
// (`data/plan_recalculator.dart`). [+ 규칙 추가]는 06 AI 비서를 규칙 모드로 연다(말로 정하기).
//
// 폼으로 직접 정하기·고치기와 겹치는 블록 시트는 아직 만들지 않았다(다음 PR). 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/form_parts.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rule_text.dart';
import 'package:cnu_ai_assistant/features/assistant/assistant_args.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 빈 상태에서 보이는 예시 문장. 누르면 06 AI 비서(규칙 모드)의 입력창에 넣는다.
const List<String> ruleExampleSentences = [
  '밤 11시 이후엔 공부 안 할래',
  '하루 공부는 4시간까지만',
  '한 번에 1시간 반까지만',
];

/// 12 내 규칙.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final rules = ref.watch(rulesProvider);
    final courses = ref.watch(selectableCoursesProvider).value ?? const [];
    final courseNames = {for (final course in courses) course.id: course.name};
    // 알림 규칙은 알림 재설계 전까지 보이지 않는다.
    final list = [
      for (final rule in rules.value ?? const <Rule>[])
        if (rule.kind != RuleKind.notify) rule,
    ];
    final active = list.where((r) => r.active && !r.isUnreadable).length;

    void speak([String? prefill]) => context.push(
      Routes.assistant,
      extra: AssistantArgs(mode: AssistantMode.rule, prefill: prefill),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myRules)),
      body: SafeArea(
        child: rules.value == null
            ? Center(
                child: rules.hasError
                    ? Text(
                        '규칙을 불러오지 못했어요',
                        style: AppText.body.copyWith(color: colors.muted),
                      )
                    : const SizedBox.shrink(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.screen,
                  AppSpace.s8,
                  AppSpace.screen,
                  AppSpace.s24,
                ),
                children: [
                  Text(
                    '할 일을 놓을 때 지키는 조건이에요. 이 폰에만 저장해요',
                    style: AppText.small.copyWith(color: colors.muted),
                  ),
                  if (list.isEmpty) ...[
                    const SizedBox(height: AppSpace.s24),
                    Text(
                      '아직 정한 규칙이 없어요',
                      style: AppText.body.copyWith(
                        fontWeight: AppText.semibold,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      '이렇게 말해 보세요',
                      style: AppText.small.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: AppSpace.s12),
                    Wrap(
                      spacing: AppSpace.s8,
                      runSpacing: AppSpace.s8,
                      children: [
                        for (final sentence in ruleExampleSentences)
                          ChoiceChipButton(
                            label: sentence,
                            selected: false,
                            onTap: () => speak(sentence),
                          ),
                      ],
                    ),
                  ] else ...[
                    FormLabel('배치', trailing: '$active개 켜짐'),
                    for (final rule in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s8),
                        child: _RuleCard(
                          rule: rule,
                          courseName: courseNames[rule.params.courseId],
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpace.s16),
                  FilledButton.icon(
                    onPressed: speak,
                    icon: const AppIcon(AppIconName.plus, size: 18),
                    label: const Text('규칙 추가 · 말로 정하기'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule, this.courseName});

  final Rule rule;

  /// 예상 시간 규칙의 과목 이름.
  final String? courseName;

  Future<void> _run(
    WidgetRef ref,
    Future<Result<bool>> Function() action,
    String done,
  ) async {
    final toast = ref.read(toastControllerProvider.notifier);
    switch (await action()) {
      case Ok(value: true):
        toast.show(done, undoable: true);
      case Ok():
        break;
      case Err():
        toast.show(AppStrings.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final repository = ref.read(rulesRepositoryProvider);
    DateTime now() => ref.read(clockProvider).now();
    final name = ruleKindName(rule.kind);
    final unreadable = rule.isUnreadable;
    final value = unreadable
        ? null
        : ruleShortValue(
            rule.kind,
            rule.params,
            weekdays: rule.weekdays,
            courseName: courseName,
          );
    final sentence = rule.sentence?.trim();
    final source = rule.source == EntrySource.ai ? '말로 정함' : '직접 정함';

    void delete() => _run(
      ref,
      () => repository.delete(rule.id, now: now()),
      '$name 규칙을 지웠어요',
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s8,
        AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.listGroup),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unreadable ? '읽을 수 없는 규칙 · $name' : name,
                      style: AppText.small.copyWith(
                        fontWeight: AppText.semibold,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? (unreadable ? '이 버전에서 읽을 수 없는 값이에요' : name),
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: AppText.semibold,
                        color: rule.active && !unreadable
                            ? colors.ink
                            : colors.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (sentence != null && sentence.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '“$sentence”',
                        style: AppText.small.copyWith(color: colors.ink2),
                      ),
                    ],
                  ],
                ),
              ),
              if (!unreadable)
                Semantics(
                  label: '$name 규칙 ${rule.active ? '켜짐' : '꺼짐'}',
                  child: Switch(
                    value: rule.active,
                    onChanged: (on) => _run(
                      ref,
                      () =>
                          repository.setActive(rule.id, active: on, now: now()),
                      on ? '$name 규칙을 켰어요' : '$name 규칙을 껐어요',
                    ),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  unreadable ? '배치에 쓰지 않아요' : source,
                  style: AppText.caption.copyWith(color: colors.muted),
                ),
              ),
              TextButton.icon(
                onPressed: delete,
                icon: const AppIcon(AppIconName.trash, size: 16),
                label: const Text('지우기'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
