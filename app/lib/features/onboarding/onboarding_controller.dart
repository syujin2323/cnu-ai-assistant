// 온보딩의 단계와 동작. docs/screens.md '14 온보딩', docs/architecture.md '온보딩'.
//
// 다섯 단계(1 LMS 로그인 · 2 불러온 시간표 확인 · 3 고정 일정 · 4 AI 사용 동의 · 5 아침 브리핑 시각)이고,
// 5단계를 마치면 `shared_preferences`의 `onboarding_done`을 true로 두고 시작 위치(`/`)로 간다.
// '건너뛰기'는 3단계에만, 뒤로 가기는 3단계부터 있다. 건너뛴 단계는 `settings`의 `onboardingSkipped`에
// 단계 번호로 남는다(지금은 3만). 이 값을 쓰는 화면은 문서에 없다(홈 위 카드가 아님). 건너뛴 고정 일정은
// 나중에 10 나에서 넣는다. 로그아웃 뒤 다시 들어왔으면(`onboarding_done`이 이미 켜져 있음) 1단계에서
// 로그인하면 2–5단계 없이 시작 위치로 간다([OnboardingController.loggedIn]). 처음 온보딩에서 로그인한 뒤
// 끝내기 전에 앱이 꺼졌으면 다음에 열 때 2단계부터 연다(다시 로그인하지 않음, docs/decisions.md 2026-11-13
// '로그인한 뒤 온보딩 도중 앱이 꺼지면 2단계부터 연다'). 그래서 처음 열 때 `settings`를 한 번 읽고, 읽기가
// 끝나기 전에는 상태가 없다. 4단계는 `aiEnabled`·`aiConsentAt`을, 5단계는 브리핑 시각을 내 규칙
// (`notify`)으로 쓴다. debug 빌드에서는 1단계에 개발용 '로그인 없이 다음으로'가 있다
// ([OnboardingController.skipLoginForDev]).

import 'package:cnu_ai_assistant/app/logging.dart';
import 'package:cnu_ai_assistant/app/providers.dart';
import 'package:cnu_ai_assistant/domain/errors.dart';
import 'package:cnu_ai_assistant/domain/models/app_settings.dart';
import 'package:cnu_ai_assistant/domain/models/entry_source.dart';
import 'package:cnu_ai_assistant/domain/models/lms_session_state.dart';
import 'package:cnu_ai_assistant/domain/models/rule.dart';
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

/// 온보딩 상태. 화면을 떠나면 처음으로 돌아간다. 처음 열 때 시작 단계를 정하려고 `settings`를 한 번
/// 읽으므로, 그동안은 불러오는 중이다.
final onboardingControllerProvider =
    AsyncNotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

