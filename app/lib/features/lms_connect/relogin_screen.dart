// 14 다시 로그인(셸 밖 전체 화면 `/login`). docs/screens.md '다시 로그인'.
//
// 01 아침 브리핑·02 홈·03 할 일의 '다시 로그인' 칩, 03 할 일 LMS 정보 시트, 10 나 › LMS 계정이
// `context.push(Routes.login)`으로 열고, 로그인이 끝나면 pop해 연 화면으로 돌아간다(go로 열면 돌아갈
// 곳이 없다). 데모 모드에서는 이 화면을 열지 않고 '데모에서는 LMS에 연결하지 않아요'를 띄운다.
// 받아 둔 할 일은 그대로라고 안내하고, 14 온보딩 1단계와 함께 쓰는 로그인 폼의 다시 로그인 모드(저장된 학번
// 고정, 비밀번호만. 저장된 학번이 없으면 학번 칸도 엶. 동의와 '로그인 없이 둘러보기'는 없음)를 둔다.
// 진행 줄 둘(다시 로그인 → 할 일 새로 불러오기)이 끝나면 돌아가고, 시간표는 다시 부르지 않는다.

import 'package:cnu_ai_assistant/app/router.dart';
import 'package:cnu_ai_assistant/design/strings.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/features/lms_connect/login_form.dart';
import 'package:cnu_ai_assistant/lms/login_flow.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 14 다시 로그인.
class ReloginScreen extends StatelessWidget {
  const ReloginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('다시 로그인')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.screen,
            AppSpace.s8,
            AppSpace.screen,
            AppSpace.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '받아 둔 할 일은 그대로 있어요.',
                style: AppText.body.copyWith(color: colors.ink2),
              ),
              const SizedBox(height: AppSpace.s20),
              LoginForm(
                mode: LoginMode.relogin,
                onSucceeded: () async {
                  if (context.mounted) _close(context);
                },
              ),
              const SizedBox(height: AppSpace.s24),
              Text(
                AppStrings.unofficialShort,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 연 화면으로 돌아간다. 돌아갈 곳이 없으면(직접 연 경우) 시작 위치로 간다.
  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.root);
    }
  }
}
