// 나·설정(`/me`, 드로어의 톱니바퀴). 맨 위 앱 이름 옆에 '충남대 비공식 앱'을 두고, 설정 항목으로 간다.
// 설정 내용(AI 동의, 사캠, 알림, 모션 등)은 각 PR에서 더한다.

import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/icons.dart';
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
            const SizedBox(height: AppSpace.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: Text(
                AppStrings.inProgress,
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpace.s16),
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
