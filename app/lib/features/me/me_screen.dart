// 10 나(나 탭 `/me`). 맨 위 앱 이름 옆에 짧은 '충남대 비공식 앱'을, 맨 아래에 긴 비공식 문구를 두고
// 설정 항목으로 간다(docs/screens.md '10 나'·''충남대 비공식 앱' 표시').
// 설정 내용(AI 동의, LMS, 알림, 모션 등)은 각 PR에서 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/domain/app_mode.dart';
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
                    AppStrings.unofficialShort,
                    style: AppText.caption.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: Text(
                AppStrings.inProgress,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpace.s16),
            // 셸 밖 전체 화면은 push로 열어, 닫으면 10 나로 돌아온다.
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