/// 온보딩 화면의 상태와 동작. 단계를 끝내는 동작은 온보딩을 끝냈으면 true를 돌려주고, 화면은 그때
/// 시작 위치로 간다. 처음 읽기가 끝나기 전에는 동작하지 않는다(false).
class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    final reentry =
        ref.watch(sharedPreferencesProvider).getBool(PrefKeys.onboardingDone) ??
        false;
    return OnboardingState(
      step: reentry ? OnboardingStep.login : await _firstStep(),
      reentry: reentry,
    );
  }

  /// 처음 온보딩에서 열 단계. 로그인한 뒤(LMS 상태가 로그인 전(`disconnected`·`connecting`)이 아님) 끝내기 전에
  /// 앱이 꺼졌으면 2단계, 아니면 1단계다. 로그인에 실패해 `connecting`으로 남은 채 둘러보기 → 끝내기로 돌아와도
  /// 1단계다(docs/decisions.md 2026-11-14 '로그인하는 중은 로그인 전으로 본다'). `settings`를 읽지 못하면 1단계다.
  Future<OnboardingStep> _firstStep() async {
    switch (await ref.read(settingsRepositoryProvider).read()) {
      case Ok(:final value):
        return value.lmsSessionState.beforeLogin
            ? OnboardingStep.login
            : OnboardingStep.timetable;
      case Err(:final error):
        appLog(
          'onboarding_start_read_failed',
          area: 'onboarding',
          data: errorLogData(error),
        );
        return OnboardingStep.login;
    }
  }

  /// 지금 상태. 처음 읽기가 끝나기 전에는 null이다.
  OnboardingState? get _current => state.value;

  set _current(OnboardingState? next) {
    if (next != null) state = AsyncData(next);
  }

  /// 지금 단계를 마치고 다음으로 간다. 앞에서 건너뛰었다가 돌아와 마쳤으면 건너뛴 목록에서 뺀다.
  Future<bool> next() => _whileBusy(_next);

  /// 지금 단계를 건너뛴다(3단계만). 건너뛸 수 없는 단계면 아무것도 하지 않는다.
  Future<bool> skip() {
    final step = _current?.step;
    if (step == null) return Future.value(false);
    assert(step.skippable, '$step는 건너뛸 수 없다');
    if (!step.skippable) return Future.value(false);
    return _whileBusy(() async {
      await _setSkipped(step, skipped: true);
      return _advance();
    });
  }

  /// 앞 단계로 돌아간다. 돌아갈 수 없는 단계(1·2단계)이거나 진행 중이면 아무것도 하지 않는다.
  void back() {
    final current = _current;
    if (current == null || current.busy || !current.step.canGoBack) return;
    _current = current.copyWith(
      step: OnboardingStep.values[current.step.index - 1],
    );
  }

  /// 4단계 '동의하고 계속': AI를 켜고 동의 시각을 적은 뒤 다음 단계로 간다. 저장하지 못해도 기록만 남기고
  /// 계속한다(AI는 꺼진 채로 남아 AI 기능을 쓰려 할 때 다시 묻는다).
  Future<bool> consentToAi() => _whileBusy(() async {
    await _writeSettings({
      SettingKeys.aiEnabled: true,
      SettingKeys.aiConsentAt: ref.read(clockProvider).now(),
    });
    return _next();
  });

  /// 4단계 '동의하지 않고 계속': `aiEnabled` false만 쓰고 다음 단계로 간다(docs/decisions.md 2026-11-06
  /// 'AI 사용 동의는 선택 동의다'). 저장하지 못해도 계속한다(기본값도 꺼짐).
  Future<bool> declineAi() => _whileBusy(() async {
    await _writeSettings({SettingKeys.aiEnabled: false});
    return _next();
  });

  /// 5단계 '다음': 고른 브리핑 시각([briefingMin], 자정 기준 분)을 내 규칙 `notify`(`source` `manual`)로
  /// 저장하고 온보딩을 끝낸다. `notify`는 하나만 두는 종류라 이미 있으면 그 행에 합친다. 저장하지 못해도
  /// 기록만 남기고 끝낸다(브리핑 시각은 기본값을 씀). [briefingMin]은 브리핑 칩의 값이다.
  Future<bool> finishWithBriefingTime(int briefingMin) => _whileBusy(() async {
    final saved = await ref
        .read(rulesRepositoryProvider)
        .save(
          kind: RuleKind.notify,
          params: RuleParams(briefingMin: briefingMin),
          source: EntrySource.manual,
          now: ref.read(clockProvider).now(),
        );
    if (saved case Err(:final error)) {
      appLog(
        'onboarding_briefing_time_save_failed',
        area: 'onboarding',
        data: errorLogData(error),
      );
    }
    return _next();
  });

  /// 1단계 로그인을 마쳤을 때(로그인 폼이 진행 줄을 끝낸 뒤). 로그아웃 뒤 다시 들어왔으면 2–5단계 없이
  /// 시작 위치로 가고(true), 아니면 2단계로 간다. LMS 상태와 학번·비밀번호는 로그인 흐름이 이미 썼다.
  Future<bool> loggedIn() => _whileBusy(_afterLogin);

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
          data: errorLogData(error),
        );
        return false;
      }
      return _afterLogin();
    });
  }

  /// 1단계 로그인 뒤. 로그아웃 뒤 다시 들어왔으면 2–5단계를 다시 거치지 않는다.
  Future<bool> _afterLogin() async {
    final current = _current;
    if (!ref.mounted || current == null) return false;
    if (current.reentry) return true;
    return _next();
  }

  Future<bool> _next() async {
    final step = _current?.step;
    if (step == null) return false;
    await _setSkipped(step, skipped: false);
    return _advance();
  }

  Future<bool> _advance() async {
    final current = _current;
    if (!ref.mounted || current == null) return false;
    if (!current.step.isLast) {
      _current = current.copyWith(
        step: OnboardingStep.values[current.step.index + 1],
      );
      return false;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.onboardingDone, true);
    return true;
  }

  /// [action]을 하는 동안 [OnboardingState.busy]를 켠다. 이미 진행 중이면 하지 않고 false다.
  Future<bool> _whileBusy(Future<bool> Function() action) async {
    final current = _current;
    if (current == null || current.busy) return false;
    _current = current.copyWith(busy: true);
    try {
      return await action();
    } finally {
      if (ref.mounted) _current = _current?.copyWith(busy: false);
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

  /// 설정 여러 키를 한 번에 쓴다. 쓰지 못하면 기록만 남긴다.
  Future<void> _writeSettings(Map<String, Object?> values) async {
    final written = await ref.read(settingsRepositoryProvider).writeAll(values);
    if (written case Err(:final error)) {
      appLog(
        'onboarding_settings_save_failed',
        area: 'onboarding',
        data: {'count': values.length, ...errorLogData(error)},
      );
    }
  }

  static void _logStorageFailure(AppError error) => appLog(
    'onboarding_skipped_save_failed',
    area: 'onboarding',
    data: errorLogData(error),
  );
}
