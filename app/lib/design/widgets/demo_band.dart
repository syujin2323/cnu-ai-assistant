// 데모 모드 띠. docs/architecture.md '데모 모드'.
//
// 데모 모드인 동안 모든 화면 위에 늘 보여 준다. '끝내기'를 누르면 데모 DB를 비우고 들어온
// 곳으로 돌아간다(그 동작은 `app/app.dart`가 [onExit]로 넘긴다). 끝내는 동안은 버튼을 막고, 데모 DB를
// 비우지 못하면 그 안내와 '다시 시도'를 보인다(디자인 전 임시 문구). 이 띠는 앱의 Navigator
// 바깥(`MaterialApp.builder`)에 놓이므로 Overlay가 필요한 tooltip 대신 Semantics를 쓴다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 화면 맨 위의 '데모 · 샘플 학생의 하루' 띠와 '끝내기' 버튼.
class DemoBand extends StatelessWidget {
  const DemoBand({
    super.key,
    required this.onExit,
    this.exiting = false,
    this.failed = false,
  });

  /// '끝내기'(실패 뒤에는 '다시 시도')를 눌렀을 때.
  final VoidCallback onExit;

  /// 끝내는 중이면 버튼을 막는다.
  final bool exiting;

  /// 데모 DB를 비우지 못해 끝내지 못했으면 그 안내와 '다시 시도'를 보인다.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onInk = colors.bg;
    return Material(
      color: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.screen,
            vertical: AppSpace.s8,
          ),
          child: Center(
            child: Semantics(
              container: true,
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.s16,
                    right: AppSpace.s4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          failed ? '데모를 끝내지 못했어요' : '데모 · 샘플 학생의 하루',
                          style: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                            color: onInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      TextButton(
                        onPressed: exiting ? null : onExit,
                        style: TextButton.styleFrom(
                          foregroundColor: onInk,
                          // 끝내는 동안 막은 버튼의 글자. 정하지 않으면 Material 기본 비활성색(ink 38%)이 되어
                          // 같은 ink인 띠 배경에 묻힌다.
                          disabledForegroundColor: colors.faint,
                          minimumSize: const Size(
                            AppSize.minTouch,
                            AppSize.minTouch,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                          ),
                        ),
                        child: Text(failed ? '다시 시도' : '끝내기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
