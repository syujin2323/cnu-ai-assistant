// 온보딩의 단계와 동작. docs/architecture.md '온보딩'.
//
// 단계는 문서의 순서이고 모두 건너뛸 수 있다. 건너뛴 단계는 `settings`의 `onboardingSkipped`에
// 단계 번호로 남아 홈 위 카드가 되고, 온보딩을 끝내면 `shared_preferences`의
// `onboarding_done`을 true로 둔다. LMS 연결 단계는 `LmsFeature.included`일 때만 있다.
// debug 빌드에서는 그 단계에 개발용 '로그인 없이 다음으로'가 있다([OnboardingController.skipLoginForDev]).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/lms/lms_feature.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 온보딩 단계. [number]는 문서의 단계 번호(1–8)다.
enum OnboardingStep {
  intro(1, '시작'),
  privacy(2, '개인정보 한 장'),
  lmsConnect(3, 'LMS 연결'),
  timetable(4, '시간표'),
  fixedBlocks(5, '고정 일정'),
  aiConsent(6, 'AI 사용 동의'),
  briefingTime(7, '브리핑과 알림'),
  firstBriefing(8, '첫 브리핑 미리보기');

  const OnboardingStep(this.number, this.title);

  /// 문서의 단계 번호. `onboardingSkipped`에 이 값을 적는다.
  final int number;

  /// 단계 이름.
  final String title;

  /// 이 빌드에서 보여 줄 단계(순서대로).
  static List<OnboardingStep> get active => [
    for (final step in values)
      if (step != lmsConnect || LmsFeature.included) step,
  ];
}

/// 지금 보고 있는 단계의 위치([OnboardingStep.active] 안의 순서). 화면을 떠나면 처음으로 돌아간다.
final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, int>(
      OnboardingController.new,
    );

/// 온보딩 화면의 상태와 동작.
class OnboardingController extends Notifier<int> {
  @override
  int build() => 0;

  /// 지금 단계.
  OnboardingStep get current => OnboardingStep.active[state];

  /// 지금 단계를 마치고 다음으로 간다. 앞에서 건너뛰었다가 돌아와 마쳤으면 건너뛴 목록에서 뺀다.
  /// 마지막 단계였으면 온보딩을 끝내고 true를 돌려준다.
  Future<bool> next() async {
    await _setSkipped(current, skipped: false);
    return _advance();
  }

  /// 지금 단계를 건너뛴다. 마지막 단계였으면 온보딩을 끝내고 true를 돌려준다.
  Future<bool> skip() async {
    await _setSkipped(current, skipped: true);
    return _advance();
  }

  /// 개발용 '로그인 없이 다음으로'(debug 빌드에서만, docs/decisions.md 2026-11-06 '개발 중에는 debug
  /// 빌드에만 로그인 없이 넘어가는 길을 둔다'). LMS에 요청하지 않고 LMS 상태를 `active`로 쓴 뒤 다음
  /// 단계로 간다. 시작 위치 규칙은 실제 모드에서 LMS 상태가 `disconnected`면 온보딩을 끝내도 다시
  /// 온보딩으로 보내므로, LMS 로그인이 붙기 전에 기기에서 실제 모드 화면을 보려면 이 길이 있어야 한다.
  /// release·profile 빌드에서는 아무것도 하지 않는다. 상태를 쓰지 못하면 이 단계에 머문다.
  ///
  /// 온보딩은 실제 모드에서만 열리므로 [settingsRepositoryProvider]가 LMS 상태를 두는 실제 DB다.
  Future<bool> skipLoginForDev() async {
    if (!kDebugMode) return false;
    final written = await ref
        .read(settingsRepositoryProvider)
        .write(SettingKeys.lmsSessionState, LmsSessionState.active);
    if (written case Err(:final error)) {
      appLog(
        'onboarding_dev_login_skip_failed',
        area: 'onboarding',
        data: {'error': error.toString()},
      );
      return false;
    }
    if (!ref.mounted) return false;
    return next();
  }

  /// 앞 단계로 돌아간다. 첫 단계면 아무것도 하지 않는다.
  void back() {
    if (state > 0) state = state - 1;
  }

  Future<bool> _advance() async {
    if (!ref.mounted) return false;
    if (state < OnboardingStep.active.length - 1) {
      state = state + 1;
      return false;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.onboardingDone, true);
    return true;
  }

  /// 건너뛴 단계 목록을 고친다. 폰 DB를 읽거나 쓰지 못하면 기록만 남기고 온보딩은 계속한다
  /// (건너뛴 단계는 홈 위 카드로만 쓰이므로 온보딩을 막지 않는다).
  Future<void> _setSkipped(OnboardingStep step, {required bool skipped}) async {
    final repository = ref.read(settingsRepositoryProvider);
    final List<int> saved;
    switch (await repository.read()) {
      case Ok(:final value):
        saved = value.onboardingSkipped;
      case Err(:final error):
        _logStorageFailure(error);
        return;
    }
    if (saved.contains(step.number) == skipped) return;
    final numbers = {...saved};
    if (skipped) {
      numbers.add(step.number);
    } else {
      numbers.remove(step.number);
    }
    final written = await repository.write(
      SettingKeys.onboardingSkipped,
      numbers.toList()..sort(),
    );
    if (written case Err(:final error)) _logStorageFailure(error);
  }

  static void _logStorageFailure(AppError error) => appLog(
    'onboarding_skipped_save_failed',
    area: 'onboarding',
    data: {'error': error.toString()},
  );
}
