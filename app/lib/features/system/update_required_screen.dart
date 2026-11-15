// 20 시스템: 업데이트 필요. docs/screens.md '20 시스템'.
//
// 앱 버전이 Remote Config `min_app_version`보다 낮으면 라우터가 어느 화면에서든 이 화면으로 막는다
// (`app/update_required.dart`, `app/router.dart`). 이유와 그대로인 것(폰 데이터, LMS 로그인)을 알리고
// 업데이트 버튼을 둔다. 버튼은 Android는 Play 스토어, iOS는 App Store에 내기 전까지 기기 등록 배포의 테스터
// 페이지를 연다(`AppConfig`). 뒤로 가기로 벗어나지 않는다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/app/config.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/external_link.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

/// 업데이트 필요 화면.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, this.launcher});

  /// 링크를 여는 함수. 테스트가 바꾼다.
  final Future<bool> Function(Uri uri)? launcher;

  /// 이 플랫폼에서 업데이트 버튼이 여는 주소.
  static Uri updateUri(TargetPlatform platform) => Uri.parse(
    platform == TargetPlatform.iOS
        ? AppConfig.iosUpdateUrl
        : AppConfig.androidUpdateUrl,
  );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.s32),
                Semantics(
                  header: true,
                  child: Text('새 버전으로 업데이트해 주세요', style: AppText.heading),
                ),
                const SizedBox(height: AppSpace.s12),
                Text(
                  '이 버전은 더 이상 쓸 수 없어요. 업데이트해도 이 폰에 있는 일정·할 일과 LMS 로그인은 그대로예요.',
                  style: AppText.body.copyWith(color: colors.ink2),
                ),
                const SizedBox(height: AppSpace.s24),
                FilledButton(
                  onPressed: () => openExternalLink(
                    context,
                    updateUri(defaultTargetPlatform),
                    launcher: launcher,
                  ),
                  child: const Text('업데이트하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
