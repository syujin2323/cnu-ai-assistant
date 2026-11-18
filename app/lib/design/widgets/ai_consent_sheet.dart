// AI 사용 동의 시트. docs/screens.md 'AI 사용 동의'.
//
// AI가 꺼진 상태에서 AI를 켜려 할 때(10 나 › AI 사용. 06 AI 비서·12 '말로 정하기'·07 켜기도 같은 시트를 쓴다)
// 공용 문구 [AiConsentBody]로 묻는다. 동의를 적는 것(`settings`의 `aiEnabled` true와 `aiConsentAt`)은 부르는
// 쪽이 한다. '동의 문구 다시 보기'는 버튼 하나로 같은 문구를 보인다. 문구는 디자인 전 임시 문구다.

import 'package:cnu_ai_assistant/design/motion.dart';
import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:cnu_ai_assistant/design/widgets/ai_consent_body.dart';
import 'package:cnu_ai_assistant/design/widgets/app_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// AI 사용 동의를 묻는다. [동의하고 켜기]면 true, [동의하지 않음]이나 닫으면 false다.
Future<bool> showAiConsentSheet(
  BuildContext context,
  MotionLevel motion,
) async =>
    await showAppSheet<bool>(
      context: context,
      motion: motion,
      builder: (context) => const _AiConsentSheet(ask: true),
    ) ??
    false;

/// 동의 문구를 다시 보인다. [consentedOn]이 있으면 제목 아래에 '{날짜}에 동의했어요'를 둔다.
Future<void> showAiConsentReview(
  BuildContext context,
  MotionLevel motion, {
  String? consentedOn,
}) => showAppSheet<void>(
  context: context,
  motion: motion,
  builder: (context) => _AiConsentSheet(ask: false, consentedOn: consentedOn),
);

class _AiConsentSheet extends StatelessWidget {
  const _AiConsentSheet({required this.ask, this.consentedOn});

  /// 동의를 묻는지(아니면 다시 보기).
  final bool ask;

  /// 다시 보기에서 동의한 날('11월 18일').
  final String? consentedOn;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lead = ask
        ? 'AI 비서에게 말로 일정·할 일·규칙을 넣을 때 쓰는 기능이에요. 쓰려면 동의가 필요해요.'
        : consentedOn == null
        ? null
        : '$consentedOn에 동의했어요';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.s4,
        AppSpace.screen,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(ask ? 'AI를 쓸까요?' : 'AI에 보내는 것', style: AppText.title),
          ),
          if (lead != null) ...[
            const SizedBox(height: AppSpace.s4),
            Text(lead, style: AppText.small.copyWith(color: colors.muted)),
          ],
          const AiConsentBody(),
          const SizedBox(height: AppSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ask ? true : null),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(ask ? '동의하고 켜기' : '확인'),
          ),
          if (ask) ...[
            const SizedBox(height: AppSpace.s8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSize.minTouch),
              ),
              child: const Text('동의하지 않음'),
            ),
          ],
        ],
      ),
    );
  }
}
