// AI 사용 동의 문구. docs/screens.md 'AI 사용 동의'.
//
// 14 온보딩 4단계, AI가 꺼진 상태에서 AI 기능(06 AI 비서, 12 '말로 정하기', 07 켜기)을 쓰려 할 때, 10 나 ›
// AI 켜기가 같은 내용을 보인다(버튼은 쓰는 쪽이 둔다). 실제로 보내는 항목만 적고(07 알림 감지 조각은 그
// 기능이 들어가는 R1 빌드부터), 제공사 이름·나라·보관 기간·학습 여부는 AI 모델을 정할 때 넣는다(CLAUDE.md
// '아직 정하지 않은 것'). 보관 일수와 학습하지 않는다는 약속은 쓰지 않는다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// AI 사용 동의 문구.
class AiConsentBody extends StatelessWidget {
  const AiConsentBody({super.key});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('보내는 것', const ['AI 비서에 쓴 문장, 과목 이름·별칭, 오늘 날짜·요일·지금 시각을 보내요.']),
        section('가는 곳', const [
          '앱 서버(서울 리전)를 거쳐 해외 AI 제공사로 가요. 앱은 이 내용을 일정·할 일·규칙으로 바꾸고 질문을 읽는 데 써요.',
          '앱 서버는 문장을 저장하거나 로그에 남기지 않아요.',
        ]),
        section('알아 둘 것', const [
          '동의하기 전에는 아무것도 보내지 않아요.',
          '하루에 쓸 수 있는 횟수가 정해져 있어요.',
          '동의하지 않아도 일정·할 일은 직접 넣을 수 있고, 나 › AI에서 언제든 바꿀 수 있어요.',
        ]),
      ],
    );
  }
}
