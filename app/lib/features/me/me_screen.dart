// 10 나(나 탭 `/me`). docs/screens.md '10 나'·''충남대 비공식 앱' 표시'.
//
// 위에서부터 앱 이름과 '충남대 비공식 앱', 학기 카드(과목 수·이번 주 할 일 수, 누르면 03 할 일), LMS 계정(가린 학번,
// 상태, 상태별 줄, 로그아웃, PC·웹 세션이 끊길 수 있다는 한 줄), 일정(시간표·고정 일정·내 규칙), 데이터(데모 모드,
// 데이터 삭제), 앱 정보(처리방침·이용약관·오픈소스 라이선스·문의 메일·버전)다. 하루 경계·브리핑 시각·AI·사용
// 지표·화면 항목은 다음 PR에서 붙인다. 데모 모드에서는 LMS 계정 동작과 데이터 삭제를 두지 않는다(데모를 끝내면
// 샘플이 지워짐).

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
import 'package:cnu_ai_assistant/design/widgets/external_link.dart';
import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/design/widgets/lms_status_line.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/lms_status.dart';
import 'package:cnu_ai_assistant/domain/models/sync_run.dart';
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
            Rise(
              delay: const Duration(milliseconds: 170),
              child: MeGroup(
                title: '일정',
                children: [
                  // 셸 밖 전체 화면은 push로 열어, 닫으면 10 나로 돌아온다.
                  MeRow(
                    icon: AppIconName.calendar,
                    label: '시간표',
                    onTap: () => context.push(Routes.meTimetable),
                  ),
                  MeRow(
                    icon: AppIconName.calendar,
                    label: '고정 일정',
                    onTap: () =>
                        context.push(Routes.meTimetableTab(TimetableTab.fixed)),
                  ),
                  MeRow(
                    icon: AppIconName.pencil,
                    label: AppStrings.myRules,
                    sub: '말이나 폼으로 정한 배치 조건',
                    onTap: () => context.push(Routes.meRules),
                  ),
                ],
              ),
            ),
            Rise(
              delay: const Duration(milliseconds: 230),
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
              delay: const Duration(milliseconds: 290),
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
