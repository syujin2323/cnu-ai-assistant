// 개인정보 처리 안내 시트(14 온보딩 1단계의 '보기'). docs/screens.md '개인정보 처리 안내 시트'.
//
// 그 빌드가 실제로 하는 처리만 적는다(docs/decisions.md 2026-11-13 '개인정보 처리 안내 시트에는 그 빌드가
// 하는 것만 적는다'). 사용 지표는 10 나에서 켤 수 있는 빌드부터 적고(켠 사람만 보냄), 07 알림 감지 조각·07의
// 알림 접근 권한(스토어 공개 뒤)은 그 기능이 들어가는 빌드부터 넣는다. '처리방침 전체 보기'는 처리방침 전문을 외부 브라우저가 아니라 앱 안의 덮개
// 화면으로 연다(`design/widgets/legal_document.dart`). '확인했어요'를 누르면 시트는 true를 돌려주고 폼이 동의를
// 체크한다(폼의 동의 칸은 이 시트를 열지 않아도 바로 체크된다). 서버 신호 푸시(FCM) 줄은 원격 스위치
// `push_signal_enabled`가 켜졌을 때만 넣는다(그때부터 그 처리를 함, `platform/push.dart`).

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:cnu_ai_assistant/design/widgets/legal_document.dart';
import 'package:cnu_ai_assistant/platform/push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// 서버 신호 푸시(FCM)를 쓰는 동안 '서버를 거치는 것'에 더하는 줄.
const syncSignalPrivacyLine =
    'LMS에 로그인해 있는 동안 할 일을 새로 받으라는 신호를 Google(Firebase Cloud Messaging)을 거쳐 받아요. '
    '이 폰의 푸시 토큰으로 신호 하나를 구독할 뿐 알림은 띄우지 않고, 로그아웃하거나 데이터를 지우면 구독을 풀고 토큰을 지워요.';

/// 개인정보 처리 안내.
class PrivacySheet extends ConsumerWidget {
  const PrivacySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushSignal = ref.watch(pushSignalEnabledProvider).value ?? false;
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
          section('서버를 거치는 것', [
            'AI 비서에 쓴 문장과 함께 보내는 것은 AI 사용에 동의했을 때만 해외 AI 제공사로 가요.',
            '앱 서버에는 설치마다 만든 무작위 값별 AI 호출 수(이틀)와 접속 기록(시각·IP, 30일)이 남아요.',
            '앱이 멈추거나 오류가 나면 오류 종류와 코드 위치, 기기 모델·OS 버전, 설치마다 만든 무작위 값을 Google(Firebase Crashlytics)로 보내고 90일 동안 남아요. 할 일·일정·학번 같은 내용은 보내지 않아요.',
            '나 › AI에서 사용 지표 보내기를 켜면(기본은 꺼짐) 하루 한 번 날짜별 숫자(계획 화면을 봤는지, 계획을 확정했는지, 동기화 시도·성공 수, 설치 후 며칠째인지 등)를 보내요. 무작위 값도 붙이지 않고, 서버는 날짜별 합계에 더하기만 해요.',
            if (pushSignal) syncSignalPrivacyLine,
          ]),
          section('알아 둘 것', const [
            '꼭 허락해야 하는 권한은 없어요.',
            '로그인하거나 앱이 자동으로 다시 로그인하면 같은 계정으로 PC·웹에서 쓰던 LMS 세션이 끊길 수 있어요.',
            '로그아웃하면 학번·비밀번호와 LMS 로그인 정보, 불러온 시간표와 LMS 할 일을 지워요.',
          ]),
          const SizedBox(height: AppSpace.s16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () =>
                  showLegalDocument(context, LegalDocument.privacy),
              child: const Text('처리방침 전체 보기'),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인했어요'),
          ),
        ],
      ),
    );
  }
}
