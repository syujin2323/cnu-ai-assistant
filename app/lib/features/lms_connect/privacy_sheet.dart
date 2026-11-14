// 개인정보 처리 안내 시트(14 온보딩 1단계의 '보기'). docs/screens.md '개인정보 처리 안내 시트'.
//
// 그 빌드가 실제로 하는 처리만 적는다(docs/decisions.md 2026-11-13 '개인정보 처리 안내 시트에는 그 빌드가
// 하는 것만 적는다'). 07 알림 감지 조각, 사용 지표, 07의 알림 접근 권한은 그 기능이 들어가는 R1 빌드부터
// 넣는다. 처리방침 전체 보기 링크는 처리방침을 공개해 주소가 생기면 붙인다
// (`design/widgets/external_link.dart`). '확인했어요'를 누르면 시트는 true를 돌려주고 폼이 동의를 체크한다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// 개인정보 처리 안내 시트를 연다. '확인했어요'를 누르면 true, 그냥 닫으면 false다.
Future<bool> showPrivacySheet(
  BuildContext context, {
  MotionLevel motion = MotionLevel.full,
}) async {
  final confirmed = await showAppSheet<bool>(
    context: context,
    motion: motion,
    builder: (context) => const PrivacySheet(),
  );
  return confirmed ?? false;
}

/// 개인정보 처리 안내.
class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget section(String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.body.copyWith(
              fontWeight: AppText.semibold,
              color: colors.ink,
            ),
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                line,
                style: AppText.body.copyWith(color: colors.ink2),
              ),
            ),
        ],
      ),
    );
    // 위 여백은 시트의 끌기 손잡이 자리가 대신한다(`showAppSheet`).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        0,
        AppSpace.screen,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text('개인정보 처리 안내', style: AppText.title),
          ),
          section('이 폰에만 두는 것', const [
            '학번·비밀번호는 이 폰의 보안 저장소에만 두고 LMS 로그인에만 써요. 앱 서버로는 보내지 않아요.',
            '불러온 시간표·할 일과 직접 넣은 일정·규칙도 이 폰에만 있어요.',
          ]),
          section('서버를 거치는 것', const [
            'AI 비서에 쓴 문장과 함께 보내는 것은 AI 사용에 동의했을 때만 해외 AI 제공사로 가요.',
            '앱 서버에는 설치마다 만든 무작위 값별 AI 호출 수(이틀)와 접속 기록(시각·IP, 30일)이 남아요.',
          ]),
          section('알아 둘 것', const [
            '꼭 허락해야 하는 권한은 없어요.',
            '로그인하거나 앱이 자동으로 다시 로그인하면 같은 계정으로 PC·웹에서 쓰던 LMS 세션이 끊길 수 있어요.',
            '로그아웃하면 학번·비밀번호와 LMS 로그인 정보, 불러온 시간표와 LMS 할 일을 지워요.',
          ]),
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인했어요'),
          ),
        ],
      ),
    );
  }
}
