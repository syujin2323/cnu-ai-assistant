// 10 나(나 탭 `/me`). docs/screens.md '10 나'·''충남대 비공식 앱' 표시'.
//
// 위에서부터 앱 이름과 '충남대 비공식 앱', 학기 카드(과목 수·이번 주 할 일 수, 누르면 03 할 일), LMS 계정(가린 학번,
// 상태, 상태별 줄, 로그아웃, PC·웹 세션이 끊길 수 있다는 한 줄), 일정(시간표·고정 일정·내 규칙·하루 경계·이동·점심
// 시간 표시), 알림(아침 브리핑 시각), AI(사용 스위치와 상태, 동의 문구 다시 보기), 화면(글자 크기), 데이터(데모
// 모드, 데이터 삭제), 앱 정보(처리방침·이용약관·오픈소스 라이선스·문의 메일·버전)다. 사용 지표 보내기는 지표를
// 보내는 PR에서 붙인다. 데모 모드에서는 LMS 계정 동작과 데이터 삭제를 두지 않는다(데모를 끝내면 샘플이 지워짐).
// 하루 경계·이동·점심 시간 표시·브리핑 시각·AI는 그 모드의 폰 DB에 쓴다(데모에서는 데모 DB).

import 'dart:async';

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/app/update_required.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/legal_texts.dart';
import 'package:cnu_ai_assistant/design/motion/press.dart';
import 'package:cnu_ai_assistant/design/motion/rise.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/external_link.dart';
import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/models.dart';
import 'package:cnu_ai_assistant/domain/rules.dart';
import 'package:cnu_ai_assistant/domain/text/josa.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/lms_connect/lms_actions.dart';
import 'package:cnu_ai_assistant/features/me/me_controller.dart';
import 'package:cnu_ai_assistant/features/me/timetable_screen.dart';
import 'package:cnu_ai_assistant/features/me/widgets/me_rows.dart';
import 'package:cnu_ai_assistant/features/me/widgets/me_sheets.dart';
import 'package:cnu_ai_assistant/lms/sync_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 10 나.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    final exiting = ref.watch(demoExitProvider) == DemoExitState.exiting;
    final version = ref.watch(appVersionProvider).value;
    final contact = contactEmailFrom(privacyPolicyMarkdown);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s16,
            AppSpace.screen,
            MediaQuery.paddingOf(context).bottom + 100,
          ),
          children: [
            Rise(
              child: Wrap(
                spacing: 10,
                runSpacing: AppSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      AppStrings.appName,
                      style: AppText.heading,
                    ),
                  ),
                  Text(
                    AppStrings.unofficialShort,
                    style: AppText.small.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            const Rise(
              delay: Duration(milliseconds: 60),
              child: _SemesterCard(),
            ),
            Rise(
              delay: const Duration(milliseconds: 110),
              child: _LmsAccount(demo: demo),
            ),
            const Rise(
              delay: Duration(milliseconds: 170),
              child: _ScheduleGroup(),
            ),
            const Rise(
              delay: Duration(milliseconds: 230),
              child: _BriefingGroup(),
            ),
            const Rise(delay: Duration(milliseconds: 290), child: _AiGroup()),
            const Rise(
              delay: Duration(milliseconds: 350),
              child: MeGroup(
                title: '화면',
                children: [
                  MeRow(
                    icon: AppIconName.eye,
                    label: '글자 크기',
                    sub: '기기 설정을 따라요',
                    value: '시스템',
                  ),
                ],
              ),
            ),
            Rise(
              delay: const Duration(milliseconds: 410),
              child: MeGroup(
                title: '데이터',
                children: [
                  if (demo)
                    MeRow(
                      icon: AppIconName.demo,
                      label: '데모 모드 끝내기',
                      sub: '샘플을 지우고 내 데이터로 돌아가요',
                      chevron: false,
                      onTap: exiting
                          ? null
                          : () => ref.read(demoExitProvider.notifier).exit(),
                    )
                  else ...[
                    MeRow(
                      icon: AppIconName.demo,
                      label: '데모 모드 들어가기',
                      sub: '샘플 학생의 하루로 둘러봐요. 내 데이터는 그대로예요',
                      chevron: false,
                      onTap: () => _enterDemo(context, ref),
                    ),
                    MeRow(
                      icon: AppIconName.trash,
                      label: '데이터 삭제',
                      sub: '이 폰의 모든 데이터와 LMS 로그인 정보를 지워요',
                      alert: true,
                      onTap: () => _deleteData(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            Rise(
              delay: const Duration(milliseconds: 470),
              child: MeGroup(
                title: '앱 정보',
                children: [
                  MeRow(
                    icon: AppIconName.shield,
                    label: LegalDocument.privacy.title,
                    onTap: () =>
                        showLegalDocument(context, LegalDocument.privacy),
                  ),
                  MeRow(
                    icon: AppIconName.doc,
                    label: LegalDocument.terms.title,
                    onTap: () =>
                        showLegalDocument(context, LegalDocument.terms),
                  ),
                  MeRow(
                    icon: AppIconName.list,
                    label: '오픈소스 라이선스',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: AppStrings.appName,
                      applicationVersion: version,
                    ),
                  ),
                  if (contact != null)
                    MeRow(
                      icon: AppIconName.mail,
                      label: '문의 메일',
                      sub: contact,
                      onTap: () => openExternalLink(
                        context,
                        Uri(scheme: 'mailto', path: contact),
                      ),
                    ),
                  MeRow(
                    icon: AppIconName.info,
                    label: '버전',
                    value: version ?? '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enterDemo(BuildContext context, WidgetRef ref) async {
    await ref.read(appModeProvider.notifier).enterDemo(DemoEntry.me);
    if (!context.mounted) return;
    // 시작 위치(redirect)가 데모 DB를 보고 브리핑이나 오늘로 보낸다.
    context.go(Routes.root);
  }

  /// 데이터 삭제: 되돌릴 수 없다고 알리고, 지우면 첫 실행처럼 14 온보딩 1단계로 간다.
  Future<void> _deleteData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeleteDataSheet(
      context,
      ref.read(motionLevelProvider),
    );
    if (!confirmed || !context.mounted) return;
    switch (await ref.read(dataDeletionProvider).deleteAll()) {
      case Ok():
        if (context.mounted) context.go(Routes.root);
      case Err():
        ref
            .read(toastControllerProvider.notifier)
            .show('데이터를 지우지 못했어요. 다시 해 주세요');
    }
  }
}

/// 저장하지 못했을 때의 문구(디자인 전 임시 문구).
const String _saveFailedText = '바꾸지 못했어요. 다시 해 주세요';

/// 일정: 시간표·고정 일정·내 규칙(셸 밖 전체 화면은 push로 열어, 닫으면 10 나로 돌아온다), 하루 경계, 이동·점심
/// 시간 표시. 설정을 읽기 전에는 값을 보이지 않고 바꿀 수 없다.
class _ScheduleGroup extends ConsumerWidget {
  const _ScheduleGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    return MeGroup(
      title: '일정',
      children: [
        MeRow(
          icon: AppIconName.calendar,
          label: '시간표',
          onTap: () => context.push(Routes.meTimetable),
        ),
        MeRow(
          icon: AppIconName.calendar,
          label: '고정 일정',
          onTap: () => context.push(Routes.meTimetableTab(TimetableTab.fixed)),
        ),
        MeRow(
          icon: AppIconName.pencil,
          label: AppStrings.myRules,
          sub: '말이나 폼으로 정한 배치 조건',
          onTap: () => context.push(Routes.meRules),
        ),
        MeRow(
          icon: AppIconName.moon,
          label: '하루 경계',
          sub: '이 시각 전까지는 전날로 봐요',
          value: settings == null ? null : hhmmText(settings.dayBoundaryMin),
          onTap: settings == null
              ? null
              : () => _pickDayBoundary(context, ref, settings.dayBoundaryMin),
        ),
        MeSwitchRow(
          icon: AppIconName.bus,
          label: '이동·점심 시간 표시',
          sub: '꺼도 할 일을 놓을 때는 그 시간을 비워 둬요',
          value:
              settings?.showTravelMeal ?? AppSettings.defaults.showTravelMeal,
          onChanged: settings == null
              ? null
              : (on) => _write(ref, SettingKeys.showTravelMeal, on),
        ),
      ],
    );
  }

  /// 하루 경계 시트에서 고르면 `settings`의 `dayBoundaryMin`에 쓴다(되돌리기 없음).
  Future<void> _pickDayBoundary(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final picked = await showDayBoundarySheet(
      context,
      ref.read(motionLevelProvider),
      current: current,
    );
    if (picked == null || picked == current) return;
    final saved = await _write(ref, SettingKeys.dayBoundaryMin, picked);
    if (saved) {
      ref
          .read(toastControllerProvider.notifier)
          .show('하루 경계를 ${withJosa(hhmmText(picked), Josa.euroRo)} 바꿨어요');
    }
  }
}

/// [key]에 [value]를 쓴다. 쓰지 못하면 토스트로 알리고 false다.
Future<bool> _write(WidgetRef ref, String key, Object? value) async {
  switch (await ref.read(settingsRepositoryProvider).write(key, value)) {
    case Ok():
      return true;
    case Err():
      ref.read(toastControllerProvider.notifier).show(_saveFailedText);
      return false;
  }
}

/// 알림: 아침 브리핑 시각(14 온보딩 5단계와 같은 칩). 고르면 내 규칙 `notify`(`source` `manual`)로 저장하고
/// 되돌리기 토스트를 보인다. 다른 알림 항목은 두지 않는다(알림은 재설계 예정).
class _BriefingGroup extends ConsumerWidget {
  const _BriefingGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value;
    final briefingMin = rules == null
        ? null
        : NotifyConfig.from(rules).briefingMin;
    return MeGroup(
      title: '알림',
      children: [
        MeRow(
          icon: AppIconName.sun,
          label: '아침 브리핑',
          value: briefingMin == null ? null : hhmmText(briefingMin),
          semanticsLabel: briefingMin == null
              ? null
              : '아침 브리핑, 매일 ${clockText(briefingMin)}',
          onTap: briefingMin == null
              ? null
              : () => _pickBriefingTime(context, ref, briefingMin),
        ),
      ],
    );
  }

  Future<void> _pickBriefingTime(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final picked = await showBriefingTimeSheet(
      context,
      ref.read(motionLevelProvider),
      current: current,
    );
    if (picked == null || picked == current) return;
    final saved = await ref
        .read(rulesRepositoryProvider)
        .save(
          kind: RuleKind.notify,
          params: RuleParams(briefingMin: picked),
          source: EntrySource.manual,
          now: ref.read(clockProvider).now(),
        );
    final toast = ref.read(toastControllerProvider.notifier);
    switch (saved) {
      case Ok():
        toast.show(
          '아침 브리핑을 ${withJosa(hhmmText(picked), Josa.euroRo)} 바꿨어요',
          undoable: true,
        );
      case Err():
        toast.show(_saveFailedText);
    }
  }
}

/// AI: 사용 스위치와 상태(켜짐/꺼짐/오늘 사용량 다 씀, [aiStatusOf]), 동의 문구 다시 보기. 켜면 AI 사용 동의를
/// 묻고 동의하면 `aiEnabled`를 켜고 `aiConsentAt`을 적는다. 끄면 바로 끈다.
class _AiGroup extends ConsumerWidget {
  const _AiGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final settings = ref.watch(settingsProvider).value;
    final now = ref.watch(minuteClockProvider);
    final state = settings == null ? null : aiStatusOf(settings, now: now);
    final note = switch (state) {
      AiStatus.off => 'AI를 끄면 AI 비서는 직접 추가 폼으로 열고, 내 규칙은 폼으로 정해요',
      AiStatus.limitReached => '내일 다시 쓸 수 있어요. 그동안은 직접 추가 폼과 내 규칙 폼으로 해요',
      AiStatus.on || null => null,
    };
    return MeGroup(
      title: 'AI',
      footer: note == null
          ? null
          : Text(note, style: AppText.caption.copyWith(color: colors.muted)),
      children: [
        MeSwitchRow(
          icon: AppIconName.assistant,
          label: 'AI 사용',
          sub: switch (state) {
            AiStatus.on => '켜져 있어요',
            AiStatus.off => '꺼져 있어요',
            AiStatus.limitReached => '오늘 사용량을 다 썼어요',
            null => null,
          },
          value: settings?.aiEnabled ?? false,
          onChanged: settings == null ? null : (on) => _setAi(context, ref, on),
        ),
        MeRow(
          icon: AppIconName.doc,
          label: '동의 문구 다시 보기',
          onTap: () => showAiConsentReview(
            context,
            ref.read(motionLevelProvider),
            consentedOn: switch (settings) {
              AppSettings(aiEnabled: true, aiConsentAt: final at?) =>
                monthDayText(
                  DateTime(at.year, at.month, at.day),
                  today: DateTime(now.year, now.month, now.day),
                ),
              _ => null,
            },
          ),
        ),
      ],
    );
  }

  Future<void> _setAi(BuildContext context, WidgetRef ref, bool on) async {
    final repository = ref.read(settingsRepositoryProvider);
    final toast = ref.read(toastControllerProvider.notifier);
    if (!on) {
      if (await _write(ref, SettingKeys.aiEnabled, false)) {
        toast.show('AI 사용을 껐어요 · 일정·할 일은 직접 넣어요');
      }
      return;
    }
    if (!await showAiConsentSheet(context, ref.read(motionLevelProvider))) {
      return;
    }
    final saved = await repository.writeAll({
      SettingKeys.aiEnabled: true,
      SettingKeys.aiConsentAt: ref.read(clockProvider).now(),
    });
    toast.show(switch (saved) {
      Ok() => 'AI 사용에 동의했어요 · 나 › AI에서 언제든 끌 수 있어요',
      Err() => _saveFailedText,
    });
  }
}

/// 학기 카드: 과목 수와 이번 주 할 일 수. 누르면 03 할 일.
class _SemesterCard extends ConsumerWidget {
  const _SemesterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final courses = ref.watch(courseCountProvider).value;
    final weekly = ref.watch(weeklyTaskCountProvider);
    final counts = '과목 ${courses ?? '–'}개 · 이번 주 할 일 ${weekly ?? '–'}개';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16),
      child: Semantics(
        button: true,
        label: '이번 학기, $counts, 할 일 보기',
        excludeSemantics: true,
        child: Press(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go(Routes.tasks),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.surface, colors.tint],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: colors.edge),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.edge),
                      ),
                      child: AppIcon(
                        AppIconName.school,
                        size: 22,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이번 학기',
                            style: AppText.bodyLarge.copyWith(
                              fontWeight: AppText.semibold,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            counts,
                            style: AppText.small.copyWith(color: colors.ink2),
                          ),
                        ],
                      ),
                    ),
                    AppIcon(
                      AppIconName.chevronRight,
                      size: 16,
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

/// LMS 계정: 가린 학번과 상태, 상태별 줄, 로그아웃.
class _LmsAccount extends ConsumerWidget {
  const _LmsAccount({required this.demo});

  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final status = ref.watch(lmsStatusProvider);
    final busy = ref.watch(lmsSyncingProvider).value ?? false;
    final studentId = ref.watch(maskedStudentIdProvider).value;
    final kind = status?.kind;
    final rows = <Widget>[
      MeRow(
        icon: AppIconName.person,
        label: demo ? '데모 계정' : studentId ?? '로그인하지 않았어요',
        sub: status?.text,
        subColor: kind == null ? null : lmsStatusColor(colors, kind),
      ),
    ];
    if (!demo) {
      switch (kind) {
        case LmsStatusKind.synced ||
            LmsStatusKind.connectionFailed ||
            LmsStatusKind.maintenance:
          final retry = kind != LmsStatusKind.synced;
          rows.add(
            MeRow(
              icon: AppIconName.refresh,
              label: busy
                  ? LmsStatusLine.busyText
                  : (retry ? '다시 확인' : '지금 새로 고침'),
              sub: '할 일과 마감을 지금 다시 받아요',
              chevron: false,
              onTap: busy ? null : () => _refresh(ref),
            ),
          );
        case LmsStatusKind.reloginNeeded:
          rows.add(
            MeRow(
              icon: AppIconName.person,
              label: '다시 로그인',
              sub: '비밀번호가 바뀌었거나 로그인이 끝났어요',
              accent: true,
              onTap: () => openRelogin(context, ref),
            ),
          );
        case LmsStatusKind.beforeLogin:
          rows.add(
            MeRow(
              icon: AppIconName.key,
              label: 'LMS에 로그인',
              sub: '학번과 비밀번호로 로그인하면 시간표와 할 일을 불러와요',
              onTap: () => openRelogin(context, ref),
            ),
          );
        case LmsStatusKind.paused || LmsStatusKind.demo || null:
          break;
      }
      if (studentId != null) {
        rows.add(
          MeCenterRow(label: '로그아웃', onTap: () => _logout(context, ref)),
        );
      }
    }
    return MeGroup(
      title: 'LMS 계정',
      footer: demo
          ? null
          : Text(
              '로그인하거나 앱이 자동으로 다시 로그인하면 PC·웹 LMS 세션이 끊길 수 있어요',
              style: AppText.caption.copyWith(color: colors.muted),
            ),
      children: rows,
    );
  }

  void _refresh(WidgetRef ref) => unawaited(
    ref
        .read(syncCoordinatorProvider)
        .run(trigger: SyncTrigger.manual, scope: SyncScope.list),
  );

  /// 로그아웃: 지우는 것과 두는 것을 보이고, 로그아웃하면 14 온보딩 1단계로 간다.
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showLogoutSheet(
      context,
      ref.read(motionLevelProvider),
    );
    if (!confirmed || !context.mounted) return;
    switch (await ref.read(logoutProvider)()) {
      case Ok():
        if (context.mounted) context.go(Routes.root);
      case Err():
        ref
            .read(toastControllerProvider.notifier)
            .show('로그아웃하지 못했어요. 다시 해 주세요');
    }
  }
}
