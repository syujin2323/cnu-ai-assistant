// 나·설정(`/me`, 드로어의 톱니바퀴). 맨 위 앱 이름 옆에 '충남대 비공식 앱'을 두고, 설정 항목으로 간다.
//
// - 데일리 브리핑: 브리핑 시각(`notify` 규칙의 `briefingMin`)을 고르면 그 규칙에 합쳐 저장하고
//   알림을 다시 예약한다. 정확한 알람 권한이 없으면 "알림이 최대 한 시간 늦을 수 있어요"를 적는다.
// - 사이버캠퍼스: `settings`의 `lmsLastSuccessAt`으로 연결 상태를 보여 준다. 동기화는 아직 없어
//   '지금 동기화'는 누를 수 없게 둔다(사캠 연결 PR에서 붙인다).
// 그 밖의 설정 내용(AI 동의, 모션 등)은 각 PR에서 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
import 'package:cnu_ai_assistant/domain/defaults.dart';
import 'package:cnu_ai_assistant/domain/text/time_text.dart';
import 'package:cnu_ai_assistant/features/calendar/calendar_controller.dart';
import 'package:cnu_ai_assistant/features/me/me_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 10 나.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    return Scaffold(
      // 드로어에서 push로 열면 뒤로 가기가 캘린더로 돌아간다. 데모 끝내기처럼 go로 왔으면
      // 돌아갈 곳이 없으므로 캘린더로 가는 버튼을 둔다.
      appBar: AppBar(
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: '캘린더로 가기',
                onPressed: () => context.go(Routes.calendar),
                icon: const AppIcon(AppIconName.back, color: AppColors.ink),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: Wrap(
                spacing: AppSpace.s8,
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
                    AppStrings.unofficial,
                    style: AppText.caption.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            const _SectionTitle('데일리 브리핑'),
            const _BriefingTimeTile(),
            const SizedBox(height: AppSpace.s16),
            const _SectionTitle('사이버캠퍼스'),
            const _LmsSection(),
            const SizedBox(height: AppSpace.s16),
            const _SectionTitle('설정'),
            ListTile(
              title: const Text(AppStrings.myRules),
              onTap: () => context.push(Routes.meRules),
            ),
            ListTile(
              title: const Text(AppStrings.timetableAndFixed),
              onTap: () => context.push(Routes.meTimetable),
            ),
            if (!demo)
              ListTile(
                title: const Text('데모 모드 들어가기'),
                onTap: () => _enterDemo(context, ref),
              ),
            ListTile(
              title: const Text('오픈소스 라이선스'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppStrings.appName,
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
}

/// 설정 묶음의 제목.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s8,
        AppSpace.screen,
        AppSpace.s4,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppText.small.copyWith(
            fontWeight: AppText.semibold,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

/// '브리핑 시각' 행. 누르면 시각을 고르고 `notify` 규칙에 저장한다.
class _BriefingTimeTile extends ConsumerWidget {
  const _BriefingTimeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingMin =
        ref.watch(
          notifyConfigProvider.select((config) => config.value?.briefingMin),
        ) ??
        Defaults.briefingMin;
    final exact = ref.watch(exactAlarmAllowedProvider).value ?? true;
    return ListTile(
      title: const Text('브리핑 시각'),
      subtitle: Text(
        exact
            ? clockText(briefingMin)
            : '${clockText(briefingMin)} · 알림이 최대 한 시간 늦을 수 있어요',
      ),
      onTap: () => _pick(context, ref, briefingMin),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, int current) async {
    final picked = await showTimePicker(
      context: context,
      helpText: '브리핑 시각',
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    if (minute == current) return;
    final saved = await ref.read(saveBriefingTimeProvider)(minute);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브리핑 시각을 저장하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }
}

/// 사캠 연결 상태와 '지금 동기화'(아직 누를 수 없음).
class _LmsSection extends ConsumerWidget {
  const _LmsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(appModeProvider) == AppMode.demo;
    final lastSuccessAt = ref.watch(
      settingsProvider.select((settings) => settings.value?.lmsLastSuccessAt),
    );
    final today = ref
        .watch(clockProvider)
        .today(dayBoundaryMin: ref.watch(dayBoundaryProvider));
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.screen,
        vertical: AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lastSuccessAt == null
                ? '아직 연결하지 않았어요'
                : '마지막 동기화 ${_whenText(lastSuccessAt, today)}',
            style: AppText.body,
          ),
          const SizedBox(height: AppSpace.s12),
          const OutlinedButton(onPressed: null, child: Text('지금 동기화')),
          const SizedBox(height: AppSpace.s4),
          Text(
            demo ? '데모에서는 연결할 수 없어요' : '사캠 연결 기능은 준비 중이에요',
            style: AppText.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  /// '오늘 오후 3시', '어제 오전 9시 30분', '10월 27일 오후 1시'.
  static String _whenText(DateTime at, DateTime today) {
    final day = DateTime(at.year, at.month, at.day);
    final label = day == today
        ? '오늘'
        : day == DateTime(today.year, today.month, today.day - 1)
        ? '어제'
        : '${at.month}월 ${at.day}일';
    return '$label ${clockText(at.hour * 60 + at.minute)}';
  }
}
