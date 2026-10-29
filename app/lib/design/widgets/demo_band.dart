// 데모 모드 띠. docs/architecture.md '데모 모드'.
//
// 데모 모드인 동안 모든 화면 위에 늘 보여 준다. '끝내기'를 누르면 데모 DB를 지우고 들어온
// 곳으로 돌아간다(그 동작은 `app/app.dart`가 [onExit]로 넘긴다). 이 띠는 앱의 Navigator
// 바깥(`MaterialApp.builder`)에 놓이므로 Overlay가 필요한 tooltip 대신 Semantics를 쓴다.

import 'package:cnu_ai_assistant/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// 화면 맨 위의 '데모 · 샘플 학생의 하루' 띠와 '끝내기' 버튼.
class DemoBand extends StatelessWidget {
  const DemoBand({super.key, required this.onExit});

  /// '끝내기'를 눌렀을 때.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final onInk = AppColors.bg;
    return Material(
      color: AppColors.bg,
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
                  color: AppColors.ink,
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
                          '데모 · 샘플 학생의 하루',
                          style: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                            color: onInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      TextButton(
                        onPressed: onExit,
                        style: TextButton.styleFrom(
                          foregroundColor: onInk,
                          minimumSize: const Size(
                            AppSize.minTouch,
                            AppSize.minTouch,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: AppText.small.copyWith(
                            fontWeight: AppText.semibold,
                          ),
                        ),
                        child: const Text('끝내기'),
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
