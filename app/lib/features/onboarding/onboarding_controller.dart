// 온보딩의 단계와 동작. docs/screens.md '14 온보딩', docs/architecture.md '온보딩'.
//
// 다섯 단계(1 LMS 로그인 · 2 불러온 시간표 확인 · 3 고정 일정 · 4 AI 사용 동의 · 5 아침 브리핑 시각)이고,
// 5단계를 마치면 `shared_preferences`의 `onboarding_done`을 true로 두고 시작 위치(`/`)로 간다.
// '건너뛰기'는 3단계에만, 뒤로 가기는 3단계부터 있다. 건너뛴 단계는 `settings`의 `onboardingSkipped`에
// 단계 번호로 남는다(지금은 3만). 이 값을 쓰는 화면은 문서에 없다(홈 위 카드가 아님). 건너뛴 고정 일정은
// 나중에 10 나에서 넣는다. 로그아웃 뒤 다시 들어왔으면(`onboarding_done`이 이미 켜져 있음) 1단계에서
// 로그인하면 2–5단계 없이 시작 위치로 간다. debug 빌드에서는 1단계에 개발용 '로그인 없이 다음으로'가 있다
// ([OnboardingController.skipLoginForDev]).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:flutter/foundation.dart' show immutable, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 온보딩 단계. [number]는 문서의 단계 번호(1–5)다.
enum OnboardingStep {
  login(1, 'LMS 로그인'),
  timetable(2, '불러온 시간표 확인'),
  fixedBlocks(3, '고정 일정'),
  aiConsent(4, 'AI 사용 동의'),
  briefingTime(5, '아침 브리핑 시각');

  const OnboardingStep(this.number, this.title);

  /// 문서의 단계 번호. `onboardingSkipped`에 이 값을 적는다.
  final int number;

  /// 단계 이름.
  final String title;

  /// '건너뛰기'가 있는지(3단계만).
  bool get skippable => this == fixedBlocks;

  /// 앞 단계로 돌아갈 수 있는지(3단계부터). 2단계는 1단계 로그인으로 돌아가지 않는다.
  bool get canGoBack => number >= 3;

  /// 마지막 단계인지.
  bool get isLast => this == values.last;
}

/// 온보딩 화면의 상태.
@immutable
class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.login,
    this.reentry = false,
    this.busy = false,
  });

  /// 지금 단계.
  final OnboardingStep step;

  /// 로그아웃 뒤 다시 들어왔는지(`onboarding_done`이 이미 켜져 있음). 1단계에서 로그인하면 2–5단계 없이
  /// 시작 위치로 간다.
  final bool reentry;

  /// 저장 같은 일이 진행 중인지. 그동안에는 다음·건너뛰기·뒤로 가기를 받지 않는다.
  final bool busy;

  OnboardingState copyWith({OnboardingStep? step, bool? busy}) =>
      OnboardingState(
        step: step ?? this.step,
        reentry: reentry,
        busy: busy ?? this.busy,
      );
}

/// 온보딩 상태. 화면을 떠나면 처음으로 돌아간다.
final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

/// 온보딩 화면의 상태와 동작. 단계를 끝내는 동작은 온보딩을 끝냈으면 true를 돌려주고, 화면은 그때
/// 시작 위치로 간다.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => OnboardingState(
    reentry:
        ref.watch(sharedPreferencesProvider).getBool(PrefKeys.onboardingDone) ??
        false,
  );

  /// 지금 단계를 마치고 다음으로 간다. 앞에서 건너뛰었다가 돌아와 마쳤으면 건너뛴 목록에서 뺀다.
  Future<bool> next() => _whileBusy(_next);

  /// 지금 단계를 건너뛴다(3단계만). 건너뛸 수 없는 단계면 아무것도 하지 않는다.
  Future<bool> skip() {
    assert(state.step.skippable, '${state.step}는 건너뛸 수 없다');
    if (!state.step.skippable) return Future.value(false);
    return _whileBusy(() async {
      await _setSkipped(state.step, skipped: true);
      return _advance();
    });
  }

  /// 앞 단계로 돌아간다. 돌아갈 수 없는 단계(1·2단계)이거나 진행 중이면 아무것도 하지 않는다.
  void back() {
    if (state.busy || !state.step.canGoBack) return;
    state = state.copyWith(step: OnboardingStep.values[state.step.index - 1]);
  }

  /// '로그인 없이 둘러보기 · 샘플 학생의 하루': 데모 모드로 들어간다. 시작 위치로 가면 데모 DB를 보고
  /// 01 아침 브리핑이나 02 홈을 연다.
  Future<bool> browseDemo() => _whileBusy(() async {
    await ref.read(appModeProvider.notifier).enterDemo(DemoEntry.onboarding);
    return true;
  });

  /// 개발용 '로그인 없이 다음으로'(debug 빌드에서만, docs/decisions.md 2026-11-06 '개발 중에는 debug
  /// 빌드에만 로그인 없이 넘어가는 길을 둔다'). LMS에 요청하지 않고 LMS 상태를 `active`로 쓴 뒤 1단계
  /// 로그인을 마친 것처럼 간다. 시작 위치 규칙은 실제 모드에서 LMS 상태가 `disconnected`면 온보딩으로
  /// 돌려보내므로, LMS 로그인이 붙기 전에 기기에서 실제 모드 화면을 보려면 이 길이 있어야 한다.
  /// release·profile 빌드에서는 아무것도 하지 않는다. 상태를 쓰지 못하면 이 단계에 머문다.
  ///
  /// 온보딩은 실제 모드에서만 열리므로 [settingsRepositoryProvider]가 LMS 상태를 두는 실제 DB다.
  Future<bool> skipLoginForDev() async {
    if (!kDebugMode) return false;
    return _whileBusy(() async {
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
      // 로그아웃 뒤 다시 들어왔으면 2–5단계를 다시 거치지 않는다.
      if (state.reentry) return true;
      return _next();
    });
  }

  Future<bool> _next() async {
    await _setSkipped(state.step, skipped: false);
    return _advance();
  }

  Future<bool> _advance() async {
    if (!ref.mounted) return false;
    if (!state.step.isLast) {
      state = state.copyWith(step: OnboardingStep.values[state.step.index + 1]);
      return false;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.onboardingDone, true);
    return true;
  }

  /// [action]을 하는 동안 [OnboardingState.busy]를 켠다. 이미 진행 중이면 하지 않고 false다.
  Future<bool> _whileBusy(Future<bool> Function() action) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      return await action();
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// 건너뛴 단계 목록을 고친다. 폰 DB를 읽거나 쓰지 못하면 기록만 남기고 온보딩은 계속한다
  /// (이 값을 쓰는 화면이 없으므로 온보딩을 막지 않는다).
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
